import 'dart:convert';

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
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/couriers/domain/charge_calculator.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

export 'package:parcel_khata/features/orders/domain/order_filter.dart';

/// Page cursor for keyset pagination (order date desc, id desc).
class OrderCursor {
  const OrderCursor(this.orderDate, this.id);
  final DateTime orderDate;
  final String id;
}

class FilterTotals {
  const FilterTotals({
    required this.count,
    required this.codExpected,
    required this.outstanding,
    required this.profit,
    required this.profitFinal,
    required this.profitProvisional,
    required this.incompleteCount,
    required this.revenue,
    required this.grossCounted,
    required this.profitCounted,
    required this.delivered,
    required this.failedOrReturned,
    required this.dispatched,
    required this.countedOrders,
  });

  final int count;
  final int codExpected;
  final int outstanding;
  final int profit;
  final int profitFinal;
  final int profitProvisional;
  final int incompleteCount;

  /// Gross collected value on delivered orders.
  final int revenue;

  /// Gross and profit over orders whose profit is not Incomplete (margin).
  final int grossCounted;
  final int profitCounted;
  final int delivered;
  final int failedOrReturned;
  final int dispatched;
  final int countedOrders;
}

class OrderListItem {
  const OrderListItem(this.order, this.customerName, {this.courierStuckDays});
  final Order order;
  final String? customerName;

  /// Stuck threshold of the order's courier (null when no courier).
  final int? courierStuckDays;
}

class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.lines,
    required this.charges,
    required this.events,
    required this.edits,
    required this.customer,
  });

  final Order order;
  final List<OrderLine> lines;
  final List<OrderCharge> charges;
  final List<OrderStatusEvent> events;
  final List<OrderEdit> edits;
  final Customer? customer;
}

/// Outcome of an update; [warnings] are non-blocking notices for the UI.
class OrderUpdateOutcome {
  const OrderUpdateOutcome(this.order, {this.warnings = const []});
  final Order order;
  final List<OrderWarning> warnings;
}

enum AssignWarning { cnPatternMismatch }

class AssignOutcome {
  const AssignOutcome(this.order, this.warnings);
  final Order order;
  final List<AssignWarning> warnings;
}

enum OrderWarning {
  /// Amounts changed while the courier holds the parcel (COD may now differ
  /// from what the courier was told).
  amountsChangedAfterHandover,
}

class OrderRepository {
  OrderRepository(
    this._db,
    this._ids,
    this._clock,
    this._audit,
    this._shopId,
    this._couriers,
    this._settings,
    this._ledger,
  );

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;
  final CourierRepository _couriers;
  final SettingsRepository _settings;
  final LedgerWriter _ledger;

  static const pageSize = 30;
  static const recentlyDeletedDays = 30;

  /// Emits whenever any order-related table changes.
  Stream<void> get changes => _db
      .tableUpdates(TableUpdateQuery.onAllTables([
        _db.orders,
        _db.orderLines,
        _db.orderCharges,
        _db.orderStatusEvents,
        _db.orderEditLog,
      ]))
      .map((_) {});

  // ---------------------------------------------------------------- create

  /// Creates a confirmed order, or a draft when [draft] is true.
  Future<Result<Order>> create(OrderInput input, {bool draft = false}) async {
    if (!draft) {
      final bad = input.validateForConfirm();
      if (bad != null) return Result.err(ValidationFailure(bad));
    }
    final conflict = await cnConflict(input.courierId, input.consignmentNo, null);
    if (conflict != null) return Result.err(conflict);

    final settings = await _settings.read();
    final feeRules = input.courierId == null
        ? null
        : await _couriers.feeRules(input.courierId!);
    final now = _clock.now();
    final id = _ids.generate();
    final status = draft ? OrderStatus.draft : OrderStatus.confirmed;

    await _db.transaction(() async {
      final number = await _nextOrderNumber(settings.orderStartNumber);
      final b = input.breakdown;
      await _db.into(_db.orders).insert(OrdersCompanion.insert(
            id: id,
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            orderNumber: number,
            orderNo: '${settings.orderPrefix}${number.toString().padLeft(4, '0')}',
            orderDate: input.orderDate ?? now,
            status: status.dbValue,
            channel: Value(input.channel.dbValue),
            sourceRef: Value(_blank(input.sourceRef)),
            customerId: Value(input.customerId),
            addressSnapshot: Value(input.address.trim()),
            paymentType: Value(input.paymentType.dbValue),
            itemsTotal: Value(b.itemsTotal.poisha),
            discountTotal: Value(b.orderDiscount.poisha),
            deliveryChargeCustomer: Value(b.deliveryCharge.poisha),
            advanceReceived: Value(b.advance.poisha),
            advanceMethod: Value(_blank(input.advanceMethod)),
            codExpected: Value(b.effective.poisha),
            codOverridden: Value(b.overridden),
            codStatus: Value(_initialCodStatus(input.paymentType, b.effective).dbValue),
            courierId: Value(input.courierId),
            consignmentNo: Value(_blank(input.consignmentNo)),
            zone: Value(input.zone),
            weightG: Value(input.weightG),
            notes: Value(_blank(input.notes)),
            tagsJson: Value(jsonEncode(input.tags)),
          ));
      await _insertLines(id, input.lines, now);
      await _writeExpectedCharges(
        orderId: id,
        feeRules: feeRules,
        zone: input.zone,
        weightG: input.weightG,
        cod: b.effective,
        packaging: Money.taka(settings.defaultPackagingCostTaka),
        now: now,
      );
      await _insertEvent(id, null, status, now);
      await _ledger.refresh(id);
      await _audit.write(
        entity: 'order',
        entityId: id,
        action: draft ? 'create_draft' : 'create',
      );
    });
    if (!draft) {
      // Remember the last used channel as the next default (F1).
      await _settings.save(settings.copyWith(defaultChannel: input.channel.dbValue));
    }
    return Result.ok((await _order(id))!);
  }

