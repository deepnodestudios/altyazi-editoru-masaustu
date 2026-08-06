import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  /// GitHub repo'su: release'ler buradan çekilir.
  static const String githubRepo = 'deepnodestudios/altyazi-editoru-masaustu';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';
  /// Fallback: web sitesindeki statik sürüm dosyası (GitHub API erişilemezse).
  static const String fallbackUrl = 'https://deepnodestudios.net/windows_version.json';

  static Future<void> checkForUpdates(BuildContext context) async {
    String? latestVersion;
    String? downloadUrl;

    try {
      final response = await http.get(Uri.parse(releasesApiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tag = data['tag_name'] as String?;
        if (tag != null) {
          latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
        }
        final assets = data['assets'] as List?;
        if (assets != null && assets.isNotEmpty) {
          for (final asset in assets) {
            if (asset is Map && asset['browser_download_url'] is String) {
              downloadUrl = asset['browser_download_url'] as String;
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check updates via GitHub: $e');
    }

    // Fallback: web üzerindeki windows_version.json
    if (latestVersion == null || downloadUrl == null) {
      try {
        final response = await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          latestVersion ??= data['version'] as String?;
          downloadUrl ??= data['url'] as String?;
        }
      } catch (e) {
        debugPrint('Failed to check updates via fallback: $e');
      }
    }

    if (latestVersion != null && downloadUrl != null) {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isUpdateAvailable(currentVersion, latestVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, downloadUrl);
        }
      }
    }
  }

  static bool _isUpdateAvailable(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (var i = 0; i < currentParts.length && i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      // If parsing fails, don't show an update
      return false;
    }
  }

  static void _showUpdateDialog(BuildContext context, String newVersion, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Update Available / Güncelleme Mevcut'),
          content: Text('A new version ($newVersion) of the application is available. Would you like to download it now?\n\nUygulamanın yeni bir sürümü ($newVersion) mevcut. Şimdi indirmek ister misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later / Sonra'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update / Güncelle'),
            ),
          ],
        );
      },
    );
  }
}
