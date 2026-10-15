import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_khata/features/backup/domain/csv.dart';
import 'package:parcel_khata/features/backup/domain/csv_import.dart';
import 'package:parcel_khata/features/templates/domain/message_templates.dart';

void main() {
  group('templates', () {
    test('renders known placeholders and keeps unknown ones', () {
      final s = MessageTemplates.render(
        'Hi {name}, CN {cn}, {oops}',
        {'name': 'Rahim', 'cn': 'AB1'},
      );
      expect(s, 'Hi Rahim, CN AB1, {oops}');
      expect(MessageTemplates.unknownPlaceholders('{name} {oops} {cn}'), ['oops']);
    });

    test('every default exists in both languages and uses only known placeholders', () {
      for (final lang in ['en', 'bn']) {
        for (final k in TemplateKind.values) {
          final b = MessageTemplates.defaultBody(k, lang);
          expect(b, isNotEmpty);
          expect(MessageTemplates.unknownPlaceholders(b), isEmpty, reason: '$lang $k');
        }
      }
    });

    test('whatsapp link normalizes BD numbers and encodes text', () {
      final u = MessageTemplates.whatsAppLink('01712-345678', 'Hello & thanks');
      expect(u.host, 'wa.me');
      expect(u.path, '/8801712345678');
      expect(u.queryParameters['text'], 'Hello & thanks');
      expect(MessageTemplates.whatsAppLink('+8801712345678', 'x').path, '/8801712345678');
    });
  });

  group('csv', () {
    test('round trip with commas, quotes, newlines and Bangla', () {
      final rows = [
        ['name', 'note'],
        ['রহিম, উদ্দিন', 'said "hi"\nsecond line'],
        ['', 'plain'],
      ];
      final text = Csv.encode(rows);
      expect(text.startsWith(Csv.bom), isTrue);
      expect(Csv.parse(text), rows);
    });

    test('parses CRLF/LF, trailing newline, no BOM', () {
      expect(Csv.parse('a,b\r\n1,2\r\n'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(Csv.parse('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(Csv.parse(''), isEmpty);
    });

    test('empty fields are preserved', () {
      expect(Csv.parse('a,,c\n,,\n'), [
        ['a', '', 'c'],
        ['', '', ''],
      ]);
    });
  });

  group('import planner', () {
    test('auto-maps headers and synonyms', () {
      final m = autoMapColumns(
        ['Customer Name', 'Mobile', 'ঠিকানা', 'Notes'],
        CsvColumns.customers,
      );
      expect(m['name'], 0);
      expect(m['phone'], 1);
      expect(m['address'], 2);
      expect(m['notes'], 3);
    });

    test('customers: validation, normalization, in-file duplicates', () {
      final data = [
        ['Rahim', '+8801712345678', '', ''],
        ['', '01712345679', '', ''],
        ['Karim', '123', '', ''],
        ['Rahim again', '01712-345678', '', ''],
      ];
      final plan = CsvImportPlanner.customers(data, {'name': 0, 'phone': 1});
      expect(plan.rows.single.phoneNormalized, '01712345678');
      expect(plan.issues.map((i) => i.message), ['name_required', 'invalid_phone']);
      expect(plan.duplicatesInFile, [4]);
    });

    test('orders: single-row and separate line file', () {
      final headers = [
        'order_no', 'order_date', 'customer_phone', 'item_name', 'qty', 'unit_price', 'unit_cost',
      ];
      final map = autoMapColumns(headers, CsvColumns.orders)
        ..addAll(autoMapColumns(headers, ['item_name', 'qty', 'unit_price', 'unit_cost']));
      final plan = CsvImportPlanner.orders([
        ['A1', '2026-10-01', '01712345678', 'Shirt', '2', '500', '300'],
        ['A2', '03/10/2026', '01712345678', '', '', '', ''],
        ['A3', 'bad', '01712345678', 'x', '1', '1', ''],
        ['A1', '2026-10-02', '01712345678', 'Dup', '1', '1', ''],
      ], map, lineData: [
        ['A2', 'Hat', '1', '200', '', ''],
      ], lineMap: {
        'order_no': 0, 'item_name': 1, 'qty': 2, 'unit_price': 3, 'unit_cost': 4, 'line_discount': 5,
      });
      expect(plan.rows.map((r) => r.orderRef), ['A1', 'A2']);
      expect(plan.rows[0].lines.single.qty, 2);
      expect(plan.rows[1].orderDate, DateTime(2026, 10, 3));
      expect(plan.rows[1].lines.single.name, 'Hat');
      expect(plan.issues.map((i) => i.message), ['invalid_date', 'duplicate_order_no']);
    });

    test('date parsing', () {
      expect(CsvImportPlanner.parseDate('2026-10-15'), DateTime(2026, 10, 15));
      expect(CsvImportPlanner.parseDate('15/10/2026'), DateTime(2026, 10, 15));
      expect(CsvImportPlanner.parseDate('15-10-2026'), DateTime(2026, 10, 15));
      expect(CsvImportPlanner.parseDate('32/13/2026'), isNull);
      expect(CsvImportPlanner.parseDate(''), isNull);
    });
  });
}
