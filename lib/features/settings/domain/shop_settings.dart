import 'dart:convert';

/// Typed wrapper over `shops.settings_json`, with defaults and a version.
class ShopSettings {
  const ShopSettings({
    this.version = currentVersion,
    this.businessName = '',
    this.businessPhone = '',
    this.orderPrefix = 'ORD-',
    this.orderStartNumber = 1,
    this.defaultChannel = 'facebook',
    this.defaultDeliveryChargeTaka = 0,
    this.defaultPackagingCostTaka = 0,
    this.defaultCourierId,
    this.packedStepEnabled = true,
    this.inTransitStepEnabled = true,
    this.autoStartReturnFlow = true,
    this.stockTrackingEnabled = false,
    this.languageCode = 'bn',
    this.returnInTransitDays = 7,
    this.hideProfitInLists = false,
    this.lastBackupAtMs,
    this.backupReminderDays = 7,
    this.digestEnabled = false,
    this.digestMinute = 21 * 60,
    this.quietEnabled = true,
    this.quietStartMinute = 22 * 60,
    this.quietEndMinute = 7 * 60,
    this.digestKinds = defaultDigestKinds,
    this.batteryGuideShown = false,
    this.onboardingDone = false,
    this.hideAmountsOnDashboard = false,
    this.telemetryConsent,
    this.applyPackagingToNewOrders = true,
    this.riskReturnRatePercent = 40,
    this.riskMinOrders = 3,
    this.riskRefusalRecencyDays = 90,
    this.driveEnabled = false,
    this.driveLastSuccessMs,
    this.driveLastError,
    this.adsRemoved = false,
    this.highContrast = false,
  });

  static const defaultDigestKinds = [
    'staleHandedOver',
    'overdueCod',
    'returnTooLong',
    'oldDraft',
    'dispute',
    'toDispatch',
    'backupDue',
  ];

  static const currentVersion = 1;

  final int version;
  final String businessName;
  final String businessPhone;
  final String orderPrefix;
  final int orderStartNumber;
  final String defaultChannel;
  final int defaultDeliveryChargeTaka;
  final int defaultPackagingCostTaka;
  final String? defaultCourierId;
  final bool packedStepEnabled;
  final bool inTransitStepEnabled;
  final bool autoStartReturnFlow;
  final bool stockTrackingEnabled;
  final String languageCode;

  /// A return still in transit after this many days is flagged.
  final int returnInTransitDays;

  /// Privacy: hide profit chips in order lists (e.g. phone shared with helper).
  final bool hideProfitInLists;

  /// Last successful backup (epoch ms); null = never.
  final int? lastBackupAtMs;
  final int backupReminderDays;
  final bool digestEnabled;

  /// Minutes after midnight for the daily digest (default 21:00).
  final int digestMinute;
  final bool quietEnabled;
  final int quietStartMinute;
  final int quietEndMinute;

  /// Attention kinds included in the digest (names of AttentionKind).
  final List<String> digestKinds;
  final bool batteryGuideShown;
  final bool onboardingDone;

  /// Dashboard money tiles show dots until tapped.
  final bool hideAmountsOnDashboard;

  /// Opt-in analytics/crash reports; null = never asked, treated as "no".
  final bool? telemetryConsent;

  /// Add the default packaging cost to every new order (Settings > Defaults).
  final bool applyPackagingToNewOrders;

  /// Customer risk badge thresholds (F12).
  final int riskReturnRatePercent;
  final int riskMinOrders;
  final int riskRefusalRecencyDays;

  /// Optional Google Drive (appdata) backup; the passphrase lives in the
  /// secure store, never in settings.
  final bool driveEnabled;
  final int? driveLastSuccessMs;
  final String? driveLastError;

  /// The shop paid to remove ads (set by the purchase flow). Roles/ads are
  /// inert without a store product, so this stays false until then.
  final bool adsRemoved;

  /// Display: darker status colours and solid, bordered chips.
  final bool highContrast;

