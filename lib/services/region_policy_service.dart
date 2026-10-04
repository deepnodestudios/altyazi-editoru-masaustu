import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:locale_names/locale_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_version_service.dart';

/// Detects regions where free-credit earning channels are restricted.
///
/// Geography only (country code OR distinctive timezone). Language is ignored
/// so diaspora users abroad can use Hindi/Farsi/etc. without being restricted.
///
/// Legacy (all versions): IR, IN + UTC+3:30 / UTC+5:30.
/// Wave 1.7.6+: first low-eCPM expansion.
/// Wave 1.7.7+: additional African countries.
class RegionPolicyService extends ChangeNotifier {
  RegionPolicyService._();

  static final RegionPolicyService instance = RegionPolicyService._();

  static const int iranOffsetMinutes = 210; // UTC+3:30
  static const int indiaOffsetMinutes = 330; // UTC+5:30

  /// Keep in sync with functions/src/billing/regionPolicy.ts
  static const String expandedGeoV176MinVersion = '1.7.6';
  static const String expandedGeoV177MinVersion = '1.7.7';

  static const Set<String> legacyRestrictedCountryCodes = {'IR', 'IN'};

  /// Applied when app version >= [expandedGeoV176MinVersion].
  static const Set<String> expandedRestrictedCountryCodesV176 = {
    // South Asia
    'PK',
    'BD',
    'NP',
    'LK',
    'AF',
    // Southeast Asia (very low eCPM)
    'MM',
    'KH',
    'LA',
    // Africa (first wave)
    'NG',
    'ET',
    'KE',
    'GH',
    'TZ',
    'UG',
    'CD',
    'SD',
    // MENA (low demand)
    'IQ',
    'YE',
    'SY',
  };

  /// Applied when app version >= [expandedGeoV177MinVersion].
  static const Set<String> expandedRestrictedCountryCodesV177 = {
    'CM',
    'CI',
    'SN',
    'ML',
    'BF',
    'NE',
    'TD',
    'MG',
    'MZ',
    'ZM',
    'ZW',
    'AO',
    'RW',
    'BI',
    'SO',
    'LR',
    'SL',
    'GN',
    'TG',
    'BJ',
    'MW',
    'SS',
  };

  /// Applied when app version >= [expandedGeoV177MinVersion] (Tier 3 low eCPM expansion).
  static const Set<String> expandedRestrictedCountryCodesTier3 = {
    // North Africa & Middle East (low eCPM)
    'EG', // Egypt
    'DZ', // Algeria
    'MA', // Morocco
    'TN', // Tunisia
    'LY', // Libya
    'JO', // Jordan
    'LB', // Lebanon
    'PS', // Palestine
    // Central Asia & Caucasus (CIS)
    'UZ', // Uzbekistan
    'KG', // Kyrgyzstan
    'TJ', // Tajikistan
    'TM', // Turkmenistan
    'AZ', // Azerbaijan
    'AM', // Armenia
    'GE', // Georgia
    'MD', // Moldova
    // Latin America & Caribbean (very low eCPM / crisis)
    'VE', // Venezuela
    'BO', // Bolivia
    'CU', // Cuba
    'NI', // Nicaragua
    'HT', // Haiti
    'HN', // Honduras
    'GT', // Guatemala
    'SV', // El Salvador
    'PY', // Paraguay
    'EC', // Ecuador
    'DO', // Dominican Republic
    // Africa (remaining low eCPM)
    'CG', // Republic of the Congo
    'GA', // Gabon
    'GQ', // Equatorial Guinea
    'NA', // Namibia
    'BW', // Botswana
    'GM', // Gambia
    'GW', // Guinea-Bissau
    'CV', // Cape Verde
    'ST', // Sao Tome and Principe
    'DJ', // Djibouti
    'KM', // Comoros
    'ER', // Eritrea
    'MR', // Mauritania
    'LS', // Lesotho
    'SZ', // Eswatini
    // Asia
    'MN', // Mongolia
    'BT', // Bhutan
    'MV', // Maldives
  };

  /// Full set for docs / latest clients.
  static const Set<String> restrictedCountryCodes = {
    ...legacyRestrictedCountryCodes,
    ...expandedRestrictedCountryCodesV176,
    ...expandedRestrictedCountryCodesV177,
    ...expandedRestrictedCountryCodesTier3,
  };

  static const String _geoLockedPrefsKey = 'free_rewards_geo_locked';
  static const String _detectedCountryPrefsKey = 'user_detected_country';

  bool _geoLocked = false;
  String? _detectedCountry;
  bool _prefsLoaded = false;
  bool _v176GeoEnabled = false;
  bool _v177GeoEnabled = false;

  bool get isGeoLocked => _geoLocked;
  String? get detectedCountry => _detectedCountry;
  String? get detectedCountryName => resolveCountryFullName(_detectedCountry);

