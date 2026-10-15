import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/features/backup/domain/csv.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';

String _taka(int? poisha) {
  if (poisha == null) return '';
  final neg = poisha < 0;
  final a = poisha.abs();
  final whole = a ~/ 100;
  final frac = a % 100;
  final s = frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
  return neg ? '-$s' : s;
}

String _dt(DateTime? t) => t == null ? '' : t.toLocal().toIso8601String();

/// CSV export (UTF-8 with BOM). Column names are the stable contract in
/// docs/csv-columns.md and are exactly what the importer reads back.
class CsvExporter {
  CsvExporter(this._db, this._shopId);

  final AppDatabase _db;
  final String _shopId;

  Future<String> customers() async {
    final cs = await (_db.select(_db.customers)
          ..where((c) => c.shopId.equals(_shopId) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
    final addrs = await (_db.select(_db.customerAddresses)
          ..where((a) => a.deletedAt.isNull() & a.isDefault.equals(true)))
        .get();
    final byCustomer = {for (final a in addrs) a.customerId: a};
    return Csv.encode([
      CsvColumns.customers,
      for (final c in cs)
        [
          c.name,
          c.phonePrimary,
          c.phoneAlt ?? '',
          c.whatsapp ?? '',
          byCustomer[c.id]?.fullText ?? '',
          byCustomer[c.id]?.district ?? '',
          byCustomer[c.id]?.area ?? '',
          c.notes ?? '',
        ],
    ]);
  }

  Future<String> orders() async {
    final q = _db.select(_db.orders).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.orders.customerId)),
      leftOuterJoin(_db.couriers, _db.couriers.id.equalsExp(_db.orders.courierId)),
    ])
      ..where(_db.orders.shopId.equals(_shopId) &
          _db.orders.deletedAt.isNull() &
          _db.orders.status.equals('draft').not())
      ..orderBy([OrderingTerm.asc(_db.orders.orderNumber)]);
    final rows = await q.get();
    return Csv.encode([
      CsvColumns.orders,
      for (final r in rows)
        () {
          final o = r.readTable(_db.orders);
          final c = r.readTableOrNull(_db.customers);
          return [
            o.orderNo,
            _dt(o.orderDate),
            c?.phonePrimary ?? '',
            c?.name ?? '',
            o.addressSnapshot,
            o.channel,
            o.paymentType,
            _taka(o.deliveryChargeCustomer),
            _taka(o.discountTotal),
            _taka(o.advanceReceived),
            r.readTableOrNull(_db.couriers)?.name ?? '',
            o.consignmentNo ?? '',
            o.status,
            _taka(o.codExpected),
            o.notes ?? '',
            o.sourceRef ?? '',
          ];
        }(),
    ]);
  }

  Future<String> orderLines() async {
    final q = _db.select(_db.orderLines).join([
      innerJoin(_db.orders, _db.orders.id.equalsExp(_db.orderLines.orderId)),
    ])
      ..where(_db.orders.shopId.equals(_shopId) &
          _db.orders.deletedAt.isNull() &
          _db.orders.status.equals('draft').not() &
          _db.orderLines.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(_db.orders.orderNumber), OrderingTerm.asc(_db.orderLines.createdAt)]);
    final rows = await q.get();
    return Csv.encode([
      CsvColumns.orderLines,
      for (final r in rows)
        () {
          final l = r.readTable(_db.orderLines);
          return [
            r.readTable(_db.orders).orderNo,
            l.nameSnapshot,
            '${l.qty}',
            _taka(l.unitSellPrice),
            _taka(l.unitCostPrice),
            _taka(l.lineDiscount),
          ];
        }(),
    ]);
  }

  Future<String> products() async {
    final ps = await (_db.select(_db.products)
          ..where((p) => p.shopId.equals(_shopId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return Csv.encode([
      CsvColumns.products,
      for (final p in ps)
        [
          p.name,
          p.sku ?? '',
          _taka(p.defaultSellPrice),
          _taka(p.defaultCostPrice),
          p.stockQty?.toString() ?? '',
          p.isActive ? '1' : '0',
        ],
    ]);
  }

  Future<String> payouts() async {
    final q = _db.select(_db.payouts).join([
      leftOuterJoin(_db.couriers, _db.couriers.id.equalsExp(_db.payouts.courierId)),
    ])
      ..where(_db.payouts.shopId.equals(_shopId) & _db.payouts.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(_db.payouts.paidAt)]);
    final rows = await q.get();
    return Csv.encode([
      CsvColumns.payouts,
      for (final r in rows)
        () {
          final p = r.readTable(_db.payouts);
          return [
            p.id,
            r.readTableOrNull(_db.couriers)?.name ?? '',
            _dt(p.paidAt),
            p.method,
            p.reference ?? '',
            _taka(p.totalReceived),
            p.status,
          ];
        }(),
    ]);
  }

  Future<String> payoutAllocations() async {
    final q = _db.select(_db.payoutAllocations).join([
      innerJoin(_db.orders, _db.orders.id.equalsExp(_db.payoutAllocations.orderId)),
    ])
      ..where(_db.payoutAllocations.shopId.equals(_shopId));
    final rows = await q.get();
    return Csv.encode([
      CsvColumns.payoutAllocations,
      for (final r in rows)
        () {
          final a = r.readTable(_db.payoutAllocations);
          return [
            a.payoutId,
            r.readTable(_db.orders).orderNo,
            _taka(a.amountApplied),
            _taka(a.writeOffAmount),
          ];
        }(),
    ]);
  }

  Future<String> returns() async {
    final q = _db.select(_db.returnRecords).join([
      innerJoin(_db.orders, _db.orders.id.equalsExp(_db.returnRecords.orderId)),
    ])
      ..where(_db.returnRecords.shopId.equals(_shopId) & _db.returnRecords.deletedAt.isNull());
    final rows = await q.get();
    return Csv.encode([
      CsvColumns.returns,
      for (final r in rows)
        () {
          final x = r.readTable(_db.returnRecords);
          return [
            r.readTable(_db.orders).orderNo,
            x.type,
            x.reason,
            _dt(x.initiatedAt),
            _dt(x.receivedBackAt),
            x.condition ?? '',
            _taka(x.lossAmount),
          ];
        }(),
    ]);
  }

  /// Header-only templates the seller can fill in and import back.
  static String template(List<String> columns) => Csv.encode([columns]);
}

final csvExporterProvider = Provider<CsvExporter>(
    (ref) => CsvExporter(ref.watch(databaseProvider), ref.watch(shopIdProvider)));
