import 'package:meta/meta.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/customers/domain/phone_normalizer.dart';

/// Rule-based, on-device parsing of a pasted customer chat message into an
/// order draft (S14). Pure Dart. Never decides anything: every field carries
/// a confidence so the UI can highlight what needs checking.
enum Confidence { high, medium, low }

@immutable
class ParsedField<T> {
  const ParsedField(this.value, this.confidence);
  final T value;
  final Confidence confidence;
}

/// What the parser needs to know about a catalog product.
@immutable
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    this.sellPrice,
    this.costPrice,
  });

  final String id;
  final String name;
  final Money? sellPrice;
  final Money? costPrice;
}

@immutable
class ParsedLine {
  const ParsedLine({
    required this.mention,
    required this.qty,
    required this.confidence,
    this.product,
    this.priceHint,
    this.ambiguousWith = const [],
  });

  /// Product text as the customer wrote it.
  final String mention;
  final int qty;
  final CatalogProduct? product;

  /// A price written next to the mention (per the message, not verified).
  final Money? priceHint;
  final Confidence confidence;

  /// Other catalog products that matched about as well.
  final List<CatalogProduct> ambiguousWith;
}

@immutable
class ParsedOrderDraft {
  const ParsedOrderDraft({
    this.phone,
    this.altPhones = const [],
    this.name,
    this.address,
    this.lines = const [],
    this.totalHint,
    this.deliveryHint,
    this.advanceHint,
    this.notes = const [],
  });

  final ParsedField<String>? phone;
  final List<String> altPhones;
  final ParsedField<String>? name;
  final ParsedField<String>? address;
  final List<ParsedLine> lines;

  /// Amounts mentioned in the message (never applied silently).
  final Money? totalHint;
  final Money? deliveryHint;
  final Money? advanceHint;

  /// Lines the parser could not place anywhere.
  final List<String> notes;

  bool get isEmpty =>
      phone == null && name == null && address == null && lines.isEmpty;
}

abstract final class PasteParser {
  // ------------------------------------------------------------ text prep

  static const _bn = '০১২৩৪৫৬৭৮৯';

  static String asciiDigits(String s) => s.replaceAllMapped(
      RegExp('[০-৯]'), (m) => _bn.indexOf(m.group(0)!).toString());

  // ------------------------------------------------------------- phones

  static final _phoneRe = RegExp(
    r'(?<![\d])(?:\+?\s*88[\s-]?)?0?1[3-9](?:[\s-]?\d){8}(?![\d])',
  );

  // ------------------------------------------------------------- labels

  static const _labelWords = <String, List<String>>{
    'address': [
      'delivery address',
      'address',
      'addr',
      'location',
      'ডেলিভারি ঠিকানা',
      'ঠিকানা',
      'এড্রেস',
      'অ্যাড্রেস',
    ],
    'name': [
      'customer name',
      'name',
      'customer',
      'receiver',
      'নাম',
      'ক্রেতার নাম',
      'গ্রাহকের নাম',
      'প্রাপকের নাম',
    ],
    'phone': [
      'mobile number',
      'mobile',
      'phone',
      'contact',
      'cell',
      'number',
      'মোবাইল নাম্বার',
      'মোবাইল',
      'ফোন',
      'নাম্বার',
      'নম্বর',
      'যোগাযোগ',
    ],
    'product': [
      'product',
      'item',
      'items',
      'order',
      'পণ্য',
      'প্রোডাক্ট',
      'আইটেম',
      'অর্ডার',
    ],
    'total': [
      'total bill',
      'টোটাল',
      'total',
      'cod',
      'collect',
      'মোট',
      'সর্বমোট',
      'কালেক্ট',
    ],
    'delivery': [
      'delivery charge',
      'delivery',
      'shipping',
      'courier charge',
      'ডেলিভারি চার্জ',
      'ডেলিভারি',
      'কুরিয়ার চার্জ',
    ],
    'advance': ['advance', 'অগ্রিম', 'এডভান্স', 'অ্যাডভান্স'],
    'qty': ['quantity', 'qty', 'পরিমাণ'],
    'price': ['price', 'দাম', 'মূল্য', 'প্রাইস'],
  };

  static RegExp _labelRe() {
    final all = [
      for (final e in _labelWords.values) ...e,
    ]..sort((a, b) => b.length.compareTo(a.length));
    final alt = all.map(RegExp.escape).join('|');
    return RegExp('^\\s*[-*•#.)\\d]*\\s*($alt)\\s*(?:[:：=]|[-–—]\\s)\\s*(.+)\$',
        caseSensitive: false);
  }

  static final _labelPattern = _labelRe();

