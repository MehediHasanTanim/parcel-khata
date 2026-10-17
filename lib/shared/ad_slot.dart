import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/ads/ads_policy.dart';
import 'package:parcel_khata/core/ads/ads_service.dart';
import 'package:parcel_khata/shared/ads_providers.dart';

/// A banner slot. Renders nothing (zero height) unless ads are enabled,
/// consented and an ad actually loaded, so the app is identical when
/// offline, ad-free or in a build without ads. Only use it on screens that
/// are allowed to show ads (`AdsPolicy`, enforced by a source-scanning test).
class AdSlot extends ConsumerStatefulWidget {
  const AdSlot(this.placement, {super.key});

  final AdPlacement placement;

  @override
  ConsumerState<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends ConsumerState<AdSlot> {
  AdBannerHandle? _handle;
  Widget? _ad;
  bool _started = false;

  @override
  void dispose() {
    _handle?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final handle = ref.read(adsServiceProvider).createBanner(widget.placement);
    _handle = handle;
    final w = await handle.load();
    if (mounted) setState(() => _ad = w);
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(adsReadyProvider).value ?? false;
    if (ready && !_started) {
      _started = true;
      // After the frame: never touch the SDK while building.
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final ad = _ad;
    if (!ready || ad == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Advertisement',
      child: SafeArea(
        top: false,
        child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: ad)),
      ),
    );
  }
}
