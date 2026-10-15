import 'package:flutter/material.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';

class CodScreen extends StatelessWidget {
  const CodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.codTitle)),
      body: EmptyState(icon: Icons.construction, title: l.comingSoon),
    );
  }
}
