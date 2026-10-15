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
