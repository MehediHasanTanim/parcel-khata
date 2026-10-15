import 'package:flutter/material.dart';
import 'package:parcel_khata/app/theme.dart';

enum StatusTone { success, warning, danger, neutral }

/// Always shows icon + text so meaning never depends on color alone.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.icon, this.tone = StatusTone.neutral, super.key});

  final String label;
  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<StatusColors>()!;
    final color = switch (tone) {
      StatusTone.success => c.success,
      StatusTone.warning => c.warning,
      StatusTone.danger => c.danger,
      StatusTone.neutral => c.neutral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