  Future<void> loadCachedPolicy() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _geoLocked = prefs.getBool(_geoLockedPrefsKey) ?? false;
      _detectedCountry = prefs.getString(_detectedCountryPrefsKey);
    } catch (_) {
      _geoLocked = false;
    }
    try {
      final version = await AppVersionService.getVersion();
      _v176GeoEnabled =
          AppVersionService.isAtLeast(version, expandedGeoV176MinVersion);
      _v177GeoEnabled =
          AppVersionService.isAtLeast(version, expandedGeoV177MinVersion);
    } catch (_) {
      _v176GeoEnabled = false;
      _v177GeoEnabled = false;
    }
    _prefsLoaded = true;
  }

  Future<void> applyServerPolicy({
    bool? freeRewardsGeoLocked,
    String? country,
  }) async {
    bool changed = false;
    final prefs = await SharedPreferences.getInstance();

    if (freeRewardsGeoLocked == true && !_geoLocked) {
      _geoLocked = true;
      changed = true;
      try {
        await prefs.setBool(_geoLockedPrefsKey, true);
      } catch (_) {}
    }

    final normalizedCountry = _normalizeCountryCode(country);
    if (normalizedCountry != null && normalizedCountry != _detectedCountry) {
      _detectedCountry = normalizedCountry;
      changed = true;
      try {
        await prefs.setString(_detectedCountryPrefsKey, normalizedCountry);
      } catch (_) {}

      if (!_geoLocked) {
        final restricted = activeRestrictedCountryCodes(
          v176GeoEnabled: _v176GeoEnabled,
          v177GeoEnabled: _v177GeoEnabled,
        );
        if (restricted.contains(normalizedCountry)) {
          _geoLocked = true;
          try {
            await prefs.setBool(_geoLockedPrefsKey, true);
          } catch (_) {}
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Sticky geo-lock from server wins; otherwise evaluate current geography.
  bool isFreeRewardsRestricted({String? appLanguage}) {
    if (_geoLocked) return true;
    if (_detectedCountry != null) {
      final restricted = activeRestrictedCountryCodes(
        v176GeoEnabled: _v176GeoEnabled,
        v177GeoEnabled: _v177GeoEnabled,
      );
      if (restricted.contains(_detectedCountry)) return true;
    }
    return matchesGeoRestrictedSignals(
      countryCodes: collectCountryCodes(),
      timeZoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      v176GeoEnabled: _v176GeoEnabled,
      v177GeoEnabled: _v177GeoEnabled,
    );
  }

  /// This APK is past 1.7.7: hide rewarded-ad copy for the full country list,
  /// not only IR/IN, even before version flags finish loading.
  bool hidesRewardedAdsUi({String? appLanguage}) {
    if (_geoLocked) return true;
    if (_detectedCountry != null) {
      final restricted = activeRestrictedCountryCodes(
        v176GeoEnabled: true,
        v177GeoEnabled: true,
      );
      if (restricted.contains(_detectedCountry)) return true;
    }
    return matchesGeoRestrictedSignals(
      countryCodes: collectCountryCodes(),
      timeZoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      v176GeoEnabled: true,
      v177GeoEnabled: true,
    );
  }

  Map<String, dynamic> toCallablePayload({String? appLanguage}) {
    return {
      'timeZoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'countryCodes': collectCountryCodes(),
      // Kept for backward-compatible logging; server ignores language for policy.
      'languageCodes': collectLanguageCodes(appLanguage: appLanguage),
    };
  }

  List<String> collectCountryCodes() {
    final codes = <String>{};

    void add(String? raw) {
      final normalized = _normalizeCountryCode(raw);
      if (normalized != null) {
        codes.add(normalized);
      }
    }

    if (_detectedCountry != null) {
      add(_detectedCountry);
    }
    add(ui.PlatformDispatcher.instance.locale.countryCode);
    for (final locale in ui.PlatformDispatcher.instance.locales) {
      add(locale.countryCode);
    }

    return codes.toList(growable: false);
  }

  List<String> collectLanguageCodes({String? appLanguage}) {
    final codes = <String>{};

    void add(String? raw) {
      final normalized = _normalizeLanguageCode(raw);
      if (normalized != null) {
        codes.add(normalized);
      }
    }

    add(appLanguage);
    add(ui.PlatformDispatcher.instance.locale.languageCode);
    for (final locale in ui.PlatformDispatcher.instance.locales) {
      add(locale.languageCode);
    }

    return codes.toList(growable: false);
  }

  static Set<String> activeRestrictedCountryCodes({
    required bool v176GeoEnabled,
    required bool v177GeoEnabled,
  }) {
    final codes = Set<String>.from(legacyRestrictedCountryCodes);
    if (v176GeoEnabled) {
      codes.addAll(expandedRestrictedCountryCodesV176);
    }
    if (v177GeoEnabled) {
      codes.addAll(expandedRestrictedCountryCodesV177);
      codes.addAll(expandedRestrictedCountryCodesTier3);
    }
    return codes;
  }

  static bool matchesGeoRestrictedSignals({
    required Iterable<String> countryCodes,
    required int timeZoneOffsetMinutes,
    bool v176GeoEnabled = false,
    bool v177GeoEnabled = false,
    @Deprecated('Use v176GeoEnabled / v177GeoEnabled')
    bool expandedGeoEnabled = false,
  }) {
    final normalized = countryCodes
        .map(_normalizeCountryCode)
        .whereType<String>()
        .toSet();
    final restricted = activeRestrictedCountryCodes(
      v176GeoEnabled: v176GeoEnabled || expandedGeoEnabled,
      v177GeoEnabled: v177GeoEnabled,
    );

    if (normalized.any(restricted.contains)) return true;
    if (timeZoneOffsetMinutes == iranOffsetMinutes) return true;
    if (timeZoneOffsetMinutes == indiaOffsetMinutes) return true;
    return false;
  }

  static String? resolveCountryFullName(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.length == 2) {
      try {
        final loc = ui.Locale('und', trimmed.toUpperCase());
        final name = loc.displayCountryIn(const ui.Locale('en')).trim();
        if (name.isNotEmpty) return name;
      } catch (_) {}
    }
    return trimmed.isNotEmpty ? trimmed : null;
  }

  static String? _normalizeCountryCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toUpperCase();
    return trimmed.length == 2 ? trimmed : null;
  }

  static String? _normalizeLanguageCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('-') || trimmed.contains('_')) {
      return trimmed.split(RegExp(r'[-_]')).first;
    }
    return trimmed;
  }
}
