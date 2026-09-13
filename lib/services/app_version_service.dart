import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  AppVersionService._();

  static String? _cachedVersion;

  static Future<String> getVersion() async {
    if (_cachedVersion != null && _cachedVersion!.trim().isNotEmpty) {
      return _cachedVersion!;
    }

    final info = await PackageInfo.fromPlatform();
    _cachedVersion = info.version.trim();
    return _cachedVersion!;
  }

  static bool isAtLeast(String currentVersion, String requiredVersion) {
    final cleanCurrent = currentVersion.split('+').first.trim();
    final cleanRequired = requiredVersion.split('+').first.trim();

    List<int> parse(String value) {
      return value
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList(growable: false);
    }

    final current = parse(cleanCurrent);
    final required = parse(cleanRequired);
    final maxLength = current.length > required.length ? current.length : required.length;

    for (var index = 0; index < maxLength; index++) {
      final currentPart = index < current.length ? current[index] : 0;
      final requiredPart = index < required.length ? required[index] : 0;
      if (currentPart > requiredPart) return true;
      if (currentPart < requiredPart) return false;
    }

    return true;
  }

  static Future<bool> isV160OrAbove() async {
    final version = await getVersion();
    return isAtLeast(version, '1.6.0');
  }

  static Future<bool> isV163OrAbove() async {
    final version = await getVersion();
    return isAtLeast(version, '1.6.3');
  }

  static Future<bool> isV164OrAbove() async {
    final version = await getVersion();
    return isAtLeast(version, '1.6.4');
  }

  static Future<bool> isV175OrAbove() async {
    final version = await getVersion();
    return isAtLeast(version, '1.7.5');
  }

  static Future<bool> isV180OrAbove() async {
    final version = await getVersion();
    return isAtLeast(version, '1.8.0');
  }
}
