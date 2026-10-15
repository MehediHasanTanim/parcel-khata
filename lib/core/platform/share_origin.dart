import 'dart:ui';

import 'package:flutter/widgets.dart';

/// iPad share sheets are popovers and need an anchor rectangle (omitting it
/// crashes). A small rect at the middle of the screen is a safe anchor for
/// call sites that have no button geometry; harmless on phones and Android.
Rect shareOrigin() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
  final v = views.first;
  final size = v.physicalSize / v.devicePixelRatio;
  return Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
}
