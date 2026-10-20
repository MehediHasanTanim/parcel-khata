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

  @override
  String get pendingWithCourier => 'Pending with couriers';

  @override
  String get inTransitCod => 'COD in transit';

  @override
  String get settledThisMonth => 'Received this month';

  @override
  String get recordPayout => 'Record payout';

  @override
  String get ageingTitle => 'COD ageing';

  @override
  String get payoutsHistory => 'Payouts';

  @override
  String get overdueLabel => 'Overdue';

  @override
  String ordersCountN(int n) {
    return '$n orders';
  }

  @override
  String oldestDays(int n) {
    return 'Oldest: $n days';
  }

  @override
  String get ledgerTitle => 'COD ledger';

  @override
  String get expectedCod => 'Expected COD';

  @override
  String get collectedAmount => 'Collected by courier';

  @override
  String get deductionsLabel => 'Courier deductions';

  @override
  String get netReceivable => 'Net receivable';

  @override
  String get settledAmount => 'Received';

  @override
  String get writtenOffAmount => 'Written off';

  @override
  String get outstandingLabel => 'Outstanding';

  @override
  String get recordCollected => 'Record collected amount';

  @override
  String get collectedReason => 'Reason for the difference';

  @override
  String get enterActual => 'Enter actual fee';

  @override
  String get actualFee => 'Actual';

  @override
  String get markDispute => 'Mark as disputed';

  @override
  String get resolveDispute => 'Resolve dispute';

  @override
  String get disputeNote => 'Note';

  @override
  String get disputedOrders => 'Disputed orders';

  @override
  String get payoutNewTitle => 'Record payout';

  @override
  String get totalReceived => 'Total received';

  @override
  String get payMethod => 'Method';

  @override
  String get methodBank => 'Bank';

  @override
  String get methodBkash => 'bKash';

  @override
  String get methodNagad => 'Nagad';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodOther => 'Other';

  @override
  String get referenceNo => 'Reference no.';

  @override
  String get paidOn => 'Paid on';

  @override
  String get nextStep => 'Next';

  @override
  String get backStep => 'Back';

  @override
  String get expectedLabel => 'Expected';

  @override
  String get receivedLabel => 'Received';

  @override
  String get differenceLabel => 'Difference';

  @override
  String get shortfallLabel => 'Shortfall';

  @override
  String get surplusLabel => 'Surplus';

  @override
  String get autoAllocate => 'Auto-allocate (oldest first)';

  @override
  String get shortfallHandling => 'How to handle the shortfall?';

  @override
  String get handleAllocate => 'Leave the balance outstanding';

  @override
  String get handleDispute => 'Mark unpaid orders as disputed';

  @override
  String get handleWriteOff => 'Write off (accept the loss)';

  @override
  String get allowOverpayment => 'Allow overpayment';

  @override
  String get confirmPayout => 'Save payout';

  @override
  String get payoutSaved => 'Payout saved';

  @override
  String get reversePayout => 'Reverse payout';

  @override
  String get reverseReason => 'Reason for reversal';

  @override
  String get payoutReversed => 'Payout reversed';

  @override
  String get noPayableOrders => 'Nothing is owed by this courier';

  @override
  String get errAllocationMismatch =>
      'Allocated amounts must equal the cash received';

  @override
  String get errExceedsOutstanding =>
      'An amount is more than the balance owed on an order';

  @override
  String get errShortfallPolicy => 'Choose how to handle the shortfall';

  @override
  String get errNoOrdersSelected => 'Select at least one order';

  @override
  String get errTotalPositive => 'Enter the total received';

  @override
  String get payoutStatusReversed => 'Reversed';

  @override
  String get allocationsTitle => 'Allocations';

  @override
  String get bucket0to3 => '0–3 days';

  @override
  String get bucket4to7 => '4–7 days';

  @override
  String get bucket8to14 => '8–14 days';

  @override
  String get bucket15plus => '15+ days';

  @override
  String get allCouriers => 'All couriers';

  @override
  String get selectOrdersTitle => 'Orders covered by this payout';

  @override
  String get amountApplied => 'Amount applied';

  @override
  String get noPayouts => 'No payouts yet';

  @override
  String get returnsTitle => 'Returns';

  @override
  String get tabInTransit => 'In transit';

  @override
  String get tabReceived => 'Received';

  @override
  String get tabNotReceived => 'Not received';

  @override
  String get startReturn => 'Start return';

  @override
  String get partialReturn => 'Partial return';

  @override
  String get fullReturn => 'Full return';

  @override
  String get returnReason => 'Return reason';

  @override
  String get returnQty => 'Qty returned';

  @override
  String get conditionResellable => 'Resellable';

  @override
  String get conditionDamaged => 'Damaged';

  @override
  String get conditionLost => 'Lost';

  @override
  String get conditionMixed => 'Mixed';

  @override
  String get lossAmountLabel => 'Loss';

  @override
  String get stockWillRestore => 'Resellable items go back to stock';

  @override
  String get returnedValueLabel => 'Value returned';

  @override
  String daysInTransitN(int n) {
    return '$n days in transit';
  }

  @override
  String get returnSaved => 'Return saved';

  @override
  String get receivedBackOn => 'Received on';

  @override
  String get errReturnStatus => 'A return is not possible in this status';

  @override
  String get errReturnNoLines => 'Select at least one item';

  @override
  String get errReturnBadQty => 'Quantity is more than ordered';

  @override
  String get errReturnUseFull => 'All items returned: use a full return';

  @override
  String get errReturnExists => 'A return already exists for this order';

  @override
  String get returnCard => 'Return';

  @override
  String get profitTitle => 'Profit';

  @override
  String get profitRevenue => 'Product revenue';

  @override
  String get profitDelivery => 'Delivery charge';

  @override
  String get profitGross => 'Collected value';

  @override
  String get costCogs => 'Product cost';

  @override
  String get costGoodsLoss => 'Damaged/lost goods';

  @override
  String get profitNet => 'Net profit';

  @override
  String get marginLabel => 'Margin';

  @override
  String get stateProvisional => 'Provisional';

  @override
  String get stateFinal => 'Final';

  @override
  String get stateIncomplete => 'Incomplete';

  @override
  String get helpProvisional =>
      'Based on expected fees or the order is not settled yet.';

  @override
  String get helpFinal => 'All amounts are known.';

  @override
  String get helpIncomplete =>
      'A product cost is missing, so profit cannot be trusted.';

  @override
  String get missingCostFor => 'Cost missing for';

  @override
  String get expectedFeesNote => 'includes expected fees';

  @override
  String get hideProfit => 'Hide profit in lists';

  @override
  String get returnTransitDays => 'Flag returns in transit after (days)';

  @override
  String get fixMissingCosts => 'Fix missing costs';

  @override
  String get noMissingCosts => 'No orders with missing costs';

  @override
  String get alsoUpdateCatalog => 'Also set this as the catalog cost';

  @override
  String get customerSummary => 'Summary';

  @override
  String get ordersTotal => 'Orders';

  @override
  String get deliveredPct => 'Delivered';

  @override
  String get returnedPct => 'Returned';

  @override
  String get lifetimeRevenue => 'Lifetime revenue';

  @override
  String get lifetimeProfit => 'Lifetime profit';

  @override
  String get lastOrderOn => 'Last order';

  @override
  String get periodToday => 'Today';

  @override
  String get periodYesterday => 'Yesterday';

  @override
  String get period7d => '7 days';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodLastMonth => 'Last month';

  @override
  String get periodCustom => 'Custom';

  @override
  String get sectionCash => 'Cash';

  @override
  String get sectionOps => 'Operations';

  @override
  String get sectionPerformance => 'Performance';

  @override
  String get tileOrders => 'Orders';

  @override
  String get tileToDispatch => 'To dispatch';

  @override
  String get tileInTransitOps => 'In transit';

  @override
  String get tileStuck => 'Stuck parcels';

  @override
  String get tileReturnsAwaiting => 'Returns awaiting';

  @override
  String get tileRevenue => 'Revenue';

  @override
  String get tileProfitFinal => 'Final profit';

  @override
  String get tileProfitProvisional => 'Provisional profit';

  @override
  String get tileMargin => 'Margin';

  @override
  String get tileDeliverySuccess => 'Delivery success';

  @override
  String get tileReturnRate => 'Return rate';

  @override
  String get tileAvgProfit => 'Avg profit / order';

  @override
  String get savedViews => 'Saved views';

  @override
  String get saveCurrentView => 'Save current filters as view';

  @override
  String get viewName => 'View name';

  @override
  String get renameView => 'Rename';

  @override
  String get deleteView => 'Delete';

  @override
  String get viewToDispatch => 'To dispatch today';

  @override
  String get viewCodPending5 => 'Delivered, COD pending > 5 days';

  @override
  String get viewReturnsNotReceived => 'Returns not received';

  @override
  String get viewLossMaking => 'Loss-making orders';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get applyFilters => 'Apply';

  @override
  String get resetFilters => 'Reset';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get sortAmount => 'Amount';

  @override
  String get sortProfit => 'Profit';

  @override
  String get sortDispatch => 'Longest with courier';

  @override
  String get searchOrders => 'Search order, name, phone, CN, product';

  @override
  String get filterCodStatus => 'COD status';

  @override
  String get filterProfit => 'Profit';

  @override
  String get profitOnly => 'Profit';

  @override
  String get lossOnly => 'Loss';

  @override
  String get hasReturnLabel => 'Has return';

  @override
  String get amountMin => 'Min amount';

  @override
  String get amountMax => 'Max amount';

  @override
  String get tagLabel => 'Tag';

  @override
  String get areaLabel => 'Area';

  @override
  String get dispatchDates => 'Dispatched between';

  @override
  String get deliveredDates => 'Delivered between';

  @override
  String get orderDates => 'Ordered between';

  @override
  String ordersCountHeader(int n) {
    return '$n orders';
  }

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportDaily => 'Daily summary';

  @override
  String get reportCourier => 'Courier performance';

  @override
  String get reportProfit => 'Profit report';

  @override
  String get reportReturns => 'Returns report';

  @override
  String get groupDay => 'By day';

  @override
  String get groupCourier => 'By courier';

  @override
  String get groupChannel => 'By channel';

  @override
  String get groupCustomer => 'By customer';

  @override
  String get groupProduct => 'By product';

  @override
  String get groupArea => 'By area';

  @override
  String get colOrders => 'Orders';

  @override
  String get colRevenue => 'Revenue';

  @override
  String get colProfit => 'Profit';

  @override
  String get colMargin => 'Margin';

  @override
  String get colDelivered => 'Delivered';

  @override
  String get colReturned => 'Returned';

  @override
  String get colUnits => 'Units';

  @override
  String get colFees => 'Fees';

  @override
  String get colAvgDays => 'Avg days';

  @override
  String get colPayoutLag => 'Payout lag';

  @override
  String get colShortfall => 'Shortfall';

  @override
  String get colCreated => 'Created';

  @override
  String get colDispatched => 'Dispatched';

  @override
  String get colCollected => 'COD collected';

  @override
  String get colFailed => 'Failed';

  @override
  String get colName => 'Name';

  @override
  String get bestOrders => 'Best orders';

  @override
  String get worstOrders => 'Worst orders';

  @override
  String get byReason => 'By reason';

  @override
  String get payoutsReceivedLabel => 'Payouts received';

  @override
  String get lossTotal => 'Total loss';

  @override
  String incompleteExcluded(int n) {
    return '$n incomplete orders are excluded from margins';
  }

  @override
  String get noData => 'No data for this period';

  @override
  String get attentionTitle => 'Needs attention';

  @override
  String get attentionEmpty => 'All caught up';

  @override
  String attStale(int n) {
    return 'No update for $n days. Delivered?';
  }

  @override
  String attOverdueCod(int n) {
    return 'COD overdue by $n days';
  }

  @override
  String attReturn(int n) {
    return 'Return in transit $n days';
  }

  @override
  String get attDraft => 'Draft older than a day';

  @override
  String get attDispute => 'Disputed settlement';

  @override
  String get attDispatch => 'Waiting to be dispatched';

  @override
  String attBackup(int n) {
    return 'No backup for $n days';
  }

  @override
  String get stillInTransit => 'Still in transit';

  @override
  String get snooze1d => 'Snooze 1 day';

  @override
  String get snooze3d => 'Snooze 3 days';

  @override
  String get dismissItem => 'Dismiss';

  @override
  String get dismissReasonLabel => 'Why dismiss?';

  @override
  String get dismissDone => 'Already handled';

  @override
  String get dismissNotNeeded => 'Not needed';

  @override
  String get callCustomer => 'Call';

  @override
  String get whatsappCustomer => 'WhatsApp';

  @override
  String get openTracking => 'Track';

  @override
  String get viewAll => 'View all';

  @override
  String get messageTemplates => 'Message templates';

  @override
  String get tplConfirmation => 'Order confirmation';

  @override
  String get tplDispatch => 'Dispatch notice';

  @override
  String get tplFollowUp => 'Delivery follow-up';

  @override
  String get tplBeAvailable => 'Please be available';

  @override
  String get tplPlaceholders =>
      'Placeholders: {name} {cn} {amount} {order} {courier} {shop}';

  @override
  String get tplReset => 'Reset to default';

  @override
  String get tplUnknown => 'Unknown placeholder';

  @override
  String get sendViaWhatsapp => 'Send via WhatsApp';

  @override
  String get digestSettings => 'Daily digest';

  @override
  String get digestEnable => 'Send a daily reminder';

  @override
  String get digestTime => 'Time';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietFrom => 'From';

  @override
  String get quietTo => 'To';

  @override
  String get digestTitle => 'Parcel Khata';

  @override
  String digestStale(int n) {
    return '$n parcels need a status update';
  }

  @override
  String digestOverdue(String amount, int n) {
    return '$amount COD overdue ($n orders)';
  }

  @override
  String digestReturns(int n) {
    return '$n returns waiting';
  }

  @override
  String digestDrafts(int n) {
    return '$n old drafts';
  }

  @override
  String digestDisputes(int n) {
    return '$n disputes';
  }

  @override
  String digestDispatch(int n) {
    return '$n to dispatch';
  }

  @override
  String get digestBackup => 'Backup due';

  @override
  String get batteryGuideTitle => 'Keep reminders working';

  @override
  String get batteryGuideBody =>
      'Some phones stop apps in the background. Allow Parcel Khata to run without battery restrictions so reminders arrive. The in-app list always works.';

  @override
  String get batteryGuideOpen => 'How to allow';

  @override
  String get gotIt => 'Got it';

  @override
  String get dataSection => 'Data';

  @override
  String get backupNow => 'Create backup';

  @override
  String get backupPassphrase => 'Passphrase (optional)';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get restoreBackup => 'Restore from backup';

  @override
  String get restorePreview => 'This backup contains';

  @override
  String get restoreReplace => 'Replace everything on this phone';

  @override
  String get restoreMerge => 'Merge: add what is missing';

  @override
  String get restoreDone => 'Restore complete';

  @override
  String get errBackupNotBackup => 'This is not a Parcel Khata backup';

  @override
  String get errBackupCorrupted => 'The backup file is damaged';

  @override
  String get errBackupChecksum => 'The backup failed its integrity check';

  @override
  String get errBackupNewer => 'This backup is from a newer app version';

  @override
  String get errBackupPass => 'Wrong passphrase';

  @override
  String get errBackupNeedPass =>
      'This backup is encrypted: enter its passphrase';

  @override
  String get lastBackup => 'Last backup';

  @override
  String get neverBackedUp => 'Never';

  @override
  String get exportData => 'Export data (CSV)';

  @override
  String get exportOrders => 'Orders';

  @override
  String get exportCustomers => 'Customers';

  @override
  String get exportProducts => 'Products';

  @override
  String get exportPayouts => 'Payouts';

  @override
  String get exportReturns => 'Returns';

  @override
  String get importCsv => 'Import from CSV';

  @override
  String get importCustomers => 'Import customers';

  @override
  String get importOrders => 'Import orders';

  @override
  String get downloadTemplate => 'Share CSV template';

  @override
  String get mapColumns => 'Match columns';

  @override
  String get notMapped => '— not used —';

  @override
  String get importPreview => 'Preview';

  @override
  String importValid(int n) {
    return '$n rows ready';
  }

  @override
  String importErrors(int n) {
    return '$n rows have problems';
  }

  @override
  String importDuplicates(int n) {
    return '$n already exist and will be skipped';
  }

  @override
  String get importSkipBad => 'Skip bad rows and import the rest';

  @override
  String get importAllOrNothing => 'Import only if every row is valid';

  @override
  String get importRun => 'Import';

  @override
  String importDone(int n) {
    return '$n imported';
  }

  @override
  String get pickFile => 'Choose file';

  @override
  String get shareOrderSlip => 'Share order slip (PDF)';

  @override
  String get shareStatement => 'Courier statement (PDF)';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get lockTitle => 'Parcel Khata is locked';

  @override
  String get lockEnterPin => 'Enter your PIN';

  @override
  String get lockWrongPin => 'Wrong PIN';

  @override
  String lockTryAgain(int s) {
    return 'Try again in $s seconds';
  }

  @override
  String get lockUseBiometric => 'Use fingerprint / face';

  @override
  String get lockBiometricReason => 'Unlock Parcel Khata';

  @override
  String get lockSetPin => 'Choose a PIN (4–8 digits)';

  @override
  String get lockConfirmPin => 'Confirm PIN';

  @override
  String get lockPinMismatch => 'PINs do not match';

  @override
  String get lockPinInvalid => 'Use 4 to 8 digits';

  @override
  String get secTitle => 'Security & privacy';

  @override
  String get secEnableLock => 'Lock the app with a PIN';

  @override
  String get secChangePin => 'Change PIN';

  @override
  String get secBiometric => 'Unlock with fingerprint / face';

  @override
  String get secTimeout => 'Lock after leaving the app';

  @override
  String get secTimeoutNow => 'Immediately';

  @override
  String get secTimeout1m => 'After 1 minute';

  @override
  String get secTimeout5m => 'After 5 minutes';

  @override
  String get secHideAmounts => 'Hide dashboard amounts until tapped';

  @override
  String get secHideProfit => 'Hide profit everywhere';

  @override
  String get secTelemetry => 'Share anonymous usage and crash reports';

  @override
  String get secTelemetryHelp =>
      'Never includes customers, phones, addresses or amounts.';

  @override
  String get secErase => 'Erase all data';

  @override
  String get secEraseWarn =>
      'This deletes every order, customer, product, payout, attachment and setting on this phone. It cannot be undone. Make a backup first.';

  @override
  String get secEraseWord => 'ERASE';

  @override
  String get secEraseType => 'Type ERASE to confirm';

  @override
  String get secErased => 'All data erased';

  @override
  String get tapToReveal => 'Tap to show';

  @override
  String get obWelcome => 'Welcome to Parcel Khata';

  @override
  String get obWelcomeSub =>
      'Track orders, courier cash and real profit in one place.';

  @override
  String get obLanguage => 'Choose your language';

  @override
  String get obBusiness => 'Your business';

  @override
  String get obCourier => 'Which courier do you use most?';

  @override
  String get obCourierHelp => 'You can add rates and more couriers later.';

  @override
  String get obSample => 'Add a few sample records';

  @override
  String get obSampleHelp =>
      'Two customers and three products so you can try an order right away.';

  @override
  String get obFinish => 'Start using the app';

  @override
  String get obNext => 'Next';

  @override
  String get obSkip => 'Skip';

  @override
  String get obTelemetryAsk =>
      'Help improve the app with anonymous usage reports';

  @override
  String get emptyOrdersHint =>
      'Orders you take on Facebook, WhatsApp or by phone appear here.';

  @override
  String get emptyOrdersCta => 'Create your first order';

  @override
  String get sampleCustomerA => 'Sample customer A';

  @override
  String get sampleCustomerB => 'Sample customer B';

  @override
  String get sampleProduct1 => 'Sample T-shirt';

  @override
  String get sampleProduct2 => 'Sample bag';

  @override
  String get sampleProduct3 => 'Sample mug';

  @override
  String get costAdAllocation => 'Ad cost';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get expenseNew => 'Add expense';

  @override
  String get expenseEdit => 'Edit expense';

  @override
  String get catAds => 'Ads';

  @override
  String get catPackaging => 'Packaging';

  @override
  String get catRent => 'Rent';

  @override
  String get catSalary => 'Salary';

  @override
  String get catMisc => 'Misc';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get expenseDate => 'Date';

  @override
  String get expenseNote => 'Note';

  @override
  String get expenseCampaign => 'Campaign';

  @override
  String get expenseRecurring => 'Repeats every month';

  @override
  String expenseRecurringAdded(int n) {
    return 'Added $n recurring expenses for this month';
  }

  @override
  String get expenseTotal => 'Total';

  @override
  String get campaignsTitle => 'Ad campaigns';

  @override
  String get campaignNew => 'New campaign';

  @override
  String get campaignEdit => 'Edit campaign';

  @override
  String get campaignName => 'Campaign name';

  @override
  String get campaignTag => 'Order tag';

  @override
  String get campaignTagHelp => 'Orders with this tag share the spend';

  @override
  String get campaignSpend => 'Ad spend';

  @override
  String get campaignStart => 'From';

  @override
  String get campaignEnd => 'To';

  @override
  String get allocByCount => 'Equal share per order';

  @override
  String get allocByRevenue => 'In proportion to sales';

  @override
  String get allocPreview => 'Preview';

  @override
  String get allocApply => 'Apply to orders';

  @override
  String get allocClear => 'Remove from orders';

  @override
  String allocApplied(int n) {
    return 'Applied to $n orders';
  }

  @override
  String get allocNeedsReapply => 'Changed since applied: apply again';

  @override
  String get allocNoOrders => 'No orders carry this tag in these dates';

  @override
  String taggedOrdersN(int n) {
    return '$n orders';
  }

  @override
  String get orderTags => 'Tags (comma separated)';

  @override
  String get reportPnl => 'Business profit (P&L)';

  @override
  String get pnlRevenue => 'Revenue';

  @override
  String get pnlCogs => 'Product cost';

  @override
  String get pnlCourierFees => 'Courier fees';

  @override
  String get pnlReturnLoss => 'Returns & write-offs';

  @override
  String get pnlPackaging => 'Packaging';

  @override
  String get pnlAds => 'Ads (on orders)';

  @override
  String get pnlOtherCosts => 'Other order costs';

  @override
  String get pnlOrderProfit => 'Order profit';

  @override
  String get pnlExpenses => 'Business expenses';

  @override
  String get pnlBusinessProfit => 'Business profit';

  @override
  String get settingApplyPackaging =>
      'Add default packaging cost to new orders';

  @override
  String get openExpenses => 'Expenses';

  @override
  String get riskReliable => 'Reliable';

  @override
  String get riskRefusedLastCod => 'Refused last COD';

  @override
  String get riskHighReturnRate => 'High return rate';

  @override
  String get riskNewCustomer => 'New customer';

  @override
  String get riskBlocklisted => 'Blocklisted';

  @override
  String get riskWhyTitle => 'Orders behind this badge';

  @override
  String get riskNoOrders => 'No orders — set manually or no history yet.';

  @override
  String get riskCaution => 'Caution note';

  @override
  String get riskCautionHint => 'Private note about this customer';

  @override
  String get riskBlocklist => 'Blocklist';

  @override
  String get riskUnblock => 'Remove from blocklist';

  @override
  String get riskBlockReason => 'Reason';

  @override
  String get riskBannerTitle => 'Risky customer — consider taking an advance.';

  @override
  String get riskTakeAdvance => 'Take advance';

  @override
  String get riskSettings => 'Customer risk flags';

  @override
  String get riskReturnRateLabel => 'High return rate from (%)';

  @override
  String get riskMinOrdersLabel => 'Minimum finished orders';

  @override
  String get riskRecencyLabel => 'Refusal counts for (days)';

  @override
  String get riskPrivateNote =>
      'Seller-private. Based only on your own orders.';

  @override
  String get riskSection => 'Risk flags';

  @override
  String get riskSave => 'Save';

  @override
  String get exchangeAction => 'Exchange';

  @override
  String get exchangeTitle => 'Exchange order';

  @override
  String get exchangeReturnedItems => 'Items coming back';

  @override
  String get exchangeReplacementItems => 'Replacement items';

  @override
  String get exchangeAddItem => 'Add item';

  @override
  String get exchangeSameItems => 'Same items, new size';

  @override
  String get exchangeWhoPays => 'Who pays the courier';

  @override
  String get exchangePayerSeller => 'I pay';

  @override
  String get exchangePayerCustomer => 'Customer pays';

  @override
  String get exchangeDeliveryCharge => 'Replacement delivery charge';

  @override
  String get exchangeReturnShipping => 'Return shipping fee';

  @override
  String get exchangeValueReturned => 'Value coming back';

  @override
  String get exchangeValueReplacement => 'Replacement value';

  @override
  String get exchangeCollect => 'Collect on delivery';

  @override
  String get exchangeRefundDue => 'Refund due to customer';

  @override
  String get exchangeShippingLoss => 'Shipping you absorb';

  @override
  String get exchangeCreate => 'Create exchange';

  @override
  String get exchangeChip => 'Exchange';

  @override
  String get exchangeLinked => 'Linked exchange';

  @override
  String get exchangeOriginalOrder => 'Original order';

  @override
  String get exchangeReplacementOrder => 'Replacement order';

  @override
  String get exchangeGroupProfit => 'Profit of both orders';

  @override
  String get exchangeNeedItems => 'Pick items to return and add a replacement.';

  @override
  String get exchangeItemName => 'Item name';

  @override
  String get exchangeQty => 'Qty';

  @override
  String get exchangeSell => 'Price';

  @override
  String get exchangeCost => 'Cost';

  @override
  String get exchangeCreated => 'Exchange created';

  @override
  String get exchangeNotDelivered => 'Only delivered orders can be exchanged.';

  @override
  String get exchangeExists => 'This order already has a return or exchange.';

  @override
  String get scanCn => 'Scan barcode';

  @override
  String get scanTitle => 'Scan consignment barcode';

  @override
  String get scanTorch => 'Torch';

  @override
  String get scanHint => 'Point the camera at the parcel barcode or QR code.';

  @override
  String get scanPermissionDenied =>
      'Camera not available. Type the number instead.';

  @override
  String get scanManualField => 'Consignment number';

  @override
  String get scanUse => 'Use';

  @override
  String get importProducts => 'Products';

  @override
  String get importOpeningBalance => 'Opening balance';

  @override
  String get importHistory => 'Import history';

  @override
  String get importUndo => 'Undo import';

  @override
  String get importUndone => 'Undone';

  @override
  String importUndoResult(int removed, int kept) {
    return '$removed removed, $kept kept (already used)';
  }

  @override
  String get importSavedMapping =>
      'Using the column mapping you saved for this file layout.';

  @override
  String importBatchCount(int n) {
    return '$n rows';
  }

  @override
  String get importOpeningHint =>
      'Columns: courier, amount, consignment_no, delivered_date. Each row becomes a delivered, unpaid parcel so payouts can be matched.';

  @override
  String get importUndoConfirm => 'Remove everything this import created?';

  @override
  String get importNone => 'No imports yet.';

  @override
  String get driveTitle => 'Google Drive backup';

  @override
  String get driveSubtitle =>
      'Encrypted copy in a private app folder. Only this app can see it.';

  @override
  String get driveEnable => 'Turn on';

  @override
  String get driveDisable => 'Turn off';

  @override
  String get driveBackupNow => 'Back up to Drive now';

  @override
  String get driveRestore => 'Restore from Drive';

  @override
  String get drivePassphraseHelp =>
      'The backup is encrypted with this passphrase before upload. Keep it safe: it cannot be recovered.';

  @override
  String get driveLastSuccess => 'Last Drive backup';

  @override
  String get driveNoBackups => 'No backups found in Drive.';

  @override
  String get driveUploaded => 'Backed up to Drive';

  @override
  String get driveErrNotSignedIn =>
      'Not signed in to Google. Open this screen and turn Drive backup on again.';

  @override
  String get driveErrPassphrase => 'Encryption passphrase is missing.';

  @override
  String get driveErrNetwork => 'No connection. Try again on Wi-Fi.';

  @override
  String get driveErrOther => 'Drive backup failed.';

  @override
  String get driveSchedule => 'Weekly, on Wi-Fi while charging';

  @override
  String get stmtImport => 'Import statement';

  @override
  String get stmtTitle => 'Courier statement';

  @override
  String get stmtPickFile => 'Choose statement file (CSV or Excel)';

  @override
  String get stmtProfile => 'Column profile';

  @override
  String get stmtEditMapping => 'Edit columns';

  @override
  String get stmtSaveProfile => 'Save profile';

  @override
  String get stmtProfileName => 'Profile name';

  @override
  String get stmtTolerance => 'Amount tolerance (৳)';

  @override
  String get stmtColumnHint =>
      'Header names in the file; use | between alternatives';

  @override
  String get stmtNoCn =>
      'Could not find the consignment column. Edit the columns and try again.';

  @override
  String get stmtAlreadyApplied =>
      'This exact file was already applied. Nothing more to do.';

  @override
  String get stmtOutMatched => 'Matched';

  @override
  String get stmtOutUnknown => 'Unknown CN';

  @override
  String get stmtOutDuplicate => 'Duplicate in file';

  @override
  String get stmtOutMismatch => 'Amount differs';

  @override
  String get stmtOutSettled => 'Already settled';

  @override
  String get stmtAll => 'All';

  @override
  String get stmtInclude => 'Include';

  @override
  String get stmtAdjust => 'Use the statement\'s collected amount';

  @override
  String get stmtAdjustReason => 'Reason for adjusting collected amounts';

  @override
  String get stmtRecorded => 'Recorded';

  @override
  String get stmtStatementSays => 'Statement';

  @override
  String get stmtPayoutTotal => 'Payout to record';

  @override
  String get stmtFeesUpdated => 'Actual fees to save';

  @override
  String get stmtApply => 'Apply statement';

  @override
  String get stmtApplied => 'Statement applied';

  @override
  String get stmtDisputePdf => 'Dispute PDF';

  @override
  String get stmtNoMismatch => 'No differences to report.';

  @override
  String get stmtIssues => 'Rows that could not be read';

  @override
  String get stmtNothingToPay =>
      'Nothing to pay on the included rows; fees and adjustments will still be saved.';

  @override
  String get stmtErrReason => 'Enter a reason for adjusting collected amounts';

  @override
  String get stmtErrIneligible =>
      'Only matched or amount-differs rows can be applied';

  @override
  String get stmtErrNothing => 'Select at least one row';

  @override
  String get pasteTitle => 'Paste order';

  @override
  String get pasteMenu => 'Paste order from chat';

  @override
  String get pasteHint => 'Paste the customer\'s message here';

  @override
  String get pasteFromClipboard => 'Paste';

  @override
  String get pasteParse => 'Read message';

  @override
  String get pasteNothing => 'Nothing recognised. Fill the order manually.';

  @override
  String get pasteCreate => 'Create order';

  @override
  String get pasteReview =>
      'Check the highlighted fields before creating the order. Nothing is saved yet.';

  @override
  String get pasteExisting => 'Existing customer found';

  @override
  String get pasteExistingNote =>
      'This customer is used as saved. Their details are not changed.';

  @override
  String get pasteNameDiffers => 'The message says a different name';

  @override
  String get pasteNewCustomer =>
      'New customer: you can review the details first';

  @override
  String get pasteLines => 'Products';

  @override
  String get pasteQty => 'Qty';

  @override
  String get pasteMatch => 'Catalog product';

  @override
  String get pasteNoMatch => 'Not in catalog (free text)';

  @override
  String get pastePriceHint => 'Price in message';

  @override
  String get pasteTotalHint => 'Message mentions a total of';

  @override
  String get pasteUseDelivery => 'Use delivery charge from message';

  @override
  String get pasteUseAdvance => 'Use advance from message';

  @override
  String get pasteCheck => 'Check';

  @override
  String get pasteSure => 'Looks right';

  @override
  String get pasteAmbiguous => 'Several products match';

  @override
  String get pasteMoreNumbers => 'Other numbers';

  @override
  String get notAllowedForRole => 'Your role does not have access to this.';

  @override
  String get activityTitle => 'Who changed what';

  @override
  String get activityMoneyOnly => 'Money-affecting only';

  @override
  String get activityAllActors => 'Everyone';

  @override
  String get activityYou => 'You (owner)';

  @override
  String get activityNone => 'No activity yet.';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleOrderTaker => 'Order taker';

  @override
  String get rolePacker => 'Packer';

  @override
  String get activityMoney => 'Money';

  @override
  String get adsPrivacyChoices => 'Privacy and ad choices';

  @override
  String get codWhoOwesYou => 'Who owes you';

  @override
  String payoutStepOf(int n) {
    return 'Step $n of 3';
  }

  @override
  String get moreGroupPeople => 'People & catalog';

  @override
  String get moreGroupMoney => 'Money';

  @override
  String get moreGroupComms => 'Communication';

  @override
  String get moreGroupSystem => 'System';
}
