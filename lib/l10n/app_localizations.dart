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

  /// No description provided for @periodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get periodToday;

  /// No description provided for @periodYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get periodYesterday;

  /// No description provided for @period7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get period7d;

  /// No description provided for @periodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get periodThisMonth;

  /// No description provided for @periodLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get periodLastMonth;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get periodCustom;

  /// No description provided for @sectionCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get sectionCash;

  /// No description provided for @sectionOps.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get sectionOps;

  /// No description provided for @sectionPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get sectionPerformance;

  /// No description provided for @tileOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get tileOrders;

  /// No description provided for @tileToDispatch.
  ///
  /// In en, this message translates to:
  /// **'To dispatch'**
  String get tileToDispatch;

  /// No description provided for @tileInTransitOps.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get tileInTransitOps;

  /// No description provided for @tileStuck.
  ///
  /// In en, this message translates to:
  /// **'Stuck parcels'**
  String get tileStuck;

  /// No description provided for @tileReturnsAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Returns awaiting'**
  String get tileReturnsAwaiting;

  /// No description provided for @tileRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get tileRevenue;

  /// No description provided for @tileProfitFinal.
  ///
  /// In en, this message translates to:
  /// **'Final profit'**
  String get tileProfitFinal;

  /// No description provided for @tileProfitProvisional.
  ///
  /// In en, this message translates to:
  /// **'Provisional profit'**
  String get tileProfitProvisional;

  /// No description provided for @tileMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get tileMargin;

  /// No description provided for @tileDeliverySuccess.
  ///
  /// In en, this message translates to:
  /// **'Delivery success'**
  String get tileDeliverySuccess;

  /// No description provided for @tileReturnRate.
  ///
  /// In en, this message translates to:
  /// **'Return rate'**
  String get tileReturnRate;

  /// No description provided for @tileAvgProfit.
  ///
  /// In en, this message translates to:
  /// **'Avg profit / order'**
  String get tileAvgProfit;

  /// No description provided for @savedViews.
  ///
  /// In en, this message translates to:
  /// **'Saved views'**
  String get savedViews;

  /// No description provided for @saveCurrentView.
  ///
  /// In en, this message translates to:
  /// **'Save current filters as view'**
  String get saveCurrentView;

  /// No description provided for @viewName.
  ///
  /// In en, this message translates to:
  /// **'View name'**
  String get viewName;

  /// No description provided for @renameView.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameView;

  /// No description provided for @deleteView.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteView;

  /// No description provided for @viewToDispatch.
  ///
  /// In en, this message translates to:
  /// **'To dispatch today'**
  String get viewToDispatch;

  /// No description provided for @viewCodPending5.
  ///
  /// In en, this message translates to:
  /// **'Delivered, COD pending > 5 days'**
  String get viewCodPending5;

  /// No description provided for @viewReturnsNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Returns not received'**
  String get viewReturnsNotReceived;

  /// No description provided for @viewLossMaking.
  ///
  /// In en, this message translates to:
  /// **'Loss-making orders'**
  String get viewLossMaking;

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTitle;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyFilters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetFilters;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get sortOldest;

  /// No description provided for @sortAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sortAmount;

  /// No description provided for @sortProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get sortProfit;

  /// No description provided for @sortDispatch.
  ///
  /// In en, this message translates to:
  /// **'Longest with courier'**
  String get sortDispatch;

  /// No description provided for @searchOrders.
  ///
  /// In en, this message translates to:
  /// **'Search order, name, phone, CN, product'**
  String get searchOrders;

  /// No description provided for @filterCodStatus.
  ///
  /// In en, this message translates to:
  /// **'COD status'**
  String get filterCodStatus;

  /// No description provided for @filterProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get filterProfit;

  /// No description provided for @profitOnly.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profitOnly;

  /// No description provided for @lossOnly.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get lossOnly;

  /// No description provided for @hasReturnLabel.
  ///
  /// In en, this message translates to:
  /// **'Has return'**
  String get hasReturnLabel;

  /// No description provided for @amountMin.
  ///
  /// In en, this message translates to:
  /// **'Min amount'**
  String get amountMin;

  /// No description provided for @amountMax.
  ///
  /// In en, this message translates to:
  /// **'Max amount'**
  String get amountMax;

  /// No description provided for @tagLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagLabel;

  /// No description provided for @areaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get areaLabel;

  /// No description provided for @dispatchDates.
  ///
  /// In en, this message translates to:
  /// **'Dispatched between'**
  String get dispatchDates;

  /// No description provided for @deliveredDates.
  ///
  /// In en, this message translates to:
  /// **'Delivered between'**
  String get deliveredDates;

  /// No description provided for @orderDates.
  ///
  /// In en, this message translates to:
  /// **'Ordered between'**
  String get orderDates;

  /// No description provided for @ordersCountHeader.
  ///
  /// In en, this message translates to:
  /// **'{n} orders'**
  String ordersCountHeader(int n);

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily summary'**
  String get reportDaily;

  /// No description provided for @reportCourier.
  ///
  /// In en, this message translates to:
  /// **'Courier performance'**
  String get reportCourier;

  /// No description provided for @reportProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit report'**
  String get reportProfit;

  /// No description provided for @reportReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns report'**
  String get reportReturns;

  /// No description provided for @groupDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get groupDay;

  /// No description provided for @groupCourier.
  ///
  /// In en, this message translates to:
  /// **'By courier'**
  String get groupCourier;

  /// No description provided for @groupChannel.
  ///
  /// In en, this message translates to:
  /// **'By channel'**
  String get groupChannel;

  /// No description provided for @groupCustomer.
  ///
  /// In en, this message translates to:
  /// **'By customer'**
  String get groupCustomer;

  /// No description provided for @groupProduct.
  ///
  /// In en, this message translates to:
  /// **'By product'**
  String get groupProduct;

  /// No description provided for @groupArea.
  ///
  /// In en, this message translates to:
  /// **'By area'**
  String get groupArea;

  /// No description provided for @colOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get colOrders;

  /// No description provided for @colRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get colRevenue;

  /// No description provided for @colProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get colProfit;

  /// No description provided for @colMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get colMargin;

  /// No description provided for @colDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get colDelivered;

  /// No description provided for @colReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get colReturned;

  /// No description provided for @colUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get colUnits;

  /// No description provided for @colFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get colFees;

  /// No description provided for @colAvgDays.
  ///
  /// In en, this message translates to:
  /// **'Avg days'**
  String get colAvgDays;

  /// No description provided for @colPayoutLag.
  ///
  /// In en, this message translates to:
  /// **'Payout lag'**
  String get colPayoutLag;

  /// No description provided for @colShortfall.
  ///
  /// In en, this message translates to:
  /// **'Shortfall'**
  String get colShortfall;

  /// No description provided for @colCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get colCreated;

  /// No description provided for @colDispatched.
  ///
  /// In en, this message translates to:
  /// **'Dispatched'**
  String get colDispatched;

  /// No description provided for @colCollected.
  ///
  /// In en, this message translates to:
  /// **'COD collected'**
  String get colCollected;

  /// No description provided for @colFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get colFailed;

  /// No description provided for @colName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get colName;

  /// No description provided for @bestOrders.
  ///
  /// In en, this message translates to:
  /// **'Best orders'**
  String get bestOrders;

  /// No description provided for @worstOrders.
  ///
  /// In en, this message translates to:
  /// **'Worst orders'**
  String get worstOrders;

  /// No description provided for @byReason.
  ///
  /// In en, this message translates to:
  /// **'By reason'**
  String get byReason;

  /// No description provided for @payoutsReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Payouts received'**
  String get payoutsReceivedLabel;

  /// No description provided for @lossTotal.
  ///
  /// In en, this message translates to:
  /// **'Total loss'**
  String get lossTotal;

  /// No description provided for @incompleteExcluded.
  ///
  /// In en, this message translates to:
  /// **'{n} incomplete orders are excluded from margins'**
  String incompleteExcluded(int n);

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get noData;

  /// No description provided for @attentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get attentionTitle;

  /// No description provided for @attentionEmpty.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get attentionEmpty;

  /// No description provided for @attStale.
  ///
  /// In en, this message translates to:
  /// **'No update for {n} days. Delivered?'**
  String attStale(int n);

  /// No description provided for @attOverdueCod.
  ///
  /// In en, this message translates to:
  /// **'COD overdue by {n} days'**
  String attOverdueCod(int n);

  /// No description provided for @attReturn.
  ///
  /// In en, this message translates to:
  /// **'Return in transit {n} days'**
  String attReturn(int n);

  /// No description provided for @attDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft older than a day'**
  String get attDraft;

  /// No description provided for @attDispute.
  ///
  /// In en, this message translates to:
  /// **'Disputed settlement'**
  String get attDispute;

  /// No description provided for @attDispatch.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be dispatched'**
  String get attDispatch;

  /// No description provided for @attBackup.
  ///
  /// In en, this message translates to:
  /// **'No backup for {n} days'**
  String attBackup(int n);

  /// No description provided for @stillInTransit.
  ///
  /// In en, this message translates to:
  /// **'Still in transit'**
  String get stillInTransit;

  /// No description provided for @snooze1d.
  ///
  /// In en, this message translates to:
  /// **'Snooze 1 day'**
  String get snooze1d;

  /// No description provided for @snooze3d.
  ///
  /// In en, this message translates to:
  /// **'Snooze 3 days'**
  String get snooze3d;

  /// No description provided for @dismissItem.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissItem;

  /// No description provided for @dismissReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Why dismiss?'**
  String get dismissReasonLabel;

  /// No description provided for @dismissDone.
  ///
  /// In en, this message translates to:
  /// **'Already handled'**
  String get dismissDone;

  /// No description provided for @dismissNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'Not needed'**
  String get dismissNotNeeded;

  /// No description provided for @callCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callCustomer;

  /// No description provided for @whatsappCustomer.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappCustomer;

  /// No description provided for @openTracking.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get openTracking;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @messageTemplates.
  ///
  /// In en, this message translates to:
  /// **'Message templates'**
  String get messageTemplates;

  /// No description provided for @tplConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Order confirmation'**
  String get tplConfirmation;

  /// No description provided for @tplDispatch.
  ///
  /// In en, this message translates to:
  /// **'Dispatch notice'**
  String get tplDispatch;

  /// No description provided for @tplFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Delivery follow-up'**
  String get tplFollowUp;

  /// No description provided for @tplBeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Please be available'**
  String get tplBeAvailable;

  /// No description provided for @tplPlaceholders.
  ///
  /// In en, this message translates to:
  /// **'Placeholders: \'{name}\' \'{cn}\' \'{amount}\' \'{order}\' \'{courier}\' \'{shop}\''**
  String get tplPlaceholders;

  /// No description provided for @tplReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get tplReset;

  /// No description provided for @tplUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown placeholder'**
  String get tplUnknown;

  /// No description provided for @sendViaWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Send via WhatsApp'**
  String get sendViaWhatsapp;

  /// No description provided for @digestSettings.
  ///
  /// In en, this message translates to:
  /// **'Daily digest'**
  String get digestSettings;

  /// No description provided for @digestEnable.
  ///
  /// In en, this message translates to:
  /// **'Send a daily reminder'**
  String get digestEnable;

  /// No description provided for @digestTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get digestTime;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @quietFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get quietFrom;

  /// No description provided for @quietTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get quietTo;

  /// No description provided for @digestTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel Khata'**
  String get digestTitle;

  /// No description provided for @digestStale.
  ///
  /// In en, this message translates to:
  /// **'{n} parcels need a status update'**
  String digestStale(int n);

  /// No description provided for @digestOverdue.
  ///
  /// In en, this message translates to:
  /// **'{amount} COD overdue ({n} orders)'**
  String digestOverdue(String amount, int n);

  /// No description provided for @digestReturns.
  ///
  /// In en, this message translates to:
  /// **'{n} returns waiting'**
  String digestReturns(int n);

  /// No description provided for @digestDrafts.
  ///
  /// In en, this message translates to:
  /// **'{n} old drafts'**
  String digestDrafts(int n);

  /// No description provided for @digestDisputes.
  ///
  /// In en, this message translates to:
  /// **'{n} disputes'**
  String digestDisputes(int n);

  /// No description provided for @digestDispatch.
  ///
  /// In en, this message translates to:
  /// **'{n} to dispatch'**
  String digestDispatch(int n);

  /// No description provided for @digestBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup due'**
  String get digestBackup;

  /// No description provided for @batteryGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep reminders working'**
  String get batteryGuideTitle;

  /// No description provided for @batteryGuideBody.
  ///
  /// In en, this message translates to:
  /// **'Some phones stop apps in the background. Allow Parcel Khata to run without battery restrictions so reminders arrive. The in-app list always works.'**
  String get batteryGuideBody;

  /// No description provided for @batteryGuideOpen.
  ///
  /// In en, this message translates to:
  /// **'How to allow'**
  String get batteryGuideOpen;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @dataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataSection;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupNow;

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase (optional)'**
  String get backupPassphrase;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupCreated;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreBackup;

  /// No description provided for @restorePreview.
  ///
  /// In en, this message translates to:
  /// **'This backup contains'**
  String get restorePreview;

  /// No description provided for @restoreReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace everything on this phone'**
  String get restoreReplace;

  /// No description provided for @restoreMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge: add what is missing'**
  String get restoreMerge;

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get restoreDone;

  /// No description provided for @errBackupNotBackup.
  ///
  /// In en, this message translates to:
  /// **'This is not a Parcel Khata backup'**
  String get errBackupNotBackup;

  /// No description provided for @errBackupCorrupted.
  ///
  /// In en, this message translates to:
  /// **'The backup file is damaged'**
  String get errBackupCorrupted;

  /// No description provided for @errBackupChecksum.
  ///
  /// In en, this message translates to:
  /// **'The backup failed its integrity check'**
  String get errBackupChecksum;

  /// No description provided for @errBackupNewer.
  ///
  /// In en, this message translates to:
  /// **'This backup is from a newer app version'**
  String get errBackupNewer;

  /// No description provided for @errBackupPass.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase'**
  String get errBackupPass;

  /// No description provided for @errBackupNeedPass.
  ///
  /// In en, this message translates to:
  /// **'This backup is encrypted: enter its passphrase'**
  String get errBackupNeedPass;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup'**
  String get lastBackup;

  /// No description provided for @neverBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get neverBackedUp;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data (CSV)'**
  String get exportData;

  /// No description provided for @exportOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get exportOrders;

  /// No description provided for @exportCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get exportCustomers;

  /// No description provided for @exportProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get exportProducts;

  /// No description provided for @exportPayouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get exportPayouts;

  /// No description provided for @exportReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get exportReturns;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import from CSV'**
  String get importCsv;

  /// No description provided for @importCustomers.
  ///
  /// In en, this message translates to:
  /// **'Import customers'**
  String get importCustomers;

  /// No description provided for @importOrders.
  ///
  /// In en, this message translates to:
  /// **'Import orders'**
  String get importOrders;

  /// No description provided for @downloadTemplate.
  ///
  /// In en, this message translates to:
  /// **'Share CSV template'**
  String get downloadTemplate;

  /// No description provided for @mapColumns.
  ///
  /// In en, this message translates to:
  /// **'Match columns'**
  String get mapColumns;

  /// No description provided for @notMapped.
  ///
  /// In en, this message translates to:
  /// **'— not used —'**
  String get notMapped;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get importPreview;

  /// No description provided for @importValid.
  ///
  /// In en, this message translates to:
  /// **'{n} rows ready'**
  String importValid(int n);

  /// No description provided for @importErrors.
  ///
  /// In en, this message translates to:
  /// **'{n} rows have problems'**
  String importErrors(int n);

  /// No description provided for @importDuplicates.
  ///
  /// In en, this message translates to:
  /// **'{n} already exist and will be skipped'**
  String importDuplicates(int n);

  /// No description provided for @importSkipBad.
  ///
  /// In en, this message translates to:
  /// **'Skip bad rows and import the rest'**
  String get importSkipBad;

  /// No description provided for @importAllOrNothing.
  ///
  /// In en, this message translates to:
  /// **'Import only if every row is valid'**
  String get importAllOrNothing;

  /// No description provided for @importRun.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importRun;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'{n} imported'**
  String importDone(int n);

  /// No description provided for @pickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get pickFile;

  /// No description provided for @shareOrderSlip.
  ///
  /// In en, this message translates to:
  /// **'Share order slip (PDF)'**
  String get shareOrderSlip;

  /// No description provided for @shareStatement.
  ///
  /// In en, this message translates to:
  /// **'Courier statement (PDF)'**
  String get shareStatement;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel Khata is locked'**
  String get lockTitle;

  /// No description provided for @lockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockEnterPin;

  /// No description provided for @lockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get lockWrongPin;

  /// No description provided for @lockTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again in {s} seconds'**
  String lockTryAgain(int s);

  /// No description provided for @lockUseBiometric.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint / face'**
  String get lockUseBiometric;

  /// No description provided for @lockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Parcel Khata'**
  String get lockBiometricReason;

  /// No description provided for @lockSetPin.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN (4–8 digits)'**
  String get lockSetPin;

  /// No description provided for @lockConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get lockConfirmPin;

  /// No description provided for @lockPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get lockPinMismatch;

  /// No description provided for @lockPinInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 4 to 8 digits'**
  String get lockPinInvalid;

  /// No description provided for @secTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & privacy'**
  String get secTitle;

  /// No description provided for @secEnableLock.
  ///
  /// In en, this message translates to:
  /// **'Lock the app with a PIN'**
  String get secEnableLock;

  /// No description provided for @secChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get secChangePin;

  /// No description provided for @secBiometric.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint / face'**
  String get secBiometric;

  /// No description provided for @secTimeout.
  ///
  /// In en, this message translates to:
  /// **'Lock after leaving the app'**
  String get secTimeout;

  /// No description provided for @secTimeoutNow.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get secTimeoutNow;

  /// No description provided for @secTimeout1m.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get secTimeout1m;

  /// No description provided for @secTimeout5m.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get secTimeout5m;

  /// No description provided for @secHideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide dashboard amounts until tapped'**
  String get secHideAmounts;

  /// No description provided for @secHideProfit.
  ///
  /// In en, this message translates to:
  /// **'Hide profit everywhere'**
  String get secHideProfit;

  /// No description provided for @secTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage and crash reports'**
  String get secTelemetry;

  /// No description provided for @secTelemetryHelp.
  ///
  /// In en, this message translates to:
  /// **'Never includes customers, phones, addresses or amounts.'**
  String get secTelemetryHelp;

  /// No description provided for @secErase.
  ///
  /// In en, this message translates to:
  /// **'Erase all data'**
  String get secErase;

  /// No description provided for @secEraseWarn.
  ///
  /// In en, this message translates to:
  /// **'This deletes every order, customer, product, payout, attachment and setting on this phone. It cannot be undone. Make a backup first.'**
  String get secEraseWarn;

  /// No description provided for @secEraseWord.
  ///
  /// In en, this message translates to:
  /// **'ERASE'**
  String get secEraseWord;

  /// No description provided for @secEraseType.
  ///
  /// In en, this message translates to:
  /// **'Type ERASE to confirm'**
  String get secEraseType;

  /// No description provided for @secErased.
  ///
  /// In en, this message translates to:
  /// **'All data erased'**
  String get secErased;

  /// No description provided for @tapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to show'**
  String get tapToReveal;

  /// No description provided for @obWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Parcel Khata'**
  String get obWelcome;

  /// No description provided for @obWelcomeSub.
  ///
  /// In en, this message translates to:
  /// **'Track orders, courier cash and real profit in one place.'**
  String get obWelcomeSub;

  /// No description provided for @obLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get obLanguage;

  /// No description provided for @obBusiness.
  ///
  /// In en, this message translates to:
  /// **'Your business'**
  String get obBusiness;

  /// No description provided for @obCourier.
  ///
  /// In en, this message translates to:
  /// **'Which courier do you use most?'**
  String get obCourier;

  /// No description provided for @obCourierHelp.
  ///
  /// In en, this message translates to:
  /// **'You can add rates and more couriers later.'**
  String get obCourierHelp;

  /// No description provided for @obSample.
  ///
  /// In en, this message translates to:
  /// **'Add a few sample records'**
  String get obSample;

  /// No description provided for @obSampleHelp.
  ///
  /// In en, this message translates to:
  /// **'Two customers and three products so you can try an order right away.'**
  String get obSampleHelp;

  /// No description provided for @obFinish.
  ///
  /// In en, this message translates to:
  /// **'Start using the app'**
  String get obFinish;

  /// No description provided for @obNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get obNext;

  /// No description provided for @obSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get obSkip;

  /// No description provided for @obTelemetryAsk.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app with anonymous usage reports'**
  String get obTelemetryAsk;

  /// No description provided for @emptyOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'Orders you take on Facebook, WhatsApp or by phone appear here.'**
  String get emptyOrdersHint;

  /// No description provided for @emptyOrdersCta.
  ///
  /// In en, this message translates to:
  /// **'Create your first order'**
  String get emptyOrdersCta;

  /// No description provided for @sampleCustomerA.
  ///
  /// In en, this message translates to:
  /// **'Sample customer A'**
  String get sampleCustomerA;

  /// No description provided for @sampleCustomerB.
  ///
  /// In en, this message translates to:
  /// **'Sample customer B'**
  String get sampleCustomerB;

  /// No description provided for @sampleProduct1.
  ///
  /// In en, this message translates to:
  /// **'Sample T-shirt'**
  String get sampleProduct1;

  /// No description provided for @sampleProduct2.
  ///
  /// In en, this message translates to:
  /// **'Sample bag'**
  String get sampleProduct2;

  /// No description provided for @sampleProduct3.
  ///
  /// In en, this message translates to:
  /// **'Sample mug'**
  String get sampleProduct3;

  /// No description provided for @costAdAllocation.
  ///
  /// In en, this message translates to:
  /// **'Ad cost'**
  String get costAdAllocation;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @expenseNew.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseNew;

  /// No description provided for @expenseEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get expenseEdit;

  /// No description provided for @catAds.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get catAds;

  /// No description provided for @catPackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get catPackaging;

  /// No description provided for @catRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get catRent;

  /// No description provided for @catSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get catSalary;

  /// No description provided for @catMisc.
  ///
  /// In en, this message translates to:
  /// **'Misc'**
  String get catMisc;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseAmount;

  /// No description provided for @expenseDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get expenseDate;

  /// No description provided for @expenseNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get expenseNote;

  /// No description provided for @expenseCampaign.
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get expenseCampaign;

  /// No description provided for @expenseRecurring.
  ///
  /// In en, this message translates to:
  /// **'Repeats every month'**
  String get expenseRecurring;

  /// No description provided for @expenseRecurringAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {n} recurring expenses for this month'**
  String expenseRecurringAdded(int n);

  /// No description provided for @expenseTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get expenseTotal;

  /// No description provided for @campaignsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad campaigns'**
  String get campaignsTitle;

  /// No description provided for @campaignNew.
  ///
  /// In en, this message translates to:
  /// **'New campaign'**
  String get campaignNew;

  /// No description provided for @campaignEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit campaign'**
  String get campaignEdit;

  /// No description provided for @campaignName.
  ///
  /// In en, this message translates to:
  /// **'Campaign name'**
  String get campaignName;

  /// No description provided for @campaignTag.
  ///
  /// In en, this message translates to:
  /// **'Order tag'**
  String get campaignTag;

  /// No description provided for @campaignTagHelp.
  ///
  /// In en, this message translates to:
  /// **'Orders with this tag share the spend'**
  String get campaignTagHelp;

  /// No description provided for @campaignSpend.
  ///
  /// In en, this message translates to:
  /// **'Ad spend'**
  String get campaignSpend;

  /// No description provided for @campaignStart.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get campaignStart;

  /// No description provided for @campaignEnd.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get campaignEnd;

  /// No description provided for @allocByCount.
  ///
  /// In en, this message translates to:
  /// **'Equal share per order'**
  String get allocByCount;

  /// No description provided for @allocByRevenue.
  ///
  /// In en, this message translates to:
  /// **'In proportion to sales'**
  String get allocByRevenue;

  /// No description provided for @allocPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get allocPreview;

  /// No description provided for @allocApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to orders'**
  String get allocApply;

  /// No description provided for @allocClear.
  ///
  /// In en, this message translates to:
  /// **'Remove from orders'**
  String get allocClear;

  /// No description provided for @allocApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied to {n} orders'**
  String allocApplied(int n);

  /// No description provided for @allocNeedsReapply.
  ///
  /// In en, this message translates to:
  /// **'Changed since applied: apply again'**
  String get allocNeedsReapply;

  /// No description provided for @allocNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders carry this tag in these dates'**
  String get allocNoOrders;

  /// No description provided for @taggedOrdersN.
  ///
  /// In en, this message translates to:
  /// **'{n} orders'**
  String taggedOrdersN(int n);

  /// No description provided for @orderTags.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma separated)'**
  String get orderTags;

  /// No description provided for @reportPnl.
  ///
  /// In en, this message translates to:
  /// **'Business profit (P&L)'**
  String get reportPnl;

  /// No description provided for @pnlRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get pnlRevenue;

  /// No description provided for @pnlCogs.
  ///
  /// In en, this message translates to:
  /// **'Product cost'**
  String get pnlCogs;

  /// No description provided for @pnlCourierFees.
  ///
  /// In en, this message translates to:
  /// **'Courier fees'**
  String get pnlCourierFees;

  /// No description provided for @pnlReturnLoss.
  ///
  /// In en, this message translates to:
  /// **'Returns & write-offs'**
  String get pnlReturnLoss;

  /// No description provided for @pnlPackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get pnlPackaging;

  /// No description provided for @pnlAds.
  ///
  /// In en, this message translates to:
  /// **'Ads (on orders)'**
  String get pnlAds;

  /// No description provided for @pnlOtherCosts.
  ///
  /// In en, this message translates to:
  /// **'Other order costs'**
  String get pnlOtherCosts;

  /// No description provided for @pnlOrderProfit.
  ///
  /// In en, this message translates to:
  /// **'Order profit'**
  String get pnlOrderProfit;

  /// No description provided for @pnlExpenses.
  ///
  /// In en, this message translates to:
  /// **'Business expenses'**
  String get pnlExpenses;

  /// No description provided for @pnlBusinessProfit.
  ///
  /// In en, this message translates to:
  /// **'Business profit'**
  String get pnlBusinessProfit;

  /// No description provided for @settingApplyPackaging.
  ///
  /// In en, this message translates to:
  /// **'Add default packaging cost to new orders'**
  String get settingApplyPackaging;

  /// No description provided for @openExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get openExpenses;

  /// No description provided for @riskReliable.
  ///
  /// In en, this message translates to:
  /// **'Reliable'**
  String get riskReliable;

  /// No description provided for @riskRefusedLastCod.
  ///
  /// In en, this message translates to:
  /// **'Refused last COD'**
  String get riskRefusedLastCod;

  /// No description provided for @riskHighReturnRate.
  ///
  /// In en, this message translates to:
  /// **'High return rate'**
  String get riskHighReturnRate;

  /// No description provided for @riskNewCustomer.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get riskNewCustomer;

  /// No description provided for @riskBlocklisted.
  ///
  /// In en, this message translates to:
  /// **'Blocklisted'**
  String get riskBlocklisted;

  /// No description provided for @riskWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders behind this badge'**
  String get riskWhyTitle;

  /// No description provided for @riskNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders — set manually or no history yet.'**
  String get riskNoOrders;

  /// No description provided for @riskCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution note'**
  String get riskCaution;

  /// No description provided for @riskCautionHint.
  ///
  /// In en, this message translates to:
  /// **'Private note about this customer'**
  String get riskCautionHint;

  /// No description provided for @riskBlocklist.
  ///
  /// In en, this message translates to:
  /// **'Blocklist'**
  String get riskBlocklist;

  /// No description provided for @riskUnblock.
  ///
  /// In en, this message translates to:
  /// **'Remove from blocklist'**
  String get riskUnblock;

  /// No description provided for @riskBlockReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get riskBlockReason;

  /// No description provided for @riskBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Risky customer — consider taking an advance.'**
  String get riskBannerTitle;

  /// No description provided for @riskTakeAdvance.
  ///
  /// In en, this message translates to:
  /// **'Take advance'**
  String get riskTakeAdvance;

  /// No description provided for @riskSettings.
  ///
  /// In en, this message translates to:
  /// **'Customer risk flags'**
  String get riskSettings;

  /// No description provided for @riskReturnRateLabel.
  ///
  /// In en, this message translates to:
  /// **'High return rate from (%)'**
  String get riskReturnRateLabel;

  /// No description provided for @riskMinOrdersLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum finished orders'**
  String get riskMinOrdersLabel;

  /// No description provided for @riskRecencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Refusal counts for (days)'**
  String get riskRecencyLabel;

  /// No description provided for @riskPrivateNote.
  ///
  /// In en, this message translates to:
  /// **'Seller-private. Based only on your own orders.'**
  String get riskPrivateNote;

  /// No description provided for @riskSection.
  ///
  /// In en, this message translates to:
  /// **'Risk flags'**
  String get riskSection;

  /// No description provided for @riskSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get riskSave;

  /// No description provided for @exchangeAction.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get exchangeAction;

  /// No description provided for @exchangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange order'**
  String get exchangeTitle;

  /// No description provided for @exchangeReturnedItems.
  ///
  /// In en, this message translates to:
  /// **'Items coming back'**
  String get exchangeReturnedItems;

  /// No description provided for @exchangeReplacementItems.
  ///
  /// In en, this message translates to:
  /// **'Replacement items'**
  String get exchangeReplacementItems;

  /// No description provided for @exchangeAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get exchangeAddItem;

  /// No description provided for @exchangeSameItems.
  ///
  /// In en, this message translates to:
  /// **'Same items, new size'**
  String get exchangeSameItems;

  /// No description provided for @exchangeWhoPays.
  ///
  /// In en, this message translates to:
  /// **'Who pays the courier'**
  String get exchangeWhoPays;

  /// No description provided for @exchangePayerSeller.
  ///
  /// In en, this message translates to:
  /// **'I pay'**
  String get exchangePayerSeller;

  /// No description provided for @exchangePayerCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer pays'**
  String get exchangePayerCustomer;

  /// No description provided for @exchangeDeliveryCharge.
  ///
  /// In en, this message translates to:
  /// **'Replacement delivery charge'**
  String get exchangeDeliveryCharge;

  /// No description provided for @exchangeReturnShipping.
  ///
  /// In en, this message translates to:
  /// **'Return shipping fee'**
  String get exchangeReturnShipping;

  /// No description provided for @exchangeValueReturned.
  ///
  /// In en, this message translates to:
  /// **'Value coming back'**
  String get exchangeValueReturned;

  /// No description provided for @exchangeValueReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replacement value'**
  String get exchangeValueReplacement;

  /// No description provided for @exchangeCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect on delivery'**
  String get exchangeCollect;

  /// No description provided for @exchangeRefundDue.
  ///
  /// In en, this message translates to:
  /// **'Refund due to customer'**
  String get exchangeRefundDue;

  /// No description provided for @exchangeShippingLoss.
  ///
  /// In en, this message translates to:
  /// **'Shipping you absorb'**
  String get exchangeShippingLoss;

  /// No description provided for @exchangeCreate.
  ///
  /// In en, this message translates to:
  /// **'Create exchange'**
  String get exchangeCreate;

  /// No description provided for @exchangeChip.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get exchangeChip;

  /// No description provided for @exchangeLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked exchange'**
  String get exchangeLinked;

  /// No description provided for @exchangeOriginalOrder.
  ///
  /// In en, this message translates to:
  /// **'Original order'**
  String get exchangeOriginalOrder;

  /// No description provided for @exchangeReplacementOrder.
  ///
  /// In en, this message translates to:
  /// **'Replacement order'**
  String get exchangeReplacementOrder;

  /// No description provided for @exchangeGroupProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit of both orders'**
  String get exchangeGroupProfit;

  /// No description provided for @exchangeNeedItems.
  ///
  /// In en, this message translates to:
  /// **'Pick items to return and add a replacement.'**
  String get exchangeNeedItems;

  /// No description provided for @exchangeItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get exchangeItemName;

  /// No description provided for @exchangeQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get exchangeQty;

  /// No description provided for @exchangeSell.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get exchangeSell;

  /// No description provided for @exchangeCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get exchangeCost;

  /// No description provided for @exchangeCreated.
  ///
  /// In en, this message translates to:
  /// **'Exchange created'**
  String get exchangeCreated;

  /// No description provided for @exchangeNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'Only delivered orders can be exchanged.'**
  String get exchangeNotDelivered;

  /// No description provided for @exchangeExists.
  ///
  /// In en, this message translates to:
  /// **'This order already has a return or exchange.'**
  String get exchangeExists;
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
