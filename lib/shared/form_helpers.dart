import 'package:flutter/material.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/l10n/l10n.dart';

/// Taka amount form field. Empty is allowed unless [required].
class MoneyFormField extends StatelessWidget {
  const MoneyFormField({
    required this.controller,
    required this.label,
    this.required = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: '৳ '),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return required ? context.l10n.errInvalidAmount : null;
        final m = Money.tryParse(t);
        return (m == null || m.isNegative) ? context.l10n.errInvalidAmount : null;
      },
    );
  }
}

Money? parseMoneyOrNull(String s) => s.trim().isEmpty ? null : Money.tryParse(s);

String? blankToNull(String s) => s.trim().isEmpty ? null : s.trim();

int? parseIntOrNull(String s) => int.tryParse(s.trim());

Widget gap([double h = 12]) => SizedBox(height: h);
