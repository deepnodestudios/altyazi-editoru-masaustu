import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class MaintenanceModeService {
  static const String keyGlobal = 'maintenance_mode_enabled';
  static const String keyMobile = 'maintenance_mode_mobile';
  static const String keyDesktop = 'maintenance_mode_desktop';
  static const String keyWeb = 'maintenance_mode_web';

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
    try {
      final rc = FirebaseRemoteConfig.instance;
      await ensureDefaults(rc);
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          // Maintenance checks must bypass the long RC cache window.
          minimumFetchInterval: Duration.zero,
        ),
      );
      final activated = await rc.fetchAndActivate();
      if (kDebugMode) {
        debugPrint(
          'MaintenanceModeService fetchAndActivate=$activated '
          'global=${_readBool(rc, keyGlobal)} '
          'mobile=${_readBool(rc, keyMobile)} '
          'desktop=${_readBool(rc, keyDesktop)} '
          'web=${_readBool(rc, keyWeb)}',
        );
      }
    } catch (e) {
      debugPrint('MaintenanceModeService refresh failed: $e');
    }
    return isActive();
  }

  static bool isActive() {
    try {
      final rc = FirebaseRemoteConfig.instance;
      if (_readBool(rc, keyGlobal)) return true;
      if (kIsWeb) return _readBool(rc, keyWeb);
      if (Platform.isAndroid || Platform.isIOS) {
        return _readBool(rc, keyMobile);
      }
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return _readBool(rc, keyDesktop);
      }
    } catch (e) {
      debugPrint('MaintenanceModeService read failed: $e');
    }
    return false;
  }

  static bool _readBool(FirebaseRemoteConfig rc, String key) {
    try {
      if (rc.getBool(key)) return true;
    } catch (_) {}

    try {
      final value = rc.getValue(key).asString().trim().toLowerCase();
      return value == 'true' || value == '1' || value == 'yes';
    } catch (_) {}

    return false;
  }
}
