import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/app/locale_provider.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/products/application/product_repository.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';

/// Shows first-run setup until it is completed.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(shopSettingsProvider);
    return s.when(
      loading: () => ColoredBox(color: Theme.of(context).colorScheme.surface),
      error: (_, __) => child,
      data: (v) => v.onboardingDone ? child : const OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  String _lang = 'bn';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  ({String name, String? tracking})? _courier;
  bool _sample = false;
  bool _telemetry = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool skip}) async {
    setState(() => _saving = true);
    final repo = ref.read(settingsRepositoryProvider);
    final l = context.l10n;
    String? courierId;
    if (!skip && _courier != null) {
      final r = await ref.read(courierRepositoryProvider).create(CourierInput(
            name: _courier!.name,
            trackingUrlTemplate: _courier!.tracking,
            codFeePercentBp: 100,
          ));
      courierId = r.valueOrNull?.id;
    }
    if (!skip && _sample) {
      final c = ref.read(customerRepositoryProvider);
      await c.create(CustomerInput(name: l.sampleCustomerA, phone: '01700000001'));
      await c.create(CustomerInput(name: l.sampleCustomerB, phone: '01700000002'));
      final p = ref.read(productRepositoryProvider);
      for (final e in [
        (l.sampleProduct1, 500, 300),
        (l.sampleProduct2, 900, 550),
        (l.sampleProduct3, 250, 120),
      ]) {
        await p.create(ProductInput(
          name: e.$1,
          sellPrice: Money.taka(e.$2),
          costPrice: Money.taka(e.$3),
        ));
      }
    }
    final cur = await repo.read();
    await repo.save(cur.copyWith(
      onboardingDone: true,
      languageCode: _lang,
      businessName: skip ? null : _name.text.trim(),
      businessPhone: skip ? null : _phone.text.trim(),
      defaultCourierId: courierId,
      telemetryConsent: skip ? false : _telemetry,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final steps = <Widget>[
      // 1 language
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.obWelcome, style: t.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l.obWelcomeSub),
        const SizedBox(height: 24),
        Text(l.obLanguage, style: t.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'bn', label: Text(l.languageBangla)),
            ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
          ],
          selected: {_lang},
          onSelectionChanged: (s) {
            setState(() => _lang = s.first);
            ref.read(localeProvider.notifier).set(Locale(s.first));
          },
        ),
      ]),
      // 2 business
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.obBusiness, style: t.textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(controller: _name, decoration: InputDecoration(labelText: l.businessName)),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: l.businessPhone),
        ),
      ]),
      // 3 courier
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.obCourier, style: t.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(l.obCourierHelp),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in kCourierPresets)
            ChoiceChip(
              label: Text(c.name),
              selected: _courier?.name == c.name,
              onSelected: (_) => setState(() => _courier = (name: c.name, tracking: c.tracking)),
            ),
        ]),
      ]),
      // 4 sample data + telemetry
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.obSample),
          subtitle: Text(l.obSampleHelp),
          value: _sample,
          onChanged: (v) => setState(() => _sample = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.obTelemetryAsk),
          subtitle: Text(l.secTelemetryHelp),
          value: _telemetry,
          onChanged: (v) => setState(() => _telemetry = v),
        ),
      ]),
    ];
    final last = _step == steps.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            LinearProgressIndicator(value: (_step + 1) / steps.length),
            const SizedBox(height: 24),
            Expanded(child: SingleChildScrollView(child: steps[_step])),
            Row(children: [
              if (_step == 0)
                TextButton(
                  onPressed: _saving ? null : () => _finish(skip: true),
                  child: Text(l.obSkip),
                )
              else
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: Text(l.backStep),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () => last ? _finish(skip: false) : setState(() => _step++),
                child: Text(last ? l.obFinish : l.obNext),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
