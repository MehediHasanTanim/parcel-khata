import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/domain/paste_parser.dart';

/// Seller catalog used by the corpus (English, Bangla and mixed names).
const corpusCatalog = [
  CatalogProduct(id: 'shirt', name: 'Cotton Shirt', sellPrice: Money.taka(650)),
  CatalogProduct(id: 'jeans', name: 'Denim Jeans', sellPrice: Money.taka(1200)),
  CatalogProduct(id: 'saree', name: 'Silk Saree', sellPrice: Money.taka(2500)),
  CatalogProduct(id: 'three', name: 'Three Piece Lawn', sellPrice: Money.taka(1800)),
  CatalogProduct(id: 'wallet', name: 'Leather Wallet', sellPrice: Money.taka(450)),
  CatalogProduct(id: 'hijab', name: 'Hijab Premium', sellPrice: Money.taka(350)),
  CatalogProduct(id: 'perfume', name: 'Perfume Oud', sellPrice: Money.taka(900)),
  CatalogProduct(id: 'panjabi', name: 'Panjabi Black', sellPrice: Money.taka(1500)),
  CatalogProduct(id: 'jamdani', name: 'শাড়ি জামদানি', sellPrice: Money.taka(4200)),
  CatalogProduct(id: 'kurti', name: 'কুর্তি কটন', sellPrice: Money.taka(950)),
  CatalogProduct(id: 'cream', name: 'Face Cream', sellPrice: Money.taka(400)),
  CatalogProduct(id: 'watch', name: 'Smart Watch', sellPrice: Money.taka(2200)),
];

/// Expected product line: catalog id (or null = not in catalog) and qty.
class ExpLine {
  const ExpLine(this.productId, this.qty);
  final String? productId;
  final int qty;
}

class PasteCase {
  const PasteCase(
    this.text, {
    this.phone,
    this.name,
    this.address,
    this.lines = const [],
    this.total,
    this.tag = '',
  });

  final String text;
  final String? phone;
  final String? name;

  /// Substring the parsed address must contain.
  final String? address;
  final List<ExpLine> lines;
  final int? total;
  final String tag;
}