  // Bangla label followed by a space instead of a colon ("নাম মিঠু").
  static final _bnLabelNoSep = RegExp(
    r'^\s*(নাম|ফোন|মোবাইল|ঠিকানা|পণ্য|মোট|টোটাল|সর্বমোট)\s+(.+)$',
  );

  static String? _labelKey(String label) {
    final l = label.toLowerCase().trim();
    for (final e in _labelWords.entries) {
      if (e.value.contains(l)) return e.key;
    }
    return null;
  }

  // ------------------------------------------------------------ keywords

  static const _addressWords = [
    'road', 'rd', 'house', 'flat', 'block', 'sector', 'lane', 'village', 'vill',
    'post', 'thana', 'upazila', 'upazilla', 'union', 'district', 'zila', 'bazar',
    'bazaar', 'market', 'colony', 'ward', 'holding', 'floor', 'near', 'behind',
    'বাসা', 'বাড়ি', 'বাড়ী', 'রোড', 'রোড়', 'গ্রাম', 'থানা', 'উপজেলা', 'জেলা',
    'ইউনিয়ন', 'পোস্ট', 'বাজার', 'ফ্ল্যাট', 'ব্লক', 'সেক্টর', 'লেন', 'মার্কেট',
    'কলোনি', 'ওয়ার্ড', 'হোল্ডিং', 'পাড়া', 'মহল্লা', 'এলাকা', 'সংলগ্ন',
  ];

  static const _places = [
    'dhaka', 'chittagong', 'chattogram', 'ctg', 'sylhet', 'rajshahi', 'khulna',
    'barisal', 'barishal', 'rangpur', 'mymensingh', 'comilla', 'cumilla',
    'gazipur', 'narayanganj', 'savar', 'uttara', 'mirpur', 'dhanmondi',
    'mohammadpur', 'banani', 'gulshan', 'badda', 'rampura', 'tongi', 'bogura',
    'bogra', 'jessore', 'jashore', 'cox', 'sadar', 'tangail', 'sirajganj', 'pabna',
    'kushtia', 'faridpur', 'narsingdi', 'manikganj', 'munshiganj', 'netrokona',
    'kishoreganj', 'habiganj', 'moulvibazar', 'sunamganj', 'noakhali', 'feni',
    'lakshmipur', 'chandpur', 'brahmanbaria', 'bhola', 'patuakhali', 'barguna',
    'jhalokati', 'pirojpur', 'gopalganj', 'madaripur', 'shariatpur', 'rajbari',
    'magura', 'narail', 'jhenaidah', 'chuadanga', 'meherpur', 'satkhira',
    'bagerhat', 'dinajpur', 'thakurgaon', 'panchagarh', 'nilphamari',
    'lalmonirhat', 'kurigram', 'gaibandha', 'joypurhat', 'naogaon', 'natore',
    'nawabganj', 'sherpur', 'jamalpur', 'টাঙ্গাইল', 'সিরাজগঞ্জ', 'পাবনা', 'কুষ্টিয়া',
    'ফরিদপুর', 'নরসিংদী', 'সদর', 'ঢাকা', 'চট্টগ্রাম', 'সিলেট', 'রাজশাহী',
    'খুলনা', 'বরিশাল', 'রংপুর', 'ময়মনসিংহ', 'কুমিল্লা', 'গাজীপুর', 'নারায়ণগঞ্জ',
    'সাভার', 'উত্তরা', 'মিরপুর', 'ধানমন্ডি', 'মোহাম্মদপুর', 'বনানী', 'গুলশান',
    'বাড্ডা', 'রামপুরা', 'টঙ্গী', 'বগুড়া', 'যশোর',
  ];

  static const _noise = [
    'hi', 'hello', 'hey', 'salam', 'assalamualaikum', 'assalamu alaikum',
    'thanks', 'thank you', 'please', 'plz', 'pls', 'confirm', 'ok', 'okay',
    'order korte chai', 'i want to order', 'want to order', 'order',
    'সালাম', 'আসসালামু আলাইকুম', 'আসসালামুয়ালাইকুম', 'ধন্যবাদ', 'প্লিজ',
    'কনফার্ম', 'অর্ডার করতে চাই', 'অর্ডার করব', 'অর্ডার করবো', 'ভাই', 'আপু',
    'আপনার', 'আমি', 'আমার',
  ];

