import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parcel_khata/core/money/money.dart';

/// Taka amount input with a numeric keypad. Emits [Money] (poisha) on change.
class AmountField extends StatefulWidget {
  const AmountField({
    required this.label,
    required this.onChanged,
    this.initial,
    super.key,
  });

  final String label;
  final Money? initial;
  final ValueChanged<Money?> onChanged;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.format(symbol: false),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.,]'))],
      decoration: InputDecoration(labelText: widget.label, prefixText: '৳ '),
      style: Theme.of(context).textTheme.titleLarge,
      onChanged: (v) => widget.onChanged(Money.tryParse(v)),
    );
  }
}
