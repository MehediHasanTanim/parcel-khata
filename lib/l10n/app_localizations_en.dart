// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Parcel Khata';

  @override
  String get navHome => 'Home';

  @override
  String get navOrders => 'Orders';

  @override
  String get navNewOrder => 'New order';

  @override
  String get navCod => 'COD';

  @override
  String get navMore => 'More';

  @override
  String get homeTitle => 'Home';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get newOrderTitle => 'New order';

  @override
  String get codTitle => 'COD';

  @override
  String get moreTitle => 'More';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageBangla => 'বাংলা';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get undo => 'Undo';

  @override
  String get emptyDefaultTitle => 'Nothing here yet';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusFailed => 'Failed';

  @override
  String get amountLabel => 'Amount';

  @override
  String get debugMenu => 'Debug menu';

  @override
  String get customers => 'Customers';

  @override
  String get customerNew => 'New customer';

  @override
  String get customerEdit => 'Edit customer';

  @override
  String get searchCustomers => 'Search by name or phone';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldPhone => 'Mobile number';

  @override
  String get fieldPhoneAlt => 'Alternate number';

  @override
  String get fieldWhatsapp => 'WhatsApp number';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get addresses => 'Addresses';

  @override
  String get addAddress => 'Add address';

  @override
  String get addressLabel => 'Label (Home, Office)';

  @override
  String get addressText => 'Full address';

  @override
  String get district => 'District';

  @override
  String get area => 'Area / Thana';

  @override
  String get defaultAddress => 'Default';

  @override
  String get save => 'Save';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Restore';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Remove';

  @override
  String get duplicatePhone => 'A customer with this number already exists';

  @override
  String get useExisting => 'Use existing customer';

  @override
  String get errNameRequired => 'Name is required';

  @override
  String get errInvalidPhone => 'Enter a valid mobile number';

  @override
  String get errInvalidAmount => 'Enter a valid amount';

  @override
  String get archivedBadge => 'Archived';

  @override
  String get products => 'Products';

  @override
  String get productNew => 'New product';

  @override
  String get productEdit => 'Edit product';

  @override
  String get searchProducts => 'Search products';

  @override
  String get sellPrice => 'Selling price';

  @override
  String get costPrice => 'Cost price';

  @override
  String get costMissing => 'Cost missing';

  @override
  String get sku => 'SKU / code';

  @override
  String get variants => 'Variants';

  @override
  String get addVariant => 'Add variant';

  @override
  String get variantLabel => 'Size / color';

  @override
  String get activeLabel => 'Active';

  @override
  String get stockQty => 'Stock quantity';

  @override
  String get couriers => 'Couriers';

  @override
  String get courierNew => 'New courier';

  @override
  String get courierEdit => 'Edit courier';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get trackingTemplate => 'Tracking link ({cn} = consignment no.)';

  @override
  String get trackingPreview => 'Preview';

  @override
  String get errTrackingTemplate => 'Must be an http(s) link containing {cn}';

  @override
  String get payoutCycleDays => 'Payout cycle (days)';

  @override
  String get stuckDays => 'Stuck parcel after (days)';

  @override
  String get cnPattern => 'CN pattern (optional regex)';

  @override
  String get rateCard => 'Rate card';

  @override
  String get addRule => 'Add rate';

  @override
  String get zone => 'Zone';

  @override
  String get zoneInsideDhaka => 'Inside Dhaka';

  @override
  String get zoneDhakaSuburb => 'Dhaka suburb';

  @override
  String get zoneOutsideDhaka => 'Outside Dhaka';

  @override
  String get zoneCustom => 'Custom';

  @override
  String get weightMinG => 'From (g)';

  @override
  String get weightMaxG => 'Under (g)';

  @override
  String get fee => 'Fee';

  @override
  String get codFeePercent => 'COD fee (%)';

  @override
  String get codFeeFlat => 'COD flat fee';

  @override
  String get codFeeFreeUnder => 'No COD fee under';

  @override
  String get returnFee => 'Return fee';

  @override
  String get returnNone => 'None';

  @override
  String get returnFlat => 'Flat';

  @override
  String get returnPercent => '% of delivery fee';

  @override
  String get returnValue => 'Return fee value';

  @override
  String get settings => 'Settings';

  @override
  String get businessProfile => 'Business profile';

  @override
  String get businessName => 'Business name';

  @override
  String get businessPhone => 'Business phone';

  @override
  String get orderPrefix => 'Order number prefix';

  @override
  String get orderStart => 'Starting number';

  @override
  String get defaults => 'Defaults';

  @override
  String get defaultChannel => 'Default channel';

  @override
  String get defaultDeliveryCharge => 'Default delivery charge';

  @override
  String get defaultPackaging => 'Default packaging cost';

  @override
  String get defaultCourier => 'Default courier';

  @override
  String get none => 'None';

  @override
  String get workflow => 'Workflow';

  @override
  String get packedStep => 'Use Packed step';

  @override
  String get inTransitStep => 'Use In Transit step';

  @override
  String get autoReturnFlow => 'Start return flow on failed delivery';

  @override
  String get stockTracking => 'Track stock';

  @override
  String get masterData => 'Your data';

  @override
  String get channelFacebook => 'Facebook';

  @override
  String get channelWhatsapp => 'WhatsApp';

  @override
  String get channelInstagram => 'Instagram';

  @override
  String get channelPhone => 'Phone';

  @override
  String get channelWalkIn => 'Walk-in';

  @override
  String get channelOther => 'Other';

  @override
  String get saved => 'Saved';

  @override
  String get noResults => 'No results';

  @override
  String get orderNew => 'New order';

  @override
  String get orderEdit => 'Edit order';

  @override
  String get drafts => 'Drafts';

  @override
  String get recentlyDeleted => 'Recently deleted';

  @override
  String get restore => 'Restore';

  @override
  String get deleteOrder => 'Delete order';

  @override
  String get duplicateOrder => 'Duplicate';

  @override
  String get orderDeleted => 'Order deleted';

  @override
  String get noOrders => 'No orders yet';

  @override
  String get statusAll => 'All';

  @override
  String get statusPacked => 'Packed';

  @override
  String get statusHanded => 'With courier';

  @override
  String get statusInTransit => 'In transit';

  @override
  String get statusReturnInTransit => 'Return in transit';

  @override
  String get statusReturned => 'Returned';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get codNotApplicable => 'Prepaid';

  @override
  String get codPending => 'COD pending';

  @override
  String get codCollected => 'With courier';

  @override
  String get codSettled => 'Settled';

  @override
  String get codPartial => 'Partly settled';

  @override
  String get codNotCollected => 'Not collected';

  @override
  String get codDisputed => 'Disputed';

  @override
  String get customer => 'Customer';

  @override
  String get selectCustomer => 'Select customer';

  @override
  String get addNewCustomer => 'Add new customer';

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String get chooseSavedAddress => 'Choose saved address';

  @override
  String get items => 'Items';

  @override
  String get addFromCatalog => 'From catalog';

  @override
  String get addFreeText => 'Free item';

  @override
  String get itemName => 'Item name';

  @override
  String get quantity => 'Qty';

  @override
  String get unitPrice => 'Unit price';

  @override
  String get unitCost => 'Unit cost';

  @override
  String get lineDiscount => 'Discount';

  @override
  String get saveToCatalog => 'Save to catalog';

  @override
  String get savedToCatalog => 'Saved to catalog';

  @override
  String get itemsTotal => 'Items total';

  @override
  String get orderDiscount => 'Order discount';

  @override
  String get discountPercent => 'Percent';

  @override
  String get deliveryCharge => 'Delivery charge';

  @override
  String get paymentType => 'Payment';

  @override
  String get payCod => 'COD';

  @override
  String get payPrepaid => 'Prepaid';

  @override
  String get payPartial => 'Advance + COD';

  @override
  String get advanceReceived => 'Advance received';

  @override
  String get advanceMethod => 'Method (bKash, Nagad...)';

  @override
  String get codAmount => 'COD amount';

  @override
  String get codOverriddenMark => 'Overridden';

  @override
  String get resetToCalculated => 'Reset to calculated';

  @override
  String get overrideCod => 'Override COD';

  @override
  String get courier => 'Courier';

  @override
  String get consignmentNo => 'Consignment no. (CN)';

  @override
  String get noCourier => 'Not assigned';

  @override
  String get expectedDeliveryFee => 'Expected delivery fee';

  @override
  String get expectedCodFee => 'Expected COD fee';

  @override
  String get weightGrams => 'Weight (g)';

  @override
  String get channel => 'Channel';

  @override
  String get sourceRef => 'Chat name / reference';

  @override
  String get internalNotes => 'Internal notes';

  @override
  String get saveOrder => 'Save order';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get errCustomerRequired => 'Select a customer';

  @override
  String get errItemsRequired => 'Add at least one item';

  @override
  String get errAddressRequired => 'Enter a delivery address';

  @override
  String get errCnTaken => 'This CN is already used by another order';

  @override
  String get viewConflictingOrder => 'View order';

  @override
  String get warnEditAfterHandover =>
      'Amounts changed while the courier has this parcel. The COD the courier collects may differ.';

  @override
  String get confirmEditDelivered =>
      'This order is delivered. Change its amounts anyway?';

  @override
  String get timeline => 'Timeline';

  @override
  String get charges => 'Courier & other charges';

  @override
  String get chargeDeliveryFee => 'Delivery fee';

  @override
  String get chargeCodFee => 'COD fee';

  @override
  String get chargeReturnFee => 'Return fee';

  @override
  String get chargePackaging => 'Packaging';

  @override
  String get chargeOther => 'Other';

  @override
  String get expected => 'expected';

  @override
  String get discountLabel => 'Discount';

  @override
  String get total => 'Total';

  @override
  String get advanceLabel => 'Advance';

  @override
  String get orderDate => 'Order date';

  @override
  String get filterChannel => 'Channel';

  @override
  String get filterDates => 'Dates';

  @override
  String get clearFilters => 'Clear';

  @override
  String get unsavedDraftHint => 'Leaving saves this as a draft';

  @override
  String get deletedOn => 'Deleted';

  @override
  String get restored => 'Order restored';

  @override
  String get orderCreated => 'Order created';

  @override
  String get orderUpdated => 'Order updated';

  @override
  String get change => 'Change';

  @override
  String get statusEventCreated => 'Created';

  @override
  String get fieldChanged => 'changed';

  @override
  String get actionPacked => 'Mark packed';

  @override
  String get actionHanded => 'Hand to courier';

  @override
  String get actionInTransit => 'Mark in transit';

  @override
  String get actionDelivered => 'Mark delivered';

  @override
  String get actionFailed => 'Delivery failed';

  @override
  String get actionReturnTransit => 'Return in transit';

  @override
  String get actionReturned => 'Received back';

  @override
  String get actionCancel => 'Cancel order';

  @override
  String get changeStatusTitle => 'Change status';

  @override
  String get whenLabel => 'When';

  @override
  String get reasonLabel => 'Reason';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get reasonCustomerRefused => 'Customer refused';

  @override
  String get reasonNotReachable => 'Not reachable';

  @override
  String get reasonWrongAddress => 'Wrong address';

  @override
  String get reasonCustomerCancelled => 'Customer cancelled';

  @override
  String get reasonOutOfStock => 'Out of stock';

  @override
  String get reasonCourierIssue => 'Courier issue';

  @override
  String get reasonOther => 'Other';

  @override
  String get reasonCorrection => 'Correction';

  @override
  String get correctStatus => 'Correct status';

  @override
  String get correctionNote => 'Why is this being corrected?';

  @override
  String get errCourierRequired => 'Select a courier first';

  @override
  String get errCnRequired => 'Enter the consignment number first';

  @override
  String get errReasonRequired => 'Select a reason';

  @override
  String get errFutureDate => 'Date cannot be in the future';

  @override
  String get errNotAllowed => 'This change is not allowed';

  @override
  String get errBeforeInitiated => 'Received date is before the return started';

  @override
  String get assignCourier => 'Courier & CN';

  @override
  String get markHandedOver => 'Mark as handed over';

  @override
  String get paste => 'Paste';

  @override
  String get cnPatternWarn => 'CN does not match the usual pattern';

  @override
  String get trackParcel => 'Track parcel';

  @override
  String get lastUpdatedByYou => 'Last updated by you';

  @override
  String daysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
      zero: 'today',
    );
    return '$_temp0';
  }

  @override
  String bulkSummary(int changed, int skipped) {
    return '$changed updated, $skipped skipped';
  }

  @override
  String selectedCount(int n) {
    return '$n selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get stuckParcels => 'Stuck parcels';

  @override
  String withCourierDays(int n) {
    return 'With courier $n days';
  }

  @override
  String get fastCnEntry => 'Fast CN entry';

  @override
  String get skip => 'Skip';

  @override
  String get saveNext => 'Save & next';

  @override
  String get allHaveCn => 'All orders have a CN';

  @override
  String remainingCount(int n) {
    return '$n left';
  }

  @override
  String get trackUnavailable => 'Add a tracking link to this courier first';

  @override
  String get warnDialogTitle => 'Check with the courier';

  @override
  String get ok => 'OK';
}
