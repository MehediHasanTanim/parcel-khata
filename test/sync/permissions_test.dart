import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/sync/application/sync_engine.dart';
import 'package:parcel_khata/features/sync/domain/permissions.dart';
import 'package:parcel_khata/features/sync/domain/sync_protocol.dart';

/// The permission matrix is ONE table (`kActions`, `kTableAccess`). These
/// tests replay every action as real server writes for every role and assert
/// the server's decision equals the client's gating.
void main() {
  const shop = 'shopA';
  final owner = const Principal(userId: 'owner', shopId: shop, role: 'owner');
  Principal as(Role r) => Principal(userId: 'u-${r.wire}', shopId: shop, role: r.wire);

  int clockN = 0;
  Hlc stamp() => Hlc(1000 + clockN++, 0, 'dev');

  /// Fresh server with a baseline row of every table, written by the owner.
  SyncServer seeded() {
    final s = SyncServer(schema: kSyncSpecs, authorizer: const RolePolicy(), nowMs: () => 5);
    final rows = <(String, Map<String, Object?>)>[
      ('customers', {'name': 'Base', 'phone_primary': '01711111111'}),
      ('products', {'name': 'Base', 'default_sell_price': 1, 'default_cost_price': 400}),
      ('product_variants', {'label': 'M', 'cost_price': 300}),
      ('couriers', {'name': 'Pathao'}),
      ('courier_rate_rules', {'zone': 'z', 'delivery_fee': 1}),
      ('orders', {'order_no': 'B-1', 'address': 'a', 'cod_expected': 1}),
      ('order_lines', {'name_snapshot': 'x', 'qty': 1, 'unit_cost_price': 400}),
      ('order_charges', {'type': 'delivery_fee', 'expected_amount': 60}),
      ('payouts', {'status': 'active', 'total_received': 1}),
      ('payout_allocations', {'amount_applied': 1}),
      ('return_records', {'type': 'full', 'reason': 'x'}),
      ('expenses', {'category': 'rent', 'amount': 1}),
      ('campaigns', {'name': 'c'}),
    ];
    final batch = [
      for (final r in rows)
        Change(
          changeId: 'seed-${r.$1}',
          table: r.$1,
          rowId: 'r1',
          shopId: shop,
          fields: {for (final e in r.$2.entries) e.key: Versioned(e.value, stamp())},
        ),
    ];
    final res = s.push(owner, 'seed', batch);
    expect(res.rejected, isEmpty, reason: '${res.rejected}');
    return s;
  }

  /// Orders are probed on the seeded row (a packer may only touch existing
  /// orders); everything else on a fresh row so insert-once tables are not
  /// compared with the seed.
  Set<String> pushProbe(SyncServer s, Role role, Probe p, {String? rowId}) {
    rowId ??= p.table == 'orders' ? 'r1' : 'fresh-${clockN++}';
    final res = s.push(as(role), 'dev-${role.wire}', [
      Change(
        changeId: 'probe-${clockN++}',
        table: p.table,
        rowId: rowId,
        shopId: shop,
        fields: {for (final e in p.fields.entries) e.key: Versioned(e.value, stamp())},
      ),
    ]);
    return res.rejected.values.toSet();
  }

  group('matrix: client gating == server policy', () {
    for (final action in Capability.values) {
      for (final role in Role.values) {
        final spec = kActions[action]!;
        if (spec.probes.isEmpty) continue;
        test('${action.name} / ${role.wire}', () {
          final server = seeded();
          final expected = can(role, action);
          final results = [for (final p in spec.probes) pushProbe(server, role, p)];
          final allAccepted = results.every((r) => r.isEmpty);
          expect(allAccepted, expected,
              reason: 'server=$results client=$expected for ${action.name} as ${role.wire}');
          if (!expected) {
            // At least one probe is refused, never silently half-applied.
            expect(results.any((r) => r.isNotEmpty), isTrue);
          }
        });
      }
    }

    test('every action is defined for every role (no holes in the table)', () {
      for (final a in Capability.values) {
        expect(kActions.containsKey(a), isTrue, reason: a.name);
      }
      for (final t in kTableAccess.entries) {
        for (final r in Role.values) {
          expect(t.value.containsKey(r), isTrue, reason: '${t.key} missing ${r.wire}');
        }
      }
    });

    for (final role in Role.values) {
      test('read-only capabilities / ${role.wire}', () {
        final s = seeded();
        final pulled = s.pull(as(role), 0, limit: 1000).rows;
        Object? field(String table, String f) =>
            pulled.where((r) => r.table == table).map((r) => r[f]).firstOrNull;
        bool visible(String table) => pulled.any((r) => r.table == table);

        // viewCostAndProfit: cost fields and courier deductions are never sent.
        final sees = can(role, Capability.viewCostAndProfit);
        expect(field('order_lines', 'unit_cost_price') != null, sees);
        expect(field('products', 'default_cost_price') != null, sees);
        expect(field('product_variants', 'cost_price') != null, sees);
        expect(visible('order_charges'), sees);
        expect(visible('courier_rate_rules'), sees);
        // viewReports needs payouts + expenses.
        expect(visible('payouts') && visible('expenses'), can(role, Capability.viewReports));
        // viewActivity / manageHelpers
        expect(s.activity(as(role)).isNotEmpty, can(role, Capability.viewActivity));
        if (can(role, Capability.manageHelpers)) {
          expect(s.invite(as(role), phone: '01811111111', role: 'packer'), isNotEmpty);
        } else {
          expect(() => s.invite(as(role), phone: '01811111111', role: 'packer'),
              throwsStateError);
        }
        // Everyone sees the shop's orders and customers (they need them).
        expect(visible('orders'), isTrue);
        expect(visible('customers'), isTrue);
      });
    }
  });

  group('negative tests: direct forbidden writes', () {
    test('order-taker cannot set collected amount or dispute flags', () {
      final s = seeded();
      expect(pushProbe(s, Role.orderTaker, const Probe('orders', {'cod_collected': 500})),
          {'forbidden_field:cod_collected'});
      expect(pushProbe(s, Role.orderTaker, const Probe('orders', {'is_disputed': 1})),
          {'forbidden_field:is_disputed'});
      // Insert defaults are fine (a normal order create sends them).
      expect(
          pushProbe(s, Role.orderTaker,
              const Probe('orders', {'cod_collected': null, 'is_disputed': 0}), rowId: 'new1'),
          isEmpty);
      expect(s.row('orders', 'r1')!['cod_collected'], isNull);
    });

    test('packer may touch only dispatch fields and cannot create orders', () {
      final s = seeded();
      expect(pushProbe(s, Role.packer, const Probe('orders', {'address': 'hijack'})),
          {'forbidden_field:address'});
      expect(pushProbe(s, Role.packer, const Probe('orders', {'courier_id': 'c1'}), rowId: 'brand-new'),
          {'forbidden_role'});
      expect(s.row('orders', 'brand-new'), isNull);
    });

    test('status events are limited to the role\'s statuses', () {
      final s = seeded();
      expect(pushProbe(s, Role.orderTaker, const Probe('order_status_events', {'to_status': 'delivered'}), rowId: 'e1'),
          {'forbidden_status:delivered'});
      expect(pushProbe(s, Role.packer, const Probe('order_status_events', {'to_status': 'cancelled'}), rowId: 'e2'),
          {'forbidden_status:cancelled'});
      expect(pushProbe(s, Role.packer, const Probe('order_status_events', {'to_status': 'packed'}), rowId: 'e3'),
          isEmpty);
    });

    test('helpers cannot reverse or edit payouts, nor write other shops', () {
      final s = seeded();
      for (final r in [Role.orderTaker, Role.packer]) {
        expect(pushProbe(s, r, const Probe('payouts', {'status': 'reversed'})), {'forbidden_role'});
      }
      expect(s.row('payouts', 'r1')!['status'], 'active');
      final res = s.push(as(Role.orderTaker), 'x', [
        Change(
          changeId: 'cross',
          table: 'customers',
          rowId: 'r1',
          shopId: 'shopB',
          fields: {'name': Versioned('pwn', stamp())},
        ),
      ]);
      expect(res.rejected['cross'], 'wrong_shop');
    });

    test('hidden fields written by a helper are ignored, not applied', () {
      final s = seeded();
      final res = s.push(as(Role.orderTaker), 'h', [
        Change(
          changeId: 'hf',
          table: 'order_lines',
          rowId: 'r1',
          shopId: shop,
          fields: {
            'qty': Versioned(3, stamp()),
            'unit_cost_price': Versioned(1, stamp()),
          },
        ),
      ]);
      expect(res.rejected, isEmpty);
      expect(s.row('order_lines', 'r1')!['qty'], 3);
      expect(s.row('order_lines', 'r1')!['unit_cost_price'], 400);
    });

    test('revoked users are cut off on the next call', () {
      final s = seeded();
      final h = as(Role.orderTaker);
      expect(() => s.pull(h, 0), returnsNormally);
      s.revoke(owner, h.userId);
      expect(() => s.pull(h, 0), throwsA(isA<RevokedException>()));
      expect(() => s.push(h, 'd', const []), throwsA(isA<RevokedException>()));
      expect(() => s.revoke(h, 'someone'), throwsStateError);
    });

    test('invites: wrong phone or reused code is refused', () {
      final s = seeded();
      final code = s.invite(owner, phone: '01811111111', role: 'order_taker');
      expect(() => s.accept(phone: '01899999999', code: code), throwsStateError);
      final p = s.accept(phone: '01811111111', code: code);
      expect(p.role, 'order_taker');
      expect(p.shopId, shop);
      expect(() => s.accept(phone: '01811111111', code: code), throwsStateError);
    });

    test('activity log: server stamps the actor, flags money, owner-only', () {
      final s = seeded();
      pushProbe(s, Role.orderTaker, const Probe('customers', {'name': 'Edited'}));
      pushProbe(s, Role.packer, const Probe('orders', {'consignment_no': 'CN7'}));
      final entries = s.activity(owner);
      final byTaker = entries.where((e) => e.actorUserId == 'u-order_taker').toList();
      expect(byTaker, hasLength(1));
      expect(byTaker.single.table, 'customers');
      expect(byTaker.single.role, 'order_taker');
      expect(byTaker.single.money, isFalse);
      expect(s.activity(owner, actor: 'u-packer').single.table, 'orders');
      // The seeded owner payout is money-affecting.
      expect(s.activity(owner, moneyOnly: true).any((e) => e.table == 'payouts'), isTrue);
      expect(s.activity(as(Role.packer)), isEmpty);
    });
  });
}
