/// Sync protocol (S15 spike -> S16 contract, docs/decisions/002-sync-backend.md).
///
/// Pure Dart: HLC, per-field merge rules, and an in-memory reference server
/// that defines what a real backend must do. The Drift-backed client engine
/// lives in `application/sync_engine.dart`.
library;

import 'package:meta/meta.dart';

// ---------------------------------------------------------------- clock

/// Hybrid logical clock stamp: wall time, counter, node id (total order).
@immutable
class Hlc implements Comparable<Hlc> {
  const Hlc(this.wallMs, this.counter, this.node);

  final int wallMs;
  final int counter;
  final String node;

  @override
  int compareTo(Hlc other) {
    final w = wallMs.compareTo(other.wallMs);
    if (w != 0) return w;
    final c = counter.compareTo(other.counter);
    if (c != 0) return c;
    return node.compareTo(other.node);
  }

  bool operator >(Hlc o) => compareTo(o) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc && other.wallMs == wallMs && other.counter == counter && other.node == node;

  @override
  int get hashCode => Object.hash(wallMs, counter, node);

  @override
  String toString() => '$wallMs:$counter:$node';

  String encode() => toString();

  static Hlc parse(String s) {
    final i = s.indexOf(':');
    final j = s.indexOf(':', i + 1);
    return Hlc(int.parse(s.substring(0, i)), int.parse(s.substring(i + 1, j)), s.substring(j + 1));
  }
}

class HlcClock {
  HlcClock(this.node, this._wallMs);

  final String node;
  final int Function() _wallMs;
  int _lastWall = 0;
  int _counter = 0;

  /// Stamp for a local event; always greater than anything seen so far.
  Hlc tick() {
    final w = _wallMs();
    if (w > _lastWall) {
      _lastWall = w;
      _counter = 0;
    } else {
      _counter++;
    }
    return Hlc(_lastWall, _counter, node);
  }

  /// Stamp an edit that happened at [wallMs] (the row's own `updated_at`),
  /// never earlier than anything already issued or seen.
  Hlc tickAt(int wallMs) {
    if (wallMs > _lastWall) {
      _lastWall = wallMs;
      _counter = 0;
    } else {
      _counter++;
    }
    return Hlc(_lastWall, _counter, node);
  }

  /// Absorb a remote stamp so later local edits order after it, even when
  /// this device's wall clock is behind.
  void receive(Hlc remote) {
    final w = _wallMs();
    final maxWall = [w, _lastWall, remote.wallMs].reduce((a, b) => a > b ? a : b);
    if (maxWall == _lastWall && maxWall == remote.wallMs) {
      _counter = (_counter > remote.counter ? _counter : remote.counter) + 1;
    } else if (maxWall == _lastWall) {
      _counter++;
    } else if (maxWall == remote.wallMs) {
      _counter = remote.counter + 1;
    } else {
      _counter = 0;
    }
    _lastWall = maxWall;
  }
}

// ----------------------------------------------------------- data model

@immutable
class Versioned {
  const Versioned(this.value, this.hlc);
  final Object? value;
  final Hlc hlc;

  @override
  bool operator ==(Object other) =>
      other is Versioned && other.value == value && other.hlc == hlc;

  @override
  int get hashCode => Object.hash(value, hlc);

  @override
  String toString() => '$value@$hlc';
}

/// How a table resolves concurrent writes.
enum TablePolicy {
  /// Per-field last-writer-wins by HLC (customers, orders' editable fields).
  lww,

  /// Money events: rows are insert-once; only monotonic fields may change
  /// afterwards (e.g. payout status active -> reversed).
  appendOnly,
}

class TableSpec {
  const TableSpec(
    this.policy, {
    this.synced = const {},
    this.excluded = const {},
    this.monotonic = const {},
    this.writeRoles = const {'owner', 'manager', 'helper'},
  });

  final TablePolicy policy;

  /// Columns that sync. Anything else (derived ledger/profit caches) stays
  /// local and is recomputed after merge. Empty = every field.
  final Set<String> synced;

  /// Columns that never sync (derived caches, order status: it is derived
  /// from the append-only status events).
  final Set<String> excluded;

