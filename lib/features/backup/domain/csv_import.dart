import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/customers/domain/phone_normalizer.dart';

/// Documented export/import column contract (docs/csv-columns.md).
abstract final class CsvColumns {
  static const customers = [
    'name',
    'phone',
    'phone_alt',
    'whatsapp',
    'address',
    'district',
    'area',
    'notes',
  ];

  static const orders = [
    'order_no',
    'order_date',
    'customer_phone',
    'customer_name',
    'address',
    'channel',
    'payment_type',
    'delivery_charge',
    'discount',
    'advance',
    'courier',
    'consignment_no',
    'status',
    'cod_amount',
    'notes',
    'source_ref',
  ];

  static const orderLines = [
    'order_no',
    'item_name',
    'qty',
    'unit_price',
    'unit_cost',
    'line_discount',
  ];

  static const products = ['name', 'sku', 'sell_price', 'cost_price', 'stock', 'active'];

  /// Export-only tables.
  static const payouts = [
    'payout_id',
    'courier',
    'paid_at',
    'method',
    'reference',
    'total_received',
    'status',
  ];

  static const payoutAllocations = ['payout_id', 'order_no', 'amount_applied', 'write_off'];

  static const returns = [
    'order_no',
    'type',
    'reason',
    'initiated_at',
    'received_back_at',
    'condition',
    'loss_amount',
  ];
}

/// Header synonyms so a seller's own spreadsheet maps with little effort.
const Map<String, List<String>> kHeaderSynonyms = {
  'name': ['name', 'customer', 'customer name', 'নাম'],
  'phone': ['phone', 'mobile', 'mobile number', 'phone number', 'ফোন', 'মোবাইল'],
  'customer_phone': ['customer_phone', 'customer phone', 'phone', 'mobile'],
  'customer_name': ['customer_name', 'customer name', 'customer', 'name'],
  'address': ['address', 'delivery address', 'ঠিকানা'],
  'order_no': ['order_no', 'order no', 'order number', 'order', 'invoice'],
  'order_date': ['order_date', 'date', 'order date'],
  'qty': ['qty', 'quantity', 'quantity'],
  'unit_price': ['unit_price', 'price', 'unit price', 'sell price'],
  'unit_cost': ['unit_cost', 'cost', 'unit cost', 'cost price'],
  'item_name': ['item_name', 'item', 'product', 'product name'],
  'consignment_no': ['consignment_no', 'cn', 'consignment', 'tracking', 'tracking no'],
  'delivery_charge': ['delivery_charge', 'delivery', 'shipping'],
  'cod_amount': ['cod_amount', 'cod', 'cod amount'],
};

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ');

/// Suggests which CSV column feeds each target field.
Map<String, int> autoMapColumns(List<String> headers, List<String> targets) {
  final normHeaders = [for (final h in headers) _norm(h)];
  final out = <String, int>{};
  for (final t in targets) {
    final candidates = {_norm(t), ...(kHeaderSynonyms[t] ?? const []).map(_norm)};
    final idx = normHeaders.indexWhere(candidates.contains);
    if (idx >= 0) out[t] = idx;
  }
  return out;
}

@immutable
class ImportRowIssue {
  const ImportRowIssue(this.row, this.message);

  /// 1-based data row number (header excluded).
  final int row;
  final String message;
}

@immutable
class CustomerImportRow {
  const CustomerImportRow({
    required this.row,
    required this.name,
    required this.phoneNormalized,
    this.phoneAlt,
    this.whatsapp,
    this.address,
    this.district,
    this.area,
    this.notes,
  });

  final int row;
  final String name;
  final String phoneNormalized;
  final String? phoneAlt;
  final String? whatsapp;
  final String? address;
  final String? district;
  final String? area;
  final String? notes;
}

@immutable
class CustomerImportPlan {
  const CustomerImportPlan(this.rows, this.issues, this.duplicatesInFile);

  final List<CustomerImportRow> rows;
  final List<ImportRowIssue> issues;
  final List<int> duplicatesInFile;
}

@immutable
class OrderLineImport {
  const OrderLineImport({
    required this.name,
    required this.qty,
    required this.unitSell,
    this.unitCost,
    this.discount = Money.zero,
  });

  final String name;
  final int qty;
  final Money unitSell;
  final Money? unitCost;
  final Money discount;
}

@immutable
class OrderImportRow {
  const OrderImportRow({
    required this.row,
    required this.orderRef,
    required this.customerPhone,
    required this.lines,
    required this.orderDate,
    this.customerName,
    this.address = '',
    this.channel,
    this.paymentType,
    this.deliveryCharge = Money.zero,
    this.discount = Money.zero,
    this.advance = Money.zero,
    this.courier,
    this.consignmentNo,
    this.status,
    this.notes,
  });

  final int row;

  /// The seller's own order number; used for duplicate detection.
  final String orderRef;
  final String customerPhone;
  final String? customerName;
  final String address;
  final DateTime orderDate;
  final List<OrderLineImport> lines;
  final String? channel;
  final String? paymentType;
  final Money deliveryCharge;
  final Money discount;
  final Money advance;
  final String? courier;
  final String? consignmentNo;
  final String? status;
  final String? notes;
}

@immutable
class OrderImportPlan {
  const OrderImportPlan(this.rows, this.issues);
  final List<OrderImportRow> rows;
  final List<ImportRowIssue> issues;
}

abstract final class CsvImportPlanner {
  static String _cell(List<String> row, Map<String, int> map, String field) {
    final i = map[field];
    return i == null || i >= row.length ? '' : row[i].trim();
  }