  ShopSettings copyWith({
    String? businessName,
    String? businessPhone,
    String? orderPrefix,
    int? orderStartNumber,
    String? defaultChannel,
    int? defaultDeliveryChargeTaka,
    int? defaultPackagingCostTaka,
    String? defaultCourierId,
    bool clearDefaultCourier = false,
    bool? packedStepEnabled,
    bool? inTransitStepEnabled,
    bool? autoStartReturnFlow,
    bool? stockTrackingEnabled,
    String? languageCode,
    int? returnInTransitDays,
    bool? hideProfitInLists,
    int? lastBackupAtMs,
    int? backupReminderDays,
    bool? digestEnabled,
    int? digestMinute,
    bool? quietEnabled,
    int? quietStartMinute,
    int? quietEndMinute,
    List<String>? digestKinds,
    bool? batteryGuideShown,
    bool? onboardingDone,
    bool? hideAmountsOnDashboard,
    bool? telemetryConsent,
    bool? applyPackagingToNewOrders,
    int? riskReturnRatePercent,
    int? riskMinOrders,
    int? riskRefusalRecencyDays,
    bool? driveEnabled,
    int? driveLastSuccessMs,
    String? driveLastError,
    bool clearDriveError = false,
    bool clearLastBackup = false,
    bool? adsRemoved,
    bool? highContrast,
  }) =>
      ShopSettings(
        businessName: businessName ?? this.businessName,
        businessPhone: businessPhone ?? this.businessPhone,
        orderPrefix: orderPrefix ?? this.orderPrefix,
        orderStartNumber: orderStartNumber ?? this.orderStartNumber,
        defaultChannel: defaultChannel ?? this.defaultChannel,
        defaultDeliveryChargeTaka:
            defaultDeliveryChargeTaka ?? this.defaultDeliveryChargeTaka,
        defaultPackagingCostTaka:
            defaultPackagingCostTaka ?? this.defaultPackagingCostTaka,
        defaultCourierId:
            clearDefaultCourier ? null : (defaultCourierId ?? this.defaultCourierId),
        packedStepEnabled: packedStepEnabled ?? this.packedStepEnabled,
        inTransitStepEnabled: inTransitStepEnabled ?? this.inTransitStepEnabled,
        autoStartReturnFlow: autoStartReturnFlow ?? this.autoStartReturnFlow,
        stockTrackingEnabled: stockTrackingEnabled ?? this.stockTrackingEnabled,
        languageCode: languageCode ?? this.languageCode,
        returnInTransitDays: returnInTransitDays ?? this.returnInTransitDays,
        hideProfitInLists: hideProfitInLists ?? this.hideProfitInLists,
        lastBackupAtMs: clearLastBackup ? null : (lastBackupAtMs ?? this.lastBackupAtMs),
        backupReminderDays: backupReminderDays ?? this.backupReminderDays,
        digestEnabled: digestEnabled ?? this.digestEnabled,
        digestMinute: digestMinute ?? this.digestMinute,
        quietEnabled: quietEnabled ?? this.quietEnabled,
        quietStartMinute: quietStartMinute ?? this.quietStartMinute,
        quietEndMinute: quietEndMinute ?? this.quietEndMinute,
        digestKinds: digestKinds ?? this.digestKinds,
        batteryGuideShown: batteryGuideShown ?? this.batteryGuideShown,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        hideAmountsOnDashboard: hideAmountsOnDashboard ?? this.hideAmountsOnDashboard,
        telemetryConsent: telemetryConsent ?? this.telemetryConsent,
        applyPackagingToNewOrders:
            applyPackagingToNewOrders ?? this.applyPackagingToNewOrders,
        riskReturnRatePercent: riskReturnRatePercent ?? this.riskReturnRatePercent,
        riskMinOrders: riskMinOrders ?? this.riskMinOrders,
        riskRefusalRecencyDays: riskRefusalRecencyDays ?? this.riskRefusalRecencyDays,
        driveEnabled: driveEnabled ?? this.driveEnabled,
        driveLastSuccessMs: driveLastSuccessMs ?? this.driveLastSuccessMs,
        driveLastError: clearDriveError ? null : (driveLastError ?? this.driveLastError),
        adsRemoved: adsRemoved ?? this.adsRemoved,
        highContrast: highContrast ?? this.highContrast,
      );

  Map<String, Object?> toJson() => {
        'version': version,
        'businessName': businessName,
        'businessPhone': businessPhone,
        'orderPrefix': orderPrefix,
        'orderStartNumber': orderStartNumber,
        'defaultChannel': defaultChannel,
        'defaultDeliveryChargeTaka': defaultDeliveryChargeTaka,
        'defaultPackagingCostTaka': defaultPackagingCostTaka,
        'defaultCourierId': defaultCourierId,
        'packedStepEnabled': packedStepEnabled,
        'inTransitStepEnabled': inTransitStepEnabled,
        'autoStartReturnFlow': autoStartReturnFlow,
        'stockTrackingEnabled': stockTrackingEnabled,
        'languageCode': languageCode,
        'returnInTransitDays': returnInTransitDays,
        'hideProfitInLists': hideProfitInLists,
        'lastBackupAtMs': lastBackupAtMs,
        'backupReminderDays': backupReminderDays,
        'digestEnabled': digestEnabled,
        'digestMinute': digestMinute,
        'quietEnabled': quietEnabled,
        'quietStartMinute': quietStartMinute,
        'quietEndMinute': quietEndMinute,
        'digestKinds': digestKinds,
        'batteryGuideShown': batteryGuideShown,
        'onboardingDone': onboardingDone,
        'hideAmountsOnDashboard': hideAmountsOnDashboard,
        'telemetryConsent': telemetryConsent,
        'applyPackagingToNewOrders': applyPackagingToNewOrders,
        'riskReturnRatePercent': riskReturnRatePercent,
        'riskMinOrders': riskMinOrders,
        'riskRefusalRecencyDays': riskRefusalRecencyDays,
        'driveEnabled': driveEnabled,
        'driveLastSuccessMs': driveLastSuccessMs,
        'driveLastError': driveLastError,
        'adsRemoved': adsRemoved,
        'highContrast': highContrast,
      };

