import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Parcel Khata'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// No description provided for @navNewOrder.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get navNewOrder;

  /// No description provided for @navCod.
  ///
  /// In en, this message translates to:
  /// **'COD'**
  String get navCod;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// No description provided for @newOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get newOrderTitle;

  /// No description provided for @codTitle.
  ///
  /// In en, this message translates to:
  /// **'COD'**
  String get codTitle;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageBangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get languageBangla;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @emptyDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyDefaultTitle;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @debugMenu.
  ///
  /// In en, this message translates to:
  /// **'Debug menu'**
  String get debugMenu;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @customerNew.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get customerNew;

  /// No description provided for @customerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get customerEdit;

  /// No description provided for @searchCustomers.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get searchCustomers;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get fieldPhone;

  /// No description provided for @fieldPhoneAlt.
  ///
  /// In en, this message translates to:
  /// **'Alternate number'**
  String get fieldPhoneAlt;

  /// No description provided for @fieldWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get fieldWhatsapp;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @addresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addresses;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addAddress;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Label (Home, Office)'**
  String get addressLabel;

  /// No description provided for @addressText.
  ///
  /// In en, this message translates to:
  /// **'Full address'**
  String get addressText;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @area.
  ///
  /// In en, this message translates to:
  /// **'Area / Thana'**
  String get area;

  /// No description provided for @defaultAddress.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultAddress;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get unarchive;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @duplicatePhone.
  ///
  /// In en, this message translates to:
  /// **'A customer with this number already exists'**
  String get duplicatePhone;

  /// No description provided for @useExisting.
  ///
  /// In en, this message translates to:
  /// **'Use existing customer'**
  String get useExisting;

  /// No description provided for @errNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get errNameRequired;

  /// No description provided for @errInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number'**
  String get errInvalidPhone;

  /// No description provided for @errInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get errInvalidAmount;

  /// No description provided for @archivedBadge.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedBadge;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @productNew.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get productNew;

  /// No description provided for @productEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get productEdit;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchProducts;

  /// No description provided for @sellPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get sellPrice;

  /// No description provided for @costPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get costPrice;

  /// No description provided for @costMissing.
  ///
  /// In en, this message translates to:
  /// **'Cost missing'**
  String get costMissing;

  /// No description provided for @sku.
  ///
  /// In en, this message translates to:
  /// **'SKU / code'**
  String get sku;

  /// No description provided for @variants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get variants;

  /// No description provided for @addVariant.
  ///
  /// In en, this message translates to:
  /// **'Add variant'**
  String get addVariant;

  /// No description provided for @variantLabel.
  ///
  /// In en, this message translates to:
  /// **'Size / color'**
  String get variantLabel;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @stockQty.
  ///
  /// In en, this message translates to:
  /// **'Stock quantity'**
  String get stockQty;

  /// No description provided for @couriers.
  ///
  /// In en, this message translates to:
  /// **'Couriers'**
  String get couriers;

  /// No description provided for @courierNew.
  ///
  /// In en, this message translates to:
  /// **'New courier'**
  String get courierNew;

  /// No description provided for @courierEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit courier'**
  String get courierEdit;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAdd;

  /// No description provided for @trackingTemplate.
  ///
  /// In en, this message translates to:
  /// **'Tracking link (\'{cn}\' = consignment no.)'**
  String get trackingTemplate;

  /// No description provided for @trackingPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get trackingPreview;

  /// No description provided for @errTrackingTemplate.
  ///
  /// In en, this message translates to:
  /// **'Must be an http(s) link containing \'{cn}\''**
  String get errTrackingTemplate;

  /// No description provided for @payoutCycleDays.
  ///
  /// In en, this message translates to:
  /// **'Payout cycle (days)'**
  String get payoutCycleDays;

  /// No description provided for @stuckDays.
  ///
  /// In en, this message translates to:
  /// **'Stuck parcel after (days)'**
  String get stuckDays;

  /// No description provided for @cnPattern.
  ///
  /// In en, this message translates to:
  /// **'CN pattern (optional regex)'**
  String get cnPattern;

  /// No description provided for @rateCard.
  ///
  /// In en, this message translates to:
  /// **'Rate card'**
  String get rateCard;

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add rate'**
  String get addRule;

  /// No description provided for @zone.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get zone;

  /// No description provided for @zoneInsideDhaka.
  ///
  /// In en, this message translates to:
  /// **'Inside Dhaka'**
  String get zoneInsideDhaka;

  /// No description provided for @zoneDhakaSuburb.
  ///
  /// In en, this message translates to:
  /// **'Dhaka suburb'**
  String get zoneDhakaSuburb;

  /// No description provided for @zoneOutsideDhaka.
  ///
  /// In en, this message translates to:
  /// **'Outside Dhaka'**
  String get zoneOutsideDhaka;

  /// No description provided for @zoneCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get zoneCustom;

  /// No description provided for @weightMinG.
  ///
  /// In en, this message translates to:
  /// **'From (g)'**
  String get weightMinG;

  /// No description provided for @weightMaxG.
  ///
  /// In en, this message translates to:
  /// **'Under (g)'**
  String get weightMaxG;

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// No description provided for @codFeePercent.
  ///
  /// In en, this message translates to:
  /// **'COD fee (%)'**
  String get codFeePercent;

  /// No description provided for @codFeeFlat.
  ///
  /// In en, this message translates to:
  /// **'COD flat fee'**
  String get codFeeFlat;

  /// No description provided for @codFeeFreeUnder.
  ///
  /// In en, this message translates to:
  /// **'No COD fee under'**
  String get codFeeFreeUnder;

  /// No description provided for @returnFee.
  ///
  /// In en, this message translates to:
  /// **'Return fee'**
  String get returnFee;

  /// No description provided for @returnNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get returnNone;

  /// No description provided for @returnFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get returnFlat;

  /// No description provided for @returnPercent.
  ///
  /// In en, this message translates to:
  /// **'% of delivery fee'**
  String get returnPercent;

  /// No description provided for @returnValue.
  ///
  /// In en, this message translates to:
  /// **'Return fee value'**
  String get returnValue;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @businessProfile.
  ///
  /// In en, this message translates to:
  /// **'Business profile'**
  String get businessProfile;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// No description provided for @businessPhone.
  ///
  /// In en, this message translates to:
  /// **'Business phone'**
  String get businessPhone;

  /// No description provided for @orderPrefix.
  ///
  /// In en, this message translates to:
  /// **'Order number prefix'**
  String get orderPrefix;

  /// No description provided for @orderStart.
  ///
  /// In en, this message translates to:
  /// **'Starting number'**
  String get orderStart;

  /// No description provided for @defaults.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get defaults;

  /// No description provided for @defaultChannel.
  ///
  /// In en, this message translates to:
  /// **'Default channel'**
  String get defaultChannel;

  /// No description provided for @defaultDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Default delivery charge'**
  String get defaultDeliveryCharge;

  /// No description provided for @defaultPackaging.
  ///
  /// In en, this message translates to:
  /// **'Default packaging cost'**
  String get defaultPackaging;

  /// No description provided for @defaultCourier.
  ///
  /// In en, this message translates to:
  /// **'Default courier'**
  String get defaultCourier;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @workflow.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get workflow;

  /// No description provided for @packedStep.
  ///
  /// In en, this message translates to:
  /// **'Use Packed step'**
  String get packedStep;

  /// No description provided for @inTransitStep.
  ///
  /// In en, this message translates to:
  /// **'Use In Transit step'**
  String get inTransitStep;

  /// No description provided for @autoReturnFlow.
  ///
  /// In en, this message translates to:
  /// **'Start return flow on failed delivery'**
  String get autoReturnFlow;

  /// No description provided for @stockTracking.
  ///
  /// In en, this message translates to:
  /// **'Track stock'**
  String get stockTracking;

  /// No description provided for @masterData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get masterData;

  /// No description provided for @channelFacebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get channelFacebook;

  /// No description provided for @channelWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get channelWhatsapp;

  /// No description provided for @channelInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get channelInstagram;

  /// No description provided for @channelPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get channelPhone;

  /// No description provided for @channelWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get channelWalkIn;

  /// No description provided for @channelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get channelOther;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @orderNew.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get orderNew;

  /// No description provided for @orderEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit order'**
  String get orderEdit;

  /// No description provided for @drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get drafts;

  /// No description provided for @recentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get recentlyDeleted;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @deleteOrder.
  ///
  /// In en, this message translates to:
  /// **'Delete order'**
  String get deleteOrder;

  /// No description provided for @duplicateOrder.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateOrder;

  /// No description provided for @orderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Order deleted'**
  String get orderDeleted;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrders;

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// No description provided for @statusPacked.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get statusPacked;

  /// No description provided for @statusHanded.
  ///
  /// In en, this message translates to:
  /// **'With courier'**
  String get statusHanded;

  /// No description provided for @statusInTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get statusInTransit;

  /// No description provided for @statusReturnInTransit.
  ///
  /// In en, this message translates to:
  /// **'Return in transit'**
  String get statusReturnInTransit;

  /// No description provided for @statusReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get statusReturned;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @codNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get codNotApplicable;

  /// No description provided for @codPending.
  ///
  /// In en, this message translates to:
  /// **'COD pending'**
  String get codPending;

  /// No description provided for @codCollected.
  ///
  /// In en, this message translates to:
  /// **'With courier'**
  String get codCollected;

  /// No description provided for @codSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get codSettled;

  /// No description provided for @codPartial.
  ///
  /// In en, this message translates to:
  /// **'Partly settled'**
  String get codPartial;

  /// No description provided for @codNotCollected.
  ///
  /// In en, this message translates to:
  /// **'Not collected'**
  String get codNotCollected;

  /// No description provided for @codDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get codDisputed;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get selectCustomer;

  /// No description provided for @addNewCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add new customer'**
  String get addNewCustomer;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress;

  /// No description provided for @chooseSavedAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose saved address'**
  String get chooseSavedAddress;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @addFromCatalog.
  ///
  /// In en, this message translates to:
  /// **'From catalog'**
  String get addFromCatalog;

  /// No description provided for @addFreeText.
  ///
  /// In en, this message translates to:
  /// **'Free item'**
  String get addFreeText;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemName;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantity;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get unitPrice;

  /// No description provided for @unitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get unitCost;

  /// No description provided for @lineDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get lineDiscount;

  /// No description provided for @saveToCatalog.
  ///
  /// In en, this message translates to:
  /// **'Save to catalog'**
  String get saveToCatalog;

  /// No description provided for @savedToCatalog.
  ///
  /// In en, this message translates to:
  /// **'Saved to catalog'**
  String get savedToCatalog;

  /// No description provided for @itemsTotal.
  ///
  /// In en, this message translates to:
  /// **'Items total'**
  String get itemsTotal;

  /// No description provided for @orderDiscount.
  ///
  /// In en, this message translates to:
  /// **'Order discount'**
  String get orderDiscount;

  /// No description provided for @discountPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get discountPercent;

  /// No description provided for @deliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Delivery charge'**
  String get deliveryCharge;

  /// No description provided for @paymentType.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentType;

  /// No description provided for @payCod.
  ///
  /// In en, this message translates to:
  /// **'COD'**
  String get payCod;

  /// No description provided for @payPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Prepaid'**
  String get payPrepaid;

  /// No description provided for @payPartial.
  ///
  /// In en, this message translates to:
  /// **'Advance + COD'**
  String get payPartial;

  /// No description provided for @advanceReceived.
  ///
  /// In en, this message translates to:
  /// **'Advance received'**
  String get advanceReceived;

  /// No description provided for @advanceMethod.
  ///
  /// In en, this message translates to:
  /// **'Method (bKash, Nagad...)'**
  String get advanceMethod;

  /// No description provided for @codAmount.
  ///
  /// In en, this message translates to:
  /// **'COD amount'**
  String get codAmount;

  /// No description provided for @codOverriddenMark.
  ///
  /// In en, this message translates to:
  /// **'Overridden'**
  String get codOverriddenMark;

  /// No description provided for @resetToCalculated.
  ///
  /// In en, this message translates to:
  /// **'Reset to calculated'**
  String get resetToCalculated;

  /// No description provided for @overrideCod.
  ///
  /// In en, this message translates to:
  /// **'Override COD'**
  String get overrideCod;

  /// No description provided for @courier.
  ///
  /// In en, this message translates to:
  /// **'Courier'**
  String get courier;

  /// No description provided for @consignmentNo.
  ///
  /// In en, this message translates to:
  /// **'Consignment no. (CN)'**
  String get consignmentNo;

  /// No description provided for @noCourier.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get noCourier;

  /// No description provided for @expectedDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Expected delivery fee'**
  String get expectedDeliveryFee;

  /// No description provided for @expectedCodFee.
  ///
  /// In en, this message translates to:
  /// **'Expected COD fee'**
  String get expectedCodFee;

  /// No description provided for @weightGrams.
  ///
  /// In en, this message translates to:
  /// **'Weight (g)'**
  String get weightGrams;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel;

  /// No description provided for @sourceRef.
  ///
  /// In en, this message translates to:
  /// **'Chat name / reference'**
  String get sourceRef;

  /// No description provided for @internalNotes.
  ///
  /// In en, this message translates to:
  /// **'Internal notes'**
  String get internalNotes;

  /// No description provided for @saveOrder.
  ///
  /// In en, this message translates to:
  /// **'Save order'**
  String get saveOrder;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// No description provided for @errCustomerRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a customer'**
  String get errCustomerRequired;

  /// No description provided for @errItemsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item'**
  String get errItemsRequired;

  /// No description provided for @errAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a delivery address'**
  String get errAddressRequired;

  /// No description provided for @errCnTaken.
  ///
  /// In en, this message translates to:
  /// **'This CN is already used by another order'**
  String get errCnTaken;

  /// No description provided for @viewConflictingOrder.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get viewConflictingOrder;

  /// No description provided for @warnEditAfterHandover.
  ///
  /// In en, this message translates to:
  /// **'Amounts changed while the courier has this parcel. The COD the courier collects may differ.'**
  String get warnEditAfterHandover;

  /// No description provided for @confirmEditDelivered.
  ///
  /// In en, this message translates to:
  /// **'This order is delivered. Change its amounts anyway?'**
  String get confirmEditDelivered;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @charges.
  ///
  /// In en, this message translates to:
  /// **'Courier & other charges'**
  String get charges;

  /// No description provided for @chargeDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get chargeDeliveryFee;

  /// No description provided for @chargeCodFee.
  ///
  /// In en, this message translates to:
  /// **'COD fee'**
  String get chargeCodFee;

  /// No description provided for @chargeReturnFee.
  ///
  /// In en, this message translates to:
  /// **'Return fee'**
  String get chargeReturnFee;

  /// No description provided for @chargePackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get chargePackaging;

  /// No description provided for @chargeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get chargeOther;

  /// No description provided for @expected.
  ///
  /// In en, this message translates to:
  /// **'expected'**
  String get expected;

  /// No description provided for @discountLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discountLabel;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @advanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Advance'**
  String get advanceLabel;

  /// No description provided for @orderDate.
  ///
  /// In en, this message translates to:
  /// **'Order date'**
  String get orderDate;

  /// No description provided for @filterChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get filterChannel;

  /// No description provided for @filterDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get filterDates;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// No description provided for @unsavedDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Leaving saves this as a draft'**
  String get unsavedDraftHint;

  /// No description provided for @deletedOn.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deletedOn;

  /// No description provided for @restored.
  ///
  /// In en, this message translates to:
  /// **'Order restored'**
  String get restored;

  /// No description provided for @orderCreated.
  ///
  /// In en, this message translates to:
  /// **'Order created'**
  String get orderCreated;

  /// No description provided for @orderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Order updated'**
  String get orderUpdated;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @statusEventCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get statusEventCreated;

  /// No description provided for @fieldChanged.
  ///
  /// In en, this message translates to:
  /// **'changed'**
  String get fieldChanged;

  /// No description provided for @actionPacked.
  ///
  /// In en, this message translates to:
  /// **'Mark packed'**
  String get actionPacked;

  /// No description provided for @actionHanded.
  ///
  /// In en, this message translates to:
  /// **'Hand to courier'**
  String get actionHanded;

  /// No description provided for @actionInTransit.
  ///
  /// In en, this message translates to:
  /// **'Mark in transit'**
  String get actionInTransit;

  /// No description provided for @actionDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get actionDelivered;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Delivery failed'**
  String get actionFailed;

  /// No description provided for @actionReturnTransit.
  ///
  /// In en, this message translates to:
  /// **'Return in transit'**
  String get actionReturnTransit;

  /// No description provided for @actionReturned.
  ///
  /// In en, this message translates to:
  /// **'Received back'**
  String get actionReturned;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get actionCancel;

  /// No description provided for @changeStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get changeStatusTitle;

  /// No description provided for @whenLabel.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get whenLabel;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @reasonCustomerRefused.
  ///
  /// In en, this message translates to:
  /// **'Customer refused'**
  String get reasonCustomerRefused;

  /// No description provided for @reasonNotReachable.
  ///
  /// In en, this message translates to:
  /// **'Not reachable'**
  String get reasonNotReachable;

  /// No description provided for @reasonWrongAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get reasonWrongAddress;

  /// No description provided for @reasonCustomerCancelled.
  ///
  /// In en, this message translates to:
  /// **'Customer cancelled'**
  String get reasonCustomerCancelled;

  /// No description provided for @reasonOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get reasonOutOfStock;

  /// No description provided for @reasonCourierIssue.
  ///
  /// In en, this message translates to:
  /// **'Courier issue'**
  String get reasonCourierIssue;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @reasonCorrection.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get reasonCorrection;

  /// No description provided for @correctStatus.
  ///
  /// In en, this message translates to:
  /// **'Correct status'**
  String get correctStatus;

  /// No description provided for @correctionNote.
  ///
  /// In en, this message translates to:
  /// **'Why is this being corrected?'**
  String get correctionNote;

  /// No description provided for @errCourierRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a courier first'**
  String get errCourierRequired;

  /// No description provided for @errCnRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the consignment number first'**
  String get errCnRequired;

  /// No description provided for @errReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a reason'**
  String get errReasonRequired;

  /// No description provided for @errFutureDate.
  ///
  /// In en, this message translates to:
  /// **'Date cannot be in the future'**
  String get errFutureDate;

  /// No description provided for @errNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This change is not allowed'**
  String get errNotAllowed;

  /// No description provided for @errBeforeInitiated.
  ///
  /// In en, this message translates to:
  /// **'Received date is before the return started'**
  String get errBeforeInitiated;

  /// No description provided for @assignCourier.
  ///
  /// In en, this message translates to:
  /// **'Courier & CN'**
  String get assignCourier;

  /// No description provided for @markHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Mark as handed over'**
  String get markHandedOver;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @cnPatternWarn.
  ///
  /// In en, this message translates to:
  /// **'CN does not match the usual pattern'**
  String get cnPatternWarn;

  /// No description provided for @trackParcel.
  ///
  /// In en, this message translates to:
  /// **'Track parcel'**
  String get trackParcel;

  /// No description provided for @lastUpdatedByYou.
  ///
  /// In en, this message translates to:
  /// **'Last updated by you'**
  String get lastUpdatedByYou;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{today} =1{1 day ago} other{{n} days ago}}'**
  String daysAgo(int n);

  /// No description provided for @bulkSummary.
  ///
  /// In en, this message translates to:
  /// **'{changed} updated, {skipped} skipped'**
  String bulkSummary(int changed, int skipped);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{n} selected'**
  String selectedCount(int n);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @stuckParcels.
  ///
  /// In en, this message translates to:
  /// **'Stuck parcels'**
  String get stuckParcels;

  /// No description provided for @withCourierDays.
  ///
  /// In en, this message translates to:
  /// **'With courier {n} days'**
  String withCourierDays(int n);

  /// No description provided for @fastCnEntry.
  ///
  /// In en, this message translates to:
  /// **'Fast CN entry'**
  String get fastCnEntry;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @saveNext.
  ///
  /// In en, this message translates to:
  /// **'Save & next'**
  String get saveNext;

  /// No description provided for @allHaveCn.
  ///
  /// In en, this message translates to:
  /// **'All orders have a CN'**
  String get allHaveCn;

  /// No description provided for @remainingCount.
  ///
  /// In en, this message translates to:
  /// **'{n} left'**
  String remainingCount(int n);

  /// No description provided for @trackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Add a tracking link to this courier first'**
  String get trackUnavailable;

  /// No description provided for @warnDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Check with the courier'**
  String get warnDialogTitle;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @pendingWithCourier.
  ///
  /// In en, this message translates to:
  /// **'Pending with couriers'**
  String get pendingWithCourier;

  /// No description provided for @inTransitCod.
  ///
  /// In en, this message translates to:
  /// **'COD in transit'**
  String get inTransitCod;

  /// No description provided for @settledThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Received this month'**
  String get settledThisMonth;

  /// No description provided for @recordPayout.
  ///
  /// In en, this message translates to:
  /// **'Record payout'**
  String get recordPayout;

  /// No description provided for @ageingTitle.
  ///
  /// In en, this message translates to:
  /// **'COD ageing'**
  String get ageingTitle;

  /// No description provided for @payoutsHistory.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get payoutsHistory;

  /// No description provided for @overdueLabel.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueLabel;

  /// No description provided for @ordersCountN.
  ///
  /// In en, this message translates to:
  /// **'{n} orders'**
  String ordersCountN(int n);

  /// No description provided for @oldestDays.
  ///
  /// In en, this message translates to:
  /// **'Oldest: {n} days'**
  String oldestDays(int n);

  /// No description provided for @ledgerTitle.
  ///
  /// In en, this message translates to:
  /// **'COD ledger'**
  String get ledgerTitle;

  /// No description provided for @expectedCod.
  ///
  /// In en, this message translates to:
  /// **'Expected COD'**
  String get expectedCod;

  /// No description provided for @collectedAmount.
  ///
  /// In en, this message translates to:
  /// **'Collected by courier'**
  String get collectedAmount;

  /// No description provided for @deductionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Courier deductions'**
  String get deductionsLabel;

  /// No description provided for @netReceivable.
  ///
  /// In en, this message translates to:
  /// **'Net receivable'**
  String get netReceivable;

  /// No description provided for @settledAmount.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get settledAmount;

  /// No description provided for @writtenOffAmount.
  ///
  /// In en, this message translates to:
  /// **'Written off'**
  String get writtenOffAmount;

  /// No description provided for @outstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstandingLabel;

  /// No description provided for @recordCollected.
  ///
  /// In en, this message translates to:
  /// **'Record collected amount'**
  String get recordCollected;

  /// No description provided for @collectedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for the difference'**
  String get collectedReason;

  /// No description provided for @enterActual.
  ///
  /// In en, this message translates to:
  /// **'Enter actual fee'**
  String get enterActual;

  /// No description provided for @actualFee.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get actualFee;

  /// No description provided for @markDispute.
  ///
  /// In en, this message translates to:
  /// **'Mark as disputed'**
  String get markDispute;

  /// No description provided for @resolveDispute.
  ///
  /// In en, this message translates to:
  /// **'Resolve dispute'**
  String get resolveDispute;

  /// No description provided for @disputeNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get disputeNote;

  /// No description provided for @disputedOrders.
  ///
  /// In en, this message translates to:
  /// **'Disputed orders'**
  String get disputedOrders;

  /// No description provided for @payoutNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Record payout'**
  String get payoutNewTitle;

  /// No description provided for @totalReceived.
  ///
  /// In en, this message translates to:
  /// **'Total received'**
  String get totalReceived;

  /// No description provided for @payMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get payMethod;

  /// No description provided for @methodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get methodBank;

  /// No description provided for @methodBkash.
  ///
  /// In en, this message translates to:
  /// **'bKash'**
  String get methodBkash;

  /// No description provided for @methodNagad.
  ///
  /// In en, this message translates to:
  /// **'Nagad'**
  String get methodNagad;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get methodOther;

  /// No description provided for @referenceNo.
  ///
  /// In en, this message translates to:
  /// **'Reference no.'**
  String get referenceNo;

  /// No description provided for @paidOn.
  ///
  /// In en, this message translates to:
  /// **'Paid on'**
  String get paidOn;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStep;

  /// No description provided for @backStep.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backStep;

  /// No description provided for @expectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get expectedLabel;

  /// No description provided for @receivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get receivedLabel;

  /// No description provided for @differenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get differenceLabel;

  /// No description provided for @shortfallLabel.
  ///
  /// In en, this message translates to:
  /// **'Shortfall'**
  String get shortfallLabel;

  /// No description provided for @surplusLabel.
  ///
  /// In en, this message translates to:
  /// **'Surplus'**
  String get surplusLabel;

  /// No description provided for @autoAllocate.
  ///
  /// In en, this message translates to:
  /// **'Auto-allocate (oldest first)'**
  String get autoAllocate;

  /// No description provided for @shortfallHandling.
  ///
  /// In en, this message translates to:
  /// **'How to handle the shortfall?'**
  String get shortfallHandling;

  /// No description provided for @handleAllocate.
  ///
  /// In en, this message translates to:
  /// **'Leave the balance outstanding'**
  String get handleAllocate;

  /// No description provided for @handleDispute.
  ///
  /// In en, this message translates to:
  /// **'Mark unpaid orders as disputed'**
  String get handleDispute;

  /// No description provided for @handleWriteOff.
  ///
  /// In en, this message translates to:
  /// **'Write off (accept the loss)'**
  String get handleWriteOff;

  /// No description provided for @allowOverpayment.
  ///
  /// In en, this message translates to:
  /// **'Allow overpayment'**
  String get allowOverpayment;

  /// No description provided for @confirmPayout.
  ///
  /// In en, this message translates to:
  /// **'Save payout'**
  String get confirmPayout;

  /// No description provided for @payoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Payout saved'**
  String get payoutSaved;

  /// No description provided for @reversePayout.
  ///
  /// In en, this message translates to:
  /// **'Reverse payout'**
  String get reversePayout;

  /// No description provided for @reverseReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for reversal'**
  String get reverseReason;

  /// No description provided for @payoutReversed.
  ///
  /// In en, this message translates to:
  /// **'Payout reversed'**
  String get payoutReversed;

  /// No description provided for @noPayableOrders.
  ///
  /// In en, this message translates to:
  /// **'Nothing is owed by this courier'**
  String get noPayableOrders;

  /// No description provided for @errAllocationMismatch.
  ///
  /// In en, this message translates to:
  /// **'Allocated amounts must equal the cash received'**
  String get errAllocationMismatch;

  /// No description provided for @errExceedsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'An amount is more than the balance owed on an order'**
  String get errExceedsOutstanding;

  /// No description provided for @errShortfallPolicy.
  ///
  /// In en, this message translates to:
  /// **'Choose how to handle the shortfall'**
  String get errShortfallPolicy;

  /// No description provided for @errNoOrdersSelected.
  ///
  /// In en, this message translates to:
  /// **'Select at least one order'**
  String get errNoOrdersSelected;

  /// No description provided for @errTotalPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter the total received'**
  String get errTotalPositive;

  /// No description provided for @payoutStatusReversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get payoutStatusReversed;

  /// No description provided for @allocationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Allocations'**
  String get allocationsTitle;

  /// No description provided for @bucket0to3.
  ///
  /// In en, this message translates to:
  /// **'0–3 days'**
  String get bucket0to3;

  /// No description provided for @bucket4to7.
  ///
  /// In en, this message translates to:
  /// **'4–7 days'**
  String get bucket4to7;

  /// No description provided for @bucket8to14.
  ///
  /// In en, this message translates to:
  /// **'8–14 days'**
  String get bucket8to14;

  /// No description provided for @bucket15plus.
  ///
  /// In en, this message translates to:
  /// **'15+ days'**
  String get bucket15plus;

  /// No description provided for @allCouriers.
  ///
  /// In en, this message translates to:
  /// **'All couriers'**
  String get allCouriers;

  /// No description provided for @selectOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders covered by this payout'**
  String get selectOrdersTitle;

  /// No description provided for @amountApplied.
  ///
  /// In en, this message translates to:
  /// **'Amount applied'**
  String get amountApplied;

  /// No description provided for @noPayouts.
  ///
  /// In en, this message translates to:
  /// **'No payouts yet'**
  String get noPayouts;

  /// No description provided for @returnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returnsTitle;

  /// No description provided for @tabInTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get tabInTransit;

  /// No description provided for @tabReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get tabReceived;

  /// No description provided for @tabNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Not received'**
  String get tabNotReceived;

  /// No description provided for @startReturn.
  ///
  /// In en, this message translates to:
  /// **'Start return'**
  String get startReturn;

  /// No description provided for @partialReturn.
  ///
  /// In en, this message translates to:
  /// **'Partial return'**
  String get partialReturn;

  /// No description provided for @fullReturn.
  ///
  /// In en, this message translates to:
  /// **'Full return'**
  String get fullReturn;

  /// No description provided for @returnReason.
  ///
  /// In en, this message translates to:
  /// **'Return reason'**
  String get returnReason;

  /// No description provided for @returnQty.
  ///
  /// In en, this message translates to:
  /// **'Qty returned'**
  String get returnQty;

  /// No description provided for @conditionResellable.
  ///
  /// In en, this message translates to:
  /// **'Resellable'**
  String get conditionResellable;

  /// No description provided for @conditionDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get conditionDamaged;

  /// No description provided for @conditionLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get conditionLost;

  /// No description provided for @conditionMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get conditionMixed;

  /// No description provided for @lossAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get lossAmountLabel;

  /// No description provided for @stockWillRestore.
  ///
  /// In en, this message translates to:
  /// **'Resellable items go back to stock'**
  String get stockWillRestore;

  /// No description provided for @returnedValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value returned'**
  String get returnedValueLabel;

  /// No description provided for @daysInTransitN.
  ///
  /// In en, this message translates to:
  /// **'{n} days in transit'**
  String daysInTransitN(int n);

  /// No description provided for @returnSaved.
  ///
  /// In en, this message translates to:
  /// **'Return saved'**
  String get returnSaved;

  /// No description provided for @receivedBackOn.
  ///
  /// In en, this message translates to:
  /// **'Received on'**
  String get receivedBackOn;

  /// No description provided for @errReturnStatus.
  ///
  /// In en, this message translates to:
  /// **'A return is not possible in this status'**
  String get errReturnStatus;

  /// No description provided for @errReturnNoLines.
  ///
  /// In en, this message translates to:
  /// **'Select at least one item'**
  String get errReturnNoLines;

  /// No description provided for @errReturnBadQty.
  ///
  /// In en, this message translates to:
  /// **'Quantity is more than ordered'**
  String get errReturnBadQty;

  /// No description provided for @errReturnUseFull.
  ///
  /// In en, this message translates to:
  /// **'All items returned: use a full return'**
  String get errReturnUseFull;

  /// No description provided for @errReturnExists.
  ///
  /// In en, this message translates to:
  /// **'A return already exists for this order'**
  String get errReturnExists;

  /// No description provided for @returnCard.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnCard;

  /// No description provided for @profitTitle.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profitTitle;

  /// No description provided for @profitRevenue.
  ///
  /// In en, this message translates to:
  /// **'Product revenue'**
  String get profitRevenue;

  /// No description provided for @profitDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery charge'**
  String get profitDelivery;

  /// No description provided for @profitGross.
  ///
  /// In en, this message translates to:
  /// **'Collected value'**
  String get profitGross;

  /// No description provided for @costCogs.
  ///
  /// In en, this message translates to:
  /// **'Product cost'**
  String get costCogs;

  /// No description provided for @costGoodsLoss.
  ///
  /// In en, this message translates to:
  /// **'Damaged/lost goods'**
  String get costGoodsLoss;

  /// No description provided for @profitNet.
  ///
  /// In en, this message translates to:
  /// **'Net profit'**
  String get profitNet;

  /// No description provided for @marginLabel.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get marginLabel;

  /// No description provided for @stateProvisional.
  ///
  /// In en, this message translates to:
  /// **'Provisional'**
  String get stateProvisional;

  /// No description provided for @stateFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get stateFinal;

  /// No description provided for @stateIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get stateIncomplete;

  /// No description provided for @helpProvisional.
  ///
  /// In en, this message translates to:
  /// **'Based on expected fees or the order is not settled yet.'**
  String get helpProvisional;

  /// No description provided for @helpFinal.
  ///
  /// In en, this message translates to:
  /// **'All amounts are known.'**
  String get helpFinal;

  /// No description provided for @helpIncomplete.
  ///
  /// In en, this message translates to:
  /// **'A product cost is missing, so profit cannot be trusted.'**
  String get helpIncomplete;

  /// No description provided for @missingCostFor.
  ///
  /// In en, this message translates to:
  /// **'Cost missing for'**
  String get missingCostFor;

  /// No description provided for @expectedFeesNote.
  ///
  /// In en, this message translates to:
  /// **'includes expected fees'**
  String get expectedFeesNote;

  /// No description provided for @hideProfit.
  ///
  /// In en, this message translates to:
  /// **'Hide profit in lists'**
  String get hideProfit;

  /// No description provided for @returnTransitDays.
  ///
  /// In en, this message translates to:
  /// **'Flag returns in transit after (days)'**
  String get returnTransitDays;

  /// No description provided for @fixMissingCosts.
  ///
  /// In en, this message translates to:
  /// **'Fix missing costs'**
  String get fixMissingCosts;

  /// No description provided for @noMissingCosts.
  ///
  /// In en, this message translates to:
  /// **'No orders with missing costs'**
  String get noMissingCosts;

  /// No description provided for @alsoUpdateCatalog.
  ///
  /// In en, this message translates to:
  /// **'Also set this as the catalog cost'**
  String get alsoUpdateCatalog;

  /// No description provided for @customerSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get customerSummary;

  /// No description provided for @ordersTotal.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTotal;

  /// No description provided for @deliveredPct.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveredPct;

  /// No description provided for @returnedPct.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get returnedPct;

  /// No description provided for @lifetimeRevenue.
  ///
  /// In en, this message translates to:
  /// **'Lifetime revenue'**
  String get lifetimeRevenue;

  /// No description provided for @lifetimeProfit.
  ///
  /// In en, this message translates to:
  /// **'Lifetime profit'**
  String get lifetimeProfit;

  /// No description provided for @lastOrderOn.
  ///
  /// In en, this message translates to:
  /// **'Last order'**
  String get lastOrderOn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
