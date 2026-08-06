import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records desktop app installs and session opens in Firestore.
///
/// Collection: `desktop_installs/{installId}`
/// Uses the same `install_id` pref key as [BillingService].
class DesktopInstallTracker {
  static const _prefKeyInstallId = 'install_id';

  static bool get _isDesktopPlatform =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static String _generateInstallId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Future<String?> _loadOrCreateInstallId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_prefKeyInstallId);
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }

      final created = _generateInstallId();
      await prefs.setString(_prefKeyInstallId, created);
      return created;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _resolveOsVersion() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isWindows) {
        return (await deviceInfo.windowsInfo).displayVersion;
      }
      if (Platform.isMacOS) {
        return (await deviceInfo.macOsInfo).osRelease;
      }
      if (Platform.isLinux) {
        return (await deviceInfo.linuxInfo).prettyName;
      }
    } catch (_) {}
    return '';
  }

  /// Best-effort telemetry ping. Never throws.
  static Future<void> recordAppOpen() async {
    if (!_isDesktopPlatform) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final installId = await _loadOrCreateInstallId();
      if (installId == null || installId.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final osVersion = await _resolveOsVersion();
      final docRef = FirebaseFirestore.instance
          .collection('desktop_installs')
          .doc(installId);

      final snapshot = await docRef.get();
      final payload = <String, dynamic>{
        'installId': installId,
        'platform': Platform.operatingSystem,
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'osVersion': osVersion,
        'uid': user.uid,
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        payload['firstSeenAt'] = FieldValue.serverTimestamp();
        payload['sessionCount'] = 1;
        await docRef.set(payload);
        return;
      }

      payload['sessionCount'] = FieldValue.increment(1);
      await docRef.update(payload);
    } catch (e) {
      debugPrint('DesktopInstallTracker.recordAppOpen failed: $e');
    }
  }
}
