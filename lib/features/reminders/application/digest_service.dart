import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/reminders/application/attention_service.dart';
import 'package:parcel_khata/features/reminders/domain/digest.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Shows the digest text in the notification shade. Kept behind an interface
/// so the scheduling rules can be tested without the plugin.
abstract class DigestNotifier {
  Future<void> init();
  Future<bool> requestPermission();
  Future<void> schedule({required DateTime at, required String title, required String body});
  Future<void> cancel();
}

class LocalDigestNotifier implements DigestNotifier {
  LocalDigestNotifier() : _plugin = FlutterLocalNotificationsPlugin();

  static const _id = 7001;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // v1 targets Bangladesh; the shop timezone setting defaults to Asia/Dhaka.
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id: _id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'digest',
          'Daily digest',
          channelDescription: 'Daily summary of parcels and COD needing attention',
          importance: Importance.defaultImportance,
        ),
      ),
      // Inexact is enough for a daily digest and needs no special permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel() async {
    await init();
    await _plugin.cancel(id: _id);
  }
}

/// Builds the digest text and (re)schedules the next notification. The queue
/// in the app stays the source of truth; this is a convenience on top.
class DigestService {
  DigestService(this._attention, this._settings, this._clock, this._notifier);

  final AttentionService _attention;
  final SettingsRepository _settings;
  final Clock _clock;
  final DigestNotifier _notifier;

  static String buildBody(AppLocalizations l, DigestCounts c) {
    final parts = <String>[
      if (c.stale > 0) l.digestStale(c.stale),
      if (c.overdueCod > 0) l.digestOverdue(Money(c.overdueCodPoisha).format(), c.overdueCod),
      if (c.returns > 0) l.digestReturns(c.returns),
      if (c.disputes > 0) l.digestDisputes(c.disputes),
      if (c.toDispatch > 0) l.digestDispatch(c.toDispatch),
      if (c.drafts > 0) l.digestDrafts(c.drafts),
      if (c.backup > 0) l.digestBackup,
    ];
    return parts.join(' · ');
  }

  /// Call on app start and after data changes; cheap and idempotent.
  Future<void> refresh(Locale locale) async {
    final s = await _settings.read();
    if (!s.digestEnabled) {
      await _notifier.cancel();
      return;
    }
    final enabled = {
      for (final k in AttentionKind.values)
        if (s.digestKinds.contains(k.name)) k,
    };
    final counts = DigestBuilder.count(await _attention.load(), enabled: enabled);
    if (counts.isEmpty) {
      await _notifier.cancel();
      return;
    }
    final quiet = s.quietEnabled
        ? QuietHours(startMinute: s.quietStartMinute, endMinute: s.quietEndMinute)
        : null;
    final at = DigestBuilder.nextFireTime(_clock.now(), s.digestMinute, quiet: quiet);
    final l = lookupAppLocalizations(Locale(s.languageCode));
    await _notifier.cancel();
    await _notifier.schedule(at: at, title: l.digestTitle, body: buildBody(l, counts));
  }
}

final digestNotifierProvider = Provider<DigestNotifier>((ref) => LocalDigestNotifier());

final digestServiceProvider = Provider<DigestService>((ref) => DigestService(
      ref.watch(attentionServiceProvider),
      ref.watch(settingsRepositoryProvider),
      ref.watch(clockProvider),
      ref.watch(digestNotifierProvider),
    ));
