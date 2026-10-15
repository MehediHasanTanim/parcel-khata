import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/cod_amount_calculator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/domain/order_input.dart';

class ImportReport {
  const ImportReport({
    required this.imported,
    required this.skippedExisting,
    required this.issues,
    required this.applied,
  });

  final int imported;
  final int skippedExisting;
  final List<ImportRowIssue> issues;

  /// False when all-or-nothing blocked the import because of bad rows.
  final bool applied;
}

/// Applies validated import plans through the normal repositories, so every
/// rule (phone dedupe, order numbering, CN uniqueness) still holds.
class CsvImportService {
  CsvImportService(this._db, this._customers, this._orders, this._status, this._couriers);

  final AppDatabase _db;
  final CustomerRepository _customers;
  final OrderRepository _orders;
  final OrderStatusService _status;
  final CourierRepository _couriers;

  Future<ImportReport> importCustomers(
    CustomerImportPlan plan, {
    required bool skipBadRows,
  }) async {
    if (plan.issues.isNotEmpty && !skipBadRows) {
      return ImportReport(imported: 0, skippedExisting: 0, issues: plan.issues, applied: false);
    }
    var imported = 0;
    var existing = 0;
    await _db.transaction(() async {
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
        if (res.isOk) imported++;
      }
    });
    return ImportReport(
      imported: imported,
      skippedExisting: existing + plan.duplicatesInFile.length,
      issues: plan.issues,
      applied: true,
    );
  }

  Future<ImportReport> importOrders(
    OrderImportPlan plan, {
    required bool skipBadRows,
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
    await _db.transaction(() async {
      for (final r in plan.rows) {
        var customer = await _customers.findByPhone(r.customerPhone);
        customer ??= (await _customers.create(CustomerInput(
          name: r.customerName ?? r.customerPhone,
          phone: r.customerPhone,
        )))
            .valueOrNull;
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
    );
  }
}

final csvImportServiceProvider = Provider<CsvImportService>((ref) => CsvImportService(
      ref.watch(databaseProvider),
      ref.watch(customerRepositoryProvider),
      ref.watch(orderRepositoryProvider),
      ref.watch(orderStatusServiceProvider),
      ref.watch(courierRepositoryProvider),
    ));