  bool carries(String field) =>
      !excluded.contains(field) && (synced.isEmpty || synced.contains(field));

  /// field -> allowed values in increasing rank; a higher rank always wins.
  final Map<String, List<String>> monotonic;

  /// Roles allowed to push this table (RLS analogue).
  final Set<String> writeRoles;
}

/// Spike schema: 3 tables, one of them a money event.
const kSpikeSchema = <String, TableSpec>{
  'customers': TableSpec(TablePolicy.lww),
  'orders': TableSpec(
    TablePolicy.lww,
    synced: {
      'order_no',
      'customer_id',
      'status',
      'address',
      'cod_expected',
      'cod_collected',
      'notes',
      'deleted_at',
    },
  ),
  'payouts': TableSpec(
    TablePolicy.appendOnly,
    monotonic: {
      'status': ['active', 'reversed'],
    },
    writeRoles: {'owner', 'manager'},
  ),
  'payout_allocations': TableSpec(
    TablePolicy.appendOnly,
    writeRoles: {'owner', 'manager'},
  ),
};

@immutable
class RowState {
  const RowState(this.table, this.id, this.shopId, this.fields);

  final String table;
  final String id;
  final String shopId;
  final Map<String, Versioned> fields;

  Object? operator [](String f) => fields[f]?.value;

  Map<String, Object?> get values => {for (final e in fields.entries) e.key: e.value.value};
}

/// Merge [incoming] fields into [current] under [spec]. Commutative,
/// associative and idempotent per field, so replicas converge in any order.
/// Returns null when nothing changed.
Map<String, Versioned>? mergeFields(
  TableSpec spec,
  Map<String, Versioned> current,
  Map<String, Versioned> incoming, {
  List<String>? rejected,
}) {
  var changed = false;
  final out = Map<String, Versioned>.of(current);
  for (final e in incoming.entries) {
    final f = e.key;
    final inc = e.value;
    final cur = out[f];
    if (cur == null) {
      out[f] = inc;
      changed = true;
      continue;
    }
    if (spec.policy == TablePolicy.appendOnly) {
      final ranks = spec.monotonic[f];
      if (ranks == null) {
        // Insert-once field. null -> value is allowed once (a return being
        // received); among non-null values the earliest writer (lowest HLC)
        // wins on every replica regardless of arrival order. A different
        // later value is a protocol violation: kept out and reported.
        if (cur.value == null && inc.value != null) {
          out[f] = inc;
          changed = true;
          continue;
        }
        if (inc.value == null) continue;
        if (inc.hlc.compareTo(cur.hlc) < 0) {
          if (cur.value != inc.value) rejected?.add(f);
          out[f] = inc;
          changed = true;
        } else if (cur.value != inc.value) {
          rejected?.add(f);
        }
        continue;
      }
      final cr = ranks.indexOf('${cur.value}');
      final ir = ranks.indexOf('${inc.value}');
      if (ir > cr || (ir == cr && inc.hlc > cur.hlc)) {
        out[f] = inc;
        changed = true;
      }
      continue;
    }
    if (inc.hlc > cur.hlc) {
      out[f] = inc;
      changed = true;
    }
  }
  return changed ? out : null;
}

// ------------------------------------------------------------ messages

@immutable
class Change {
  const Change({
    required this.changeId,
    required this.table,
    required this.rowId,
    required this.shopId,
    required this.fields,
  });

  /// Client-generated id (UUID v7 in the app): makes push idempotent.
  final String changeId;
  final String table;
  final String rowId;
  final String shopId;
  final Map<String, Versioned> fields;
}

@immutable
class Principal {
  const Principal({required this.userId, required this.shopId, required this.role});
  final String userId;
  final String shopId;
  final String role;
}

@immutable
class PushResult {
  const PushResult({
    this.accepted = const [],
    this.duplicates = const [],
    this.rejected = const {},
    this.lost = const {},
  });

  /// changeId -> fields where this change lost to a different existing value
  /// (LWW overwritten): the client shows these in its conflict log.
  final Map<String, List<String>> lost;

