import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

import 'sim.dart';

/// Deterministic multi-device simulator: N real databases, scripted
/// offline/online periods, shuffled/duplicated/lost deliveries, clock skew.
/// After everything is delivered, every device must hold the same data,
/// no money event may be lost and every ledger must be self-consistent.
int _orders = 0;
int _payouts = 0;
int _events = 0;
int _overAlloc = 0;
int _lost = 0;

void main() {
  Future<void> run(int seed) async {
    final rnd = Random(seed);
    final server = SyncServer(schema: kSyncSpecs);
    final t0 = DateTime(2026, 10, 15, 9);
    final devs = <Dev>[];
    for (var i = 0; i < 3; i++) {
      final d = await Dev.create('D$i', server,
          start: t0.add(Duration(seconds: rnd.nextInt(600) - 300)));
      await d.engine.enable();
      devs.add(d);
    }
    addTearDown(() async {
      for (final d in devs) {
        await d.db.close();
      }
    });

    // Shared master data, created on D0 and distributed first.
    final courier = await devs[0].courier('Pathao');
    final seedCustomers = <String>[
      await devs[0].customer('Seed A', '01711000001'),
      await devs[0].customer('Seed B', '01711000002'),
    ];
    await devs[0].sync();
    for (final d in devs.skip(1)) {
      await d.sync();
    }

    var phone = 0;
    var cn = 0;
    var payoutsCreated = 0;
    final customers = [...seedCustomers];

    Future<List<String>> ids(Dev d, String where) async => [
          for (final r in await d.db.customSelect('SELECT id FROM orders WHERE $where').get())
            r.read<String>('id'),
        ];

    for (var step = 0; step < 45; step++) {
      final d = devs[rnd.nextInt(3)];
      d.tick(1 + rnd.nextInt(20));
      switch (rnd.nextInt(10)) {
        case 0:
          customers.add(await d.customer('N${phone++}', '01712${(100000 + phone).toString()}'));
        case 1:
          final c = customers[rnd.nextInt(customers.length)];
          if (await d.row('customers', c) == null) break;
          await d.db.customStatement(
              'UPDATE customers SET name = ?, updated_at = ? WHERE id = ?',
              ['name${rnd.nextInt(99)}', d.clock.now().millisecondsSinceEpoch ~/ 1000, c]);
        case 2 || 3:
          final c = customers[rnd.nextInt(customers.length)];
          if (await d.row('customers', c) == null) break;
          await d.order(c, courier, '${d.name}-CN${cn++}', delivered: rnd.nextInt(3) == 0);
        case 4:
          final os = await ids(d, "status = 'confirmed' AND deleted_at IS NULL");
          if (os.isEmpty) break;
          await d.status.changeStatus(os[rnd.nextInt(os.length)],
              to: OrderStatus.handedToCourier, at: d.clock.now());
        case 5:
          final os = await ids(d, "status = 'handed_to_courier' AND deleted_at IS NULL");
          if (os.isEmpty) break;
          await d.status.changeStatus(os[rnd.nextInt(os.length)],
              to: OrderStatus.delivered, at: d.clock.now());
        case 6:
          final os = await ids(d, "status = 'delivered' AND outstanding > 0 AND deleted_at IS NULL");
          if (os.isEmpty) break;
          await d.payFull(courier, os[rnd.nextInt(os.length)]);
          payoutsCreated++;
        case 7:
          final ps = [
            for (final r in await d.db
                .customSelect("SELECT id FROM payouts WHERE status = 'active'")
                .get())
              r.read<String>('id'),
          ];
          if (ps.isEmpty) break;
          await d.payouts.reversePayout(ps[rnd.nextInt(ps.length)], 'sim reversal');
        default:
          d.transport
            ..loseNextAck = rnd.nextInt(6) == 0
            ..duplicatePush = rnd.nextInt(4) == 0
            ..shufflePull = rnd.nextBool()
            ..failNextPull = rnd.nextInt(8) == 0
            ..pageSize = rnd.nextBool() ? 1 + rnd.nextInt(8) : null;
          await d.sync();
      }
    }

    // Network heals: deliver everything, a few rounds to reach a fixed point.
    for (final d in devs) {
      d.transport
        ..loseNextAck = false
        ..duplicatePush = false
        ..shufflePull = false
        ..failNextPull = false
        ..failNextPush = false
        ..pageSize = null;
    }
    for (var round = 0; round < 4; round++) {
      for (final d in devs) {
        final r = await d.sync();
        expect(r.ok, isTrue, reason: 'seed $seed ${d.name}: ${r.error}');
      }
    }

    final ref = await devs[0].snapshot();
    for (final d in devs.skip(1)) {
      expect(await d.snapshot(), ref, reason: 'seed $seed: ${d.name} diverged');
    }
    for (final d in devs) {
      final st = await d.engine.status();
      expect(st.pending, 0, reason: 'seed $seed ${d.name} still has pending changes');
      expect(st.phase, SyncPhase.synced);
    }

    // No money event lost: every payout ever created exists everywhere.
    for (final d in devs) {
      expect(await d.count('payouts', where: '1 = 1'),
          await devs[0].count('payouts', where: '1 = 1'));
    }
    expect(await devs[0].count('payouts', where: '1 = 1'), greaterThanOrEqualTo(payoutsCreated));

    _orders += await devs[0].count('orders');
    _payouts += await devs[0].count('payouts', where: '1 = 1');
    _events += await devs[0].count('order_status_events', where: '1 = 1');
    for (final d in devs) {
      for (final c in await d.engine.conflicts()) {
        if (c['kind'] == 'over_allocation') _overAlloc++;
        if (c['kind'] == 'lost_edit') _lost++;
      }
    }

    // Ledger invariants hold on every device after sync: cached values equal
    // a fresh computation, and status equals the latest status event.
    for (final d in devs) {
      final orders = await d.db.customSelect('SELECT id, status, outstanding FROM orders').get();
      for (final o in orders) {
        final id = o.read<String>('id');
        final fresh = await d.ledger.compute(id);
        if (fresh != null) {
          expect(o.read<int?>('outstanding'), fresh.outstanding.poisha,
              reason: 'seed $seed ${d.name} order $id outstanding drifted');
        }
        final latest = await d.db.customSelect(
          'SELECT to_status FROM order_status_events WHERE order_id = ? '
          'ORDER BY created_at DESC, id DESC LIMIT 1',
          variables: [Variable.withString(id)],
        ).getSingleOrNull();
        if (latest != null) {
          expect(o.read<String>('status'), latest.read<String>('to_status'),
              reason: 'seed $seed ${d.name} order $id status not derived from events');
        }
      }
      // Order numbers are unique per (device, number) and never violated.
      final dup = await d.db.customSelect(
        'SELECT device_code, order_number, COUNT(*) n FROM orders '
        'GROUP BY device_code, order_number HAVING n > 1',
      ).get();
      expect(dup, isEmpty);
      final uv = await d.engine.conflicts();
      expect(uv.where((c) => c['kind'] == 'unique_violation'), isEmpty,
          reason: 'seed $seed ${d.name}: $uv');
    }
  }

  for (var seed = 1; seed <= 12; seed++) {
    test('three devices, random offline work + chaos converge (seed $seed)', () => run(seed));
  }

  test('the simulator really exercised orders, money events and conflicts', () {
    // ignore: avoid_print
    print('sim totals: orders=$_orders payouts=$_payouts events=$_events '
        'overAllocation=$_overAlloc lostEdits=$_lost');
    expect(_orders, greaterThan(30));
    expect(_payouts, greaterThan(5));
    expect(_events, greaterThan(_orders));
  });
}
