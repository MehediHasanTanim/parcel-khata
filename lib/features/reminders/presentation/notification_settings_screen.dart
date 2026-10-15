import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/reminders/application/digest_service.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

String _t(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

String _kindLabel(AppLocalizations l, AttentionKind k) => switch (k) {
      AttentionKind.staleHandedOver => l.attStale(3).replaceAll(RegExp(r'\d+'), '…'),
      AttentionKind.overdueCod => l.codTitle,
      AttentionKind.returnTooLong => l.returnsTitle,
      AttentionKind.oldDraft => l.drafts,
      AttentionKind.dispute => l.codDisputed,
      AttentionKind.toDispatch => l.tileToDispatch,
      AttentionKind.backupDue => l.backupNow,
    };

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(shopSettingsProvider).value ?? const ShopSettings();
    final repo = ref.read(settingsRepositoryProvider);

    Future<void> apply(ShopSettings Function(ShopSettings) f) async {
      await repo.save(f(await repo.read()));
      await ref
          .read(digestServiceProvider)
          .refresh(Locale(Localizations.localeOf(context).languageCode));
    }

    Future<void> pick(int current, ShopSettings Function(ShopSettings, int) set) async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      );
      if (t != null) await apply((x) => set(x, t.hour * 60 + t.minute));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.digestSettings)),
      body: ListView(children: [
        SwitchListTile(
          title: Text(l.digestEnable),
          value: s.digestEnabled,
          onChanged: (v) async {
            if (v) {
              await ref.read(digestNotifierProvider).requestPermission();
              // Android only: iOS has no per-app battery killers to explain.
              if (Platform.isAndroid && !s.batteryGuideShown && context.mounted) {
                await _showBatteryGuide(context);
                await repo.save((await repo.read()).copyWith(batteryGuideShown: true));
              }
            }
            await apply((x) => x.copyWith(digestEnabled: v));
          },
        ),
        ListTile(
          enabled: s.digestEnabled,
          title: Text(l.digestTime),
          trailing: Text(_t(s.digestMinute)),
          onTap: () => pick(s.digestMinute, (x, m) => x.copyWith(digestMinute: m)),
        ),
        SwitchListTile(
          title: Text(l.quietHours),
          value: s.quietEnabled,
          onChanged: (v) => apply((x) => x.copyWith(quietEnabled: v)),
        ),
        ListTile(
          enabled: s.quietEnabled,
          title: Text(l.quietFrom),
          trailing: Text(_t(s.quietStartMinute)),
          onTap: () => pick(s.quietStartMinute, (x, m) => x.copyWith(quietStartMinute: m)),
        ),
        ListTile(
          enabled: s.quietEnabled,
          title: Text(l.quietTo),
          trailing: Text(_t(s.quietEndMinute)),
          onTap: () => pick(s.quietEndMinute, (x, m) => x.copyWith(quietEndMinute: m)),
        ),
        const Divider(),
        for (final k in AttentionKind.values)
          CheckboxListTile(
            title: Text(_kindLabel(l, k)),
            value: s.digestKinds.contains(k.name),
            onChanged: (v) {
              final next = [...s.digestKinds];
              v == true ? next.add(k.name) : next.remove(k.name);
              apply((x) => x.copyWith(digestKinds: next));
            },
          ),
        if (Platform.isAndroid)
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: Text(l.batteryGuideTitle),
            onTap: () => _showBatteryGuide(context),
          ),
      ]),
    );
  }

  Future<void> _showBatteryGuide(BuildContext context) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.battery_alert),
        title: Text(l.batteryGuideTitle),
        content: Text(l.batteryGuideBody),
        actions: [
          TextButton(
            onPressed: () => launchUrl(
              Uri.https('dontkillmyapp.com'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(l.batteryGuideOpen),
          ),
          FilledButton(onPressed: () => Navigator.pop(d), child: Text(l.gotIt)),
        ],
      ),
    );
  }
}
