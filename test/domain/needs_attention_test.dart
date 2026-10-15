import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/reminders/domain/digest.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);
  DateTime ago({int d = 0, int h = 0}) => now.subtract(Duration(days: d, hours: h));

  OrderAttentionFacts o(
    String id, {
    OrderStatus status = OrderStatus.confirmed,
    CodStatus cod = CodStatus.pendingCollection,
    DateTime? created,
    DateTime? handed,
    DateTime? delivered,
    DateTime? lastEvent,
    DateTime? returnStarted,
    int? stuck,
    int? cycle,
    bool cn = false,
    int outstanding = 0,
  }) =>
      OrderAttentionFacts(
        orderId: id,
        orderNo: 'ORD-$id',
        status: status,
        codStatus: cod,
        createdAt: created ?? ago(d: 30),
        handedOverAt: handed,
        deliveredAt: delivered,
        lastEventAt: lastEvent,
        returnStartedAt: returnStarted,
        stuckDays: stuck,
        payoutCycleDays: cycle,
        hasCn: cn,
        hasCourier: cn,
        outstandingPoisha: outstanding,
      );

  List<AttentionItem> build(
    List<OrderAttentionFacts> orders, {
    Map<String, ReminderState> states = const {},
    DateTime? lastBackup,
    DateTime? firstUse,
    AttentionThresholds t = const AttentionThresholds(),
  }) =>
      NeedsAttentionBuilder.build(
        orders: orders,
        states: states,
        now: now,
        thresholds: t,
        lastBackupAt: lastBackup,
        firstUseAt: firstUse,
      );

  group('sources trigger at the threshold and not before', () {
    test('stale handed-over: courier threshold N days since last update', () {
      final at = o('a', status: OrderStatus.handedToCourier, handed: ago(d: 3), lastEvent: ago(d: 3), stuck: 3, cn: true);
      final before = o('b', status: OrderStatus.handedToCourier, handed: ago(d: 2), lastEvent: ago(d: 2, h: 23), stuck: 3, cn: true);
      final r = build([at, before]);
      expect(r.map((i) => i.order!.orderId), ['a']);
      expect(r.single.kind, AttentionKind.staleHandedOver);
    });

    test('stale uses default threshold without courier setting', () {
      final r = build([o('a', status: OrderStatus.inTransit, lastEvent: ago(d: 3), cn: true)]);
      expect(r, hasLength(1));
    });

    test('overdue COD: strictly longer than the payout cycle (scenario 13)', () {
      final eight = o('a', status: OrderStatus.delivered, cod: CodStatus.collectedByCourier, delivered: ago(d: 8), cycle: 5, cn: true);
      final five = o('b', status: OrderStatus.delivered, cod: CodStatus.collectedByCourier, delivered: ago(d: 5), cycle: 5, cn: true);
      final r = build([eight, five]);
      expect(r.map((i) => i.order!.orderId), ['a']);
      expect(r.single.kind, AttentionKind.overdueCod);
    });

    test('settled COD is never overdue', () {
      expect(
          build([o('a', status: OrderStatus.delivered, cod: CodStatus.settled, delivered: ago(d: 30), cycle: 3)]),
          isEmpty);
    });

    test('returns in transit too long', () {
      final r = build([
        o('a', status: OrderStatus.returnInTransit, returnStarted: ago(d: 7)),
        o('b', status: OrderStatus.returnInTransit, returnStarted: ago(d: 6)),
      ]);
      expect(r.map((i) => i.order!.orderId), ['a']);
    });

    test('draft older than 24 hours', () {
      final r = build([
        o('a', status: OrderStatus.draft, created: ago(h: 25)),
        o('b', status: OrderStatus.draft, created: ago(h: 23)),
      ]);
      expect(r.map((i) => i.order!.orderId), ['a']);
    });

    test('dispute always shows', () {
      final r = build([o('a', status: OrderStatus.delivered, cod: CodStatus.disputed, delivered: ago(d: 1), cycle: 5, lastEvent: ago(d: 1))]);
      expect(r.single.kind, AttentionKind.dispute);
    });

    test('to dispatch: confirmed without CN only', () {
      final r = build([
        o('a', status: OrderStatus.confirmed),
        o('b', status: OrderStatus.packed),
        o('c', status: OrderStatus.confirmed, cn: true),
      ]);
      expect(r.map((i) => i.order!.orderId).toSet(), {'a', 'b'});
    });
  });

  group('queue behaviour', () {
    test('priority order then age', () {
      final items = build([
        o('dispatch', status: OrderStatus.confirmed),
        o('draft', status: OrderStatus.draft, created: ago(d: 3)),
        o('stale', status: OrderStatus.handedToCourier, lastEvent: ago(d: 4), stuck: 3, cn: true),
        o('cod', status: OrderStatus.delivered, cod: CodStatus.collectedByCourier, delivered: ago(d: 9), cycle: 3, cn: true),
      ]);
      expect(items.map((i) => i.order!.orderId), ['stale', 'cod', 'draft', 'dispatch']);
    });

    test('older items first within a kind', () {
      final items = build([
        o('new', status: OrderStatus.handedToCourier, lastEvent: ago(d: 4), stuck: 3, cn: true),
        o('old', status: OrderStatus.handedToCourier, lastEvent: ago(d: 9), stuck: 3, cn: true),
      ]);
      expect(items.map((i) => i.order!.orderId), ['old', 'new']);
    });

    test('one entry per order: dispute outranks overdue COD', () {
      final items = build([
        o('a', status: OrderStatus.delivered, cod: CodStatus.disputed, delivered: ago(d: 20), cycle: 3, lastEvent: ago(d: 20), cn: true),
      ]);
      expect(items, hasLength(1));
      expect(items.single.kind, AttentionKind.overdueCod); // lower index = higher priority
    });

    test('snooze hides until the date; dismiss hides for good', () {
      final order = o('a', status: OrderStatus.confirmed);
      final key = NeedsAttentionBuilder.keyFor(AttentionKind.toDispatch, 'a');
      expect(
          build([order], states: {key: ReminderState(snoozedUntil: now.add(const Duration(days: 1)))}),
          isEmpty);
      // Snooze expired -> reappears (F11 AC2).
      expect(
          build([order], states: {key: ReminderState(snoozedUntil: now.subtract(const Duration(hours: 1)))}),
          hasLength(1));
      expect(build([order], states: {key: const ReminderState(dismissed: true)}), isEmpty);
    });

    test('badge count equals queue length', () {
      final items = build([
        o('a', status: OrderStatus.confirmed),
        o('b', status: OrderStatus.draft, created: ago(d: 2)),
      ]);
      expect(items.length, 2);
    });

    test('resolved orders drop out', () {
      expect(build([o('a', status: OrderStatus.delivered, cod: CodStatus.settled, cn: true)]), isEmpty);
    });
  });

  group('backup reminder', () {
    test('due after 7 days since last backup', () {
      expect(build(const [], lastBackup: ago(d: 6)), isEmpty);
      final r = build(const [], lastBackup: ago(d: 7));
      expect(r.single.kind, AttentionKind.backupDue);
      expect(r.single.days, 7);
    });

    test('never backed up: measured from first use', () {
      expect(build(const [], firstUse: ago(d: 3)), isEmpty);
      expect(build(const [], firstUse: ago(d: 10)), hasLength(1));
    });

    test('configurable threshold and snooze', () {
      const t = AttentionThresholds(backupReminderDays: 2);
      expect(build(const [], lastBackup: ago(d: 2), t: t), hasLength(1));
      expect(
          build(const [],
              lastBackup: ago(d: 5),
              states: {'backupDue': ReminderState(snoozedUntil: now.add(const Duration(days: 1)))}),
          isEmpty);
    });
  });

  group('digest', () {
    test('counts by kind with toggles and overdue amount', () {
      final items = build([
        o('a', status: OrderStatus.delivered, cod: CodStatus.collectedByCourier, delivered: ago(d: 9), cycle: 3, cn: true, outstanding: 230000),
        o('b', status: OrderStatus.confirmed),
        o('c', status: OrderStatus.handedToCourier, lastEvent: ago(d: 5), stuck: 3, cn: true),
      ]);
      final all = DigestBuilder.count(items);
      expect(all.total, 3);
      expect(all.overdueCodPoisha, 230000);
      final only = DigestBuilder.count(items, enabled: {AttentionKind.staleHandedOver});
      expect(only.total, 1);
      expect(only.overdueCodPoisha, 0);
    });

    test('quiet hours wrap midnight and shift the fire time', () {
      const q = QuietHours(startMinute: 22 * 60, endMinute: 7 * 60);
      expect(q.contains(23 * 60), isTrue);
      expect(q.contains(6 * 60 + 59), isTrue);
      expect(q.contains(7 * 60), isFalse);
      expect(q.contains(12 * 60), isFalse);
      final shifted = q.shiftOutOf(DateTime(2026, 10, 15, 23));
      expect(shifted, DateTime(2026, 10, 16, 7));
      final early = q.shiftOutOf(DateTime(2026, 10, 15, 5));
      expect(early, DateTime(2026, 10, 15, 7));
      expect(const QuietHours(startMinute: 0, endMinute: 0).contains(100), isFalse);
    });

    test('next fire time is strictly in the future and avoids quiet hours', () {
      final n = DateTime(2026, 10, 15, 21, 0);
      expect(DigestBuilder.nextFireTime(n, 21 * 60), DateTime(2026, 10, 16, 21));
      expect(DigestBuilder.nextFireTime(n, 22 * 60), DateTime(2026, 10, 15, 22));
      const q = QuietHours(startMinute: 22 * 60, endMinute: 7 * 60);
      expect(DigestBuilder.nextFireTime(n, 22 * 60, quiet: q), DateTime(2026, 10, 16, 7));
    });
  });
}
