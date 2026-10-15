import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Bangla-capable PDF theme (Noto Sans Bengali). Fonts are fetched once and
/// cached by the printing package; falls back to the built-in font offline.
Future<pw.ThemeData?> loadPdfTheme() async {
  try {
    final base = await PdfGoogleFonts.notoSansBengaliRegular();
    final bold = await PdfGoogleFonts.notoSansBengaliBold();
    return pw.ThemeData.withFont(base: base, bold: bold);
  } on Object {
    return null;
  }
}
