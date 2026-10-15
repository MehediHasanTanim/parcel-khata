import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';

class ImportReport {
  const ImportReport({
    required this.imported,
    required this.skippedExisting,
    required this.issues,
    required this.applied,
    this.batchId,
  });

  final int imported;
  final int skippedExisting;
  final List<ImportRowIssue> issues;

  /// False when all-or-nothing blocked the import because of bad rows.
  final bool applied;

  /// Import batch to undo from the history list (null when nothing applied).
  final String? batchId;
}

class UndoReport {
  const UndoReport({required this.removed, required this.kept});

  /// Rows soft-deleted.
  final int removed;

  /// Rows left alone because they were used afterwards (payout applied,
  /// customer has other orders).
  final int kept;
}

/// Placeholder holder of opening-balance parcels (hidden from lists).
const kOpeningBalanceName = 'Opening balance';
const kOpeningBalancePhone = '01300000000';

/// Applies validated import plans through the normal repositories, so every
/// rule (phone dedupe, order numbering, CN uniqueness) still holds.
class CsvImportService {
  CsvImportService(
    this._db,
    this._customers,
    this._orders,
    this._status,
    this._couriers,
    this._products,
    this._ids,
    this._clock,
    this._shopId,
  );

  final AppDatabase _db;
  final CustomerRepository _customers;
  final OrderRepository _orders;
  final OrderStatusService _status;
  final CourierRepository _couriers;
  final ProductRepository _products;
  final UuidV7 _ids;
  final Clock _clock;
  final String _shopId;

  // ------------------------------------------------------------- batches

  Future<String> _openBatch(String kind, String fileName) async {
    final now = _clock.now();
    final id = _ids.generate();
    await _db.into(_db.importBatches).insert(ImportBatchesCompanion.insert(
          id: id,
          shopId: _shopId,
          createdAt: now,
          updatedAt: now,
          kind: kind,
          fileName: Value(fileName),
        ));
    return id;
  }

  /// Records the count, or drops the batch when it created nothing.
  Future<String?> _closeBatch(String id, int count) async {
    if (count == 0) {
      await (_db.delete(_db.importBatches)..where((b) => b.id.equals(id))).go();
      return null;
    }
    await (_db.update(_db.importBatches)..where((b) => b.id.equals(id)))
        .write(ImportBatchesCompanion(createdCount: Value(count)));
    return id;
  }

  Future<void> _stamp(TableInfo<Table, dynamic> table, String rowId, String batchId) =>
      _db.customUpdate(
        'UPDATE ${table.actualTableName} SET import_batch_id = ? WHERE id = ?',
        variables: [Variable.withString(batchId), Variable.withString(rowId)],
        updates: {table},
      );

