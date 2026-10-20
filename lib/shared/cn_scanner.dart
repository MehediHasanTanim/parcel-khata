import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:parcel_khata/features/couriers/domain/cn_normalizer.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

/// What the scan sheet gives a camera view to report back through.
class ScannerHandle {
  ScannerHandle({required this.onCode, required this.onUnavailable});

  final void Function(String raw) onCode;

  /// Permission denied / no camera: the sheet switches to manual entry.
  final void Function() onUnavailable;
}

typedef ScannerViewBuilder = Widget Function(BuildContext context, ScannerHandle handle);

/// Swappable so widget tests can drive scans without a camera.
final scannerViewBuilderProvider = Provider<ScannerViewBuilder>(
  (ref) => (context, handle) => _CameraView(handle: handle),
);

class _CameraView extends StatefulWidget {
  const _CameraView({required this.handle});

  final ScannerHandle handle;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_done) return;
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && v.trim().isNotEmpty) {
              _done = true;
              widget.handle.onCode(v);
              return;
            }
          }
        },
        errorBuilder: (context, error) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => widget.handle.onUnavailable());
          return const SizedBox.shrink();
        },
      ),
      Positioned(
        right: 8,
        top: 8,
        child: IconButton.filledTonal(
          tooltip: context.l10n.scanTorch,
          icon: const Icon(LucideIcons300.flashlight),
          onPressed: _controller.toggleTorch,
        ),
      ),
    ]);
  }
}

/// Opens the scanner and returns the normalized consignment number, or null.
/// Camera permission is requested by the scanner on first use only. A
/// pattern mismatch warns afterwards (never blocks).
Future<String?> scanCn(
  BuildContext context,
  WidgetRef ref, {
  String? courierPattern,
}) async {
  final builder = ref.read(scannerViewBuilderProvider);
  final raw = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ScanSheet(builder: builder),
  );
  if (raw == null) return null;
  final cn = CnNormalizer.normalize(raw);
  if (cn.isEmpty) return null;
  if (context.mounted && CnNormalizer.matchesPattern(cn, courierPattern) == false) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.cnPatternWarn)));
  }
  return cn;
}

class _ScanSheet extends StatefulWidget {
  const _ScanSheet({required this.builder});

  final ScannerViewBuilder builder;

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  bool _manual = false;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.scanTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (!_manual) ...[
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: widget.builder(
                  context,
                  ScannerHandle(
                    onCode: (raw) {
                      if (mounted) Navigator.pop(context, raw);
                    },
                    onUnavailable: () {
                      if (mounted && !_manual) setState(() => _manual = true);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(l.scanHint, style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: () => setState(() => _manual = true),
              child: Text(l.scanManualField),
            ),
          ] else ...[
            Text(l.scanPermissionDenied),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              autofocus: true,
              decoration: InputDecoration(labelText: l.scanManualField),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _text.text),
                child: Text(l.scanUse),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
