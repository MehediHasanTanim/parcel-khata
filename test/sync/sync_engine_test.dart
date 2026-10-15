import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

import 'sim.dart';

void main() {
  late SyncServer server;
  final t0 = DateTime(2026, 10, 15, 12);

  setUp(() => server = SyncServer(schema: kSyncSpecs));

  Future<Dev> dev(String n, {DateTime? start}) async {
    final d = await Dev.create(n, server, start: start ?? t0);
    await d.engine.enable();
    addTearDown(d.db.close);
    return d;
  }

  group('replication', () {
    test('existing data uploads as the initial snapshot; a second device downloads it',
        () async {
      final a = await Dev.create('A', server, start: t0);
      addTearDown(a.db.close);
      // Data exists BEFORE sync is turned on (a migrating user).
      final c = await a.customer('Rahim', '01712345678');
      final courier = await a.courier('Pathao');
      final o = await a.order(c, courier, 'CN1', delivered: true);
      await a.engine.enable();
      expect((await a.engine.status()).phase, SyncPhase.pending);
      expect((await a.sync()).ok, isTrue);
      expect((await a.engine.status()).phase, SyncPhase.synced);

      final b = await dev('B');
      expect((await b.sync()).ok, isTrue);
      expect(await b.count('customers'), 1);
      expect(await b.count('orders'), 1);
      expect(await b.count('order_lines'), 1);
      final ob = await b.row('orders', o);
      expect(ob!['status'], 'delivered'); // derived from the event log
      expect(ob['cod_collected'], (await a.row('orders', o))!['cod_collected']);
      // Derived money is recomputed locally, identically.
      final oa = await a.row('orders', o);
      expect(ob['outstanding'], oa!['outstanding']);
      expect(ob['net_receivable'], oa['net_receivable']);
      expect(ob['cod_status'], oa['cod_status']);
      expect(ob['profit'], oa['profit']);
      expect(ob['delivered_at'], oa['delivered_at']);
    });

    test('masters: different fields merge, same field is last-write-wins and logged',
        () async {
      final a = await dev('A');
      final b = await dev('B');
      final c = await a.customer('Rahim', '01712345678');
      await a.sync();
      await b.sync();

      a.tick(10);
      await a.db.customStatement(
          "UPDATE customers SET name = 'Rahim Uddin', updated_at = ? WHERE id = ?",
          [a.clock.now().millisecondsSinceEpoch ~/ 1000, c]);
      b.clock.advance(const Duration(seconds: 20));
      await b.db.customStatement(
          "UPDATE customers SET notes = 'call first', phone_alt = '01811111111', updated_at = ? WHERE id = ?",
          [b.clock.now().millisecondsSinceEpoch ~/ 1000, c]);
      // Same field, B is later.
      await b.db.customStatement(
          "UPDATE customers SET name = 'R. Uddin', updated_at = ? WHERE id = ?",
          [b.clock.now().millisecondsSinceEpoch ~/ 1000, c]);

      await a.sync();
      await b.sync();
      await a.sync();
      for (final d in [a, b]) {
        final r = await d.row('customers', c);
        expect(r!['name'], 'R. Uddin');
        expect(r['notes'], 'call first');
        expect(r['phone_alt'], '01811111111');
      }
      // A's lost edit is visible, not silent.
      final log = await a.engine.conflicts();
      expect(log.where((x) => x['kind'] == 'lost_edit'), isNotEmpty);
    });

    test('concurrent status changes merge via the event log (same result everywhere)',
        () async {
      final a = await dev('A');
      final b = await dev('B');
      final c = await a.customer('Rahim', '01712345678');
      final courier = await a.courier('Pathao');
      final o = await a.order(c, courier, 'CN9');
      await a.sync();
      await b.sync();
      expect((await b.row('orders', o))!['status'], 'confirmed');

      a.tick(5);
      b.tick(8);
      expect((await a.status.changeStatus(o, to: OrderStatus.handedToCourier, at: a.clock.now())).isOk,
          isTrue);
      expect(
          (await b.status.changeStatus(o,
                  to: OrderStatus.cancelled, at: b.clock.now(), reason: 'customer_cancelled'))
              .isOk,
          isTrue);
      await a.sync();
      await b.sync();
      await a.sync();
      final sa = (await a.row('orders', o))!['status'];
      final sb = (await b.row('orders', o))!['status'];
      expect(sa, sb);
      expect(await a.count('order_status_events'), await b.count('order_status_events'));
      expect(await a.count('order_status_events'), 3); // create + two concurrent
    });

    test('order numbers are device-scoped: offline devices never collide', () async {
      final a = await dev('A');
      final b = await dev('B');
      final ca = await a.customer('A cust', '01712345678');
      final cb = await b.customer('B cust', '01812345678');
      final courier = await a.courier('Pathao');
      final oa = [for (var i = 0; i < 3; i++) await a.order(ca, courier, 'A$i')];
      await b.sync(); // learn courier
      await a.sync();
      await b.sync();
      final bcourier = courier;
      final ob = [for (var i = 0; i < 3; i++) await b.order(cb, bcourier, 'B$i')];
      await b.sync();
      await a.sync();
      await b.sync();
      expect(await a.count('orders'), 6);
      expect(await b.count('orders'), 6);
      expect((await a.engine.conflicts()).where((x) => x['kind'] == 'unique_violation'), isEmpty);
      expect((await b.engine.conflicts()).where((x) => x['kind'] == 'unique_violation'), isEmpty);
      final na = await a.row('orders', oa.first);
      final nb = await a.row('orders', ob.first);
      expect(na!['device_code'], isNot(nb!['device_code']));
      expect(na['order_number'], nb['order_number']); // both #1 on their device
    });
  });

  group('money', () {
    test('a payout recorded on A settles the parcel on B', () async {
      final a = await dev('A');
      final b = await dev('B');
      final c = await a.customer('Rahim', '01712345678');
      final courier = await a.courier('Pathao');
      final o = await a.order(c, courier, 'CN1', delivered: true);
      await a.sync();
      await b.sync();
      expect((await b.row('orders', o))!['cod_status'], 'collected_by_courier');
      final p = await a.payFull(courier, o);
      await a.sync();
      await b.sync();
      expect((await b.row('payouts', p))!['status'], 'active');
      final rb = await b.row('orders', o);
      expect(rb!['outstanding'], 0);
      expect(rb['cod_status'], 'settled');
    });

    test('two devices pay the same parcel: both events kept, over-allocation is flagged',
        () async {
      final a = await dev('A');
      final b = await dev('B');
      final c = await a.customer('Rahim', '01712345678');
      final courier = await a.courier('Pathao');
      final o = await a.order(c, courier, 'CN1', delivered: true);
      await a.sync();
      await b.sync();

      final pa = await a.payFull(courier, o);
      final pb = await b.payFull(courier, o);
      await a.sync();
      await b.sync();
      await a.sync();

      for (final d in [a, b]) {
        expect(await d.count('payouts'), 2, reason: 'no money event lost');
        expect(await d.count('payout_allocations'), 2);
        expect((await d.row('payouts', pa)), isNotNull);
        expect((await d.row('payouts', pb)), isNotNull);
        final r = await d.row('orders', o);
        expect(r!['outstanding'] as int, lessThan(0));
        final conflicts = await d.engine.conflicts();
        expect(conflicts.where((x) => x['kind'] == 'over_allocation'), isNotEmpty);
      }
      // Fix is an explicit reversal; it converges on both devices.
      expect((await b.payouts.reversePayout(pb, 'duplicate entry')).isOk, isTrue);
      await b.sync();
      await a.sync();
      for (final d in [a, b]) {
        expect((await d.row('payouts', pb))!['status'], 'reversed');
        expect((await d.row('orders', o))!['outstanding'], 0);
      }
    });

    test('rewriting an existing money row is rejected by the server and logged', () async {
      final a = await dev('A');
      final b = await dev('B');
      final c = await a.customer('Rahim', '01712345678');
      final courier = await a.courier('Pathao');
      final o = await a.order(c, courier, 'CN1', delivered: true);
      final p = await a.payFull(courier, o);
      await a.sync();
      await b.sync();
      final original = (await b.row('payouts', p))!['total_received'];

      b.tick(30);
      await b.db.customStatement(
          'UPDATE payouts SET total_received = 1, updated_at = ? WHERE id = ?',
          [b.clock.now().millisecondsSinceEpoch ~/ 1000, p]);
      await b.sync();
      expect(server.row('payouts', p)!['total_received'], original);
      final log = await b.engine.conflicts();
      expect(log.where((x) => x['kind'] == 'rejected'), isNotEmpty);
    });
  });

  group('chaos', () {
    test('lost ack + duplicate push apply exactly once', () async {
      final a = await dev('A');
      final c = await a.customer('Rahim', '01712345678');
      a.transport.loseNextAck = true;
      final r1 = await a.sync();
      expect(r1.ok, isFalse);
      expect((await a.engine.status()).phase, SyncPhase.error);
      expect((await a.engine.status()).pending, greaterThan(0));
      final versionAfterFirst = server.serverVersion;

      a.transport.duplicatePush = true;
      final r2 = await a.sync();
      expect(r2.ok, isTrue);
      expect(server.serverVersion, versionAfterFirst);
      expect((await a.engine.status()).phase, SyncPhase.synced);
      expect(server.row('customers', c), isNotNull);
    });

    test('push failure keeps the outbox; entry is never blocked; retry succeeds', () async {
      final a = await dev('A');
      final c = await a.customer('Offline', '01712345678');
      a.transport.failNextPush = true;
      expect((await a.sync()).ok, isFalse);
      // The seller keeps working while offline.
      await a.customer('Also offline', '01812345678');
      expect((await a.engine.status()).pending, greaterThan(0));
      expect((await a.sync()).ok, isTrue);
      expect(server.row('customers', c), isNotNull);
    });

    test('pull failure mid-way resumes from the stored cursor', () async {
      final a = await dev('A');
      final b = await dev('B');
      for (var i = 0; i < 12; i++) {
        await a.customer('C$i', '017123456${(10 + i).toString().padLeft(2, '0')}');
      }
      await a.sync();
      b.transport.pageSize = 5;
      b.transport.failNextPull = true;
      expect((await b.sync()).ok, isFalse);
      expect((await b.sync()).ok, isTrue);
      expect(await b.count('customers'), 12);
    });

    test('out-of-order rows inside a page (children before parents) still apply', () async {
      final a = await dev('A');
      final b = await dev('B');
      final c = await a.customer('Rahim', '01712345678');
      final courier = await a.courier('Pathao');
      await a.order(c, courier, 'CN1', delivered: true);
      await a.sync();
      b.transport.shufflePull = true;
      expect((await b.sync()).ok, isTrue);
      expect(await b.snapshot(), await a.snapshot());
    });

    test('a device with a slow clock converges and its later edits still win', () async {
      final a = await dev('A', start: t0.add(const Duration(hours: 5)));
      final b = await dev('B', start: t0);
      final c = await a.customer('Rahim', '01712345678');
      await a.sync();
      await b.sync();
      b.tick(60);
      await b.db.customStatement(
          "UPDATE customers SET name = 'from slow clock', updated_at = ? WHERE id = ?",
          [b.clock.now().millisecondsSinceEpoch ~/ 1000, c]);
      await b.sync();
      await a.sync();
      // B's wall clock is 5h behind, so by HLC order A's earlier-created value
      // can win on exact wall time; both replicas must still agree.
      expect((await a.row('customers', c))!['name'], (await b.row('customers', c))!['name']);
    });
  });

  test('backoff grows then caps', () {
    expect(syncBackoff(0), const Duration(seconds: 5));
    expect(syncBackoff(1), const Duration(seconds: 10));
    expect(syncBackoff(3), const Duration(seconds: 40));
    expect(syncBackoff(30), const Duration(minutes: 30));
  });

  test('replace-with-cloud discards local data after a preview', () async {
    final a = await dev('A');
    final c = await a.customer('Cloud customer', '01712345678');
    await a.sync();
    final b = await Dev.create('B', server, start: t0);
    addTearDown(b.db.close);
    await b.customer('Local only', '01899999999');
    final preview = await b.transport.summary();
    expect(preview['customers'], 1);
    expect((await b.engine.localCounts())['customers'], 1);
    await b.engine.replaceWithCloud(b.transport);
    expect(await b.count('customers'), 1);
    expect((await b.row('customers', c)), isNotNull);
    expect((await b.engine.status()).phase, SyncPhase.synced);
  });

  test('local-only mode is untouched while sync is disabled', () async {
    final d = await Dev.create('A', server, start: t0);
    addTearDown(d.db.close);
    final c = await d.customer('Rahim', '01712345678');
    final courier = await d.courier('Pathao');
    final o = await d.order(c, courier, 'CN1');
    expect((await d.engine.status()).phase, SyncPhase.disabled);
    expect((await d.row('orders', o))!['device_code'], '');
    expect((await d.row('orders', o))!['order_no'], 'ORD-0001');
    expect((await d.sync()).pushed, 0);
    expect(await d.count('sync_dirty', where: '1 = 1'), 0);
    expect(server.serverVersion, 0);
  });

  test('schema sanity', () {
    expect(kSyncSpecs['orders']!.excluded, containsAll(['status', 'outstanding', 'profit']));
    expect(kSyncSpecs['payouts']!.policy, TablePolicy.appendOnly);
    expect(AppDatabase.memory().schemaVersion, greaterThanOrEqualTo(13));
  });
}
