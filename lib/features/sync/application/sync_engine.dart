import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/sync_schema.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

// --------------------------------------------------------------- config

const _common = {'row_version'};

/// Per-table conflict policy (feature plan S16):
///  - masters + order fields: per-field LWW with hybrid logical clocks;
///  - order status is NOT a synced field: it is derived from the append-only
///    status events, so concurrent status changes merge instead of overwrite;
///  - money and event rows are immutable (insert-once, payout status
///    monotonic); corrections are reversals.
final Map<String, TableSpec> kSyncSpecs = {
  for (final t in kSyncedTables) t: TableSpec(TablePolicy.lww, excluded: _common),
  'orders': const TableSpec(TablePolicy.lww, excluded: {
    ..._common,
    'status',
    'handed_over_at',
    'delivered_at',
    'net_receivable',
    'outstanding',
    'profit',
    'profit_state',
    'gross_collected',
    'cod_status',
    'import_batch_id',
  }),
  'customers': const TableSpec(TablePolicy.lww, excluded: {..._common, 'import_batch_id'}),
  'products': const TableSpec(TablePolicy.lww, excluded: {..._common, 'import_batch_id'}),
  for (final t in [
    'order_status_events',
    'order_edit_log',
    'payout_allocations',
    'return_lines',
  ])
    t: const TableSpec(TablePolicy.appendOnly, excluded: _common),
  'payouts': const TableSpec(
    TablePolicy.appendOnly,
    excluded: _common,
    monotonic: {
      'status': ['active', 'reversed'],
    },
  ),
  'return_records': const TableSpec(TablePolicy.appendOnly, excluded: _common),
};

// ------------------------------------------------------------ transport

abstract class SyncTransport {
  Future<PushResult> push(String deviceId, List<Change> batch);
  Future<PullResult> pull(int since, {int limit = 200});
  Future<Map<String, int>> summary();
  Future<List<ActivityEntry>> activity({String? actor, bool moneyOnly = false});
}

/// Reference transport over the in-memory server (tests, local demos).
class InMemoryTransport implements SyncTransport {
  InMemoryTransport(this.server, this.principal);

  final SyncServer server;
  final Principal principal;

  @override
  Future<PushResult> push(String deviceId, List<Change> batch) async =>
      server.push(principal, deviceId, batch);

  @override
  Future<PullResult> pull(int since, {int limit = 200}) async =>
      server.pull(principal, since, limit: limit);

  @override
  Future<Map<String, int>> summary() async => server.summary(principal);

  @override
  Future<List<ActivityEntry>> activity({String? actor, bool moneyOnly = false}) async =>
      server.activity(principal, actor: actor, moneyOnly: moneyOnly);
}

// --------------------------------------------------------------- status

enum SyncPhase { disabled, synced, pending, error, revoked }

class SyncStatus {
  const SyncStatus(this.phase, {this.pending = 0, this.conflicts = 0, this.lastError, this.lastSyncAt});
  final SyncPhase phase;
  final int pending;
  final int conflicts;
  final String? lastError;
  final DateTime? lastSyncAt;
}

class SyncOutcome {
  const SyncOutcome({required this.pushed, required this.pulled, this.error, this.revoked = false});
  final int pushed;
  final int pulled;
  final Object? error;

  /// The account's access was revoked: the shop cache has been wiped.
  final bool revoked;
  bool get ok => error == null && !revoked;
}

/// Exponential backoff with a cap; deterministic for tests.
Duration syncBackoff(int failures, {Duration base = const Duration(seconds: 5)}) {
  final n = failures.clamp(0, 10);
  final ms = base.inMilliseconds * (1 << n);
  const cap = Duration(minutes: 30);
  return Duration(milliseconds: ms > cap.inMilliseconds ? cap.inMilliseconds : ms);
}

// --------------------------------------------------------------- engine