  String encode() => jsonEncode(toJson());

  /// Tolerant decode: unknown/missing keys fall back to defaults.
  factory ShopSettings.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ShopSettings();
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return const ShopSettings();
      const d = ShopSettings();
      return ShopSettings(
        businessName: j['businessName'] as String? ?? d.businessName,
        businessPhone: j['businessPhone'] as String? ?? d.businessPhone,
        orderPrefix: j['orderPrefix'] as String? ?? d.orderPrefix,
        orderStartNumber: j['orderStartNumber'] as int? ?? d.orderStartNumber,
        defaultChannel: j['defaultChannel'] as String? ?? d.defaultChannel,
        defaultDeliveryChargeTaka:
            j['defaultDeliveryChargeTaka'] as int? ?? d.defaultDeliveryChargeTaka,
        defaultPackagingCostTaka:
            j['defaultPackagingCostTaka'] as int? ?? d.defaultPackagingCostTaka,
        defaultCourierId: j['defaultCourierId'] as String?,
        packedStepEnabled: j['packedStepEnabled'] as bool? ?? d.packedStepEnabled,
        inTransitStepEnabled:
            j['inTransitStepEnabled'] as bool? ?? d.inTransitStepEnabled,
        autoStartReturnFlow:
            j['autoStartReturnFlow'] as bool? ?? d.autoStartReturnFlow,
        stockTrackingEnabled:
            j['stockTrackingEnabled'] as bool? ?? d.stockTrackingEnabled,
        languageCode: j['languageCode'] as String? ?? d.languageCode,
        returnInTransitDays: j['returnInTransitDays'] as int? ?? d.returnInTransitDays,
        hideProfitInLists: j['hideProfitInLists'] as bool? ?? d.hideProfitInLists,
        lastBackupAtMs: j['lastBackupAtMs'] as int?,
        backupReminderDays: j['backupReminderDays'] as int? ?? d.backupReminderDays,
        digestEnabled: j['digestEnabled'] as bool? ?? d.digestEnabled,
        digestMinute: j['digestMinute'] as int? ?? d.digestMinute,
        quietEnabled: j['quietEnabled'] as bool? ?? d.quietEnabled,
        quietStartMinute: j['quietStartMinute'] as int? ?? d.quietStartMinute,
        quietEndMinute: j['quietEndMinute'] as int? ?? d.quietEndMinute,
        digestKinds: (j['digestKinds'] as List<dynamic>?)?.cast<String>() ?? d.digestKinds,
        batteryGuideShown: j['batteryGuideShown'] as bool? ?? d.batteryGuideShown,
        onboardingDone: j['onboardingDone'] as bool? ?? d.onboardingDone,
        hideAmountsOnDashboard:
            j['hideAmountsOnDashboard'] as bool? ?? d.hideAmountsOnDashboard,
        telemetryConsent: j['telemetryConsent'] as bool?,
        applyPackagingToNewOrders:
            j['applyPackagingToNewOrders'] as bool? ?? d.applyPackagingToNewOrders,
        riskReturnRatePercent:
            j['riskReturnRatePercent'] as int? ?? d.riskReturnRatePercent,
        riskMinOrders: j['riskMinOrders'] as int? ?? d.riskMinOrders,
        riskRefusalRecencyDays:
            j['riskRefusalRecencyDays'] as int? ?? d.riskRefusalRecencyDays,
        driveEnabled: j['driveEnabled'] as bool? ?? d.driveEnabled,
        driveLastSuccessMs: j['driveLastSuccessMs'] as int?,
        driveLastError: j['driveLastError'] as String?,
        adsRemoved: j['adsRemoved'] as bool? ?? d.adsRemoved,
        highContrast: j['highContrast'] as bool? ?? d.highContrast,
      );
    } on FormatException {
      return const ShopSettings();
    }
  }
}