  final List<String> accepted;
  final List<String> duplicates;

  /// changeId -> reason (`forbidden_role`, `wrong_shop`, `unknown_table`,
  /// `immutable_field:<f>`).
  final Map<String, String> rejected;
}

@immutable
class PullResult {
  const PullResult(this.rows, this.cursor, this.hasMore);
  final List<RowState> rows;
  final int cursor;
  final bool hasMore;
}

// --------------------------------------------------------------- server

/// Server model of what Postgres would do: a row store, a monotonically
/// increasing `server_seq` per change, an idempotency log, RLS-like checks.
class SyncServer {
  SyncServer({Map<String, TableSpec> schema = kSpikeSchema}) : _schema = schema;

  final Map<String, TableSpec> _schema;
  final Map<String, RowState> _rows = {};
  final Map<String, int> _rowSeq = {};
  final Set<String> _seenChanges = {};
  int _seq = 0;

  int get seq => _seq;

  /// Monotonic version assigned by the server (spec: `server_version`).
  int get serverVersion => _seq;

  RowState? row(String table, String id) => _rows['$table/$id'];

  List<RowState> get allRows => _rows.values.toList();

  PushResult push(Principal who, String deviceId, List<Change> batch) {
    final accepted = <String>[];
    final dups = <String>[];
    final rejected = <String, String>{};
    final lost = <String, List<String>>{};
    for (final c in batch) {
      final key = '$deviceId/${c.changeId}';
      if (_seenChanges.contains(key)) {
        dups.add(c.changeId);
        continue;
      }
      final spec = _schema[c.table];
      if (spec == null) {
        rejected[c.changeId] = 'unknown_table';
        continue;
      }
      if (c.shopId != who.shopId) {
        rejected[c.changeId] = 'wrong_shop';
        continue;
      }
      if (!spec.writeRoles.contains(who.role)) {
        rejected[c.changeId] = 'forbidden_role';
        continue;
      }
      _seenChanges.add(key);
      accepted.add(c.changeId);
      final rowKey = '${c.table}/${c.rowId}';
      final current = _rows[rowKey]?.fields ?? const <String, Versioned>{};
      final bad = <String>[];
      final incoming = {
        for (final e in c.fields.entries)
          if (spec.carries(e.key)) e.key: e.value,
      };
      if (spec.policy == TablePolicy.lww) {
        for (final e in incoming.entries) {
          final cur = current[e.key];
          if (cur != null && cur.hlc > e.value.hlc && cur.value != e.value.value) {
            lost.putIfAbsent(c.changeId, () => []).add(e.key);
          }
        }
      }
      final merged = mergeFields(spec, current, incoming, rejected: bad);
      if (bad.isNotEmpty) rejected[c.changeId] = 'immutable_field:${bad.first}';
      if (merged != null) {
        _rows[rowKey] = RowState(c.table, c.rowId, c.shopId, merged);
        _rowSeq[rowKey] = ++_seq;
      }
    }
    return PushResult(accepted: accepted, duplicates: dups, rejected: rejected, lost: lost);
  }

  /// Row counts per table for a shop (restore-style preview before choosing
  /// "replace with cloud"). Tombstoned rows are not counted.
  Map<String, int> summary(Principal who) {
    final out = <String, int>{};
    for (final r in _rows.values) {
      if (r.shopId != who.shopId || r['deleted_at'] != null) continue;
      out[r.table] = (out[r.table] ?? 0) + 1;
    }
    return out;
  }

  /// Rows changed after [since] in this shop, oldest change first.
  PullResult pull(Principal who, int since, {int limit = 100}) {
    final changed = [
      for (final e in _rowSeq.entries)
        if (e.value > since && _rows[e.key]!.shopId == who.shopId) e,
    ]..sort((a, b) => a.value.compareTo(b.value));
    final page = changed.take(limit).toList();
    return PullResult(
      [for (final e in page) _rows[e.key]!],
      page.isEmpty ? since : page.last.value,
      changed.length > page.length,
    );
  }
}

// --------------------------------------------------------------- device

