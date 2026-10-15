import 'dart:typed_data';

import 'package:parcel_khata/core/money/money.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SlipLine {
  const SlipLine(this.name, this.qty, this.unitPrice);
  final String name;
  final int qty;
  final Money unitPrice;
}

class OrderSlipData {
  const OrderSlipData({
    required this.shopName,
    required this.orderNo,
    required this.date,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.lines,
    required this.deliveryCharge,
    required this.discount,
    required this.codAmount,
    this.courier,
    this.consignmentNo,
    this.shopPhone,
    this.notes,
  });

  final String shopName;
  final String? shopPhone;
  final String orderNo;
  final String date;
  final String customerName;
  final String phone;
  final String address;
  final List<SlipLine> lines;
  final Money deliveryCharge;
  final Money discount;
  final Money codAmount;
  final String? courier;
  final String? consignmentNo;
  final String? notes;
}

class StatementRow {
  const StatementRow({
    required this.orderNo,
    required this.cn,
    required this.deliveredOn,
    required this.expected,
    required this.received,
  });

  final String orderNo;
  final String cn;
  final String deliveredOn;

  /// Net receivable (collected minus the courier's deductions).
  final Money expected;
  final Money received;
  Money get difference => received - expected;
}

class TableDoc {
  const TableDoc({
    required this.title,
    required this.subtitle,
    required this.headers,
    required this.rows,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<String>> rows;
  final String? footer;
}

/// Builds the printable documents (order slip, courier dispute statement,
/// generic report table). Pass a Bangla-capable [theme] in the app; tests use
/// the built-in font.
abstract final class PdfDocuments {
  static pw.Document _doc(pw.ThemeData? theme) => pw.Document(theme: theme);

  static Future<Uint8List> orderSlip(OrderSlipData d, {pw.ThemeData? theme}) async {
    final doc = _doc(theme)
      ..addPage(pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(d.shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (d.shopPhone != null) pw.Text(d.shopPhone!),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(d.orderNo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(d.date),
          ]),
          pw.SizedBox(height: 8),
          pw.Text(d.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(d.phone),
          pw.Text(d.address),
          pw.SizedBox(height: 8),
          if (d.courier != null || d.consignmentNo != null)
            pw.Text('${d.courier ?? ''}  CN: ${d.consignmentNo ?? '-'}'),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'Qty', 'Price'],
            data: [
              for (final l in d.lines) [l.name, '${l.qty}', l.unitPrice.format()],
            ],
          ),
          pw.SizedBox(height: 6),
          if (!d.discount.isZero) _kv('Discount', '-${d.discount.format()}'),
          _kv('Delivery', d.deliveryCharge.format()),
          pw.Divider(),
          _kv('Collect (COD)', d.codAmount.format(), bold: true),
          if (d.notes != null) pw.Padding(padding: const pw.EdgeInsets.only(top: 8), child: pw.Text(d.notes!)),
        ]),
      ));
    return doc.save();
  }

  static pw.Widget _kv(String k, String v, {bool bold = false}) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
          pw.Text(v, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ],
      );

  /// Courier dispute statement: what the seller expected vs what arrived.
  static Future<Uint8List> courierStatement({
    required String shopName,
    required String courier,
    required String period,
    required List<StatementRow> rows,
    pw.ThemeData? theme,
  }) async {
    final expected = rows.fold(Money.zero, (s, r) => s + r.expected);
    final received = rows.fold(Money.zero, (s, r) => s + r.received);
    return table(
      TableDoc(
        title: '$shopName - $courier',
        subtitle: period,
        headers: const ['Order', 'CN', 'Delivered', 'Expected', 'Received', 'Difference'],
        rows: [
          for (final r in rows)
            [
              r.orderNo,
              r.cn,
              r.deliveredOn,
              r.expected.format(),
              r.received.format(),
              r.difference.format(),
            ],
        ],
        footer: 'Expected ${expected.format()}   Received ${received.format()}   '
            'Difference ${(received - expected).format()}',
      ),
      theme: theme,
    );
  }

  /// Generic titled table (daily summary, COD ageing...).
  static Future<Uint8List> table(TableDoc d, {pw.ThemeData? theme}) async {
    final doc = _doc(theme)
      ..addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (c) => [
          pw.Text(d.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(d.subtitle),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: d.headers,
            data: d.rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          if (d.footer != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text(d.footer!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
        ],
      ));
    return doc.save();
  }
}
