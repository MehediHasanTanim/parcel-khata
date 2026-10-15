import 'package:flutter/widgets.dart';
import 'package:parcel_khata/l10n/app_localizations.dart';

export 'package:parcel_khata/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