/// One device: local rows, HLC, an outbox of unsent changes and a pull
/// cursor. Derived columns never leave the device (stripped on push).
class SyncDevice {
  SyncDevice({
    required this.deviceId,
    required this.principal,
    required int Function() wallMs,
    Map<String, TableSpec> schema = kSpikeSchema,
  })  : _clock = HlcClock(deviceId, wallMs),
        _schema = schema;

  final String deviceId;
  final Principal principal;
  final HlcClock _clock;
  final Map<String, TableSpec> _schema;

  final Map<String, RowState> rows = {};
  final List<Change> _outbox = [];
  int cursor = 0;
  var _n = 0;

  int get pending => _outbox.length;

  @visibleForTesting
  List<Change> get outboxForTest => List.of(_outbox);

  RowState? row(String table, String id) => rows['$table/$id'];

  /// Local edit (insert or update some fields).
  void edit(String table, String id, Map<String, Object?> values) {
    final stamp = _clock.tick();
    final fields = {for (final e in values.entries) e.key: Versioned(e.value, stamp)};
    final spec = _schema[table]!;
    final key = '$table/$id';
    final cur = rows[key]?.fields ?? const <String, Versioned>{};
    final merged = mergeFields(spec, cur, fields);
    if (merged != null) {
      rows[key] = RowState(table, id, principal.shopId, merged);
    }
    _outbox.add(Change(
      changeId: '$deviceId-${_n++}',
      table: table,
      rowId: id,
      shopId: principal.shopId,
      fields: fields,
    ));
  }

  /// Push the outbox, then pull until caught up. [lossy] simulates a lost
  /// response: the server applied the push but the client saw no ack.
  void sync(SyncServer server, {bool lossy = false, int pageSize = 100}) {
    if (_outbox.isNotEmpty) {
      final res = server.push(principal, deviceId, List.of(_outbox));
      if (!lossy) {
        final done = {...res.accepted, ...res.duplicates, ...res.rejected.keys};
        _outbox.removeWhere((c) => done.contains(c.changeId));
      }
    }
    var more = true;
    while (more) {
      final page = server.pull(principal, cursor, limit: pageSize);
      for (final r in page.rows) {
        final spec = _schema[r.table]!;
        for (final v in r.fields.values) {
          _clock.receive(v.hlc);
        }
        final key = '${r.table}/${r.id}';
        final cur = rows[key]?.fields ?? const <String, Versioned>{};
        final merged = mergeFields(spec, cur, r.fields);
        if (merged != null) rows[key] = RowState(r.table, r.id, r.shopId, merged);
      }
      cursor = page.cursor;
      more = page.hasMore;
    }
  }
}

// -------------------------------------------------------- ledger checks

/// After merge, money can be inconsistent in ways no offline device could
/// prevent (two payouts applied to one parcel). Detect, never auto-fix.
class OverAllocation {
  const OverAllocation(this.orderId, this.collected, this.applied);
  final String orderId;
  final int collected;
  final int applied;
  int get excess => applied - collected;
}

List<OverAllocation> findOverAllocations(Iterable<RowState> rows) {
  final collected = <String, int>{};
  final reversed = <String>{};
  final applied = <String, int>{};
  final allocs = <RowState>[];
  for (final r in rows) {
    if (r.table == 'orders' && r['deleted_at'] == null) {
      collected[r.id] = (r['cod_collected'] as int?) ?? 0;
    } else if (r.table == 'payouts' && r['status'] == 'reversed') {
      reversed.add(r.id);
    } else if (r.table == 'payout_allocations') {
      allocs.add(r);
    }
  }
  for (final a in allocs) {
    if (reversed.contains(a['payout_id'])) continue;
    final o = a['order_id'] as String?;
    if (o == null) continue;
    applied[o] = (applied[o] ?? 0) + ((a['amount_applied'] as int?) ?? 0);
  }
  return [
    for (final e in applied.entries)
      if (e.value > (collected[e.key] ?? 0)) OverAllocation(e.key, collected[e.key] ?? 0, e.value),
  ]..sort((a, b) => a.orderId.compareTo(b.orderId));
}
