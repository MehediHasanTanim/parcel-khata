import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Android share target: text shared from another app (a WhatsApp message)
/// opens the paste-order screen. The text never leaves the device.
abstract final class ShareTarget {
  static const _channel = MethodChannel('parcel_khata/share');

  static Future<void> init(GoRouter router) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) {
        _open(router, call.arguments as String);
      }
      return null;
    });
    try {
      final text = await _channel.invokeMethod<String>('getSharedText');
      if (text != null) _open(router, text);
    } on MissingPluginException {
      // Not on Android (tests, desktop): nothing to do.
    } on PlatformException {
      // Ignore: sharing is a convenience.
    }
  }

  static void _open(GoRouter router, String text) {
    if (text.trim().isEmpty) return;
    router.push('/orders/paste', extra: text);
  }
}
