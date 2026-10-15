import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/export/application/pdf_documents.dart';

void main() {
  bool isPdf(List<int> b) =>
      b.length > 100 && String.fromCharCodes(b.take(5)) == '%PDF-';

  test('order slip renders a valid PDF', () async {
    final bytes = await PdfDocuments.orderSlip(const OrderSlipData(
      shopName: 'Test Shop',
      orderNo: 'ORD-0001',
      date: '15/10/2026',
      customerName: 'Rahim',
      phone: '01712345678',
      address: 'House 1, Dhanmondi',
      lines: [SlipLine('Shirt', 2, Money.taka(500))],
      deliveryCharge: Money.taka(60),
      discount: Money.zero,
      codAmount: Money.taka(1060),
      courier: 'Pathao',
      consignmentNo: 'CN1',
    ));
    expect(isPdf(bytes), isTrue);
  });

  test('courier statement totals and renders', () async {
    const rows = [
      StatementRow(
        orderNo: 'ORD-1',
        cn: 'A',
        deliveredOn: '01/10',
        expected: Money.taka(900),
        received: Money.taka(860),
      ),
      StatementRow(
        orderNo: 'ORD-2',
        cn: 'B',
        deliveredOn: '02/10',
        expected: Money.taka(500),
        received: Money.taka(500),
      ),
    ];
    expect(rows.first.difference, const Money.taka(-40));
    final bytes = await PdfDocuments.courierStatement(
      shopName: 'Shop',
      courier: 'Pathao',
      period: 'Oct 2026',
      rows: rows,
    );
    expect(isPdf(bytes), isTrue);
  });

  test('generic table with many rows paginates without error', () async {
    final bytes = await PdfDocuments.table(TableDoc(
      title: 'Daily summary',
      subtitle: 'Oct',
      headers: const ['Day', 'Orders'],
      rows: [for (var i = 0; i < 200; i++) ['$i', '${i * 2}']],
      footer: 'Total',
    ));
    expect(isPdf(bytes), isTrue);
  });
}