  // Common product words, Bangla -> English, so one catalog language matches
  // customers writing in the other.
  static const _synonyms = <String, String>{
    'শার্ট': 'shirt',
    'টিশার্ট': 'tshirt',
    'টি-শার্ট': 'tshirt',
    'পাঞ্জাবি': 'panjabi',
    'পাঞ্জাবী': 'panjabi',
    'শাড়ি': 'saree',
    'শাড়ী': 'saree',
    'থ্রি': 'three',
    'পিস': 'piece',
    'কুর্তি': 'kurti',
    'কুর্তা': 'kurta',
    'জুতা': 'shoe',
    'জুতো': 'shoe',
    'স্যান্ডেল': 'sandal',
    'ব্যাগ': 'bag',
    'ঘড়ি': 'watch',
    'প্যান্ট': 'pant',
    'জিন্স': 'jeans',
    'হিজাব': 'hijab',
    'বোরকা': 'borka',
    'ওড়না': 'orna',
    'লেহেঙ্গা': 'lehenga',
    'গাউন': 'gown',
    'ক্রিম': 'cream',
    'তেল': 'oil',
    'শ্যাম্পু': 'shampoo',
    'সাবান': 'soap',
    'পারফিউম': 'perfume',
    'আতর': 'attar',
    'মধু': 'honey',
    'খেজুর': 'dates',
    'কটন': 'cotton',
    'সিল্ক': 'silk',
    'লাল': 'red',
    'নীল': 'blue',
    'কালো': 'black',
    'সাদা': 'white',
    'সবুজ': 'green',
    'হলুদ': 'yellow',
    'বড়': 'large',
    'ছোট': 'small',
    'মিডিয়াম': 'medium',
    'লার্জ': 'large',
    'এক্সএল': 'xl',
    'ব্ল্যাক': 'black',
    'ব্লাক': 'black',
    'রেড': 'red',
    'ব্লু': 'blue',
    'হোয়াইট': 'white',
    'ফেস': 'face',
    'ওয়াচ': 'watch',
    'স্মার্ট': 'smart',
    'লেদার': 'leather',
    'ওয়ালেট': 'wallet',
    'প্রিমিয়াম': 'premium',
  };

  // Words too common in product names to identify one on their own.
  static const _generic = {
    'piece', 'pcs', 'pc', 'set', 'pack', 'combo', 'new', 'size', 'color',
    'colour', 'the', 'and', 'for', 'of', 'with', 'original', 'item', 'product',
  };

  // Chat filler that is never part of a name, product or address.
  static const _fillers = {
    'lagbe', 'lagbo', 'chai', 'dibo', 'dite', 'dien', 'den', 'nite', 'nibo',
    'dibe', 'kinbo', 'korte', 'plz', 'pls', 'please', 'kindly', 'urgent',
    'নিতে', 'চাই', 'লাগবে', 'দিবেন', 'দিন', 'দেন', 'কিনবো', 'করতে', 'প্লিজ',
    'আছে', 'কি', 'koto', 'কত', 'ache', 'available', 'ami', 'amar', 'আমি', 'আমার', 'ar', 'আর',
  };

  static const _greetStart =
      r'^(?:(?:hi|hello|hey|vai|bhai|vaiya|bhaiya|apu|apa|sir|madam|salam|assalamualaikum|ভাই|আপু|আপা|সালাম|ভাইয়া|স্যার)(?![A-Za-zঀ-৿])[\s,!]*)+';

  static const _qtyWords = <String, int>{
    'এক': 1, 'একটি': 1, 'একটা': 1, 'one': 1, 'ekta': 1, 'ekti': 1,
    'দুই': 2, 'দুটি': 2, 'দুটো': 2, 'দুইটা': 2, 'two': 2, 'duita': 2, 'duto': 2,
    'তিন': 3, 'তিনটি': 3, 'তিনটা': 3, 'three': 3, 'tinta': 3,
    'চার': 4, 'চারটি': 4, 'চারটা': 4, 'four': 4, 'charta': 4,
    'পাঁচ': 5, 'পাঁচটি': 5, 'পাঁচটা': 5, 'five': 5,
  };

  // --------------------------------------------------------------- parse

