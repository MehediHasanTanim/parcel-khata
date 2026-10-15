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
  });

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
      );
    } on FormatException {
      return const ShopSettings();
    }
  }
}
