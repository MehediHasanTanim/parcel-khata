import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_status_machine.dart';

void main() {
  const m = OrderStatusMachine();
  final now = DateTime.utc(2026, 10, 15, 12);

  TransitionError? check(
    OrderStatus from,
    OrderStatus to, {
    OrderStatusMachine machine = m,
    DateTime? at,
    bool courier = true,
    bool cn = true,
    String? reason,
    DateTime? initiated,
  }) =>
      machine.validate(
        from: from,
        to: to,
        at: at ?? now,
        now: now,
        hasCourier: courier,
        hasCn: cn,
        reason: reason,
        returnInitiatedAt: initiated,
      );

  group('transition table', () {
    test('every pair is either allowed or notAllowed exactly per table', () {
      for (final from in OrderStatus.values) {
        final allowed = m.allowedNext(from).toSet();
        for (final to in OrderStatus.values) {
          final err = check(from, to, reason: 'other');
          if (allowed.contains(to)) {
            expect(err, isNull, reason: '$from -> $to should be allowed');
          } else {
            expect(err, TransitionError.notAllowed, reason: '$from -> $to');
          }
        }
      }
    });

    test('terminal states have no next', () {
      for (final s in [OrderStatus.delivered, OrderStatus.returned, OrderStatus.cancelled, OrderStatus.draft]) {
        expect(m.allowedNext(s), isEmpty);
      }
    });

    test('cancel only before dispatch', () {
      expect(m.allowedNext(OrderStatus.confirmed), contains(OrderStatus.cancelled));
      expect(m.allowedNext(OrderStatus.packed), contains(OrderStatus.cancelled));
      expect(m.allowedNext(OrderStatus.handedToCourier), isNot(contains(OrderStatus.cancelled)));
    });

    test('optional steps follow settings', () {
      const short = OrderStatusMachine(packedEnabled: false, inTransitEnabled: false);
      expect(short.allowedNext(OrderStatus.confirmed), [OrderStatus.handedToCourier, OrderStatus.cancelled]);
      expect(short.allowedNext(OrderStatus.handedToCourier),
          [OrderStatus.delivered, OrderStatus.deliveryFailed]);
    });
  });

  group('guards', () {
    test('handed needs courier then CN', () {
      expect(check(OrderStatus.confirmed, OrderStatus.handedToCourier, courier: false),
          TransitionError.courierRequired);
      expect(check(OrderStatus.confirmed, OrderStatus.handedToCourier, cn: false),
          TransitionError.cnRequired);
      expect(check(OrderStatus.confirmed, OrderStatus.handedToCourier), isNull);
    });

    test('failed and cancelled need a reason', () {
      expect(check(OrderStatus.handedToCourier, OrderStatus.deliveryFailed),
          TransitionError.reasonRequired);
      expect(check(OrderStatus.handedToCourier, OrderStatus.deliveryFailed, reason: ' '),
          TransitionError.reasonRequired);
      expect(check(OrderStatus.confirmed, OrderStatus.cancelled),
          TransitionError.reasonRequired);
      expect(check(OrderStatus.confirmed, OrderStatus.cancelled, reason: 'out_of_stock'), isNull);
    });

    test('back-dating allowed, future rejected', () {
      expect(check(OrderStatus.handedToCourier, OrderStatus.delivered,
          at: now.subtract(const Duration(days: 3))), isNull);
      expect(check(OrderStatus.handedToCourier, OrderStatus.delivered,
          at: now.add(const Duration(minutes: 1))), TransitionError.futureDate);
    });

    test('received-back not before initiated', () {
      final started = now.subtract(const Duration(days: 2));
      expect(
          check(OrderStatus.returnInTransit, OrderStatus.returned,
              at: started.subtract(const Duration(hours: 1)), initiated: started),
          TransitionError.beforeInitiated);
      expect(check(OrderStatus.returnInTransit, OrderStatus.returned, at: started, initiated: started),
          isNull);
    });
  });

  group('correction', () {
    test('bypasses table but not draft/future/courier rules', () {
      TransitionError? c(OrderStatus to, {bool courier = true, bool cn = true, DateTime? at}) =>
          m.validateCorrection(
              to: to, at: at ?? now, now: now, hasCourier: courier, hasCn: cn);
      expect(c(OrderStatus.confirmed), isNull);
      expect(c(OrderStatus.draft), TransitionError.notAllowed);
      expect(c(OrderStatus.delivered, courier: false), TransitionError.courierRequired);
      expect(c(OrderStatus.delivered, cn: false), TransitionError.cnRequired);
      expect(c(OrderStatus.returned, courier: false), isNull);
      expect(c(OrderStatus.delivered, at: now.add(const Duration(days: 1))),
          TransitionError.futureDate);
    });
  });
}