/// Hand-written, real-looking messages (English, Bangla, Banglish, mixed).
/// Add a case here for every reported mis-parse.
const handCases = <PasteCase>[
  PasteCase(
    'Name: Rahim Uddin\nMobile: 01712345678\nAddress: House 12, Road 5, Dhanmondi, Dhaka\nProduct: Cotton Shirt x2',
    phone: '01712345678',
    name: 'Rahim Uddin',
    address: 'Dhanmondi',
    lines: [ExpLine('shirt', 2)],
    tag: 'labelled-en',
  ),
  PasteCase(
    'নাম: করিম হোসেন\nমোবাইল: ০১৮১২৩৪৫৬৭৮\nঠিকানা: বাসা ১০, রোড ৩, মিরপুর, ঢাকা\nপণ্য: শাড়ি জামদানি ১টি',
    phone: '01812345678',
    name: 'করিম হোসেন',
    address: 'মিরপুর',
    lines: [ExpLine('jamdani', 1)],
    tag: 'labelled-bn',
  ),
  PasteCase(
    'Assalamualaikum\nSumaiya Akter\n01912345678\nVillage: Nandipara, Thana: Sadar, Cumilla\nSilk Saree 1 pcs',
    phone: '01912345678',
    name: 'Sumaiya Akter',
    address: 'Cumilla',
    lines: [ExpLine('saree', 1)],
    tag: 'unlabelled',
  ),
  PasteCase(
    'আসসালামু আলাইকুম\nআমি ২টা Denim Jeans নিতে চাই\nনাম রাফি আহমেদ\n01611223344\nগুলশান ২, ঢাকা',
    phone: '01611223344',
    address: 'গুলশান',
    lines: [ExpLine('jeans', 2)],
    tag: 'mixed',
  ),
  PasteCase(
    'hi vai, 2 ta hijab premium lagbe. mobile 01512345678. address: Uttara sector 7, Dhaka',
    phone: '01512345678',
    address: 'Uttara',
    lines: [ExpLine('hijab', 2)],
    tag: 'banglish',
  ),
  PasteCase(
    'Name: Nusrat Jahan\nPhone: +8801712345679\nAddress: Flat 4B, Block C, Bashundhara R/A, Dhaka\nItem: Face Cream\nQty: 3\nTotal: 1260',
    phone: '01712345679',
    name: 'Nusrat Jahan',
    address: 'Bashundhara',
    lines: [ExpLine('cream', 3)],
    total: 1260,
    tag: 'labelled-qty-total',
  ),
  PasteCase(
    'Order: Leather Wallet 1 pcs, Smart Watch 1 pcs\nName: Tanvir\nNumber: 017 1234 5680\nAddress: Mohammadpur, Dhaka',
    phone: '01712345680',
    name: 'Tanvir',
    address: 'Mohammadpur',
    lines: [ExpLine('wallet', 1), ExpLine('watch', 1)],
    tag: 'multi-product',
  ),
  PasteCase(
    'পাঞ্জাবি ব্ল্যাক ১টা\n০১৭৯৯৮৮৭৭৬৬\nনাম: সাকিব\nঠিকানা: সাভার বাজার, ঢাকা',
    phone: '01799887766',
    name: 'সাকিব',
    address: 'সাভার',
    lines: [ExpLine('panjabi', 1)],
    tag: 'bn-product',
  ),
  PasteCase(
    'Mahmud Hasan 01812345670\nRoad 7, House 3, Sylhet Sadar\nPerfume Oud 2pcs',
    phone: '01812345670',
    name: 'Mahmud Hasan',
    address: 'Sylhet',
    lines: [ExpLine('perfume', 2)],
    tag: 'name-with-phone',
  ),
  PasteCase(
    'Three Piece Lawn 1\nSharmin\n01712340000\nBogura Sadar, Bogura',
    phone: '01712340000',
    name: 'Sharmin',
    address: 'Bogura',
    lines: [ExpLine('three', 1)],
    tag: 'leading-qty',
  ),
  PasteCase(
    'কুর্তি কটন ২ পিস\nআয়েশা বেগম\n01911112222\nঠিকানা: বাসা ৫, খুলনা সদর, খুলনা',
    phone: '01911112222',
    name: 'আয়েশা বেগম',
    address: 'খুলনা',
    lines: [ExpLine('kurti', 2)],
    tag: 'bn-qty-pis',
  ),
  PasteCase(
    'Name: Imran\nMobile: 8801912345671\nAddress: Chittagong, Agrabad, Block B\nProduct: Cotton Shirt, Denim Jeans',
    phone: '01912345671',
    name: 'Imran',
    address: 'Agrabad',
    lines: [ExpLine('shirt', 1), ExpLine('jeans', 1)],
    tag: 'phone-880',
  ),
  PasteCase(
    'bhai ekta Smart Watch dibo? cod charge koto? 01612345672 Rangpur',
    phone: '01612345672',
    lines: [ExpLine('watch', 1)],
    tag: 'chatty',
  ),
  PasteCase(
    'Name- Farhana\nPhone- 01512340001\nAddress- Gazipur Chowrasta, Gazipur\nOrder- Hijab Premium x 4',
    phone: '01512340001',
    name: 'Farhana',
    address: 'Gazipur',
    lines: [ExpLine('hijab', 4)],
    tag: 'dash-labels',
  ),
  PasteCase(
    'Leather Wallet 450 tk 1 pcs\nRakib\n01712345675\nNarayanganj',
    phone: '01712345675',
    name: 'Rakib',
    address: 'Narayanganj',
    lines: [ExpLine('wallet', 1)],
    tag: 'price-hint',
  ),
  PasteCase(
    'আমার নাম মিম\nমোবাইল ০১৫৫৫৬৬৬৭৭৭\nঠিকানা: রামপুরা, ঢাকা\nফেস ক্রিম ২টা',
    phone: '01555666777',
    address: 'রামপুরা',
    lines: [ExpLine('cream', 2)],
    tag: 'bn-translit-product',
  ),
  PasteCase(
    'Name: Jahid\nMobile: 01912340002\nAddress: Jessore Sadar\nProduct: Unknown Gadget x2',
    phone: '01912340002',
    name: 'Jahid',
    address: 'Jessore',
    lines: [ExpLine(null, 2)],
    tag: 'not-in-catalog',
  ),
  PasteCase(
    'Silk Saree\nDenim Jeans\nName: Mou\n01712340003\nAddress: Banani, Dhaka',
    phone: '01712340003',
    name: 'Mou',
    address: 'Banani',
    lines: [ExpLine('saree', 1), ExpLine('jeans', 1)],
    tag: 'two-lines',
  ),
  PasteCase(
    'Advance 500 paisi bkash e\nName: Tania\n01812340004\nAddress: Sylhet, Zindabazar\nPanjabi Black 1',
    phone: '01812340004',
    name: 'Tania',
    address: 'Zindabazar',
    lines: [ExpLine('panjabi', 1)],
    tag: 'advance-noise',
  ),
  PasteCase(
    'NAME: SOHEL RANA\nMOBILE: 01712340005\nADDRESS: HOUSE 9, ROAD 2, UTTARA, DHAKA\nPRODUCT: COTTON SHIRT QTY 3',
    phone: '01712340005',
    name: 'SOHEL RANA',
    address: 'UTTARA',
    lines: [ExpLine('shirt', 3)],
    tag: 'uppercase',
  ),
  // Regression cases found while probing run-on messages.
  PasteCase(
    'নাম মিঠু ফোন 01911223344 ঠিকানা কালিয়াকৈর গাজীপুর শাড়ি জামদানি 2 পিস টোটাল 8400',
    phone: '01911223344',
    name: 'মিঠু',
    address: 'কালিয়াকৈর',
    lines: [ExpLine('jamdani', 2)],
    total: 8400,
    tag: 'bn-no-colons',
  ),
  PasteCase(
    'Order details:\n1) Cotton Shirt - 2\n2) Denim Jeans - 1\nName: Lima\nPhone: 01712349999\nAddress: Sirajganj',
    phone: '01712349999',
    name: 'Lima',
    address: 'Sirajganj',
    lines: [ExpLine('shirt', 2), ExpLine('jeans', 1)],
    tag: 'numbered-list',
  ),
  PasteCase(
    'Karim 01711111111 Dhaka Cotton Shirt 450 Denim Jeans 1200',
    phone: '01711111111',
    name: 'Karim',
    address: 'Dhaka',
    lines: [ExpLine('shirt', 1), ExpLine('jeans', 1)],
    tag: 'one-line-prices',
  ),
  PasteCase(
    'Total 2500\nhijab 3\nsumi 01733334444 Rajshahi',
    phone: '01733334444',
    name: 'sumi',
    address: 'Rajshahi',
    lines: [ExpLine('hijab', 3)],
    total: 2500,
    tag: 'total-first',
  ),
  PasteCase(
    '01712345678 Rahim\nRoad 4, Mirpur 2, Dhaka\nWallet leather 1',
    phone: '01712345678',
    name: 'Rahim',
    address: 'Mirpur',
    lines: [ExpLine('wallet', 1)],
    tag: 'word-order',
  ),
];

