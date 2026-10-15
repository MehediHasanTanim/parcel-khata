import 'package:flutter/material.dart';
import 'package:parcel_khata/l10n/l10n.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
}) async {
  final l = context.l10n;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.confirm)),
      ],
    ),
  );
  return r ?? false;
}
