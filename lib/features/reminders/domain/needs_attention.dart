import 'package:meta/meta.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

/// The queue's sources, in priority order (feature spec F11).
enum AttentionKind {
  staleHandedOver,
  overdueCod,
  returnTooLong,
  oldDraft,
  dispute,
  toDispatch,
  backupDue,
}

@immutable
class OrderAttentionFacts {
  const OrderAttentionFacts({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.codStatus,
    required this.createdAt,
    this.handedOverAt,
    this.deliveredAt,
    this.lastEventAt,
    this.returnStartedAt,
    this.stuckDays,
    this.payoutCycleDays,
    this.hasCourier = false,
    this.hasCn = false,
    this.customerName,
    this.customerPhone,
    this.courierName,
    this.outstandingPoisha = 0,
    this.amountPoisha = 0,
    this.consignmentNo,
    this.trackingTemplate,
  });

  final String orderId;
  final String orderNo;
  final OrderStatus status;
  final CodStatus codStatus;
  final DateTime createdAt;
  final DateTime? handedOverAt;
  final DateTime? deliveredAt;

  /// Latest status event; "no update" is measured from here.
  final DateTime? lastEventAt;
  final DateTime? returnStartedAt;

  /// The order's courier thresholds (null when no courier).
  final int? stuckDays;
  final int? payoutCycleDays;
  final bool hasCourier;
  final bool hasCn;
  final String? customerName;
  final String? customerPhone;
  final String? courierName;
  final int outstandingPoisha;

  /// COD amount to collect (for message templates).
  final int amountPoisha;
  final String? consignmentNo;
  final String? trackingTemplate;
}

@immutable
class AttentionThresholds {
  const AttentionThresholds({
    this.defaultStaleDays = 3,
    this.returnInTransitDays = 7,
    this.draftHours = 24,
    this.backupReminderDays = 7,
  });

  /// Used when the order has no courier-specific threshold.
  final int defaultStaleDays;
  final int returnInTransitDays;
  final int draftHours;
  final int backupReminderDays;
}

/// Persisted per-item state: snoozed until / dismissed.
@immutable
class ReminderState {
  const ReminderState({this.snoozedUntil, this.dismissed = false});

  final DateTime? snoozedUntil;
  final bool dismissed;

  bool hiddenAt(DateTime now) =>
      dismissed || (snoozedUntil != null && snoozedUntil!.isAfter(now));
}

@immutable
class AttentionItem {
  const AttentionItem({
    required this.kind,
    required this.key,
    required this.since,
    required this.days,
    this.order,
  });

  final AttentionKind kind;

  /// Stable id used for snooze/dismiss: `kind:orderId` or `backup`.
  final String key;
  final DateTime since;
  final int days;
  final OrderAttentionFacts? order;

  int get priority => kind.index;
}

abstract final class NeedsAttentionBuilder {
  static String keyFor(AttentionKind k, String? orderId) =>
      orderId == null ? k.name : '${k.name}:$orderId';

  /// Builds the prioritized queue. One entry per order (its highest-priority
  /// reason); snoozed and dismissed items are hidden.
  static List<AttentionItem> build({
    required List<OrderAttentionFacts> orders,
    required Map<String, ReminderState> states,
    required DateTime now,
    AttentionThresholds thresholds = const AttentionThresholds(),
    DateTime? lastBackupAt,
    DateTime? firstUseAt,
  }) {
    final byOrder = <String, AttentionItem>{};

    void offer(AttentionItem item) {
      if (states[item.key]?.hiddenAt(now) ?? false) return;
      final id = item.order!.orderId;
      final cur = byOrder[id];
      if (cur == null || item.priority < cur.priority) byOrder[id] = item;
    }

    int daysSince(DateTime t) => now.difference(t).inDays;

    for (final o in orders) {
      switch (o.status) {
        case OrderStatus.handedToCourier:
        case OrderStatus.inTransit:
          final since = o.lastEventAt ?? o.handedOverAt ?? o.createdAt;
          final n = o.stuckDays ?? thresholds.defaultStaleDays;
          if (daysSince(since) >= n) {
            offer(AttentionItem(
              kind: AttentionKind.staleHandedOver,
              key: keyFor(AttentionKind.staleHandedOver, o.orderId),
              since: since,
              days: daysSince(since),
              order: o,
            ));
          }
        case OrderStatus.delivered:
          final disputed = o.codStatus == CodStatus.disputed;
          if (disputed) {
            offer(AttentionItem(
              kind: AttentionKind.dispute,
              key: keyFor(AttentionKind.dispute, o.orderId),
              since: o.lastEventAt ?? o.createdAt,
              days: daysSince(o.lastEventAt ?? o.createdAt),
              order: o,
            ));
          }
          final open = o.codStatus == CodStatus.collectedByCourier ||
              o.codStatus == CodStatus.partiallySettled ||
              disputed;
          final delivered = o.deliveredAt;
          if (open && delivered != null) {
            final cycle = o.payoutCycleDays ?? 3;
            // Strictly longer than the courier's payout cycle (spec F6 AC5).
            if (daysSince(delivered) > cycle) {
              offer(AttentionItem(
                kind: AttentionKind.overdueCod,
                key: keyFor(AttentionKind.overdueCod, o.orderId),
                since: delivered,
                days: daysSince(delivered),
                order: o,
              ));
            }
          }
        case OrderStatus.returnInTransit:
        case OrderStatus.deliveryFailed:
          final since = o.returnStartedAt ?? o.lastEventAt ?? o.createdAt;
          if (daysSince(since) >= thresholds.returnInTransitDays) {
            offer(AttentionItem(
              kind: AttentionKind.returnTooLong,
              key: keyFor(AttentionKind.returnTooLong, o.orderId),
              since: since,
              days: daysSince(since),
              order: o,
            ));
          }
        case OrderStatus.draft:
          if (now.difference(o.createdAt).inHours >= thresholds.draftHours) {
            offer(AttentionItem(
              kind: AttentionKind.oldDraft,
              key: keyFor(AttentionKind.oldDraft, o.orderId),
              since: o.createdAt,
              days: daysSince(o.createdAt),
              order: o,
            ));
          }
        case OrderStatus.confirmed:
        case OrderStatus.packed:
          if (!o.hasCn) {
            offer(AttentionItem(
              kind: AttentionKind.toDispatch,
              key: keyFor(AttentionKind.toDispatch, o.orderId),
              since: o.createdAt,
              days: daysSince(o.createdAt),
              order: o,
            ));
          }
        case OrderStatus.returned:
        case OrderStatus.cancelled:
          break;
      }
    }

    final items = byOrder.values.toList()
      ..sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        if (p != 0) return p;
        final d = b.days.compareTo(a.days);
        return d != 0 ? d : a.order!.orderNo.compareTo(b.order!.orderNo);
      });

    // Backup reminder (F14): measured from the last backup, or from first use
    // when there never was one.
    final reference = lastBackupAt ?? firstUseAt;
    if (reference != null && daysSince(reference) >= thresholds.backupReminderDays) {
      final key = keyFor(AttentionKind.backupDue, null);
      if (!(states[key]?.hiddenAt(now) ?? false)) {
        items.add(AttentionItem(
          kind: AttentionKind.backupDue,
          key: key,
          since: reference,
          days: daysSince(reference),
        ));
      }
    }
    return items;
  }
}