  // ---------------------------------------------------------------- update

  /// Updates an order. Editing amounts of a delivered order needs
  /// [confirmed] = true (feature spec F1 AC5). A draft is promoted to
  /// Confirmed when [promoteDraft] is true and validation passes.
  Future<Result<OrderUpdateOutcome>> update(
    String id,
    OrderInput input, {
    bool confirmed = false,
    bool promoteDraft = false,
  }) async {
    final cur = await _order(id);
    if (cur == null || cur.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    final isDraft = OrderStatus.fromDb(cur.status) == OrderStatus.draft;
    final becomesConfirmed = isDraft && promoteDraft;
    if (!isDraft || becomesConfirmed) {
      final bad = input.validateForConfirm();
      if (bad != null) return Result.err(ValidationFailure(bad));
    }
    final conflict = await cnConflict(input.courierId, input.consignmentNo, id);
    if (conflict != null) return Result.err(conflict);

    final b = input.breakdown;
    final status = OrderStatus.fromDb(cur.status);
    final amountsChanged = cur.itemsTotal != b.itemsTotal.poisha ||
        cur.discountTotal != b.orderDiscount.poisha ||
        cur.deliveryChargeCustomer != b.deliveryCharge.poisha ||
        cur.codExpected != b.effective.poisha ||
        await _linesChanged(id, input.lines);
    if (status == OrderStatus.delivered && amountsChanged && !confirmed) {
      return const Result.err(ConfirmationRequiredFailure(
          'Editing amounts on a delivered order needs confirmation'));
    }

    final settings = await _settings.read();
    final feeRules = input.courierId == null
        ? null
        : await _couriers.feeRules(input.courierId!);
    final now = _clock.now();
    final warnings = <OrderWarning>[
      if (status.withCourier && amountsChanged)
        OrderWarning.amountsChangedAfterHandover,
    ];

    await _db.transaction(() async {
      final edits = <String, (String?, String?)>{
        if (cur.customerId != input.customerId)
          'customer_id': (cur.customerId, input.customerId),
        if (cur.addressSnapshot != input.address.trim())
          'address': (cur.addressSnapshot, input.address.trim()),
        if (cur.channel != input.channel.dbValue)
          'channel': (cur.channel, input.channel.dbValue),
        if (cur.paymentType != input.paymentType.dbValue)
          'payment_type': (cur.paymentType, input.paymentType.dbValue),
        if (cur.itemsTotal != b.itemsTotal.poisha)
          'items_total': ('${cur.itemsTotal}', '${b.itemsTotal.poisha}'),
        if (cur.discountTotal != b.orderDiscount.poisha)
          'discount_total': ('${cur.discountTotal}', '${b.orderDiscount.poisha}'),
        if (cur.deliveryChargeCustomer != b.deliveryCharge.poisha)
          'delivery_charge': (
            '${cur.deliveryChargeCustomer}',
            '${b.deliveryCharge.poisha}'
          ),
        if (cur.advanceReceived != b.advance.poisha)
          'advance_received': ('${cur.advanceReceived}', '${b.advance.poisha}'),
        if (cur.codExpected != b.effective.poisha)
          'cod_expected': ('${cur.codExpected}', '${b.effective.poisha}'),
        if (cur.courierId != input.courierId)
          'courier_id': (cur.courierId, input.courierId),
        if (cur.consignmentNo != _blank(input.consignmentNo))
          'consignment_no': (cur.consignmentNo, _blank(input.consignmentNo)),
        if (cur.notes != _blank(input.notes))
          'notes': (cur.notes, _blank(input.notes)),
      };
      final newStatus = becomesConfirmed ? OrderStatus.confirmed : status;
      await (_db.update(_db.orders)..where((o) => o.id.equals(id))).write(
        OrdersCompanion(
          orderDate: Value(input.orderDate ?? cur.orderDate),
          channel: Value(input.channel.dbValue),
          sourceRef: Value(_blank(input.sourceRef)),
          customerId: Value(input.customerId),
          addressSnapshot: Value(input.address.trim()),
          paymentType: Value(input.paymentType.dbValue),
          itemsTotal: Value(b.itemsTotal.poisha),
          discountTotal: Value(b.orderDiscount.poisha),
          deliveryChargeCustomer: Value(b.deliveryCharge.poisha),
          advanceReceived: Value(b.advance.poisha),
          advanceMethod: Value(_blank(input.advanceMethod)),
          codExpected: Value(b.effective.poisha),
          codOverridden: Value(b.overridden),
          courierId: Value(input.courierId),
          consignmentNo: Value(_blank(input.consignmentNo)),
          zone: Value(input.zone),
          weightG: Value(input.weightG),
          notes: Value(_blank(input.notes)),
          tagsJson: Value(jsonEncode(input.tags)),
          status: Value(newStatus.dbValue),
          // Only pre-delivery orders have a derivable COD status here; later
          // statuses are owned by the COD ledger (Sprint 4).
          codStatus: status.index <= OrderStatus.inTransit.index
              ? Value(_initialCodStatus(input.paymentType, b.effective).dbValue)
              : const Value.absent(),
          updatedAt: Value(now),
          rowVersion: Value(cur.rowVersion + 1),
        ),
      );
      await _replaceLines(id, input.lines, now);
      // Re-derive rate-card charges; manual charges are untouched.
      await (_db.delete(_db.orderCharges)
            ..where((c) =>
                c.orderId.equals(id) & c.source.isIn(['rate_card'])))
          .go();
      await _writeExpectedCharges(
        orderId: id,
        feeRules: feeRules,
        zone: input.zone,
        weightG: input.weightG,
        cod: b.effective,
        packaging: null,
        now: now,
      );
      if (becomesConfirmed) {
        await _insertEvent(id, OrderStatus.draft, OrderStatus.confirmed, now);
        // Packaging default applies from the settings snapshot at promotion.
        final hasPackaging = await (_db.select(_db.orderCharges)
              ..where((c) => c.orderId.equals(id) & c.type.equals('packaging')))
            .get();
        if (hasPackaging.isEmpty && settings.defaultPackagingCostTaka > 0) {
          await _insertCharge(id, 'packaging',
              Money.taka(settings.defaultPackagingCostTaka), 'settings', now);
        }
      }
      for (final e in edits.entries) {
        await _db.into(_db.orderEditLog).insert(OrderEditLogCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              orderId: id,
              field: e.key,
              oldValue: Value(e.value.$1),
              newValue: Value(e.value.$2),
              at: now,
            ));
      }
      if (amountsChanged && !isDraft) {
        await _db.into(_db.orderEditLog).insert(OrderEditLogCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              orderId: id,
              field: 'lines',
              oldValue: const Value(null),
              newValue: Value('${input.lines.length} item(s)'),
              at: now,
            ));
      }
      await _ledger.refresh(id);
      await _audit.write(
        entity: 'order',
        entityId: id,
        action: 'update',
        payload: {'fields': edits.keys.toList(), 'confirmed': confirmed},
      );
    });
    if (becomesConfirmed) {
      await _settings.save(settings.copyWith(defaultChannel: input.channel.dbValue));
    }
    return Result.ok(OrderUpdateOutcome((await _order(id))!, warnings: warnings));
  }

  /// Saves a draft (creating or updating) without validation.
  Future<Result<Order>> saveDraft(String? id, OrderInput input) async {
    if (id == null) return create(input, draft: true);
    final r = await update(id, input);
    return r.when(
      ok: (o) => Result.ok(o.order),
      err: Result.err,
    );
  }

  // ------------------------------------------------------------- duplicate

  /// Copies lines, address and channel into a new confirmed order; status and
  /// COD are reset, date is now, CN is not copied.
  Future<Result<Order>> duplicate(String id) async {
    final d = await detail(id);
    if (d == null) return const Result.err(NotFoundFailure('Order not found'));
    final o = d.order;
    final input = OrderInput(
      customerId: o.customerId,
      address: o.addressSnapshot,
      channel: Channel.fromDb(o.channel),
      sourceRef: o.sourceRef,
      paymentType: PaymentType.fromDb(o.paymentType),
      advance: Money(o.advanceReceived),
      advanceMethod: o.advanceMethod,
      deliveryCharge: Money(o.deliveryChargeCustomer),
      orderDiscount: Discount.amount(Money(o.discountTotal)),
      courierId: o.courierId,
      zone: o.zone,
      weightG: o.weightG,
      notes: o.notes,
      lines: [
        for (final l in d.lines)
          LineInput(
            name: l.nameSnapshot,
            qty: l.qty,
            unitSell: Money(l.unitSellPrice),
            unitCost: l.unitCostPrice == null ? null : Money(l.unitCostPrice!),
            discount: Discount.amount(Money(l.lineDiscount)),
            productId: l.productId,
            variantId: l.variantId,
          ),
      ],
    );
    return create(input, draft: OrderStatus.fromDb(o.status) == OrderStatus.draft);
  }

  // ----------------------------------------------------- delete / restore

  Future<void> softDelete(String id) async {
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.orders)..where((o) => o.id.equals(id))).write(
          OrdersCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await _audit.write(entity: 'order', entityId: id, action: 'delete');
    });
  }

  /// Restore fails with a conflict if its CN was reused in the meantime.
  Future<Result<void>> restore(String id) async {
    final o = await _order(id);
    if (o == null) return const Result.err(NotFoundFailure('Order not found'));
    final conflict = await cnConflict(o.courierId, o.consignmentNo, id);
    if (conflict != null) return Result.err(conflict);
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.orders)..where((x) => x.id.equals(id))).write(
          OrdersCompanion(deletedAt: const Value(null), updatedAt: Value(now)));
      await _audit.write(entity: 'order', entityId: id, action: 'restore');
    });
    return const Result.ok(null);
  }

  Stream<List<OrderListItem>> watchRecentlyDeleted() {
    final cutoff =
        _clock.now().subtract(const Duration(days: recentlyDeletedDays));
    final q = _db.select(_db.orders).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.orders.customerId)),
    ])
      ..where(_db.orders.shopId.equals(_shopId) &
          _db.orders.deletedAt.isNotNull() &
          _db.orders.deletedAt.isBiggerOrEqualValue(cutoff))
      ..orderBy([OrderingTerm.desc(_db.orders.deletedAt)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            OrderListItem(r.readTable(_db.orders), r.readTableOrNull(_db.customers)?.name),
        ]);
  }

  /// Permanently removes soft-deleted orders older than 30 days. Called on
  /// app start in the later purge job (stub-level in v1: callable on demand).
  Future<int> purgeExpired() async {
    final cutoff =
        _clock.now().subtract(const Duration(days: recentlyDeletedDays));
    final expired = await (_db.select(_db.orders)
          ..where((o) => o.deletedAt.isNotNull() & o.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    if (expired.isEmpty) return 0;
    final ids = expired.map((o) => o.id).toList();
    await _db.transaction(() async {
      await (_db.delete(_db.orderLines)..where((t) => t.orderId.isIn(ids))).go();
      await (_db.delete(_db.orderCharges)..where((t) => t.orderId.isIn(ids))).go();
      await (_db.delete(_db.orderStatusEvents)..where((t) => t.orderId.isIn(ids))).go();
      await (_db.delete(_db.orderEditLog)..where((t) => t.orderId.isIn(ids))).go();
      await (_db.delete(_db.orderAttachments)..where((t) => t.orderId.isIn(ids))).go();
      await (_db.delete(_db.orders)..where((o) => o.id.isIn(ids))).go();
    });
    return ids.length;
  }

  // ------------------------------------------------------- assign courier

  /// Sets courier / CN / zone / weight and re-derives expected rate-card
  /// charges. Returns soft warnings (e.g. CN pattern mismatch).
  Future<Result<AssignOutcome>> assignCourier(
    String orderId, {
    required String courierId,
    String? consignmentNo,
    String? zone,
    int? weightG,
  }) async {
    final cur = await _order(orderId);
    if (cur == null || cur.deletedAt != null) {
      return const Result.err(NotFoundFailure('Order not found'));
    }
    final courier = await _couriers.getById(courierId);
    if (courier == null) return const Result.err(NotFoundFailure('Courier not found'));
    final cn = _blank(consignmentNo);
    final conflict = await cnConflict(courierId, cn, orderId);
    if (conflict != null) return Result.err(conflict);

    final warnings = <AssignWarning>[];
    final pattern = courier.cnRegex;
    if (cn != null && pattern != null && pattern.isNotEmpty) {
      try {
        if (!RegExp(pattern).hasMatch(cn)) warnings.add(AssignWarning.cnPatternMismatch);
      } on FormatException {
        // Invalid saved pattern: ignore, validation is soft.
      }
    }
    final feeRules = await _couriers.feeRules(courierId);
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.orders)..where((o) => o.id.equals(orderId))).write(
        OrdersCompanion(
          courierId: Value(courierId),
          consignmentNo: Value(cn),
          zone: Value(zone ?? cur.zone),
          weightG: Value(weightG ?? cur.weightG),
          updatedAt: Value(now),
          rowVersion: Value(cur.rowVersion + 1),
        ),
      );
      await (_db.delete(_db.orderCharges)
            ..where((c) => c.orderId.equals(orderId) & c.source.equals('rate_card')))
          .go();
      await _writeExpectedCharges(
        orderId: orderId,
        feeRules: feeRules,
        zone: zone ?? cur.zone,
        weightG: weightG ?? cur.weightG,
        cod: Money(cur.codExpected),
        packaging: null,
        now: now,
      );
      Future<void> edit(String f, String? a, String? b) async {
        if (a == b) return;
        await _db.into(_db.orderEditLog).insert(OrderEditLogCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              orderId: orderId,
              field: f,
              oldValue: Value(a),
              newValue: Value(b),
              at: now,
            ));
      }
      await edit('courier_id', cur.courierId, courierId);
      await edit('consignment_no', cur.consignmentNo, cn);
      await _ledger.refresh(orderId);
      await _audit.write(
          entity: 'order', entityId: orderId, action: 'assign_courier');
    });
    return Result.ok(AssignOutcome((await _order(orderId))!, warnings));
  }

  // ----------------------------------------------------------------- reads

  Future<Order?> _order(String id) =>
      (_db.select(_db.orders)..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<Order?> getById(String id) => _order(id);

  Future<OrderDetail?> detail(String id) async {
    final o = await _order(id);
    if (o == null) return null;
    final lines = await (_db.select(_db.orderLines)
          ..where((l) => l.orderId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.createdAt), (l) => OrderingTerm.asc(l.id)]))
        .get();
    final charges = await (_db.select(_db.orderCharges)
          ..where((c) => c.orderId.equals(id))
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();
    final events = await (_db.select(_db.orderStatusEvents)
          ..where((e) => e.orderId.equals(id))
          ..orderBy([(e) => OrderingTerm.asc(e.at), (e) => OrderingTerm.asc(e.id)]))
        .get();
    final edits = await (_db.select(_db.orderEditLog)
          ..where((e) => e.orderId.equals(id))
          ..orderBy([(e) => OrderingTerm.asc(e.at), (e) => OrderingTerm.asc(e.id)]))
        .get();
    final customer = o.customerId == null
        ? null
        : await (_db.select(_db.customers)..where((c) => c.id.equals(o.customerId!)))
            .getSingleOrNull();
    return OrderDetail(
        order: o,
        lines: lines,
        charges: charges,
        events: events,
        edits: edits,
        customer: customer);
  }

  /// Resolves free text to order ids via the trigram index. Tokens shorter
  /// than 3 characters fall back to LIKE (trigram needs 3+).
  Future<Set<String>> searchIds(String query) async {
    final q = query.trim();
    if (q.isEmpty) return {};
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.every((t) => t.runes.length >= 3)) {
      final match = tokens.map((t) => '"${t.replaceAll('"', '""')}"').join(' ');
      final rows = await _db
          .customSelect(
            'SELECT order_id FROM search_index WHERE search_index MATCH ? LIMIT 5000',
            variables: [Variable<String>(match)],
          )
          .get();
      return {for (final r in rows) r.read<String>('order_id')};
    }
    // Every token must appear in some column.
    final clauses = <String>[];
    final vars = <Variable<String>>[];
    for (final t in tokens) {
      final like = '%${t.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      clauses.add(
        "(order_no LIKE ? ESCAPE '\\' OR customer_name LIKE ? ESCAPE '\\' OR phone LIKE ? ESCAPE '\\' "
        "OR cn LIKE ? ESCAPE '\\' OR product_names LIKE ? ESCAPE '\\' OR notes LIKE ? ESCAPE '\\')",
      );
      vars.addAll(List.filled(6, Variable<String>(like)));
    }
    final rows = await _db
        .customSelect(
          'SELECT order_id FROM search_index WHERE ${clauses.join(' AND ')} LIMIT 5000',
          variables: vars,
        )
        .get();
    return {for (final r in rows) r.read<String>('order_id')};
  }

  /// A pasted/scanned CN or order number jumps straight to its order.
  Future<String?> exactOrderId(String text) async {
    final q = text.trim();
    if (q.isEmpty) return null;
    final rows = await (_db.select(_db.orders)
          ..where((o) =>
              o.shopId.equals(_shopId) &
              o.deletedAt.isNull() &
              (o.consignmentNo.equals(q) | o.orderNo.lower().equals(q.toLowerCase())))
          ..limit(2))
        .get();
    return rows.length == 1 ? rows.single.id : null;
  }

  /// Boolean SQL for [f] (mirrors `OrderFilterMatcher`).
  Future<Expression<bool>> whereFor(OrderFilter f, {DateTime? now}) async {
    final o = _db.orders;
    final at = now ?? _clock.now();
    Expression<bool> w = o.shopId.equals(_shopId) & o.deletedAt.isNull();
    if (f.onlyDrafts) {
      w = w & o.status.equals(OrderStatus.draft.dbValue);
    } else if (!f.includeDrafts) {
      w = w & o.status.equals(OrderStatus.draft.dbValue).not();
    }
    if (f.statuses.isNotEmpty) w = w & o.status.isIn(f.statuses.map((s) => s.dbValue));
    if (f.codStatuses.isNotEmpty) {
      w = w & o.codStatus.isIn(f.codStatuses.map((s) => s.dbValue));
    }
    if (f.profitStates.isNotEmpty) {
      w = w & o.profitState.isIn(f.profitStates.map((s) => s.dbValue));
    }
    if (f.courierId != null) w = w & o.courierId.equals(f.courierId!);
    if (f.channel != null) w = w & o.channel.equals(f.channel!.dbValue);
    if (f.paymentType != null) w = w & o.paymentType.equals(f.paymentType!.dbValue);
    if (f.customerId != null) w = w & o.customerId.equals(f.customerId!);
    if (f.tag != null) w = w & o.tagsJson.like('%"${f.tag}"%');
    if (f.area != null) w = w & o.addressSnapshot.like('%${f.area}%');
    if (f.from != null) w = w & o.orderDate.isBiggerOrEqualValue(f.from!);
    if (f.to != null) w = w & o.orderDate.isSmallerThanValue(f.to!);
    if (f.dispatchFrom != null) w = w & o.handedOverAt.isBiggerOrEqualValue(f.dispatchFrom!);
    if (f.dispatchTo != null) w = w & o.handedOverAt.isSmallerThanValue(f.dispatchTo!);
    if (f.deliveredFrom != null) w = w & o.deliveredAt.isBiggerOrEqualValue(f.deliveredFrom!);
    if (f.deliveredTo != null) w = w & o.deliveredAt.isSmallerThanValue(f.deliveredTo!);
    if (f.deliveredOlderThanDays != null) {
      final cutoff = at.subtract(Duration(days: f.deliveredOlderThanDays!));
      w = w & o.deliveredAt.isSmallerOrEqualValue(cutoff);
    }
    switch (f.profitSign) {
      case ProfitSign.profit:
        w = w & o.profit.isBiggerOrEqualValue(0);
      case ProfitSign.loss:
        w = w & o.profit.isSmallerThanValue(0);
      case null:
        break;
    }
    final total = o.itemsTotal - o.discountTotal + o.deliveryChargeCustomer;
    if (f.amountMinPoisha != null) w = w & total.isBiggerOrEqualValue(f.amountMinPoisha!);
    if (f.amountMaxPoisha != null) w = w & total.isSmallerOrEqualValue(f.amountMaxPoisha!);
    if (f.hasReturn != null) {
      final withReturn = o.id.isInQuery(
        _db.selectOnly(_db.returnRecords)
          ..addColumns([_db.returnRecords.orderId])
          ..where(_db.returnRecords.deletedAt.isNull()),
      );
      w = w & (f.hasReturn! ? withReturn : withReturn.not());
    }
    if (f.query.trim().isNotEmpty) {
      final ids = await searchIds(f.query);
      w = w & o.id.isIn(ids);
    }
    return w;
  }

  /// One page of orders. Newest/oldest use keyset paging via [after]; other
  /// sorts page by [offset].
  Future<List<OrderListItem>> fetchPage({
    OrderFilter filter = const OrderFilter(),
    OrderCursor? after,
    int limit = pageSize,
    OrderSort sort = OrderSort.newest,
    int offset = 0,
  }) async {
    final o = _db.orders;
    final q = _db.select(o).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(o.customerId)),
      leftOuterJoin(_db.couriers, _db.couriers.id.equalsExp(o.courierId)),
    ]);
    var w = await whereFor(filter);
    final keyset = sort == OrderSort.newest || sort == OrderSort.oldest;
    if (after != null && keyset) {
      w = w &
          (sort == OrderSort.newest
              ? (o.orderDate.isSmallerThanValue(after.orderDate) |
                  (o.orderDate.equals(after.orderDate) & o.id.isSmallerThanValue(after.id)))
              : (o.orderDate.isBiggerThanValue(after.orderDate) |
                  (o.orderDate.equals(after.orderDate) & o.id.isBiggerThanValue(after.id))));
    }
    final order = switch (sort) {
      OrderSort.newest => [OrderingTerm.desc(o.orderDate), OrderingTerm.desc(o.id)],
      OrderSort.oldest => [OrderingTerm.asc(o.orderDate), OrderingTerm.asc(o.id)],
      OrderSort.amountHigh => [
          OrderingTerm.desc(o.itemsTotal - o.discountTotal + o.deliveryChargeCustomer),
          OrderingTerm.desc(o.id),
        ],
      OrderSort.profitHigh => [OrderingTerm.desc(o.profit), OrderingTerm.desc(o.id)],
      OrderSort.profitLow => [OrderingTerm.asc(o.profit), OrderingTerm.asc(o.id)],
      // Oldest handover first: the parcels that have waited longest.
      OrderSort.daysSinceDispatch => [OrderingTerm.asc(o.handedOverAt), OrderingTerm.asc(o.id)],
    };
    q
      ..where(w)
      ..orderBy(order)
      ..limit(limit, offset: keyset ? null : offset);
    final rows = await q.get();
    return [
      for (final r in rows)
        OrderListItem(
          r.readTable(o),
          r.readTableOrNull(_db.customers)?.name,
          courierStuckDays: r.readTableOrNull(_db.couriers)?.stuckDays,
        ),
    ];
  }

  /// Aggregates for exactly the rows [filter] selects. Dashboard tiles and
  /// their drill-down headers both use this, so they can never disagree.
  Future<FilterTotals> totals(OrderFilter filter) async {
    final o = _db.orders;
    final where = await whereFor(filter);
    final delivered = o.status.equals(OrderStatus.delivered.dbValue);
    final failedLike = o.status.isIn([
      OrderStatus.deliveryFailed.dbValue,
      OrderStatus.returnInTransit.dbValue,
      OrderStatus.returned.dbValue,
    ]);
    final dispatched = o.status.isIn([
      OrderStatus.handedToCourier.dbValue,
      OrderStatus.inTransit.dbValue,
      OrderStatus.delivered.dbValue,
      OrderStatus.deliveryFailed.dbValue,
      OrderStatus.returnInTransit.dbValue,
      OrderStatus.returned.dbValue,
    ]);
    final count = o.id.count();
    final cod = o.codExpected.sum();
    final outstanding = o.outstanding.sum();
    final profitAll = o.profit.sum();
    final profitFinal = o.profit.sum(filter: o.profitState.equals('final'));
    final profitProv = o.profit.sum(filter: o.profitState.equals('provisional'));
    final incomplete = o.id.count(filter: o.profitState.equals('incomplete'));
    final grossDelivered = o.grossCollected.sum(filter: delivered);
    final grossCounted = o.grossCollected.sum(filter: o.profitState.equals('incomplete').not());
    final profitCounted = o.profit.sum(filter: o.profitState.equals('incomplete').not());
    final deliveredCount = o.id.count(filter: delivered);
    final failedCount = o.id.count(filter: failedLike);
    final dispatchedCount = o.id.count(filter: dispatched);
    final countedOrders = o.id.count(filter: o.profitState.equals('incomplete').not());
    final row = await (_db.selectOnly(o)
          ..addColumns([
            count,
            cod,
            outstanding,
            profitAll,
            profitFinal,
            profitProv,
            incomplete,
            grossDelivered,
            grossCounted,
            profitCounted,
            deliveredCount,
            failedCount,
            dispatchedCount,
            countedOrders,
          ])
          ..where(where))
        .getSingle();
    int i(Expression<num> e) => (row.read(e) ?? 0).toInt();
    return FilterTotals(
      count: i(count),
      codExpected: i(cod),
      outstanding: i(outstanding),
      profit: i(profitAll),
      profitFinal: i(profitFinal),
      profitProvisional: i(profitProv),
      incompleteCount: i(incomplete),
      revenue: i(grossDelivered),
      grossCounted: i(grossCounted),
      profitCounted: i(profitCounted),
      delivered: i(deliveredCount),
      failedOrReturned: i(failedCount),
      dispatched: i(dispatchedCount),
      countedOrders: i(countedOrders),
    );
  }

  /// List rows for specific ids (newest first), e.g. the stuck-parcel view.
  Future<List<OrderListItem>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final o = _db.orders;
    final q = _db.select(o).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(o.customerId)),
      leftOuterJoin(_db.couriers, _db.couriers.id.equalsExp(o.courierId)),
    ])
      ..where(o.id.isIn(ids))
      ..orderBy([OrderingTerm.desc(o.orderDate), OrderingTerm.desc(o.id)]);
    return [
      for (final r in await q.get())
        OrderListItem(
          r.readTable(o),
          r.readTableOrNull(_db.customers)?.name,
          courierStuckDays: r.readTableOrNull(_db.couriers)?.stuckDays,
        ),
    ];
  }

  Future<int> draftCount() async {
    final c = _db.orders.id.count();
    final row = await (_db.selectOnly(_db.orders)
          ..addColumns([c])
          ..where(_db.orders.shopId.equals(_shopId) &
              _db.orders.deletedAt.isNull() &
              _db.orders.status.equals(OrderStatus.draft.dbValue)))
        .getSingle();
    return row.read(c) ?? 0;
  }

  /// Expected charges for a form preview (not persisted).
  Future<ExpectedCharges?> previewCharges({
    required String? courierId,
    required String? zone,
    required int? weightG,
    required Money cod,
  }) async {
    if (courierId == null || zone == null) return null;
    final rules = await _couriers.feeRules(courierId);
    return ChargeCalculator.expected(
        rules: rules, zone: zone, codAmount: cod, weightG: weightG);
  }

  // --------------------------------------------------------------- helpers

  /// Next sequence number; never reused because deleted orders keep theirs.
  Future<int> _nextOrderNumber(int start) async {
    final maxCol = _db.orders.orderNumber.max();
    final row = await (_db.selectOnly(_db.orders)
          ..addColumns([maxCol])
          ..where(_db.orders.shopId.equals(_shopId)))
        .getSingle();
    final max = row.read(maxCol);
    return max == null ? start : (max + 1 < start ? start : max + 1);
  }

  Future<ConflictFailure?> cnConflict(
      String? courierId, String? cn, String? exceptOrderId) async {
    final c = _blank(cn);
    if (courierId == null || c == null) return null;
    final existing = await (_db.select(_db.orders)
          ..where((o) =>
              o.courierId.equals(courierId) &
              o.consignmentNo.equals(c) &
              o.deletedAt.isNull()))
        .get();
    final other = existing.where((o) => o.id != exceptOrderId).toList();
    if (other.isEmpty) return null;
    return ConflictFailure('cn_taken:${other.first.orderNo}',
        conflictingId: other.first.id);
  }

  CodStatus _initialCodStatus(PaymentType type, Money cod) =>
      (type == PaymentType.prepaid || cod.isZero)
          ? CodStatus.notApplicable
          : CodStatus.pendingCollection;

  Future<bool> _linesChanged(String orderId, List<LineInput> lines) async {
    final cur = await (_db.select(_db.orderLines)..where((l) => l.orderId.equals(orderId))).get();
    if (cur.length != lines.length) return true;
    final a = cur
        .map((l) => '${l.nameSnapshot}|${l.qty}|${l.unitSellPrice}|${l.lineDiscount}|${l.unitCostPrice}')
        .toList()
      ..sort();
    final b = lines
        .map((l) => '${l.name}|${l.qty}|${l.unitSell.poisha}|${l.discountAmount.poisha}|${l.unitCost?.poisha}')
        .toList()
      ..sort();
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  Future<void> _insertLines(String orderId, List<LineInput> lines, DateTime now) async {
    for (final l in lines) {
      await _db.into(_db.orderLines).insert(OrderLinesCompanion.insert(
            id: _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            orderId: orderId,
            nameSnapshot: l.name.trim(),
            unitSellPrice: l.unitSell.poisha,
            qty: Value(l.qty),
            unitCostPrice: Value(l.unitCost?.poisha),
            lineDiscount: Value(l.discountAmount.poisha),
            productId: Value(l.productId),
            variantId: Value(l.variantId),
          ));
    }
  }

  Future<void> _replaceLines(String orderId, List<LineInput> lines, DateTime now) async {
    await (_db.delete(_db.orderLines)..where((l) => l.orderId.equals(orderId))).go();
    await _insertLines(orderId, lines, now);
  }

  Future<void> _insertCharge(
      String orderId, String type, Money expected, String source, DateTime now) {
    return _db.into(_db.orderCharges).insert(OrderChargesCompanion.insert(
          id: _ids.generate(),
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          orderId: orderId,
          type: type,
          expectedAmount: Value(expected.poisha),
          source: Value(source),
        ));
  }

  Future<void> _writeExpectedCharges({
    required String orderId,
    required CourierFeeRules? feeRules,
    required String? zone,
    required int? weightG,
    required Money cod,
    required Money? packaging,
    required DateTime now,
  }) async {
    if (feeRules != null && zone != null) {
      final e = ChargeCalculator.expected(
          rules: feeRules, zone: zone, codAmount: cod, weightG: weightG);
      if (e.deliveryFee != null) {
        await _insertCharge(orderId, 'delivery_fee', e.deliveryFee!, 'rate_card', now);
      }
      await _insertCharge(orderId, 'cod_fee', e.codFee, 'rate_card', now);
      if (e.returnFee != null && !e.returnFee!.isZero) {
        await _insertCharge(orderId, 'return_fee', e.returnFee!, 'rate_card', now);
      }
    }
    if (packaging != null && !packaging.isZero) {
      await _insertCharge(orderId, 'packaging', packaging, 'settings', now);
    }
  }

  Future<void> _insertEvent(
      String orderId, OrderStatus? from, OrderStatus to, DateTime at) {
    return _db.into(_db.orderStatusEvents).insert(OrderStatusEventsCompanion.insert(
          id: _ids.generate(),
          shopId: _shopId,
          createdAt: at,
          updatedAt: at,
          orderId: orderId,
          toStatus: to.dbValue,
          at: at,
          fromStatus: Value(from?.dbValue),
        ));
  }

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
      ref.watch(courierRepositoryProvider),
      ref.watch(settingsRepositoryProvider),
      LedgerWriter(ref.watch(databaseProvider)),
    ));