  Stream<List<ImportBatch>> watchBatches() => (_db.select(_db.importBatches)
        ..where((b) => b.deletedAt.isNull())
        ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
      .watch();

  /// Soft-deletes everything the batch created. Orders that already have a
  /// payout applied and customers that gained other orders are kept.
  Future<UndoReport> undo(String batchId) async {
    final batch = await (_db.select(_db.importBatches)..where((b) => b.id.equals(batchId)))
        .getSingleOrNull();
    if (batch == null || batch.status != 'applied') {
      return const UndoReport(removed: 0, kept: 0);
    }
    var removed = 0;
    var kept = 0;
    final now = _clock.now();
    await _db.transaction(() async {
      final orders = await (_db.select(_db.orders)
            ..where((o) => o.importBatchId.equals(batchId) & o.deletedAt.isNull()))
          .get();
      for (final o in orders) {
        final applied = await (_db.select(_db.payoutAllocations)
              ..where((a) => a.orderId.equals(o.id) & a.deletedAt.isNull()))
            .get();
        if (applied.isNotEmpty) {
          kept++;
          continue;
        }
        await _orders.softDelete(o.id);
        removed++;
      }
      final customers = await (_db.select(_db.customers)
            ..where((c) => c.importBatchId.equals(batchId) & c.deletedAt.isNull()))
          .get();
      for (final c in customers) {
        final live = await (_db.select(_db.orders)
              ..where((o) => o.customerId.equals(c.id) & o.deletedAt.isNull()))
            .get();
        if (live.isNotEmpty) {
          kept++;
          continue;
        }
        await (_db.update(_db.customers)..where((x) => x.id.equals(c.id))).write(
            CustomersCompanion(
                deletedAt: Value(now), isArchived: const Value(true), updatedAt: Value(now)));
        removed++;
      }
      final products = await (_db.select(_db.products)
            ..where((p) => p.importBatchId.equals(batchId) & p.deletedAt.isNull()))
          .get();
      for (final p in products) {
        await (_db.update(_db.products)..where((x) => x.id.equals(p.id)))
            .write(ProductsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
        removed++;
      }
      await (_db.update(_db.importBatches)..where((b) => b.id.equals(batchId))).write(
          ImportBatchesCompanion(status: const Value('undone'), undoneAt: Value(now)));
    });
    return UndoReport(removed: removed, kept: kept);
  }

  // ----------------------------------------------------- saved mappings

  Future<Map<String, int>?> loadMapping(String signature, String kind) async {
    final row = await (_db.select(_db.columnMappings)
          ..where((m) => m.signature.equals(signature) & m.kind.equals(kind)))
        .getSingleOrNull();
    if (row == null) return null;
    final j = jsonDecode(row.mappingJson) as Map<String, dynamic>;
    return {for (final e in j.entries) e.key: e.value as int};
  }

  Future<void> saveMapping(String signature, String kind, Map<String, int> map) async {
    final now = _clock.now();
    final json = jsonEncode(map);
    final existing = await (_db.select(_db.columnMappings)
          ..where((m) => m.signature.equals(signature) & m.kind.equals(kind)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.columnMappings).insert(ColumnMappingsCompanion.insert(
            id: _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            signature: signature,
            kind: kind,
            mappingJson: json,
          ));
    } else {
      await (_db.update(_db.columnMappings)..where((m) => m.id.equals(existing.id)))
          .write(ColumnMappingsCompanion(mappingJson: Value(json), updatedAt: Value(now)));
    }
  }

  // -------------------------------------------------- products / balances

  Future<ImportReport> importProducts(
    ProductImportPlan plan, {
    required bool skipBadRows,
    String fileName = '',
  }) async {
    if (plan.issues.isNotEmpty && !skipBadRows) {
      return ImportReport(imported: 0, skippedExisting: 0, issues: plan.issues, applied: false);
    }
    var imported = 0;
    var existing = 0;
    late final String batch;
    await _db.transaction(() async {
      batch = await _openBatch('products', fileName);
      final live = await (_db.select(_db.products)..where((p) => p.deletedAt.isNull())).get();
      final skus = {for (final p in live) if (p.sku != null) p.sku!.toLowerCase()};
      final names = {for (final p in live) p.name.toLowerCase()};
      for (final r in plan.rows) {
        final dup = r.sku != null
            ? skus.contains(r.sku!.toLowerCase())
            : names.contains(r.name.toLowerCase());
        if (dup) {
          existing++;
          continue;
        }
        final res = await _products.create(ProductInput(
          name: r.name,
          sellPrice: r.sellPrice,
          costPrice: r.costPrice,
          sku: r.sku,
          stockQty: r.stock,
          isActive: r.active,
        ));
        final p = res.valueOrNull;
        if (p == null) continue;
        await _stamp(_db.products, p.id, batch);
        imported++;
      }
    });
    return ImportReport(
      imported: imported,
      skippedExisting: existing + plan.duplicatesInFile.length,
      issues: plan.issues,
      applied: true,
      batchId: await _closeBatch(batch, imported),
    );
  }

  /// Loads existing COD owed as delivered, unpaid parcels so payouts reconcile
  /// against them. Profit-neutral (cost = price) and dated in the past.
  Future<ImportReport> importOpeningBalances(
    OpeningBalancePlan plan, {
    required bool skipBadRows,
    String fileName = '',
  }) async {
    if (plan.issues.isNotEmpty && !skipBadRows) {
      return ImportReport(imported: 0, skippedExisting: 0, issues: plan.issues, applied: false);
    }
    final issues = [...plan.issues];
    var imported = 0;
    late final String batch;
    await _db.transaction(() async {
      batch = await _openBatch('opening_balance', fileName);
      final couriers = {
        for (final c in await _couriers.watchAll().first) c.name.toLowerCase(): c.id,
      };
      var holder = await _customers.findByPhone(kOpeningBalancePhone);
      if (holder == null) {
        holder = (await _customers.create(const CustomerInput(
          name: kOpeningBalanceName,
          phone: kOpeningBalancePhone,
        )))
            .valueOrNull;
        if (holder != null) {
          await _customers.archive(holder.id);
          await _stamp(_db.customers, holder.id, batch);
        }
      }
      if (holder == null) {
        issues.add(const ImportRowIssue(0, 'holder_failed'));
        return;
      }
      var seq = 0;
      for (final r in plan.rows) {
        final courierId = couriers[r.courier.toLowerCase()];
        if (courierId == null) {
          issues.add(ImportRowIssue(r.row, 'unknown_courier'));
          continue;
        }
        seq++;
        final day = r.deliveredAt ?? _clock.now().subtract(const Duration(days: 1));
        final cn = r.consignmentNo ?? 'OB-${batch.substring(batch.length - 6)}-$seq';
        final created = await _orders.create(OrderInput(
          customerId: holder.id,
          address: kOpeningBalanceName,
          orderDate: day,
          sourceRef: r.reference ?? 'opening-balance',
          courierId: courierId,
          consignmentNo: cn,
          tags: const ['opening-balance'],
          notes: r.reference,
          lines: [
            LineInput(
              name: kOpeningBalanceName,
              qty: 1,
              unitSell: r.amount,
              unitCost: r.amount,
            ),
          ],
        ));
        final order = created.valueOrNull;
        if (order == null) {
          issues.add(ImportRowIssue(r.row, created.failureOrNull?.message ?? 'create_failed'));
          continue;
        }
        final moved = await _status.correctStatus(
          order.id,
          to: OrderStatus.delivered,
          note: 'opening balance',
          at: day.isAfter(_clock.now()) ? null : day,
        );
        if (!moved.isOk) {
          issues.add(ImportRowIssue(r.row, 'status_ignored'));
        }
        await _stamp(_db.orders, order.id, batch);
        imported++;
      }
    });
    return ImportReport(
      imported: imported,
      skippedExisting: 0,
      issues: issues,
      applied: true,
      batchId: await _closeBatch(batch, imported),
    );
  }

  Future<ImportReport> importCustomers(
    CustomerImportPlan plan, {
    required bool skipBadRows,
    String fileName = '',
  }) async {
    if (plan.issues.isNotEmpty && !skipBadRows) {
      return ImportReport(imported: 0, skippedExisting: 0, issues: plan.issues, applied: false);
    }
    var imported = 0;
    var existing = 0;
    late final String batch;
    await _db.transaction(() async {
      batch = await _openBatch('customers', fileName);
      for (final r in plan.rows) {
        if (await _customers.findByPhone(r.phoneNormalized) != null) {
          existing++;
          continue;
        }
        final res = await _customers.create(CustomerInput(
          name: r.name,
          phone: r.phoneNormalized,
          phoneAlt: r.phoneAlt,
          whatsapp: r.whatsapp,
          notes: r.notes,
          addresses: [
            if (r.address != null)
              AddressInput(
                fullText: r.address!,
                district: r.district,
                area: r.area,
                isDefault: true,
              ),
          ],
        ));
        if (res.isOk) {
          await _stamp(_db.customers, res.valueOrNull!.id, batch);
          imported++;
        }
      }
    });
    return ImportReport(
      imported: imported,
      skippedExisting: existing + plan.duplicatesInFile.length,
      issues: plan.issues,
      applied: true,
      batchId: await _closeBatch(batch, imported),
    );
  }

  Future<ImportReport> importOrders(
    OrderImportPlan plan, {
    required bool skipBadRows,
    String fileName = '',
  }) async {
    if (plan.issues.isNotEmpty && !skipBadRows) {
      return ImportReport(imported: 0, skippedExisting: 0, issues: plan.issues, applied: false);
    }
    final issues = [...plan.issues];
    var imported = 0;
    var existing = 0;
    final courierByName = {
      for (final c in await _couriers.watchAll().first) c.name.toLowerCase(): c.id,
    };
    late final String batch;
    await _db.transaction(() async {
      batch = await _openBatch('orders', fileName);
      for (final r in plan.rows) {
        var customer = await _customers.findByPhone(r.customerPhone);
        if (customer == null) {
          customer = (await _customers.create(CustomerInput(
            name: r.customerName ?? r.customerPhone,
            phone: r.customerPhone,
          )))
              .valueOrNull;
          if (customer != null) await _stamp(_db.customers, customer.id, batch);
        }
        if (customer == null) {
          issues.add(ImportRowIssue(r.row, 'customer_failed'));
          continue;
        }
        // Same seller reference for the same customer = already imported.
        final dup = await (_db.select(_db.orders)
              ..where((o) =>
                  o.sourceRef.equals(r.orderRef) &
                  o.customerId.equals(customer!.id) &
                  o.deletedAt.isNull()))
            .getSingleOrNull();
        if (dup != null) {
          existing++;
          continue;
        }
        final payment = PaymentType.values.firstWhere(
          (p) => p.dbValue == r.paymentType,
          orElse: () =>
              r.advance.poisha > 0 ? PaymentType.partialAdvance : PaymentType.cod,
        );
        final courierId = r.courier == null ? null : courierByName[r.courier!.toLowerCase()];
        final result = await _orders.create(OrderInput(
          customerId: customer.id,
          address: r.address.isEmpty ? '—' : r.address,
          orderDate: r.orderDate,
          channel: Channel.values.firstWhere(
            (c) => c.dbValue == r.channel,
            orElse: () => Channel.other,
          ),
          sourceRef: r.orderRef,
          paymentType: payment,
          advance: r.advance,
          deliveryCharge: r.deliveryCharge,
          orderDiscount: Discount.amount(r.discount),
          courierId: courierId,
          consignmentNo: courierId == null ? null : r.consignmentNo,
          notes: r.notes,
          lines: [
            for (final l in r.lines)
              LineInput(
                name: l.name,
                qty: l.qty,
                unitSell: l.unitSell,
                unitCost: l.unitCost,
                discount: Discount.amount(l.discount),
              ),
          ],
        ));
        final order = result.valueOrNull;
        if (order == null) {
          issues.add(ImportRowIssue(r.row, result.failureOrNull?.message ?? 'create_failed'));
          continue;
        }
        imported++;
        await _stamp(_db.orders, order.id, batch);
        final target = OrderStatus.values.where((s) => s.dbValue == r.status).firstOrNull;
        if (target != null && target != OrderStatus.confirmed && target != OrderStatus.draft) {
          final moved = await _status.correctStatus(
            order.id,
            to: target,
            note: 'imported',
            at: r.orderDate.isAfter(DateTime.now()) ? null : r.orderDate,
          );
          // Delivered needs a courier + CN on record; otherwise keep Confirmed.
          if (!moved.isOk) issues.add(ImportRowIssue(r.row, 'status_ignored'));
        }
      }
    });
    return ImportReport(
      imported: imported,
      skippedExisting: existing,
      issues: issues,
      applied: true,
      batchId: await _closeBatch(batch, imported),
    );
  }
}

final csvImportServiceProvider = Provider<CsvImportService>((ref) => CsvImportService(
      ref.watch(databaseProvider),
      ref.watch(customerRepositoryProvider),
      ref.watch(orderRepositoryProvider),
      ref.watch(orderStatusServiceProvider),
      ref.watch(courierRepositoryProvider),
      ref.watch(productRepositoryProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
    ));
