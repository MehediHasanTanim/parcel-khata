import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

void main() {
  const owner = Principal(userId: 'u1', shopId: 'shopA', role: 'owner');
  const helper = Principal(userId: 'u2', shopId: 'shopA', role: 'helper');

  late int now;
  late SyncServer server;
  SyncDevice device(String id, {Principal p = owner, int skewMs = 0}) =>
      SyncDevice(deviceId: id, principal: p, wallMs: () => now + skewMs);

  setUp(() {
    now = 1_000_000;
    server = SyncServer();
  });

  void tick([int ms = 1000]) => now += ms;

  group('basic replication', () {
    test('create on A, pull on B', () {
      final a = device('A'), b = device('B');
      a.edit('customers', 'c1', {'name': 'Rahim', 'phone': '01712345678'});
      a.sync(server);
      b.sync(server);
      expect(b.row('customers', 'c1')!['name'], 'Rahim');
    });

    test('pull is incremental and paginated', () {
      final a = device('A'), b = device('B');
      for (var i = 0; i < 25; i++) {
        a.edit('customers', 'c$i', {'name': 'N$i'});
      }
      a.sync(server);
      b.sync(server, pageSize: 10);
      expect(b.rows.length, 25);
      final cursor = b.cursor;
      a.edit('customers', 'c3', {'name': 'Changed'});
      a.sync(server);
      b.sync(server, pageSize: 10);
      expect(b.cursor, greaterThan(cursor));
      expect(b.row('customers', 'c3')!['name'], 'Changed');
    });

    test('push is idempotent: lost ack then retry applies once', () {
      final a = device('A');
      a.edit('customers', 'c1', {'name': 'Rahim'});
      a.sync(server, lossy: true);
      expect(a.pending, 1);
      final seq = server.seq;
      a.sync(server);
      expect(a.pending, 0);
      expect(server.seq, seq, reason: 'duplicate must not create a new change');
    });
  });

  group('two-device conflicts', () {
    test('different fields concurrently edited both survive', () {
      final a = device('A'), b = device('B');
      a.edit('customers', 'c1', {'name': 'Rahim', 'notes': ''});
      a.sync(server);
      b.sync(server);
      tick();
      a.edit('customers', 'c1', {'name': 'Rahim Uddin'});
      b.edit('customers', 'c1', {'notes': 'calls before delivery'});
      a.sync(server);
      b.sync(server);
      a.sync(server);
      for (final d in [a, b]) {
        expect(d.row('customers', 'c1')!['name'], 'Rahim Uddin');
        expect(d.row('customers', 'c1')!['notes'], 'calls before delivery');
      }
    });

    test('same field: later HLC wins on every replica (and the server)', () {
      final a = device('A'), b = device('B');
      a.edit('orders', 'o1', {'address': 'Old', 'status': 'confirmed'});
      a.sync(server);
      b.sync(server);
      tick();
      a.edit('orders', 'o1', {'address': 'Road 5'});
      tick();
      b.edit('orders', 'o1', {'address': 'Road 9'}); // later
      // Sync in the "wrong" order.
      b.sync(server);
      a.sync(server);
      b.sync(server);
      expect(a.row('orders', 'o1')!['address'], 'Road 9');
      expect(b.row('orders', 'o1')!['address'], 'Road 9');
      expect(server.row('orders', 'o1')!['address'], 'Road 9');
    });

    test('exact tie is broken by node id deterministically', () {
      final a = device('A'), b = device('B');
      a.edit('customers', 'c1', {'name': 'from A'});
      b.edit('customers', 'c1', {'name': 'from B'}); // same wall ms, counter
      a.sync(server);
      b.sync(server);
      a.sync(server);
      expect(a.row('customers', 'c1')!['name'], b.row('customers', 'c1')!['name']);
      expect(a.row('customers', 'c1')!['name'], 'from B');
    });

    test('a device with a slow clock still orders after what it has seen', () {
      final fast = device('A', skewMs: 60_000);
      final slow = device('B', skewMs: -60_000);
      fast.edit('customers', 'c1', {'name': 'v1'});
      fast.sync(server);
      slow.sync(server);
      tick();
      slow.edit('customers', 'c1', {'name': 'v2 (after seeing v1)'});
      slow.sync(server);
      fast.sync(server);
      expect(fast.row('customers', 'c1')!['name'], 'v2 (after seeing v1)');
    });

    test('soft delete is a field: concurrent edit does not silently resurrect', () {
      final a = device('A'), b = device('B');
      a.edit('orders', 'o1', {'status': 'confirmed', 'deleted_at': null});
      a.sync(server);
      b.sync(server);
      tick();
      a.edit('orders', 'o1', {'deleted_at': 'T1'});
      tick();
      b.edit('orders', 'o1', {'notes': 'edited elsewhere'}); // concurrent, later
      a.sync(server);
      b.sync(server);
      a.sync(server);
      expect(b.row('orders', 'o1')!['deleted_at'], 'T1');
      expect(a.row('orders', 'o1')!['notes'], 'edited elsewhere');
    });
  });

  group('money events', () {
    test('two devices pay the same parcel: both rows kept, over-allocation flagged', () {
      final a = device('A'), b = device('B');
      a.edit('orders', 'o1', {'cod_collected': 100000, 'status': 'delivered'});
      a.sync(server);
      b.sync(server);
      tick();
      a.edit('payouts', 'pA', {'status': 'active', 'total': 100000});
      a.edit('payout_allocations', 'aA',
          {'payout_id': 'pA', 'order_id': 'o1', 'amount_applied': 100000});
      b.edit('payouts', 'pB', {'status': 'active', 'total': 100000});
      b.edit('payout_allocations', 'aB',
          {'payout_id': 'pB', 'order_id': 'o1', 'amount_applied': 100000});
      a.sync(server);
      b.sync(server);
      a.sync(server);

      for (final d in [a, b]) {
        expect(d.row('payouts', 'pA'), isNotNull);
        expect(d.row('payouts', 'pB'), isNotNull);
        final over = findOverAllocations(d.rows.values);
        expect(over, hasLength(1));
        expect(over.single.excess, 100000);
      }
      // Resolution is an explicit reversal, which then converges everywhere.
      b.edit('payouts', 'pB', {'status': 'reversed'});
      b.sync(server);
      a.sync(server);
      expect(findOverAllocations(a.rows.values), isEmpty);
      expect(findOverAllocations(b.rows.values), isEmpty);
    });

    test('reversal wins over a concurrent re-activation (monotonic status)', () {
      final a = device('A'), b = device('B');
      a.edit('payouts', 'p1', {'status': 'active', 'total': 5});
      a.sync(server);
      b.sync(server);
      tick();
      a.edit('payouts', 'p1', {'status': 'reversed'});
      tick();
      b.edit('payouts', 'p1', {'status': 'active'}); // later HLC, lower rank
      b.sync(server);
      a.sync(server);
      b.sync(server);
      expect(a.row('payouts', 'p1')!['status'], 'reversed');
      expect(b.row('payouts', 'p1')!['status'], 'reversed');
      expect(server.row('payouts', 'p1')!['status'], 'reversed');
    });

    test('an amount cannot be rewritten after the event exists', () {
      final a = device('A'), b = device('B');
      a.edit('payouts', 'p1', {'status': 'active', 'total': 100000});
      a.sync(server);
      b.sync(server);
      tick();
      b.edit('payouts', 'p1', {'total': 1});
      b.sync(server);
      a.sync(server);
      expect(server.row('payouts', 'p1')!['total'], 100000);
      expect(a.row('payouts', 'p1')!['total'], 100000);
    });

    test('derived ledger/profit columns are never synced', () {
      final a = device('A'), b = device('B');
      a.edit('orders', 'o1', {
        'status': 'delivered',
        'cod_collected': 1000,
        'outstanding': 1000, // derived: local only
        'profit': 300, // derived
        'net_receivable': 900, // derived
      });
      a.sync(server);
      b.sync(server);
      final r = b.row('orders', 'o1')!;
      expect(r['cod_collected'], 1000);
      expect(r.fields.containsKey('outstanding'), isFalse);
      expect(r.fields.containsKey('profit'), isFalse);
      expect(r.fields.containsKey('net_receivable'), isFalse);
    });
  });

  group('authorization (RLS analogue)', () {
    test('helper cannot push money tables but can push orders', () {
      final h = device('H', p: helper);
      h.edit('orders', 'o1', {'status': 'confirmed'});
      h.edit('payouts', 'p1', {'status': 'active'});
      final res = server.push(helper, 'H', [
        for (final c in h.outboxForTest) c,
      ]);
      expect(res.rejected.values, contains('forbidden_role'));
      expect(res.accepted, hasLength(1));
      expect(server.row('payouts', 'p1'), isNull);
      expect(server.row('orders', 'o1'), isNotNull);
    });

    test('another shop cannot write into or read from this shop', () {
      const other = Principal(userId: 'x', shopId: 'shopB', role: 'owner');
      final a = device('A');
      a.edit('customers', 'c1', {'name': 'Private'});
      a.sync(server);
      final mal = SyncDevice(deviceId: 'M', principal: other, wallMs: () => now);
      expect(mal.pending, 0);
      mal.sync(server);
      expect(mal.rows, isEmpty);
      final forged = server.push(other, 'M', [
        Change(
          changeId: 'f1',
          table: 'customers',
          rowId: 'c1',
          shopId: 'shopA',
          fields: {'name': Versioned('pwned', Hlc(now * 2, 0, 'M'))},
        ),
      ]);
      expect(forged.rejected['f1'], 'wrong_shop');
      expect(server.row('customers', 'c1')!['name'], 'Private');
    });
  });

  test('property: three devices, random edits and sync order, always converge', () {
    final rnd = Random(2026);
    for (var run = 0; run < 150; run++) {
      now = 1_000_000;
      server = SyncServer();
      final devices = [
        device('A', skewMs: rnd.nextInt(5000) - 2500),
        device('B', skewMs: rnd.nextInt(5000) - 2500),
        device('C', skewMs: rnd.nextInt(5000) - 2500),
      ];
      for (var step = 0; step < 40; step++) {
        now += rnd.nextInt(300);
        final d = devices[rnd.nextInt(3)];
        switch (rnd.nextInt(5)) {
          case 0:
            d.edit('customers', 'c${rnd.nextInt(4)}', {
              'name': 'n${rnd.nextInt(1000)}',
              if (rnd.nextBool()) 'notes': 'x${rnd.nextInt(1000)}',
            });
          case 1:
            d.edit('orders', 'o${rnd.nextInt(4)}', {
              'status': ['confirmed', 'delivered', 'returned'][rnd.nextInt(3)],
              'cod_collected': rnd.nextInt(5000),
              if (rnd.nextInt(6) == 0) 'deleted_at': 'T${rnd.nextInt(9)}',
            });
          case 2:
            d.edit('payouts', 'p${rnd.nextInt(3)}', {
              'status': rnd.nextBool() ? 'active' : 'reversed',
              'total': 100,
            });
          default:
            d.sync(server, lossy: rnd.nextInt(5) == 0, pageSize: 1 + rnd.nextInt(7));
        }
      }
      // Final: everyone syncs twice (push then pull to a fixed point).
      for (var i = 0; i < 2; i++) {
        for (final d in devices) {
          d.sync(server);
        }
      }
      for (final d in devices) {
        expect(d.rows.keys.toSet(), server.allRows.map((r) => '${r.table}/${r.id}').toSet());
        for (final r in server.allRows) {
          final local = d.row(r.table, r.id)!;
          expect(local.fields, r.fields, reason: 'run $run ${r.table}/${r.id}');
        }
      }
    }
  });
}
