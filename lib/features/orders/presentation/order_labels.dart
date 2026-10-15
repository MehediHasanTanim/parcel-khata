import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/status_chip.dart';

String statusLabel(AppLocalizations l, OrderStatus s) => switch (s) {
      OrderStatus.draft => l.statusDraft,
      OrderStatus.confirmed => l.statusConfirmed,
      OrderStatus.packed => l.statusPacked,
      OrderStatus.handedToCourier => l.statusHanded,
      OrderStatus.inTransit => l.statusInTransit,
      OrderStatus.delivered => l.statusDelivered,
      OrderStatus.deliveryFailed => l.statusFailed,
      OrderStatus.returnInTransit => l.statusReturnInTransit,
      OrderStatus.returned => l.statusReturned,
      OrderStatus.cancelled => l.statusCancelled,
    };

IconData statusIcon(OrderStatus s) => switch (s) {
      OrderStatus.draft => Icons.edit_note,
      OrderStatus.confirmed => Icons.check_circle_outline,
      OrderStatus.packed => Icons.inventory_2_outlined,
      OrderStatus.handedToCourier => Icons.local_shipping_outlined,
      OrderStatus.inTransit => Icons.directions_bike_outlined,
      OrderStatus.delivered => Icons.done_all,
      OrderStatus.deliveryFailed => Icons.error_outline,
      OrderStatus.returnInTransit => Icons.undo,
      OrderStatus.returned => Icons.assignment_return_outlined,
      OrderStatus.cancelled => Icons.cancel_outlined,
    };

StatusTone statusTone(OrderStatus s) => switch (s) {
      OrderStatus.delivered => StatusTone.success,
      OrderStatus.deliveryFailed ||
      OrderStatus.returnInTransit ||
      OrderStatus.returned ||
      OrderStatus.cancelled =>
        StatusTone.danger,
      OrderStatus.handedToCourier || OrderStatus.inTransit => StatusTone.warning,
      _ => StatusTone.neutral,
    };

String codLabel(AppLocalizations l, CodStatus s) => switch (s) {
      CodStatus.notApplicable => l.codNotApplicable,
      CodStatus.pendingCollection => l.codPending,
      CodStatus.collectedByCourier => l.codCollected,
      CodStatus.settled => l.codSettled,
      CodStatus.partiallySettled => l.codPartial,
      CodStatus.notCollected => l.codNotCollected,
      CodStatus.disputed => l.codDisputed,
    };

StatusTone codTone(CodStatus s) => switch (s) {
      CodStatus.settled => StatusTone.success,
      CodStatus.collectedByCourier || CodStatus.partiallySettled => StatusTone.warning,
      CodStatus.notCollected || CodStatus.disputed => StatusTone.danger,
      _ => StatusTone.neutral,
    };

String channelLabel(AppLocalizations l, Channel c) => switch (c) {
      Channel.facebook => l.channelFacebook,
      Channel.whatsapp => l.channelWhatsapp,
      Channel.instagram => l.channelInstagram,
      Channel.phone => l.channelPhone,
      Channel.walkIn => l.channelWalkIn,
      Channel.other => l.channelOther,
    };

String paymentLabel(AppLocalizations l, PaymentType p) => switch (p) {
      PaymentType.cod => l.payCod,
      PaymentType.prepaid => l.payPrepaid,
      PaymentType.partialAdvance => l.payPartial,
    };

String chargeLabel(AppLocalizations l, String type) => switch (type) {
      'delivery_fee' => l.chargeDeliveryFee,
      'cod_fee' => l.chargeCodFee,
      'return_fee' => l.chargeReturnFee,
      'packaging' => l.chargePackaging,
      'write_off' => l.writtenOffAmount,
      'ad_allocation' => l.costAdAllocation,
      _ => l.chargeOther,
    };

String zoneLabel(AppLocalizations l, String z) => switch (z) {
      'inside_dhaka' => l.zoneInsideDhaka,
      'dhaka_suburb' => l.zoneDhakaSuburb,
      'outside_dhaka' => l.zoneOutsideDhaka,
      _ => l.zoneCustom,
    };

String formatDateTime(DateTime d) => DateFormat('dd/MM/yyyy, h:mm a').format(d.toLocal());
String formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d.toLocal());