  static String? _opt(String s) => s.isEmpty ? null : s;

  /// Validates customer rows. A row with a bad name/phone becomes an issue;
  /// repeated phones inside the file are reported once as duplicates.
  static CustomerImportPlan customers(List<List<String>> data, Map<String, int> map) {
    final rows = <CustomerImportRow>[];
    final issues = <ImportRowIssue>[];
    final dups = <int>[];
    final seen = <String>{};
    for (var i = 0; i < data.length; i++) {
      final n = i + 1;
      final r = data[i];
      final name = _cell(r, map, 'name');
      final phone = PhoneNormalizer.normalize(_cell(r, map, 'phone'));
      if (name.isEmpty) {
        issues.add(ImportRowIssue(n, 'name_required'));
        continue;
      }
      if (phone == null) {
        issues.add(ImportRowIssue(n, 'invalid_phone'));
        continue;
      }
      if (!seen.add(phone)) {
        dups.add(n);
        continue;
      }
      rows.add(CustomerImportRow(
        row: n,
        name: name,
        phoneNormalized: phone,
        phoneAlt: _opt(_cell(r, map, 'phone_alt')),
        whatsapp: _opt(_cell(r, map, 'whatsapp')),
        address: _opt(_cell(r, map, 'address')),
        district: _opt(_cell(r, map, 'district')),
        area: _opt(_cell(r, map, 'area')),
        notes: _opt(_cell(r, map, 'notes')),
      ));
    }
    return CustomerImportPlan(rows, issues, dups);
  }

  static DateTime? parseDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(t);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) return DateTime(y, mo, d);
    }
    return null;
  }

  /// Groups order rows (and optional separate line rows) into orders.
  /// Single-row orders use `item_name/qty/unit_price/unit_cost` on the order
  /// row; otherwise lines come from [lineData] keyed by `order_no`.
  static OrderImportPlan orders(
    List<List<String>> data,
    Map<String, int> map, {
    List<List<String>> lineData = const [],
    Map<String, int> lineMap = const {},
  }) {
    final issues = <ImportRowIssue>[];
    final out = <OrderImportRow>[];
    final linesByRef = <String, List<OrderLineImport>>{};
    for (var i = 0; i < lineData.length; i++) {
      final r = lineData[i];
      final ref = _cell(r, lineMap, 'order_no');
      final name = _cell(r, lineMap, 'item_name');
      final qty = int.tryParse(_cell(r, lineMap, 'qty')) ?? 1;
      final price = Money.tryParse(_cell(r, lineMap, 'unit_price'));
      if (ref.isEmpty || name.isEmpty || price == null || qty < 1) {
        issues.add(ImportRowIssue(i + 1, 'bad_line'));
        continue;
      }
      linesByRef.putIfAbsent(ref, () => []).add(OrderLineImport(
            name: name,
            qty: qty,
            unitSell: price,
            unitCost: Money.tryParse(_cell(r, lineMap, 'unit_cost')),
            discount: Money.tryParse(_cell(r, lineMap, 'line_discount')) ?? Money.zero,
          ));
    }

    final seenRefs = <String>{};
    for (var i = 0; i < data.length; i++) {
      final n = i + 1;
      final r = data[i];
      final ref = _cell(r, map, 'order_no');
      final phone = PhoneNormalizer.normalize(_cell(r, map, 'customer_phone'));
      final date = parseDate(_cell(r, map, 'order_date'));
      if (ref.isEmpty) {
        issues.add(ImportRowIssue(n, 'order_no_required'));
        continue;
      }
      if (phone == null) {
        issues.add(ImportRowIssue(n, 'invalid_phone'));
        continue;
      }
      if (date == null) {
        issues.add(ImportRowIssue(n, 'invalid_date'));
        continue;
      }
      if (!seenRefs.add(ref)) {
        issues.add(ImportRowIssue(n, 'duplicate_order_no'));
        continue;
      }
      var lines = linesByRef[ref] ?? const <OrderLineImport>[];
      if (lines.isEmpty) {
        final name = _cell(r, map, 'item_name');
        final price = Money.tryParse(_cell(r, map, 'unit_price'));
        if (name.isNotEmpty && price != null) {
          lines = [
            OrderLineImport(
              name: name,
              qty: int.tryParse(_cell(r, map, 'qty')) ?? 1,
              unitSell: price,
              unitCost: Money.tryParse(_cell(r, map, 'unit_cost')),
            ),
          ];
        }
      }
      if (lines.isEmpty) {
        issues.add(ImportRowIssue(n, 'no_items'));
        continue;
      }
      out.add(OrderImportRow(
        row: n,
        orderRef: ref,
        customerPhone: phone,
        customerName: _opt(_cell(r, map, 'customer_name')),
        address: _cell(r, map, 'address'),
        orderDate: date,
        lines: lines,
        channel: _opt(_cell(r, map, 'channel')),
        paymentType: _opt(_cell(r, map, 'payment_type')),
        deliveryCharge: Money.tryParse(_cell(r, map, 'delivery_charge')) ?? Money.zero,
        discount: Money.tryParse(_cell(r, map, 'discount')) ?? Money.zero,
        advance: Money.tryParse(_cell(r, map, 'advance')) ?? Money.zero,
        courier: _opt(_cell(r, map, 'courier')),
        consignmentNo: _opt(_cell(r, map, 'consignment_no')),
        status: _opt(_cell(r, map, 'status')),
        notes: _opt(_cell(r, map, 'notes')),
      ));
    }
    return OrderImportPlan(out, issues);
  }
}