  static ParsedOrderDraft parse(String raw, {List<CatalogProduct> catalog = const []}) {
    var text = asciiDigits(raw).replaceAll('\r', '');
    // "নাম মিঠু ফোন 017... ঠিকানা ..." written on one line without colons.
    text = text.split('\n').map((l) {
      if (l.contains(':') || l.contains('：')) return l;
      return l.replaceAllMapped(
        RegExp(r'\s(?=(?:নাম|ফোন|মোবাইল|ঠিকানা|পণ্য|মোট|টোটাল|সর্বমোট)\s)'),
        (_) => '\n',
      );
    }).join('\n');
    final lines = [
      for (final l in text.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    if (lines.isEmpty) return const ParsedOrderDraft();

    // -- phones (anywhere in the text) ----------------------------------
    final phones = <String>[];
    final stripped = <String>[];
    for (final l in lines) {
      var rest = l;
      for (final m in _phoneRe.allMatches(l)) {
        final n = PhoneNormalizer.normalize(m.group(0)!);
        if (n != null && !phones.contains(n)) phones.add(n);
      }
      rest = rest.replaceAll(_phoneRe, ' ').trim();
      stripped.add(rest);
    }

    // Sentences inside a line are classified separately ("2 shirt lagbe.
    // Rahim, 017... . House 3, Dhaka").
    final labelWordsSorted = _labelWords.values.expand((e) => e).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final labelOnly = RegExp(
      '^(?:${labelWordsSorted.map(RegExp.escape).join('|')})\\s*[:：=\\-–]?\\s*\$',
      caseSensitive: false,
    );
    final frags = <String>[];
    for (final st in stripped) {
      for (final f in st.split(RegExp(r'[।?!]+|\.(?=\s|$)'))) {
        final t = f.trim().replaceAll(RegExp(r'^[,;\s]+|[,;\s]+$'), '');
        if (t.isEmpty || !RegExp(r'[A-Za-z\u0980-\u09FF0-9]').hasMatch(t)) continue;
        if (labelOnly.hasMatch(t)) continue;
        frags.add(t);
      }
    }

    String? name;
    var nameConf = Confidence.low;
    String? address;
    var addressConf = Confidence.low;
    final addressParts = <String>[];
    final productTexts = <String>[];
    Money? total, delivery, advance;
    String? explicitQty;
    String? explicitPrice;
    final notes = <String>[];

    // -- labelled lines --------------------------------------------------
    final remaining = <String>[];
    for (final fr in frags) {
      final m = _labelPattern.firstMatch(fr) ?? _bnLabelNoSep.firstMatch(fr);
      if (m == null) {
        remaining.add(fr);
        continue;
      }
      final key = _labelKey(m.group(1)!);
      var value = m.group(2)!.replaceAll(_phoneRe, ' ').trim();
      switch (key) {
        case 'name':
          if (value.isNotEmpty) {
            name = value;
            nameConf = Confidence.high;
          }
        case 'address':
          if (catalog.isNotEmpty) {
            final peeled = _peelProducts(value, catalog);
            if (peeled.mentions.isNotEmpty) {
              productTexts.addAll(peeled.mentions);
              value = peeled.rest;
            }
          }
          if (value.isNotEmpty) addressParts.add(value);
          addressConf = Confidence.high;
        case 'phone':
          break; // already collected
        case 'product':
          if (value.isNotEmpty) productTexts.add(value);
        case 'qty':
          explicitQty = value;
        case 'price':
          explicitPrice = value;
        case 'total':
          total = _amount(value) ?? total;
        case 'delivery':
          delivery = _amount(value) ?? delivery;
        case 'advance':
          advance = _amount(value) ?? advance;
        default:
          if (value.isNotEmpty) remaining.add(value);
      }
    }

    // -- inline amounts in unlabelled lines ------------------------------
    final inlineAmt = RegExp(
      r'(total|cod|collect|মোট|সর্বমোট|কালেক্ট|delivery|ডেলিভারি|advance|অগ্রিম)\D{0,14}?(\d[\d,]*(?:\.\d+)?)',
      caseSensitive: false,
    );
    final afterAmounts = <String>[];
    for (final l in remaining) {
      var rest = l;
      for (final m in inlineAmt.allMatches(l)) {
        final k = m.group(1)!.toLowerCase();
        final v = _amount(m.group(2)!);
        if (v == null) continue;
        if (RegExp('delivery|ডেলিভারি').hasMatch(k)) {
          delivery ??= v;
        } else if (RegExp('advance|অগ্রিম').hasMatch(k)) {
          advance ??= v;
        } else {
          total ??= v;
        }
        rest = rest.replaceFirst(m.group(0)!, ' ');
      }
      rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (rest.isNotEmpty && RegExp(r'[A-Za-zঀ-৿0-9]').hasMatch(rest)) {
        afterAmounts.add(rest);
      }
    }

    // -- classify what is left -------------------------------------------
    final candidates = <String>[];
    for (final l in afterAmounts) {
      final cleaned = _stripNoise(l);
      if (cleaned.isNotEmpty) candidates.add(cleaned);
    }

    final productish = <String>[];
    final other = <String>[];
    for (final c0 in candidates) {
      var c = c0;
      // Run-on text: lift catalog products (with their quantity/price) out of
      // the fragment so the remainder can be a name or an address.
      if (catalog.isNotEmpty && c.split(RegExp(r'\s+')).length >= 3) {
        final peeled = _peelProducts(c, catalog);
        if (peeled.mentions.isNotEmpty) {
          productish.addAll(peeled.mentions);
          c = peeled.rest;
          if (c.isEmpty) continue;
        }
      }
      if (_looksLikeAddress(c)) {
        c = c.replaceAll(RegExp(r'(?:,\s*)+,'), ',').replaceAll(RegExp(r'^[,\s]+'), '');
        if (name == null) {
          final split = _splitLeadingName(c);
          if (split != null) {
            name = split.$1;
            nameConf = Confidence.medium;
            c = split.$2;
          }
        }
        addressParts.add(c);
        if (addressConf == Confidence.low) addressConf = Confidence.medium;
      } else if (_looksLikeProduct(c, catalog)) {
        productish.add(c);
      } else {
        other.add(c);
      }
    }

    // Name: first short, digit-free, non-product line.
    if (name == null) {
      for (final o in other) {
        if (_plausibleName(o)) {
          name = o;
          nameConf = Confidence.medium;
          other.remove(o);
          break;
        }
      }
    }
    // "Rahim 01712345678" -> text next to the phone on its own line.
    if (name == null) {
      for (var i = 0; i < lines.length; i++) {
        if (!_phoneRe.hasMatch(lines[i])) continue;
        final before = _stripNoise(lines[i].substring(0, _phoneRe.firstMatch(lines[i])!.start)
            .replaceAll(RegExp(r'[:：\-–,]+\s*$'), '')
            .trim());
        if (before.isNotEmpty && _plausibleName(before) && !_looksLikeProduct(before, catalog)) {
          name = before;
          nameConf = Confidence.medium;
          break;
        }
      }
    }
    notes.addAll(other.where((o) => o != name));

    if (addressParts.isNotEmpty) {
      address = addressParts.join(', ');
    }

    // -- products ---------------------------------------------------------
    final mentions = [...productTexts, ...productish];
    final parsedLines = <ParsedLine>[];
    for (final t in mentions) {
      for (final seg in _segments(t)) {
        final pl = _line(seg, catalog);
        if (pl != null) parsedLines.add(pl);
      }
    }
    // A labelled qty/price applies to a single product line.
    if (parsedLines.length == 1) {
      final only = parsedLines.single;
      final q = explicitQty == null ? null : int.tryParse(RegExp(r'\d+').stringMatch(explicitQty) ?? '');
      final p = explicitPrice == null ? null : _amount(explicitPrice);
      if (q != null || p != null) {
        parsedLines[0] = ParsedLine(
          mention: only.mention,
          qty: q ?? only.qty,
          confidence: only.confidence,
          product: only.product,
          priceHint: p ?? only.priceHint,
          ambiguousWith: only.ambiguousWith,
        );
      }
    }

    ParsedField<String>? phoneField;
    if (phones.isNotEmpty) {
      phoneField = ParsedField(phones.first, Confidence.high);
    }
    return ParsedOrderDraft(
      phone: phoneField,
      altPhones: phones.length > 1 ? phones.sublist(1) : const [],
      name: name == null ? null : ParsedField(_tidyName(name), nameConf),
      address: address == null ? null : ParsedField(address, addressConf),
      lines: parsedLines,
      totalHint: total,
      deliveryHint: delivery,
      advanceHint: advance,
      notes: notes,
    );
  }

  // ------------------------------------------------------------- helpers

  static Money? _amount(String s) {
    final m = RegExp(r'(\d[\d,]*(?:\.\d+)?)').firstMatch(s);
    if (m == null) return null;
    return Money.tryParse(m.group(1)!.replaceAll(',', ''));
  }

  static String _tidyName(String s) =>
      s.replaceAll(RegExp(r'^[\s,:\-–]+|[\s,:\-–]+$'), '').replaceAll(RegExp(r'\s+'), ' ');

  static String _stripNoise(String s) {
    var t = s.trim();
    // Drop whole-line greetings / filler.
    final low = t.toLowerCase().replaceAll(RegExp(r'[!.,।?]+'), '').trim();
    if (low.isEmpty) return '';
    if (_noise.contains(low)) return '';
    for (final n in _noise) {
      if (n.length > 6 && low.startsWith(n) && low.length - n.length < 4) return '';
    }
    // List bullets / numbering ("1) Shirt"), but never a quantity ("2 shirt").
    t = t.replaceAll(RegExp(r'^[\s\-*•#]+'), '').replaceAll(RegExp(r'^\d+[.)]\s+'), '');
    t = t.replaceFirst(RegExp(_greetStart, caseSensitive: false), '');
    t = _dropFillers(t);
    return t.trim();
  }

  /// "Karim Dhaka" -> ("Karim", "Dhaka"): 1-3 plain words before the first
  /// address word / place / digit.
  static (String, String)? _splitLeadingName(String s) {
    final words = s.split(RegExp(r'\s+'));
    for (var i = 0; i < words.length && i <= 3; i++) {
      final w = words[i].toLowerCase().replaceAll(RegExp(r'[,.:;]+$'), '');
      final isAddr = _addressWords.contains(w) ||
          _places.contains(w) ||
          RegExp(r'\d').hasMatch(w);
      if (isAddr) {
        if (i == 0) return null;
        final before = words.sublist(0, i).join(' ');
        if (before.contains(',') && i > 1) return null;
        final rest = words.sublist(i).join(' ');
        return (before.replaceAll(RegExp(r'[,:;]+$'), '').trim(), rest);
      }
    }
    return null;
  }

  static ({String rest, List<String> mentions}) _peelProducts(
      String frag, List<CatalogProduct> catalog) {
    final toks = frag.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final used = List<bool>.filled(toks.length, false);

    bool isQtyTok(String t) => RegExp(
          r'^(?:x|x\d+|\d+x|\d{1,2}(?:pcs?|টি|টা|পিস)?|qty|pcs?|pieces?|ta|টি|টা|পিস)$',
          caseSensitive: false,
        ).hasMatch(t.replaceAll(RegExp(r'[,;]+$'), ''));
    bool isPriceTok(String t) => RegExp(
          r'^(?:\d{2,6}(?:tk|/-)?|৳|tk|taka|টাকা)[,;]?$',
          caseSensitive: false,
        ).hasMatch(t);
    bool isUnitLeading(String t) =>
        RegExp(r'^(?:ta|টা|টি)$', caseSensitive: false).hasMatch(t);

    // 1) Product cores: the best non-overlapping windows that match a
    //    catalog product closely.
    final cores = <(int, int)>[];
    for (var round = 0; round < 4; round++) {
      var best = 0.0;
      var bs = -1, be = -1;
      for (var len = toks.length < 6 ? toks.length : 6; len >= 1; len--) {
        for (var i = 0; i + len <= toks.length; i++) {
          if (used.sublist(i, i + len).any((u) => u)) continue;
          final win = toks.sublist(i, i + len).join(' ');
          if (!RegExp(r'[A-Za-zঀ-৿]').hasMatch(win)) continue;
          for (final p in catalog) {
            final sc = similarity(win, p.name);
            if (sc >= 0.8 && sc > best + 1e-9) {
              best = sc;
              bs = i;
              be = i + len;
            }
          }
        }
      }
      if (bs < 0) break;
      cores.add((bs, be));
      for (var k = bs; k < be; k++) {
        used[k] = true;
      }
    }
    if (cores.isEmpty) return (rest: frag, mentions: const <String>[]);
    cores.sort((a, b) => a.$1.compareTo(b.$1));

    // 2) Attach quantity / price tokens. A group between two products goes
    //    to the previous one ("shirt 2, jeans 1") unless it uses the
    //    leading "N ta / ২টা" form, which binds to the next.
    final from = [for (final c in cores) c.$1];
    final to = [for (final c in cores) c.$2];
    for (var k = 0; k < cores.length; k++) {
      final lo = k == 0 ? 0 : to[k - 1];
      final hi = k + 1 < cores.length ? cores[k + 1].$1 : toks.length;
      // Qty/price tokens right after core k, before the next core / end.
      var end = to[k];
      while (end < hi && (isQtyTok(toks[end]) || isPriceTok(toks[end]))) {
        end++;
      }
      final hasNext = k + 1 < cores.length;
      final group = toks.sublist(to[k], end);
      final leadsNext = hasNext &&
          end == hi &&
          group.isNotEmpty &&
          group.any(isUnitLeading) &&
          group.length <= 2;
      if (!leadsNext) {
        to[k] = end;
      }
      // Leading tokens before core k that were not claimed by core k-1.
      var start = from[k];
      final floor = k == 0 ? lo : to[k - 1];
      while (start > floor && isQtyTok(toks[start - 1])) {
        start--;
      }
      from[k] = start;
    }

    final mentions = <String>[];
    final take = List<bool>.filled(toks.length, false);
    for (var k = 0; k < cores.length; k++) {
      mentions.add(toks.sublist(from[k], to[k]).join(' '));
      for (var t = from[k]; t < to[k]; t++) {
        take[t] = true;
      }
    }
    final rest = [
      for (var i = 0; i < toks.length; i++)
        if (!take[i]) toks[i],
    ].join(' ').replaceAll(RegExp(r'^[,;\s]+|[,;\s]+$'), '').trim();
    return (rest: rest, mentions: mentions);
  }

  static String _dropFillers(String s) {
    final kept = <String>[];
    for (final w in s.split(RegExp(r'\s+'))) {
      final bare = w.toLowerCase().replaceAll(RegExp(r'^[,.;:]+|[,.;:]+$'), '');
      if (_fillers.contains(bare)) continue;
      kept.add(w);
    }
    return kept.join(' ');
  }

  static bool _looksLikeAddress(String s) {
    final low = s.toLowerCase();
    final words = low.split(RegExp(r'[\s,./:()-]+')).where((w) => w.isNotEmpty).toSet();
    for (final w in _addressWords) {
      if (words.contains(w)) return true;
    }
    for (final p in _places) {
      if (words.contains(p) || (p.length > 3 && low.contains(p) && !_hasPriceOrQty(low))) {
        // A place name alone ("Dhaka") is an address fragment.
        return true;
      }
    }
    final commas = ','.allMatches(s).length;
    return commas >= 2 && RegExp(r'\d').hasMatch(s) && !_hasPriceOrQty(low);
  }

  static bool _hasPriceOrQty(String low) => RegExp(
        r'\d\s*(tk|taka|৳|টাকা|pcs?|pieces?|টি|টা|পিস|/-)|(price|দাম|qty)\s*[:=]?\s*\d',
      ).hasMatch(low);

  static bool _plausibleName(String s) {
    if (RegExp(r'\d').hasMatch(s)) return false;
    final words = s.trim().split(RegExp(r'\s+'));
    if (words.length > 4 || s.length > 40) return false;
    if (s.contains(',')) return false;
    return true;
  }

  static bool _looksLikeProduct(String s, List<CatalogProduct> catalog) {
    if (_hasPriceOrQty(s.toLowerCase())) return true;
    if (RegExp(r'\b(x\s*\d+|\d+\s*x)\b', caseSensitive: false).hasMatch(s)) return true;
    if (RegExp(r'^\d+\s+\S').hasMatch(s) && !_looksLikeAddress(s)) return true;
    return _bestMatch(s, catalog).score >= 0.55;
  }

  /// Splits "red shirt 2pcs + black cap" into mentions.
  static List<String> _segments(String t) {
    final parts = t.split(RegExp(r'\s*(?:\+|&|;|\band\b|এবং|\bআর\b|,)\s*', caseSensitive: false));
    return [
      for (final p in parts)
        if (_stripNoise(p).isNotEmpty) _stripNoise(p),
    ];
  }

  static ParsedLine? _line(String seg, List<CatalogProduct> catalog) {
    var s = seg;
    int? qty;
    Money? price;

    // Price: "500 tk", "৳500", "price 500", "500/-"
    final priceRe = RegExp(
      r'(?:(\d[\d,]*(?:\.\d+)?)\s*(?:tk|taka|bdt|৳|টাকা|/-|/=))|(?:(?:৳|tk\.?|price|দাম|মূল্য)\s*[:=]?\s*(\d[\d,]*(?:\.\d+)?))',
      caseSensitive: false,
    );
    final pm = priceRe.firstMatch(s);
    if (pm != null) {
      price = _amount(pm.group(1) ?? pm.group(2)!);
      s = s.replaceRange(pm.start, pm.end, ' ');
    }

    final qtyPatterns = <RegExp>[
      RegExp(r'(\d+)\s*(?:pcs?|pieces?|টি|টা|পিস|পিছ|ta|ti)(?![A-Za-z\u0980-\u09FF])',
          caseSensitive: false),
      RegExp(r'(?:qty|quantity|পরিমাণ)\s*[:=]?\s*(\d+)', caseSensitive: false),
      RegExp(r'\bx\s*(\d+)\b', caseSensitive: false),
      RegExp(r'\b(\d+)\s*x\b', caseSensitive: false),
    ];
    for (final re in qtyPatterns) {
      final m = re.firstMatch(s);
      if (m != null) {
        qty = int.tryParse(m.group(1)!);
        s = s.replaceRange(m.start, m.end, ' ');
        break;
      }
    }
    if (qty == null) {
      final lead = RegExp(r'^(\d{1,2})\s+(?=[A-Za-zঀ-৿])').firstMatch(s.trim());
      if (lead != null) {
        qty = int.tryParse(lead.group(1)!);
        s = s.trim().substring(lead.end);
      }
    }
    if (price == null) {
      final tp = RegExp(r'(?<=[A-Za-z\u0980-\u09FF])[\s\-–:=]+(\d{2,6})\s*$').firstMatch(s);
      if (tp != null) {
        final v = int.tryParse(tp.group(1)!);
        if (v != null && v > 20) {
          price = Money.taka(v);
          s = s.substring(0, tp.start);
        }
      }
    }
    if (qty == null) {
      final trailing = RegExp(r'(?<=[A-Za-z\u0980-\u09FF])[\s\-–:=]+(\d{1,2})\s*$').firstMatch(s);
      if (trailing != null) {
        final v = int.tryParse(trailing.group(1)!);
        if (v != null && v >= 1 && v <= 20) {
          qty = v;
          s = s.substring(0, trailing.start);
        }
      }
    }
    if (qty == null && _bestMatch(s, catalog).score < 0.8) {
      // "Three Piece Lawn": a catalog product name beats a quantity word.
      for (final e in _qtyWords.entries) {
        final re = RegExp('(^|\\s)${RegExp.escape(e.key)}(\\s|\$)');
        if (re.hasMatch(s)) {
          qty = e.value;
          s = s.replaceFirst(re, ' ');
          break;
        }
      }
    }
    s = s
        .replaceAll(RegExp(r'\b(?:pcs?|pieces?|piece)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[\s,:;\-–]+'), ' ')
        .trim();
    s = s.replaceAll(RegExp(r'^(?:ta|টা|টি|পিস)\s+'), '');
    if (s.isEmpty || !RegExp(r'[A-Za-zঀ-৿]').hasMatch(s)) return null;
    if (qty != null && (qty < 1 || qty > 500)) qty = null;

    final best = _bestMatch(s, catalog);
    var conf = Confidence.low;
    CatalogProduct? product;
    var ambiguous = const <CatalogProduct>[];
    if (best.score >= 0.8) {
      product = best.product;
      conf = Confidence.high;
    } else if (best.score >= 0.55) {
      product = best.product;
      conf = Confidence.medium;
    }
    if (product != null) {
      final ties = [
        for (final r in best.ranked)
          if (r.product.id != product.id && r.score >= best.score - 0.05 && r.score >= 0.55)
            r.product,
      ];
      if (ties.isNotEmpty) {
        ambiguous = ties;
        conf = Confidence.medium;
      }
    }
    return ParsedLine(
      mention: s,
      qty: qty ?? 1,
      confidence: conf,
      product: product,
      priceHint: price,
      ambiguousWith: ambiguous,
    );
  }

  // --------------------------------------------------------------- match

  static String _canon(String s) {
    var t = asciiDigits(s.toLowerCase());
    t = t.replaceAll(RegExp(r'[()\[\]{}.,/\\|_]'), ' ').replaceAll('-', ' ');
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) {
      for (final e in _synonyms.entries) {
        if (w == e.key) return e.value;
        // Bangla suffixes: শার্টটা, শার্টের, শার্টে
        if (w.startsWith(e.key) && w.length - e.key.length <= 3) return e.value;
      }
      return w;
    });
    return words.join(' ').trim();
  }

