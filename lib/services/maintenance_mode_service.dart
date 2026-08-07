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
      await rc.fetchAndActivate();
    } catch (e) {
      debugPrint('MaintenanceModeService refresh failed: $e');
    }
    return isActive();
  }

  static bool isActive() {
    try {
      final rc = FirebaseRemoteConfig.instance;
      if (rc.getBool(keyGlobal)) return true;
      if (kIsWeb) return rc.getBool(keyWeb);
      if (Platform.isAndroid || Platform.isIOS) {
        return rc.getBool(keyMobile);
      }
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return rc.getBool(keyDesktop);
      }
    } catch (e) {
      debugPrint('MaintenanceModeService read failed: $e');
    }
    return false;
  }
}
