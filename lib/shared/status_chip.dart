import 'package:flutter/material.dart';
import 'package:parcel_khata/app/theme.dart';

enum StatusTone { success, warning, danger, neutral, info }

Color toneColor(BuildContext context, StatusTone tone) {
  final c = Theme.of(context).extension<StatusColors>()!;
  return switch (tone) {
    StatusTone.success => c.success,
    StatusTone.warning => c.warning,
    StatusTone.danger => c.danger,
    StatusTone.neutral => c.neutral,
    StatusTone.info => c.info,
  };
}

/// Full-width status line (order detail): tinted fill, tone border, icon + text.
class StatusBanner extends StatelessWidget {
  const StatusBanner({required this.label, required this.icon, required this.tone, super.key});

  final String label;
  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ]),
    );
  }
}

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
      StatusTone.info => c.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