class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required Clock clock,
    required UuidV7 ids,
    required String shopId,
  })  : _db = db,
        _clock = clock,
        _ids = ids,
        _shopId = shopId,
        _ledger = LedgerWriter(db);

  final AppDatabase _db;
  final Clock _clock;
  final UuidV7 _ids;
  final String _shopId;
  final LedgerWriter _ledger;
  HlcClock? _hlc;
  bool _running = false;

  // ----------------------------------------------------------- identity

  Future<({String deviceId, String code, bool enabled, int cursor, DateTime? last, String? error})>
      _state() async {
    final r = await _db.customSelect('SELECT * FROM sync_state WHERE id = 1').getSingle();
    final last = r.read<int?>('last_sync_at');
    return (
      deviceId: r.read<String>('device_id'),
      code: r.read<String>('device_code'),
      enabled: r.read<int>('enabled') == 1,
      cursor: r.read<int>('cursor'),
      last: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
      error: r.read<String?>('last_error'),
    );
  }

  Future<String> get deviceId async => (await _state()).deviceId;

  Future<HlcClock> _clockFor(String device) async =>
      _hlc ??= HlcClock(device, () => _clock.now().millisecondsSinceEpoch);

  // ------------------------------------------------------ enable/disable

  /// Turns sync on: this device gets its order-number scope and every
  /// existing row is queued as the initial snapshot upload.
  Future<void> enable() async {
    final st = await _state();
    if (st.enabled) return;
    await _db.transaction(() async {
      await _db.customStatement('UPDATE sync_state SET enabled = 1, last_error = NULL WHERE id = 1');
      await _db.customStatement(
          'UPDATE orders SET device_code = ? WHERE device_code = ?', [st.code, '']);
      for (final t in kSyncedTables) {
        await _db.customStatement(
            'INSERT OR IGNORE INTO sync_dirty(tbl, row_id) SELECT ?, id FROM "$t"', [t]);
      }
    });
  }

  Future<void> disable() =>
      _db.customStatement('UPDATE sync_state SET enabled = 0 WHERE id = 1');

  /// "Replace with cloud": discard local synced data and take the server's.
  /// Call only after the user saw [localCounts] vs [SyncTransport.summary].
  Future<void> replaceWithCloud(SyncTransport transport) async {
    final st = await _state();
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        await _db.customStatement('UPDATE sync_state SET applying = 1 WHERE id = 1');
        for (final t in kSyncedTables.reversed) {
          await _db.customStatement('DELETE FROM "$t"');
        }
        await _db.customStatement('DELETE FROM sync_dirty');
        await _db.customStatement('DELETE FROM sync_rows');
        await _db.customStatement('DELETE FROM sync_conflicts');
        await _db.customStatement(
            'UPDATE sync_state SET applying = 0, cursor = 0, enabled = 1 WHERE id = 1');
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
    // Reserve this device's order-number scope (nothing local to renumber).
    assert(st.deviceId.isNotEmpty);
    await syncOnce(transport);
  }

  /// Revoked (or signed out): remove every synced row from this device and
  /// return to local-only with no shop data, so a helper's phone keeps
  /// nothing of the owner's business.
  Future<void> wipeShopCache() async {
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        await _db.customStatement('UPDATE sync_state SET applying = 1 WHERE id = 1');
        for (final t in kSyncedTables.reversed) {
          await _db.customStatement('DELETE FROM "$t"');
        }
        await _db.customStatement('DELETE FROM audit_log');
        await _db.customStatement('DELETE FROM sync_dirty');
        await _db.customStatement('DELETE FROM sync_rows');
        await _db.customStatement('DELETE FROM sync_conflicts');
        await _db.customStatement(
          "UPDATE sync_state SET applying = 0, enabled = 0, cursor = 0, user_id = '', "
          "role = 'owner', last_error = 'revoked' WHERE id = 1",
        );
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  /// Set after sign-in / accepting an invite (account identity + role).
  Future<void> setIdentity({required String userId, required String role}) =>
      _db.customStatement(
          'UPDATE sync_state SET user_id = ?, role = ? WHERE id = 1', [userId, role]);

  /// The role to gate the UI with. Always owner without an account.
  Future<String> currentRole() async {
    final st = await _db
        .customSelect('SELECT enabled, role FROM sync_state WHERE id = 1')
        .getSingle();
    return st.read<int>('enabled') == 1 ? st.read<String>('role') : 'owner';
  }

  /// "Who changed what": authoritative server log (owner only).
  Future<List<ActivityEntry>> fetchActivity(SyncTransport t,
          {String? actor, bool moneyOnly = false}) =>
      t.activity(actor: actor, moneyOnly: moneyOnly);

  Future<Map<String, int>> localCounts() async {
    final out = <String, int>{};
    for (final t in kSyncedTables) {
      final r = await _db
          .customSelect('SELECT COUNT(*) n FROM "$t" WHERE deleted_at IS NULL')
          .getSingle();
      final n = r.read<int>('n');
      if (n > 0) out[t] = n;
    }
    return out;
  }

  // -------------------------------------------------------------- status

  Future<SyncStatus> status() async {
    final st = await _state();
    if (!st.enabled) {
      return st.error == 'revoked'
          ? const SyncStatus(SyncPhase.revoked, lastError: 'revoked')
          : const SyncStatus(SyncPhase.disabled);
    }
    final pending = (await _db.customSelect('SELECT COUNT(*) n FROM sync_dirty').getSingle())
        .read<int>('n');
    final conflicts = (await _db
            .customSelect('SELECT COUNT(*) n FROM sync_conflicts WHERE resolved = 0')
            .getSingle())
        .read<int>('n');
    final phase = st.error != null
        ? SyncPhase.error
        : pending > 0
            ? SyncPhase.pending
            : SyncPhase.synced;
    return SyncStatus(phase,
        pending: pending, conflicts: conflicts, lastError: st.error, lastSyncAt: st.last);
  }

  Future<List<Map<String, Object?>>> conflicts({bool unresolvedOnly = true}) async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM sync_conflicts ${unresolvedOnly ? 'WHERE resolved = 0' : ''} ORDER BY at DESC')
        .get();
    return [for (final r in rows) r.data];
  }

  Future<void> resolveConflict(String id) =>
      _db.customStatement('UPDATE sync_conflicts SET resolved = 1 WHERE id = ?', [id]);

  // ---------------------------------------------------------------- sync

  /// One push + pull round. Never throws: failures are recorded in the sync
  /// state (visible as an error) and the outbox stays intact for the retry.
  Future<SyncOutcome> syncOnce(SyncTransport transport) async {
    if (_running) return const SyncOutcome(pushed: 0, pulled: 0);
    final st = await _state();
    if (!st.enabled) return const SyncOutcome(pushed: 0, pulled: 0);
    _running = true;
    var pushed = 0;
    var pulled = 0;
    try {
      pushed = await _push(transport, st.deviceId);
      pulled = await _pull(transport);
      await _db.customStatement(
        'UPDATE sync_state SET last_sync_at = ?, last_error = NULL WHERE id = 1',
        [_clock.now().millisecondsSinceEpoch],
      );
      return SyncOutcome(pushed: pushed, pulled: pulled);
    } on RevokedException {
      await wipeShopCache();
      return SyncOutcome(pushed: pushed, pulled: pulled, revoked: true);
    } on Object catch (e) {
      await _db.customStatement(
          'UPDATE sync_state SET last_error = ? WHERE id = 1', ['$e'.substring(0, ('$e').length.clamp(0, 300))]);
      return SyncOutcome(pushed: pushed, pulled: pulled, error: e);
    } finally {
      _running = false;
    }
  }

  // ---------------------------------------------------------------- push

  Future<Map<String, Object?>?> _row(String t, String id) async {
    final r = await _db
        .customSelect('SELECT * FROM "$t" WHERE id = ?', variables: [Variable.withString(id)])
        .getSingleOrNull();
    return r?.data;
  }

  Future<({Map<String, Object?> values, Map<String, Hlc> clocks})?> _snap(
      String t, String id) async {
    final r = await _db
        .customSelect('SELECT * FROM sync_rows WHERE tbl = ? AND row_id = ?',
            variables: [Variable.withString(t), Variable.withString(id)])
        .getSingleOrNull();
    if (r == null) return null;
    final values = (jsonDecode(r.read<String>('values_json')) as Map).cast<String, Object?>();
    final clocks = {
      for (final e in (jsonDecode(r.read<String>('clocks_json')) as Map).entries)
        e.key as String: Hlc.parse(e.value as String),
    };
    return (values: values, clocks: clocks);
  }

  Future<void> _saveSnap(
      String t, String id, Map<String, Object?> values, Map<String, Hlc> clocks) {
    return _db.customStatement(
      'INSERT INTO sync_rows(tbl, row_id, values_json, clocks_json) VALUES(?,?,?,?) '
      'ON CONFLICT(tbl, row_id) DO UPDATE SET values_json = excluded.values_json, '
      'clocks_json = excluded.clocks_json',
      [
        t,
        id,
        jsonEncode(values),
        jsonEncode({for (final e in clocks.entries) e.key: e.value.encode()}),
      ],
    );
  }

  Map<String, Object?> _carried(TableSpec spec, Map<String, Object?> row) =>
      {for (final e in row.entries) if (spec.carries(e.key)) e.key: e.value};

  /// Fields whose local value differs from the last synced value, stamped
  /// from the row's own `updated_at` (the moment the user edited it) and
  /// strictly after the field's previous stamp.
  Future<({Map<String, Versioned> fields, Map<String, Object?> current})?> _pending(
    String t,
    String id,
    HlcClock clock,
  ) async {
    final spec = kSyncSpecs[t]!;
    final row = await _row(t, id);
    final snap = await _snap(t, id);
    if (row == null) {
      // Hard-deleted locally: tombstone (only meaningful if it ever synced).
      if (snap == null) return null;
      final stamp = clock.tickAt(_clock.now().millisecondsSinceEpoch);
      return (
        fields: {'deleted_at': Versioned(_clock.now().millisecondsSinceEpoch ~/ 1000, stamp)},
        current: {...snap.values, 'deleted_at': _clock.now().millisecondsSinceEpoch ~/ 1000},
      );
    }
    final cur = _carried(spec, row);
    final base = snap?.values ?? const <String, Object?>{};
    final updated = row['updated_at'];
    final wall = (updated is int ? updated : _clock.now().millisecondsSinceEpoch ~/ 1000) * 1000;
    // Deterministic stamp (a retry after a lost ack yields the same change
    // id): the edit time, but never before anything this device has already
    // seen for this row (so a slow clock still orders after what it saw).
    Hlc? floor;
    for (final c in snap?.clocks.values ?? const <Hlc>[]) {
      if (floor == null || c > floor) floor = c;
    }
    var stamp = Hlc(wall, 0, clock.node);
    if (floor != null && !(stamp > floor)) {
      stamp = Hlc(floor.wallMs, floor.counter + 1, clock.node);
    }
    final fields = <String, Versioned>{};
    for (final e in cur.entries) {
      if (snap != null && base.containsKey(e.key) && base[e.key] == e.value) continue;
      fields[e.key] = Versioned(e.value, stamp);
    }
    if (fields.isEmpty) return null;
    return (fields: fields, current: cur);
  }

  Future<int> _push(SyncTransport transport, String deviceId) async {
    final clock = await _clockFor(deviceId);
    var total = 0;
    while (true) {
      final dirty = await _db
          .customSelect('SELECT tbl, row_id FROM sync_dirty ORDER BY rowid LIMIT 200')
          .get();
      if (dirty.isEmpty) return total;
      final order = {for (var i = 0; i < kSyncedTables.length; i++) kSyncedTables[i]: i};
      final items = [
        for (final d in dirty) (t: d.read<String>('tbl'), id: d.read<String>('row_id')),
      ]..sort((a, b) => order[a.t]!.compareTo(order[b.t]!));

      final changes = <Change>[];
      final meta = <String, ({String t, String id, Map<String, Versioned> fields, Map<String, Object?> current})>{};
      final clean = <(String, String)>[];
      for (final it in items) {
        final p = await _pending(it.t, it.id, clock);
        if (p == null) {
          clean.add((it.t, it.id));
          continue;
        }
        final stamps = (p.fields.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => '${e.key}@${e.value.hlc}')
            .join(',');
        final digest = sha1.convert(utf8.encode(stamps)).toString().substring(0, 12);
        final changeId = '$deviceId:${it.t}:${it.id}:$digest';
        meta[changeId] = (t: it.t, id: it.id, fields: p.fields, current: p.current);
        changes.add(Change(
          changeId: changeId,
          table: it.t,
          rowId: it.id,
          shopId: _shopId,
          fields: p.fields,
        ));
      }
      for (final c in clean) {
        await _db.customStatement(
            'DELETE FROM sync_dirty WHERE tbl = ? AND row_id = ?', [c.$1, c.$2]);
      }
      if (changes.isEmpty) {
        if (clean.isEmpty) return total;
        continue;
      }
      final res = await transport.push(deviceId, changes);
      final acked = {...res.accepted, ...res.duplicates, ...res.rejected.keys};
      await _db.transaction(() async {
        for (final id in acked) {
          final m = meta[id];
          if (m == null) continue;
          final snap = await _snap(m.t, m.id);
          final values = {...?snap?.values, ...m.current};
          final clocks = {...?snap?.clocks, for (final e in m.fields.entries) e.key: e.value.hlc};
          await _saveSnap(m.t, m.id, values, clocks);
          // Keep it queued if the user edited it again while we were pushing.
          final again = await _pending(m.t, m.id, clock);
          if (again == null) {
            await _db.customStatement(
                'DELETE FROM sync_dirty WHERE tbl = ? AND row_id = ?', [m.t, m.id]);
          }
          total++;
        }
        for (final e in res.lost.entries) {
          final m = meta[e.key];
          if (m == null) continue;
          await _conflict(m.t, m.id, 'lost_edit', 'fields: ${e.value.join(', ')}');
        }
        for (final e in res.rejected.entries) {
          final m = meta[e.key];
          if (m == null) continue;
          await _conflict(m.t, m.id, 'rejected', e.value);
        }
      });
      // Anything not acknowledged stays dirty and is retried next round.
      if (acked.isEmpty) return total;
      if (dirty.length < 200) {
        final left = (await _db.customSelect('SELECT COUNT(*) n FROM sync_dirty').getSingle())
            .read<int>('n');
        if (left == 0) return total;
        // Rows re-dirtied during the push are picked up next round.
        return total;
      }
    }
  }

  Future<void> _conflict(String t, String id, String kind, String detail) async {
    // One open entry per (row, kind, detail).
    final exists = await _db
        .customSelect(
            'SELECT 1 FROM sync_conflicts WHERE tbl=? AND row_id=? AND kind=? AND detail=? AND resolved=0',
            variables: [
              Variable.withString(t),
              Variable.withString(id),
              Variable.withString(kind),
              Variable.withString(detail),
            ])
        .get();
    if (exists.isNotEmpty) return;
    await _db.customStatement(
      'INSERT INTO sync_conflicts(id, at, tbl, row_id, kind, detail, resolved) VALUES(?,?,?,?,?,?,0)',
      [_ids.generate(), _clock.now().millisecondsSinceEpoch, t, id, kind, detail],
    );
  }

  // ---------------------------------------------------------------- pull

  Future<int> _pull(SyncTransport transport) async {
    var applied = 0;
    var more = true;
    while (more) {
      final st = await _state();
      final page = await transport.pull(st.cursor, limit: 200);
      if (page.rows.isNotEmpty || page.cursor != st.cursor) {
        applied += await _applyPage(page);
      }
      more = page.hasMore;
    }
    return applied;
  }

  static const _orderChildFk = <String, String>{
    'order_lines': 'order_id',
    'order_charges': 'order_id',
    'order_tag_links': 'order_id',
    'order_attachments': 'order_id',
    'order_status_events': 'order_id',
    'order_edit_log': 'order_id',
    'payout_allocations': 'order_id',
    'return_records': 'order_id',
  };

  Future<int> _applyPage(PullResult page) async {
    final clock = await _clockFor(await deviceId);
    final order = {for (var i = 0; i < kSyncedTables.length; i++) kSyncedTables[i]: i};
    final rows = [...page.rows]..sort((a, b) => (order[a.table] ?? 99).compareTo(order[b.table] ?? 99));
    var n = 0;
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        await _db.customStatement('UPDATE sync_state SET applying = 1 WHERE id = 1');
        final touchedOrders = <String>{};
        final statusOrders = <String>{};
        for (final r in rows) {
          final spec = kSyncSpecs[r.table];
          if (spec == null) continue;
          for (final v in r.fields.values) {
            clock.receive(v.hlc);
          }
          if (await _applyRow(clock, spec, r)) n++;
          if (r.table == 'orders') {
            touchedOrders.add(r.id);
            statusOrders.add(r.id);
          } else if (_orderChildFk.containsKey(r.table)) {
            final oid = r.fields[_orderChildFk[r.table]!]?.value as String?;
            if (oid != null) {
              touchedOrders.add(oid);
              if (r.table == 'order_status_events') statusOrders.add(oid);
            }
          } else if (r.table == 'payouts') {
            final al = await _db
                .customSelect('SELECT order_id FROM payout_allocations WHERE payout_id = ?',
                    variables: [Variable.withString(r.id)])
                .get();
            for (final a in al) {
              touchedOrders.add(a.read<String>('order_id'));
            }
          } else if (r.table == 'return_lines') {
            final rid = r.fields['return_id']?.value as String?;
            if (rid != null) {
              final rec = await _row('return_records', rid);
              final oid = rec?['order_id'] as String?;
              if (oid != null) touchedOrders.add(oid);
            }
          }
        }
        for (final id in statusOrders) {
          await _deriveStatus(id);
        }
        for (final id in touchedOrders) {
          final o = await _row('orders', id);
          if (o == null) continue;
          await _ledger.refresh(id);
          final after = await _row('orders', id);
          final out = after?['outstanding'];
          if (out is int && out < 0) {
            await _conflict('orders', id, 'over_allocation', 'outstanding $out');
          }
        }
        await _db.customStatement(
            'UPDATE sync_state SET applying = 0, cursor = ? WHERE id = 1', [page.cursor]);
      });
    } finally {
      await _db.customStatement('UPDATE sync_state SET applying = 0 WHERE id = 1');
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
    return n;
  }

  /// Returns true when the local row changed.
  Future<bool> _applyRow(HlcClock clock, TableSpec spec, RowState r) async {
    final snap = await _snap(r.table, r.id);
    final local = await _row(r.table, r.id);
    final isDirty = (await _db
            .customSelect('SELECT 1 FROM sync_dirty WHERE tbl=? AND row_id=?', variables: [
              Variable.withString(r.table),
              Variable.withString(r.id),
            ])
            .get())
        .isNotEmpty;
    // Local edits not yet pushed compete with the incoming fields by HLC.
    final pending = isDirty && local != null
        ? await _pending(r.table, r.id, clock)
        : null;

    final serverBefore = {
      for (final e in (snap?.values ?? const <String, Object?>{}).entries)
        e.key: Versioned(e.value, snap!.clocks[e.key] ?? const Hlc(0, 0, '')),
    };
    final incoming = {
      for (final e in r.fields.entries) if (spec.carries(e.key)) e.key: e.value,
    };
    final merged = mergeFields(spec, serverBefore, incoming) ?? serverBefore;

    // Our own already-synced edit replaced by another device's newer value.
    for (final e in incoming.entries) {
      final before = serverBefore[e.key];
      final after = merged[e.key];
      if (before != null &&
          after != null &&
          before.hlc.node == clock.node &&
          after.hlc.node != clock.node &&
          after.hlc != before.hlc &&
          before.value != after.value &&
          spec.policy == TablePolicy.lww) {
        await _conflict(r.table, r.id, 'lost_edit', 'field: ${e.key}');
      }
    }

    final newValues = <String, Object?>{for (final e in merged.entries) e.key: e.value.value};
    final newClocks = <String, Hlc>{for (final e in merged.entries) e.key: e.value.hlc};

    // Final local value per column.
    final finalValues = <String, Object?>{...newValues};
    if (pending != null) {
      for (final p in pending.fields.entries) {
        final remote = merged[p.key];
        final remoteWon =
            remote != null && remote.hlc > p.value.hlc && spec.policy == TablePolicy.lww;
        if (remoteWon || remote == null) {
          if (remote != null && remote.value != p.value.value) {
            await _conflict(r.table, r.id, 'lost_edit', 'field: ${p.key}');
          }
          continue; // remote value stands
        }
        // Local edit is newer (or remote did not touch the field): keep it.
        finalValues[p.key] = p.value.value;
      }
    }

    var changed = false;
    try {
      if (local == null) {
        final cols = <String>[];
        final vals = <Object?>[];
        for (final e in finalValues.entries) {
          cols.add('"${e.key}"');
          vals.add(e.value);
        }
        // Derived/excluded NOT NULL columns get a placeholder; recomputed.
        if (r.table == 'orders' && !finalValues.containsKey('status')) {
          cols.add('"status"');
          vals.add('confirmed');
        }
        await _db.customStatement(
          'INSERT OR REPLACE INTO "${r.table}" (${cols.join(',')}) '
          'VALUES (${List.filled(cols.length, '?').join(',')})',
          vals,
        );
        changed = true;
      } else {
        final sets = <String>[];
        final args = <Object?>[];
        for (final e in finalValues.entries) {
          if (e.key == 'id') continue;
          if (!local.containsKey(e.key)) continue;
          if (local[e.key] != e.value) {
            sets.add('"${e.key}" = ?');
            args.add(e.value);
          }
        }
        if (sets.isNotEmpty) {
          await _db.customStatement(
              'UPDATE "${r.table}" SET ${sets.join(', ')} WHERE id = ?', [...args, r.id]);
          changed = true;
        }
      }
    } on Object catch (e) {
      await _conflict(r.table, r.id, 'unique_violation', '$e'.split('\n').first);
      return false;
    }
    await _saveSnap(r.table, r.id, newValues, newClocks);
    // The local row now differs from the snapshot only by kept local edits.
    if (pending == null || pending.fields.isEmpty) {
      await _db.customStatement(
          'DELETE FROM sync_dirty WHERE tbl = ? AND row_id = ?', [r.table, r.id]);
    }
    return changed;
  }

  /// Order status = target of the latest status event (the log is
  /// append-only and synced, so concurrent changes merge deterministically).
  Future<void> _deriveStatus(String orderId) async {
    final latest = await _db
        .customSelect(
            'SELECT to_status, at FROM order_status_events WHERE order_id = ? AND deleted_at IS NULL '
            'ORDER BY created_at DESC, id DESC LIMIT 1',
            variables: [Variable.withString(orderId)])
        .getSingleOrNull();
    if (latest == null) return;
    final status = latest.read<String>('to_status');
    await _db.customStatement('UPDATE orders SET status = ? WHERE id = ?', [status, orderId]);
    Future<void> stamp(String column, String toStatus, {bool earliest = false}) async {
      final e = await _db
          .customSelect(
              'SELECT at FROM order_status_events WHERE order_id = ? AND to_status = ? AND deleted_at IS NULL '
              'ORDER BY created_at ${earliest ? 'ASC' : 'DESC'}, id ${earliest ? 'ASC' : 'DESC'} LIMIT 1',
              variables: [Variable.withString(orderId), Variable.withString(toStatus)])
          .getSingleOrNull();
      if (e != null) {
        await _db.customStatement(
            'UPDATE orders SET $column = ? WHERE id = ? AND $column IS NULL', [e.read<int>('at'), orderId]);
      }
    }

    await stamp('handed_over_at', 'handed_to_courier', earliest: true);
    if (status == 'delivered') await stamp('delivered_at', 'delivered');
  }
}
