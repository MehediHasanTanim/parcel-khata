import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/domain/permissions.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

import 'sim.dart';

void main() {
  final t0 = DateTime(2026, 10, 15, 12);
  const ownerP = Principal(userId: 'owner-1', shopId: 's', role: 'owner');
  late SyncServer server;
  late Dev owner;
  late String courierId;
  late String customerId;
  late String productId;

  setUp(() async {
    server = SyncServer(schema: kSyncSpecs, authorizer: const RolePolicy(), nowMs: () => 7);
    owner = await Dev.create('owner', server, start: t0, principal: ownerP);
    addTearDown(owner.db.close);
    await owner.engine.setIdentity(userId: ownerP.userId, role: 'owner');
    await owner.engine.enable();
    courierId = await owner.courier('Pathao');
    customerId = await owner.customer('Rahim', '01712345678');
    final prod = ProductRepository(owner.db, owner.ids, owner.clock, owner.audit, 's');
    productId = (await prod.create(const ProductInput(
            name: 'Cotton Shirt', sellPrice: Money.taka(650), costPrice: Money.taka(400))))
        .valueOrNull!
        .id;
    // An existing delivered + paid order: charges and a payout live on the server.
    final o = await owner.order(customerId, courierId, 'CN-OWN', delivered: true);
    await owner.payFull(courierId, o);
    expect((await owner.sync()).ok, isTrue);
  });

  Future<Dev> joinAs(String role, String phone) async {
    final code = server.invite(ownerP, phone: phone, role: role);
    final p = server.accept(phone: phone, code: code);
    final d = await Dev.create('helper-$role', server, start: t0, principal: p);
    addTearDown(d.db.close);
    await d.engine.setIdentity(userId: p.userId, role: p.role);
    await d.engine.replaceWithCloud(d.transport);
    return d;
  }

  test('a helper device never receives cost, deductions, payouts or expenses', () async {
    final h = await joinAs('order_taker', '01811111111');
    expect(await h.count('customers'), 1);
    expect(await h.count('orders'), 1);
    expect(await h.count('payouts', where: '1 = 1'), 0);
    expect(await h.count('payout_allocations', where: '1 = 1'), 0);
    expect(await h.count('order_charges', where: '1 = 1'), 0);
    expect(await h.count('courier_rate_rules', where: '1 = 1'), 0);
    // Cost columns exist but are empty on the helper device.
    final line = await h.db.customSelect('SELECT unit_cost_price FROM order_lines').getSingle();
    expect(line.read<int?>('unit_cost_price'), isNull);
    final prod = await h.db.customSelect('SELECT default_cost_price, default_sell_price FROM products').getSingle();
    expect(prod.read<int?>('default_cost_price'), isNull);
    expect(prod.read<int>('default_sell_price'), 65000);
    expect(await h.engine.currentRole(), 'order_taker');
  });

  test('helper-created order gets its cost snapshot from the server; owner margin is complete',
      () async {
    final h = await joinAs('order_taker', '01811111111');
    final o = (await h.orders.create(OrderInput(
      customerId: customerId,
      address: 'Road 9',
      lines: [
        LineInput(
          name: 'Cotton Shirt',
          qty: 2,
          unitSell: const Money.taka(650),
          productId: productId,
        ),
      ],
    )))
        .valueOrNull!;
    expect((await h.sync()).ok, isTrue);
    expect((await owner.sync()).ok, isTrue);

    final line = await owner.db.customSelect(
        'SELECT unit_cost_price, unit_sell_price FROM order_lines WHERE order_id = ?',
        variables: [Variable.withString(o.id)]).getSingle();
    expect(line.read<int>('unit_cost_price'), 40000);
    final row = await owner.row('orders', o.id);
    expect(row!['profit_state'], isNot('incomplete'));
    // The helper's own copy still has no cost.
    final hl = await h.db.customSelect(
        'SELECT unit_cost_price FROM order_lines WHERE order_id = ?',
        variables: [Variable.withString(o.id)]).getSingle();
    expect(hl.read<int?>('unit_cost_price'), isNull);
  });

  test('forbidden direct writes from a helper device are rejected and cannot change money',
      () async {
    final h = await joinAs('order_taker', '01811111111');
    final orderId = (await h.db.customSelect('SELECT id FROM orders').getSingle()).read<String>('id');
    final before = (await owner.row('orders', orderId))!['cod_collected'];

    h.tick(30);
    final ts = h.clock.now().millisecondsSinceEpoch ~/ 1000;
    await h.db.customStatement(
        'UPDATE orders SET cod_collected = 1, updated_at = ? WHERE id = ?', [ts, orderId]);
    await h.db.customStatement(
        "INSERT INTO payouts(id, shop_id, created_at, updated_at, courier_id, paid_at, total_received) "
        "VALUES('evil', 's', ?, ?, ?, ?, 999999)",
        [ts, ts, courierId, ts]);
    final out = await h.sync();
    expect(out.ok, isTrue);
    expect(server.row('orders', orderId)!['cod_collected'], before);
    expect(server.row('payouts', 'evil'), isNull);
    final log = await h.engine.conflicts();
    expect(log.where((c) => c['kind'] == 'rejected').length, greaterThanOrEqualTo(2));
  });

  test('revoke wipes the shop cache on the next sync', () async {
    final code = server.invite(ownerP, phone: '01822222222', role: 'packer');
    final p = server.accept(phone: '01822222222', code: code);
    final h = await Dev.create('packer', server, start: t0, principal: p);
    addTearDown(h.db.close);
    await h.engine.setIdentity(userId: p.userId, role: p.role);
    await h.engine.replaceWithCloud(h.transport);
    expect(await h.count('orders'), 1);
    expect(await h.count('customers'), 1);

    server.revoke(ownerP, p.userId); // instant, server side
    final out = await h.sync();
    expect(out.revoked, isTrue);
    expect(await h.count('orders'), 0);
    expect(await h.count('customers'), 0);
    expect(await h.count('products'), 0);
    expect((await h.engine.status()).phase, SyncPhase.revoked);
    expect(await h.engine.currentRole(), 'owner'); // local-only again, empty
    // Still revoked: a retry cannot bring data back.
    expect((await h.sync()).pulled, 0);
    expect(await h.count('orders'), 0);
    // The owner keeps everything.
    expect(await owner.count('orders'), 1);
    expect((await owner.sync()).ok, isTrue);
  });

  test('packer enters a CN and hands over; cannot deliver or pay', () async {
    final o = await owner.order(customerId, courierId, 'CN-NEW');
    await owner.db.customStatement(
        "UPDATE orders SET consignment_no = NULL, updated_at = ? WHERE id = ?",
        [owner.clock.now().millisecondsSinceEpoch ~/ 1000 + 5, o]);
    await owner.sync();
    final h = await joinAs('packer', '01833333333');
    h.tick(20);
    await h.db.customStatement(
        "UPDATE orders SET consignment_no = 'CN-PACKED', updated_at = ? WHERE id = ?",
        [h.clock.now().millisecondsSinceEpoch ~/ 1000, o]);
    h.tick(2);
    expect((await h.status.changeStatus(o, to: OrderStatus.handedToCourier, at: h.clock.now())).isOk,
        isTrue);
    expect((await h.sync()).ok, isTrue);
    expect(server.row('orders', o)!['consignment_no'], 'CN-PACKED');

    // Delivered is the owner's decision: the packer's event is refused.
    await h.status.changeStatus(o, to: OrderStatus.delivered, at: h.clock.now());
    expect((await h.sync()).ok, isTrue);
    expect((await h.engine.conflicts()).any((c) => c['kind'] == 'rejected'), isTrue);
    expect((await owner.sync()).ok, isTrue);
    expect((await owner.row('orders', o))!['status'], 'handed_to_courier');
  });

  test('activity log attributes helper writes and flags money-affecting ones', () async {
    final code = server.invite(ownerP, phone: '01844444444', role: 'order_taker');
    final p = server.accept(phone: '01844444444', code: code);
    final h = await Dev.create('taker', server, start: t0, principal: p);
    addTearDown(h.db.close);
    await h.engine.setIdentity(userId: p.userId, role: p.role);
    await h.engine.replaceWithCloud(h.transport);
    await h.orders.create(OrderInput(
      customerId: customerId,
      address: 'Road 1',
      lines: [
        LineInput(name: 'Cotton Shirt', qty: 1, unitSell: const Money.taka(650), productId: productId)
      ],
    ));
    await h.sync();

    final all = await owner.engine.fetchActivity(owner.transport);
    final mine = all.where((e) => e.actorUserId == p.userId).toList();
    expect(mine, isNotEmpty);
    expect(mine.every((e) => e.role == 'order_taker'), isTrue);
    expect(mine.any((e) => e.table == 'orders'), isTrue);
    // Order lines carry price/qty: money-affecting.
    expect(mine.where((e) => e.table == 'order_lines').every((e) => e.money), isTrue);
    expect(mine.where((e) => e.table == 'customers'), isEmpty);
    // The owner's own payout is attributed to the owner and flagged.
    final payouts = all.where((e) => e.table == 'payouts').toList();
    expect(payouts.single.actorUserId, 'owner-1');
    expect(payouts.single.money, isTrue);
    // Filters.
    expect((await owner.engine.fetchActivity(owner.transport, actor: p.userId)).every((e) => e.actorUserId == p.userId),
        isTrue);
    expect((await owner.engine.fetchActivity(owner.transport, moneyOnly: true)).every((e) => e.money),
        isTrue);
    // Helpers cannot read the log.
    expect(await h.engine.fetchActivity(h.transport), isEmpty);
    // Local audit rows record the actor too.
    final audit = await h.db.customSelect(
        "SELECT actor_user_id FROM audit_log WHERE entity = 'order' LIMIT 1").getSingle();
    expect(audit.read<String>('actor_user_id'), p.userId);
  });

  test('local-only owner: roles are inert, everything allowed', () async {
    final solo = await Dev.create('solo', SyncServer(), start: t0);
    addTearDown(solo.db.close);
    expect(await solo.engine.currentRole(), 'owner');
    for (final a in Capability.values) {
      expect(can(Role.fromWire(await solo.engine.currentRole())!, a), isTrue);
    }
    final audit = await solo.db.customSelect('SELECT COUNT(*) n FROM audit_log').getSingle();
    expect(audit.read<int>('n'), greaterThanOrEqualTo(0));
  });
}