  static int _edit(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 2) return 3;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final c = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  static bool _tokenEq(String a, String b) {
    if (a == b) return true;
    final n = a.length < b.length ? a.length : b.length;
    if (n >= 6) return _edit(a, b) <= 1;
    return false;
  }

  static double similarity(String mention, String productName) {
    String dropGeneric(String t) {
      final kept = t.split(' ').where((w) => !_generic.contains(w)).join(' ');
      return kept.isEmpty ? t : kept;
    }

    var a = dropGeneric(_canon(mention));
    final stripped = a.split(' ').where((t) => !RegExp(r'^\d+$').hasMatch(t)).join(' ');
    if (stripped.isNotEmpty) a = stripped;
    final b = dropGeneric(_canon(productName));
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final ta = a.split(' ');
    final tb = b.split(' ');
    var hitA = 0;
    for (final x in ta) {
      if (tb.any((y) => _tokenEq(x, y))) hitA++;
    }
    var hitB = 0;
    for (final y in tb) {
      if (ta.any((x) => _tokenEq(x, y))) hitB++;
    }
    final recallA = hitA / ta.length; // how much of the mention is explained
    final recallB = hitB / tb.length; // how much of the product is mentioned
    var score = 0.0;
    if (recallA == 1 && recallB == 1) {
      score = 0.97;
    } else if (recallA == 1) {
      // Every word the customer wrote is in the product name.
      score = 0.78 + 0.18 * recallB;
    } else if (recallB == 1) {
      // The whole product name appears inside a longer mention.
      score = 0.74 + 0.18 * recallA;
    } else {
      score = 0.6 * (recallA * 0.6 + recallB * 0.4);
    }
    // A single short token matching is weak evidence.
    if (ta.length == 1 && ta.first.length <= 3) score *= 0.6;
    return score.clamp(0.0, 1.0);
  }

  static ({CatalogProduct? product, double score, List<({CatalogProduct product, double score})> ranked})
      _bestMatch(String mention, List<CatalogProduct> catalog) {
    final ranked = [
      for (final p in catalog) (product: p, score: similarity(mention, p.name)),
    ]..sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : a.product.id.compareTo(b.product.id);
      });
    if (ranked.isEmpty) return (product: null, score: 0, ranked: ranked);
    return (product: ranked.first.product, score: ranked.first.score, ranked: ranked);
  }
}
