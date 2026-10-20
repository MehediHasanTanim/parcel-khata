import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/security/application/app_lock.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

/// Wraps the app: covers content while locked, and while the app is in the
/// task switcher so no order data shows in screenshots/recents.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    final enabled = ref.read(appLockProvider).value?.phase != LockPhase.disabled;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (enabled) setState(() => _covered = true);
        if (state != AppLifecycleState.inactive) lock.onBackgrounded();
      case AppLifecycleState.resumed:
        lock.onResumed();
        if (_covered) setState(() => _covered = false);
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(appLockProvider);
    final locked = status.value?.phase == LockPhase.locked;
    final loading = status.isLoading;
    return Stack(children: [
      // Keep the app mounted underneath so state survives a quick lock.
      Positioned.fill(
        child: ExcludeSemantics(excluding: locked, child: widget.child),
      ),
      if (loading || locked || _covered)
        Positioned.fill(
          child: loading || (_covered && !locked)
              ? ColoredBox(color: Theme.of(context).colorScheme.surface)
              : const LockScreen(),
        ),
    ]);
  }
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _wrong = false;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Offer biometrics straight away when enabled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _bio() async {
    final s = ref.read(appLockProvider).value;
    if (s == null || !s.biometric) return;
    await ref
        .read(appLockProvider.notifier)
        .unlockWithBiometric(context.l10n.lockBiometricReason);
  }

  Future<void> _digit(String d) async {
    if (_busy) return;
    final s = ref.read(appLockProvider).value!;
    if (s.attempts.isLocked(ref.read(clockProvider).now())) return;
    setState(() {
      _wrong = false;
      if (_pin.length < 8) _pin += d;
    });
    // Submit automatically at the PIN's length; shorter entries never count
    // as failed attempts.
    if (_pin.length == s.pinLength) await _enter();
  }

  void _back() => setState(() {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      });

  Future<void> _enter() async {
    if (_pin.length < 4 || _busy) return;
    _busy = true;
    final r = await ref.read(appLockProvider.notifier).unlock(_pin);
    _busy = false;
    if (!mounted) return;
    if (r != UnlockResult.ok) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() {
        _pin = '';
        _wrong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final s = ref.watch(appLockProvider).value;
    final now = ref.watch(clockProvider).now();
    final remaining = s?.attempts.remaining(now) ?? Duration.zero;
    final lockedOut = remaining > Duration.zero;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons300.lock, size: 48, color: t.colorScheme.primary),
              const SizedBox(height: 12),
              Text(l.lockTitle, style: t.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(l.lockEnterPin),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 8; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _pin.length ? LucideIcons300.circleDot : LucideIcons300.circle,
                      size: 14,
                      semanticLabel: null,
                    ),
                  ),
              ]),
              SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    lockedOut
                        ? l.lockTryAgain(remaining.inSeconds + 1)
                        : (_wrong ? l.lockWrongPin : ''),
                    style: TextStyle(color: t.colorScheme.error),
                  ),
                ),
              ),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final d in row) _Key(label: d, onTap: lockedOut ? null : () => _digit(d)),
                ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Key(
                  icon: LucideIcons300.fingerprintPattern,
                  tooltip: l.lockUseBiometric,
                  onTap: (s?.biometric ?? false) ? _bio : null,
                ),
                _Key(label: '0', onTap: lockedOut ? null : () => _digit('0')),
                _Key(icon: LucideIcons300.delete, tooltip: l.remove, onTap: _back),
              ]),
              const SizedBox(height: 8),
              TextButton(
                onPressed: lockedOut || _pin.length < 4 ? null : _enter,
                child: Text(l.confirm),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.onTap, this.tooltip});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // 72 dp targets: comfortable one-handed use, above the 48 dp minimum.
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Semantics(
          button: true,
          label: tooltip ?? label,
          excludeSemantics: true,
          child: FilledButton.tonal(
            onPressed: onTap,
            style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
            child: icon != null
                ? Icon(icon, size: 26)
                : Text(label!, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
      ),
    );
  }
}
