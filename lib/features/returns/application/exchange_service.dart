import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/profit/domain/profit_calculator.dart';
import 'package:parcel_khata/features/returns/application/return_service.dart';
import 'package:parcel_khata/features/returns/domain/exchange_calculator.dart';

class ExchangeRequest {
  const ExchangeRequest({
    required this.originalOrderId,
    required this.returned,
    required this.replacementLines,
    this.reason = 'size_or_color_issue',
    this.payer = ExchangePayer.seller,
    this.replacementDelivery = Money.zero,
    this.returnShipping = Money.zero,
    this.courierId,
    this.notes,
  });

  final String originalOrderId;
  final List<ReturnQty> returned;
  final List<LineInput> replacementLines;
  final String reason;
  final ExchangePayer payer;

  /// Delivery charge for the replacement (billed only if the customer pays).
  final Money replacementDelivery;

  /// Courier charge to bring the original goods back (billed only if the
  /// customer pays; otherwise it is the business's loss).
  final Money returnShipping;
  final String? courierId;
  final String? notes;
}

class ExchangePreview {
  const ExchangePreview({
    required this.returnedValue,
    required this.replacementValue,
    required this.outcome,
  });

  final Money returnedValue;
  final Money replacementValue;
  final ExchangeOutcome outcome;
}

class ExchangeResult {
  const ExchangeResult(this.replacement, this.record, this.preview);
  final Order replacement;
  final ReturnRecord record;
  final ExchangePreview preview;
}

/// Both halves of an exchange with their cached profit and the sum.
class ExchangeGroup {
  const ExchangeGroup({required this.original, required this.replacement});

  final Order original;
  final Order replacement;

  Money get net => Money((original.profit ?? 0) + (replacement.profit ?? 0));
  bool get incomplete =>
      original.profitState == ProfitState.incomplete.dbValue ||
      replacement.profitState == ProfitState.incomplete.dbValue;
  bool get provisional =>
      original.profitState != ProfitState.finalised.dbValue ||
      replacement.profitState != ProfitState.finalised.dbValue;
}

class _Abort implements Exception {
  _Abort(this.failure);
  final Failure failure;
}

class ExchangeService {
  ExchangeService(this._db, this._ids, this._clock, this._audit, this._shopId,
      this._orders, this._returns);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;
  final OrderRepository _orders;
  final ReturnService _returns;

