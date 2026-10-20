import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/app/locale_provider.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/features/settings/domain/shop_settings.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

const _channels = ['facebook', 'whatsapp', 'instagram', 'phone', 'walk_in', 'other'];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _prefix = TextEditingController();
  final _start = TextEditingController();
  final _delivery = TextEditingController();
  final _packaging = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _prefix, _start, _delivery, _packaging]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(ShopSettings s) {
    if (_seeded) return;
    _seeded = true;
    _name.text = s.businessName;
    _phone.text = s.businessPhone;
    _prefix.text = s.orderPrefix;
    _start.text = '${s.orderStartNumber}';
    _delivery.text = '${s.defaultDeliveryChargeTaka}';
    _packaging.text = '${s.defaultPackagingCostTaka}';
  }

  Future<void> _apply(ShopSettings Function(ShopSettings) f) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.save(f(await repo.read()));
  }

  String _channelLabel(AppLocalizations l, String c) => switch (c) {
        'facebook' => l.channelFacebook,
        'whatsapp' => l.channelWhatsapp,
        'instagram' => l.channelInstagram,
        'phone' => l.channelPhone,
        'walk_in' => l.channelWalkIn,
        _ => l.channelOther,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(shopSettingsProvider);
    final couriers = ref.watch(couriersProvider).value ?? const [];
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          _seed(s);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(l.businessProfile, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l.businessName),
              onChanged: (v) => _apply((x) => x.copyWith(businessName: v)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: InputDecoration(labelText: l.businessPhone),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _apply((x) => x.copyWith(businessPhone: v)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _prefix,
                  decoration: InputDecoration(labelText: l.orderPrefix),
                  onChanged: (v) => _apply((x) => x.copyWith(orderPrefix: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _start,
                  decoration: InputDecoration(labelText: l.orderStart),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) _apply((x) => x.copyWith(orderStartNumber: n));
                  },
                ),
              ),
            ]),
            const Divider(height: 32),
            Text(l.defaults, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
 icon: const Icon(LucideIcons300.chevronDown),
 isExpanded: true,
              initialValue: s.defaultChannel,
              decoration: InputDecoration(labelText: l.defaultChannel),
              items: [
                for (final c in _channels)
                  DropdownMenuItem(value: c, child: Text(_channelLabel(l, c))),
              ],
              onChanged: (v) => _apply((x) => x.copyWith(defaultChannel: v)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _delivery,
                  decoration: InputDecoration(labelText: l.defaultDeliveryCharge, prefixText: '৳ '),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0) {
                      _apply((x) => x.copyWith(defaultDeliveryChargeTaka: n));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _packaging,
                  decoration: InputDecoration(labelText: l.defaultPackaging, prefixText: '৳ '),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0) {
                      _apply((x) => x.copyWith(defaultPackagingCostTaka: n));
                    }
                  },
                ),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingApplyPackaging),
              value: s.applyPackagingToNewOrders,
              onChanged: (v) => _apply((x) => x.copyWith(applyPackagingToNewOrders: v)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
 icon: const Icon(LucideIcons300.chevronDown),
 isExpanded: true,
              initialValue: couriers.any((c) => c.id == s.defaultCourierId)
                  ? s.defaultCourierId
                  : null,
              decoration: InputDecoration(labelText: l.defaultCourier),
              items: [
                DropdownMenuItem<String?>(child: Text(l.none)),
                for (final c in couriers)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => _apply((x) =>
                  v == null ? x.copyWith(clearDefaultCourier: true) : x.copyWith(defaultCourierId: v)),
            ),
            const Divider(height: 32),
            Text(l.workflow, style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              title: Text(l.packedStep),
              value: s.packedStepEnabled,
              onChanged: (v) => _apply((x) => x.copyWith(packedStepEnabled: v)),
            ),
            SwitchListTile(
              title: Text(l.inTransitStep),
              value: s.inTransitStepEnabled,
              onChanged: (v) => _apply((x) => x.copyWith(inTransitStepEnabled: v)),
            ),
            SwitchListTile(
              title: Text(l.autoReturnFlow),
              value: s.autoStartReturnFlow,
              onChanged: (v) => _apply((x) => x.copyWith(autoStartReturnFlow: v)),
            ),
            SwitchListTile(
              title: Text(l.stockTracking),
              value: s.stockTrackingEnabled,
              onChanged: (v) => _apply((x) => x.copyWith(stockTrackingEnabled: v)),
            ),
            SwitchListTile(
              title: Text(l.hideProfit),
              value: s.hideProfitInLists,
              onChanged: (v) => _apply((x) => x.copyWith(hideProfitInLists: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.returnTransitDays),
              trailing: DropdownButton<int>(
 icon: const Icon(LucideIcons300.chevronDown),
                value: s.returnInTransitDays,
                items: [
                  for (final d in const [3, 5, 7, 10, 14])
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => _apply((x) => x.copyWith(returnInTransitDays: v)),
              ),
            ),
            const Divider(height: 32),
            Text(l.riskSettings, style: Theme.of(context).textTheme.titleMedium),
            Text(l.riskPrivateNote, style: Theme.of(context).textTheme.bodySmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.riskReturnRateLabel),
              trailing: DropdownButton<int>(
 icon: const Icon(LucideIcons300.chevronDown),
                value: const [20, 30, 40, 50, 60].contains(s.riskReturnRatePercent) ? s.riskReturnRatePercent : const [20, 30, 40, 50, 60].first,
                items: [
                  for (final d in const [20, 30, 40, 50, 60])
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => _apply((x) => x.copyWith(riskReturnRatePercent: v)),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.riskMinOrdersLabel),
              trailing: DropdownButton<int>(
 icon: const Icon(LucideIcons300.chevronDown),
                value: const [2, 3, 4, 5].contains(s.riskMinOrders) ? s.riskMinOrders : const [2, 3, 4, 5].first,
                items: [
                  for (final d in const [2, 3, 4, 5])
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => _apply((x) => x.copyWith(riskMinOrders: v)),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.riskRecencyLabel),
              trailing: DropdownButton<int>(
 icon: const Icon(LucideIcons300.chevronDown),
                value: const [30, 60, 90, 180, 365].contains(s.riskRefusalRecencyDays) ? s.riskRefusalRecencyDays : const [30, 60, 90, 180, 365].first,
                items: [
                  for (final d in const [30, 60, 90, 180, 365])
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => _apply((x) => x.copyWith(riskRefusalRecencyDays: v)),
              ),
            ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.highContrast),
              subtitle: Text(l.highContrastHelp),
              value: s.highContrast,
              onChanged: (v) => _apply((x) => x.copyWith(highContrast: v)),
            ),
            // Stacked so the two segments never overflow at 320dp / 200% text.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.language),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
                    ButtonSegment(value: 'bn', label: Text(l.languageBangla)),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (sel) {
                    ref.read(localeProvider.notifier).set(Locale(sel.first));
                    _apply((x) => x.copyWith(languageCode: sel.first));
                  },
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