/// Deterministic templated cases (varied names, phone formats, addresses,
/// products and quantity phrasing) to cover combinations hand-writing misses.
List<PasteCase> generatedCases() {
  const names = [
    'Rahim Uddin',
    'Sumon Mia',
    'Nasrin Akter',
    'Jamal Hossain',
    'Shapla Rani',
    'Kamrul Islam',
    'রুবেল আহমেদ',
    'শিউলি বেগম',
    'মাসুদ রানা',
    'তাহমিনা খাতুন',
  ];
  const addresses = [
    ('House 12, Road 5, Dhanmondi, Dhaka', 'Dhanmondi'),
    ('Vill: Charpara, Thana: Sadar, Mymensingh', 'Mymensingh'),
    ('বাসা ৭, রোড ২, উত্তরা, ঢাকা', 'উত্তরা'),
    ('Flat 3C, Mirpur 10, Dhaka', 'Mirpur'),
    ('গ্রাম: রামপুর, থানা: সদর, বগুড়া', 'বগুড়া'),
    ('Agrabad Commercial Area, Chittagong', 'Agrabad'),
  ];
  const products = [
    ('shirt', 'Cotton Shirt'),
    ('jeans', 'Denim Jeans'),
    ('saree', 'Silk Saree'),
    ('three', 'Three Piece Lawn'),
    ('wallet', 'Leather Wallet'),
    ('hijab', 'Hijab Premium'),
    ('perfume', 'Perfume Oud'),
    ('panjabi', 'Panjabi Black'),
    ('jamdani', 'শাড়ি জামদানি'),
    ('kurti', 'কুর্তি কটন'),
    ('cream', 'Face Cream'),
    ('watch', 'Smart Watch'),
  ];
  const qtyEn = [('x2', 2), ('2 pcs', 2), ('', 1), ('qty 3', 3), ('1 pcs', 1), ('x 4', 4)];
  const qtyBn = [('২টা', 2), ('১টি', 1), ('৩ পিস', 3), ('', 1)];
  const bnDigits = '০১২৩৪৫৬৭৮৯';
  const greets = ['Hi', 'Assalamualaikum', 'আসসালামু আলাইকুম', 'Hello', 'সালাম'];

  String phoneFmt(String n, int f) {
    switch (f % 6) {
      case 0:
        return n;
      case 1:
        return '+88$n';
      case 2:
        return '${n.substring(0, 3)}-${n.substring(3, 7)}-${n.substring(7)}';
      case 3:
        return '88$n';
      case 4:
        return n.split('').map((c) => bnDigits[int.parse(c)]).join();
      default:
        return '${n.substring(0, 5)} ${n.substring(5)}';
    }
  }

  final out = <PasteCase>[];
  for (var i = 0; i < 100; i++) {
    final n = '0171${(2000 + i * 7).toString().padLeft(7, '0')}';
    final phone = phoneFmt(n, i);
    final name = names[i % names.length];
    final addr = addresses[(i ~/ 2) % addresses.length];
    final prod = products[(i * 5 + i ~/ 3) % products.length];
    final bnProduct = RegExp('[ঀ-৿]').hasMatch(prod.$2);
    final q = bnProduct || i % 4 == 3 ? qtyBn[i % qtyBn.length] : qtyEn[i % qtyEn.length];
    final mention = i % 5 == 2 && !bnProduct ? prod.$2.toLowerCase() : prod.$2;
    final prodText = q.$1.isEmpty ? mention : '$mention ${q.$1}';
    final expLines = [ExpLine(prod.$1, q.$2)];
    final tag = 'gen$i';
    switch (i % 4) {
      case 0:
        out.add(PasteCase(
          'Name: $name\nMobile: $phone\nAddress: ${addr.$1}\nProduct: $prodText',
          phone: n,
          name: name,
          address: addr.$2,
          lines: expLines,
          tag: tag,
        ));
      case 1:
        out.add(PasteCase(
          '${greets[i % greets.length]}\n$name\n$phone\n${addr.$1}\n$prodText',
          phone: n,
          name: name,
          address: addr.$2,
          lines: expLines,
          tag: tag,
        ));
      case 2:
        out.add(PasteCase(
          '$prodText lagbe. $name, $phone. ${addr.$1}',
          phone: n,
          address: addr.$2,
          lines: expLines,
          tag: tag,
        ));
      default:
        out.add(PasteCase(
          'নাম: $name\nফোন: $phone\nঠিকানা: ${addr.$1}\nপণ্য: $prodText',
          phone: n,
          name: name,
          address: addr.$2,
          lines: expLines,
          tag: tag,
        ));
    }
  }
  return out;
}
