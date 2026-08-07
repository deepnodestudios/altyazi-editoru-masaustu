import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MaintenanceModeService {
  static const String keyGlobal = 'maintenance_mode_enabled';
  static const String keyMobile = 'maintenance_mode_mobile';
  static const String keyDesktop = 'maintenance_mode_desktop';
  static const String keyWeb = 'maintenance_mode_web';

  /// Populated by HTTP fallback when native RC plugin is unreliable (Windows).
  static final Map<String, bool> _httpOverrides = <String, bool>{};
  static String? _lastStatus;

  static String? get lastStatus => _lastStatus;

  static Future<void> ensureDefaults([FirebaseRemoteConfig? remoteConfig]) async {
    final rc = remoteConfig ?? FirebaseRemoteConfig.instance;
    await rc.setDefaults(const {
      keyGlobal: false,
      keyMobile: false,
      keyDesktop: false,
      keyWeb: false,
    });
  }

  static Future<bool> refreshAndIsActive() async {
    var fetchError = '';
    try {
      final rc = FirebaseRemoteConfig.instance;
      await ensureDefaults(rc);
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: Duration.zero,
        ),
      );
      final activated = await rc.fetchAndActivate();
      debugPrint(
        'MaintenanceModeService native fetchAndActivate=$activated '
        'global=${_readNativeBool(rc, keyGlobal)} '
        'desktop=${_readNativeBool(rc, keyDesktop)} '
        'mobile=${_readNativeBool(rc, keyMobile)} '
        'web=${_readNativeBool(rc, keyWeb)}',
      );
    } catch (e) {
      fetchError = e.toString();
      debugPrint('MaintenanceModeService native refresh failed: $e');
    }

    // Windows RC plugin is flaky; always reinforce with REST fetch on desktop.
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        await _refreshViaHttpFallback();
      } catch (e) {
        debugPrint('MaintenanceModeService HTTP fallback failed: $e');
        if (fetchError.isEmpty) fetchError = e.toString();
      }
    }

    final active = isActive();
    _lastStatus =
        'active=$active desktop=${_effectiveBool(keyDesktop)} '
        'global=${_effectiveBool(keyGlobal)}'
        '${fetchError.isEmpty ? '' : ' err=$fetchError'}';
    debugPrint('MaintenanceModeService $_lastStatus');
    return active;
  }

  static bool isActive() {
    try {
      if (_effectiveBool(keyGlobal)) return true;
      if (kIsWeb) return _effectiveBool(keyWeb);
      if (Platform.isAndroid || Platform.isIOS) {
        return _effectiveBool(keyMobile);
      }
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return _effectiveBool(keyDesktop);
      }
    } catch (e) {
      debugPrint('MaintenanceModeService read failed: $e');
    }
    return false;
  }

  static bool _effectiveBool(String key) {
    if (_httpOverrides.containsKey(key)) {
      return _httpOverrides[key]!;
    }
    try {
      return _readNativeBool(FirebaseRemoteConfig.instance, key);
    } catch (_) {
      return false;
    }
  }

  static bool _readNativeBool(FirebaseRemoteConfig rc, String key) {
    try {
      if (rc.getBool(key)) return true;
    } catch (_) {}

    try {
      final value = rc.getValue(key).asString().trim().toLowerCase();
      return value == 'true' || value == '1' || value == 'yes';
    } catch (_) {}

    return false;
  }

  static Future<void> _refreshViaHttpFallback() async {
    final options = Firebase.app().options;
    final apiKey = options.apiKey;
    final appId = options.appId;
    final projectId = options.projectId;
    if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty) {
      throw StateError('Firebase options missing for RC HTTP fallback');
    }

    final uri = Uri.parse(
      'https://firebaseremoteconfig.googleapis.com/v1/projects/'
      '$projectId/namespaces/firebase:fetch?key=$apiKey',
    );

    final instanceId =
        'desktop-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'appId': appId,
            'appInstanceId': instanceId,
            'languageCode': Platform.localeName,
            'platformVersion': Platform.operatingSystemVersion,
            'timeZone': DateTime.now().timeZoneName,
            'appVersion': '1.7.5',
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'RC HTTP ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected RC HTTP payload');
    }

    final entries = decoded['entries'];
    if (entries is! Map) return;

    bool parseBool(dynamic raw) {
      if (raw is bool) return raw;
      final s = '$raw'.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    for (final key in [keyGlobal, keyMobile, keyDesktop, keyWeb]) {
      if (entries.containsKey(key)) {
        _httpOverrides[key] = parseBool(entries[key]);
      }
    }

    debugPrint(
      'MaintenanceModeService HTTP overrides=$_httpOverrides',
    );
  }
}
