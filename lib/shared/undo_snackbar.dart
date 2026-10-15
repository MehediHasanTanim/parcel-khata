import 'package:flutter/material.dart';
import 'package:parcel_khata/l10n/l10n.dart';

void showUndoSnackbar(BuildContext context, String message, VoidCallback onUndo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(label: context.l10n.undo, onPressed: onUndo),
  ));
}
