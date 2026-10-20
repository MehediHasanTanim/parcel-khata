import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/security/application/app_lock.dart';
import 'package:parcel_khata/features/security/application/erase_service.dart';
import 'package:parcel_khata/features/security/domain/pin_security.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  Future<String?> _askPin(BuildContext context, String title) async {
    final l = context.l10n;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.confirm)),
        ],
      ),
    );
    final v = c.text;
    c.dispose();
    return ok == true ? v : null;
  }

  /// Choose + confirm a new PIN; null when cancelled or mismatched.
  Future<String?> _newPin(BuildContext context) async {
    final l = context.l10n;
    final first = await _askPin(context, l.lockSetPin);
    if (first == null || !context.mounted) return null;
    if (!PinHasher.isValidPin(first)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.lockPinInvalid)));
      return null;
    }
    final again = await _askPin(context, l.lockConfirmPin);
    if (again == null || !context.mounted) return null;
    if (again != first) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.lockPinMismatch)));
      return null;
    }
    return first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lock = ref.watch(appLockProvider).value;
    final notifier = ref.read(appLockProvider.notifier);
    final s = ref.watch(shopSettingsProvider).value ?? const ShopSettings();
    final repo = ref.read(settingsRepositoryProvider);
    final enabled = lock != null && lock.phase != LockPhase.disabled;

    Future<void> apply(ShopSettings Function(ShopSettings) f) async =>
        repo.save(f(await repo.read()));

    return Scaffold(
      appBar: AppBar(title: Text(l.secTitle)),
      body: ListView(children: [
        SwitchListTile(
          title: Text(l.secEnableLock),
          value: enabled,
          onChanged: (v) async {
            if (v) {
              final pin = await _newPin(context);
              if (pin != null) await notifier.setPin(pin);
            } else {
              final pin = await _askPin(context, l.lockEnterPin);
              if (pin == null) return;
              final ok = await notifier.disable(pin);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.lockWrongPin)));
              }
            }
          },
        ),
        if (enabled) ...[
          ListTile(
            title: Text(l.secChangePin),
            onTap: () async {
              final old = await _askPin(context, l.lockEnterPin);
              if (old == null) return;
              if (await notifier.verifyPin(old) != UnlockResult.ok) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l.lockWrongPin)));
                }
                return;
              }
              if (!context.mounted) return;
              final pin = await _newPin(context);
              if (pin != null) await notifier.setPin(pin);
            },
          ),
          FutureBuilder<bool>(
            future: notifier.biometricAvailable(),
            builder: (_, snap) => SwitchListTile(
              title: Text(l.secBiometric),
              value: lock.biometric,
              onChanged: snap.data == true ? (v) => notifier.setBiometric(enabled: v) : null,
            ),
          ),
          ListTile(
            title: Text(l.secTimeout),
            trailing: DropdownButton<int>(
 icon: const Icon(LucideIcons300.chevronDown),
              value: const [0, 60, 300].contains(lock.timeoutSeconds) ? lock.timeoutSeconds : 60,
              items: [
                DropdownMenuItem(value: 0, child: Text(l.secTimeoutNow)),
                DropdownMenuItem(value: 60, child: Text(l.secTimeout1m)),
                DropdownMenuItem(value: 300, child: Text(l.secTimeout5m)),
              ],
              onChanged: (v) => notifier.setTimeout(v ?? 60),
            ),
          ),
        ],
        const Divider(),
        SwitchListTile(
          title: Text(l.secHideAmounts),
          value: s.hideAmountsOnDashboard,
          onChanged: (v) => apply((x) => x.copyWith(hideAmountsOnDashboard: v)),
        ),
        SwitchListTile(
          title: Text(l.secHideProfit),
          value: s.hideProfitInLists,
          onChanged: (v) => apply((x) => x.copyWith(hideProfitInLists: v)),
        ),
        const Divider(),
        SwitchListTile(
          title: Text(l.secTelemetry),
          subtitle: Text(l.secTelemetryHelp),
          value: s.telemetryConsent ?? false,
          onChanged: (v) => apply((x) => x.copyWith(telemetryConsent: v)),
        ),
        const Divider(),
        ListTile(
          leading: Icon(LucideIcons300.trash, color: Theme.of(context).colorScheme.error),
          title: Text(l.secErase,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () => _erase(context, ref),
        ),
      ]),
    );
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          icon: const Icon(LucideIcons300.triangleAlert),
          title: Text(l.secErase),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.secEraseWarn),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              decoration: InputDecoration(labelText: l.secEraseType),
              onChanged: (_) => setState(() {}),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: c.text.trim() == l.secEraseWord ? () => Navigator.pop(d, true) : null,
              child: Text(l.secErase),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    if (ok != true) return;
    await ref.read(eraseServiceProvider).eraseAll();
    // Reopen a fresh database and re-read the (now removed) lock secrets.
    ref
      ..invalidate(databaseProvider)
      ..invalidate(appLockProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.secErased)));
    }
  }
}
