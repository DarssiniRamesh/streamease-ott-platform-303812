import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? result = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(result != null, 'No AppLocalizations found in context');
    return result!;
  }

  String get appName => 'StreamEase';
  String get home => 'Home';
  String get search => 'Search';
  String get downloads => 'Downloads';
  String get profile => 'Profile';
  String get settings => 'Settings';

  String get continueWatching => 'Continue watching';
  String get trendingNow => 'Trending now';
  String get recommended => 'Recommended for you';

  String get offlineQueue => 'Offline queue';
  String get enqueueDownload => 'Download';
  String get cancel => 'Cancel';
  String get pause => 'Pause';
  String get resume => 'Resume';
  String get remove => 'Remove';

  String get quality => 'Quality';
  String get subtitlesDefault => 'Subtitles default';
  String get deviceInfo => 'Device & app info';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => supportedLocales.any((Locale l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