  Future<Result<ExchangePreview>> preview(ExchangeRequest r) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(r.originalOrderId)))
        .getSingleOrNull();
    if (o == null || o.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    return _preview(o, r);
  }

  Future<Result<ExchangePreview>> _preview(Order o, ExchangeRequest r) async {
    if (OrderStatus.fromDb(o.status) != OrderStatus.delivered) {
      return const Result.err(ValidationFailure('exchange_needs_delivered'));
    }
    final picked = r.returned.where((q) => q.qty > 0).toList();
    if (picked.isEmpty) return const Result.err(ValidationFailure('no_lines'));
    if (r.replacementLines.isEmpty) {
      return const Result.err(ValidationFailure('no_replacement'));
    }
    final lines = await (_db.select(_db.orderLines)
          ..where((l) => l.orderId.equals(o.id) & l.deletedAt.isNull()))
        .get();
    for (final q in picked) {
      final l = lines.where((x) => x.id == q.orderLineId).firstOrNull;
      if (l == null || q.qty > l.qty) return const Result.err(ValidationFailure('bad_qty'));
    }
    final profitLines = [
      for (final l in lines)
        ProfitLine(
          name: l.nameSnapshot,
          qty: l.qty,
          unitSell: Money(l.unitSellPrice),
          lineDiscount: Money(l.lineDiscount),
          returnedQty: picked
              .where((q) => q.orderLineId == l.id)
              .fold(0, (s, q) => s + q.qty),
        ),
    ];
    final returnedValue =
        ProfitCalculator.returnedValue(profitLines, Money(o.discountTotal));
    final replacementValue = CodAmountCalculator.compute(
      lines: r.replacementLines,
      paymentType: PaymentType.cod,
      orderDiscount: const Discount.none(),
      deliveryCharge: Money.zero,
      advance: Money.zero,
    ).itemsTotal;
    final outcome = ExchangeCalculator.compute(ExchangeInput(
      returnedValue: returnedValue,
      replacementValue: replacementValue,
      replacementDelivery: r.replacementDelivery,
      returnShipping: r.returnShipping,
      payer: r.payer,
    ));
    return Result.ok(ExchangePreview(
      returnedValue: returnedValue,
      replacementValue: replacementValue,
      outcome: outcome,
    ));
  }

  /// Return record (initiated) + linked confirmed replacement, atomically.
  Future<Result<ExchangeResult>> create(ExchangeRequest r) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(r.originalOrderId)))
        .getSingleOrNull();
    if (o == null || o.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    if (await _returns.forOrder(o.id) != null) {
      return const Result.err(ConflictFailure('return_exists'));
    }
    final pv = await _preview(o, r);
    if (!pv.isOk) return Result.err(pv.failureOrNull!);
    final preview = pv.valueOrNull!;
    final out = preview.outcome;

    final input = OrderInput(
      customerId: o.customerId,
      address: o.addressSnapshot,
      channel: Channel.fromDb(o.channel),
      lines: r.replacementLines,
      paymentType: out.isEven ? PaymentType.prepaid : PaymentType.cod,
      deliveryCharge: out.customerDeliveryCharge,
      codOverride: out.isEven ? null : out.replacementCod,
      courierId: r.courierId ?? o.courierId,
      zone: o.zone,
      notes: r.notes,
      exchangeOfOrderId: o.id,
    );

    try {
      late Order replacement;
      late ReturnRecord record;
      await _db.transaction(() async {
        final created = await _orders.create(input);
        if (!created.isOk) throw _Abort(created.failureOrNull!);
        replacement = created.valueOrNull!;
        final init = await _returns.initiate(
          o.id,
          full: false,
          reason: r.reason,
          lines: r.returned,
          notes: r.notes,
          exchangeOrderId: replacement.id,
        );
        if (!init.isOk) throw _Abort(init.failureOrNull!);
        record = init.valueOrNull!;
        final now = _clock.now();
        Future<void> link(String orderId, String otherNo) =>
            _db.into(_db.orderEditLog).insert(OrderEditLogCompanion.insert(
                  id: _ids.generate(),
                  shopId: _shopId,
                  createdAt: now,
                  updatedAt: now,
                  orderId: orderId,
                  field: 'exchange',
                  newValue: Value(otherNo),
                  at: now,
                ));
        await link(o.id, replacement.orderNo);
        await link(replacement.id, o.orderNo);
        await _audit.write(
          entity: 'order',
          entityId: o.id,
          action: 'exchange',
          payload: {
            'replacement': replacement.id,
            'refundDue': out.refundDue.poisha,
            'cod': out.replacementCod.poisha,
          },
        );
      });
      return Result.ok(ExchangeResult(replacement, record, preview));
    } on _Abort catch (e) {
      return Result.err(e.failure);
    }
  }

  /// The other half of an exchange, whichever side [orderId] is on.
  Future<ExchangeGroup?> groupFor(String orderId) async {
    final o = await (_db.select(_db.orders)..where((x) => x.id.equals(orderId)))
        .getSingleOrNull();
    if (o == null) return null;
    if (o.exchangeOfOrderId != null) {
      final orig = await (_db.select(_db.orders)
            ..where((x) => x.id.equals(o.exchangeOfOrderId!)))
          .getSingleOrNull();
      return orig == null ? null : ExchangeGroup(original: orig, replacement: o);
    }
    final repl = await (_db.select(_db.orders)
          ..where((x) => x.exchangeOfOrderId.equals(orderId) & x.deletedAt.isNull()))
        .getSingleOrNull();
    return repl == null ? null : ExchangeGroup(original: o, replacement: repl);
  }
}

final exchangeServiceProvider = Provider<ExchangeService>((ref) => ExchangeService(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
      ref.watch(orderRepositoryProvider),
      ref.watch(returnServiceProvider),
    ));
