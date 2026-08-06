import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String fileName;
  final String downloadUrl;
  final String? folderUrl;

  const DesktopUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.fileName,
    required this.downloadUrl,
    this.folderUrl,
  });
}

class UpdateService {
  /// GitHub repo'su: release'ler buradan çekilir.
  static const String githubRepo = 'deepnodestudios/altyazi-editoru-masaustu';
  static const String releasesLatestPage =
      'https://github.com/$githubRepo/releases/latest';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';
  /// Fallback: web sitesindeki statik sürüm dosyası (GitHub API erişilemezse).
  static const String fallbackUrl =
      'https://deepnodestudios.net/windows_version.json';

  static Future<DesktopUpdateInfo?> fetchLatestRelease() async {
    String? latestVersion;
    String? downloadUrl;
    String? fileName;

    try {
      final response =
          await http.get(Uri.parse(releasesApiUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tag = data['tag_name'] as String?;
        if (tag != null) {
          latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
        }

        final assets = data['assets'] as List?;
        if (assets != null) {
          for (final asset in assets) {
            if (asset is! Map) continue;
            final url = asset['browser_download_url'];
            final name = asset['name'];
            if (url is! String || name is! String) continue;
            if (!name.toLowerCase().endsWith('.exe')) continue;
            downloadUrl = url;
            fileName = name;
            break;
          }

          if (downloadUrl == null) {
            for (final asset in assets) {
              if (asset is! Map) continue;
              final url = asset['browser_download_url'];
              final name = asset['name'];
              if (url is String && name is String) {
                downloadUrl = url;
                fileName = name;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check updates via GitHub: $e');
    }

    if (latestVersion == null || downloadUrl == null) {
      try {
        final response =
            await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          latestVersion ??= data['version'] as String?;
          downloadUrl ??= data['url'] as String?;
          fileName ??= 'desktop_installer';
        }
      } catch (e) {
        debugPrint('Failed to check updates via fallback: $e');
      }
    }

    if (latestVersion == null || downloadUrl == null) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    return DesktopUpdateInfo(
      currentVersion: packageInfo.version,
      latestVersion: latestVersion,
      fileName: fileName ?? 'desktop_installer',
      downloadUrl: downloadUrl,
      folderUrl: releasesLatestPage,
    );
  }

  static Future<void> checkForUpdates(BuildContext context) async {
    final update = await fetchLatestRelease();
    if (update == null) return;

    if (isUpdateAvailable(update.currentVersion, update.latestVersion)) {
      if (context.mounted) {
        _showUpdateDialog(context, update.latestVersion, update.downloadUrl);
      }
    }
  }

  static bool isUpdateAvailable(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (var i = 0; i < currentParts.length && i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return false;
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String url,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Update Available / Güncelleme Mevcut'),
          content: Text(
            'A new version ($newVersion) of the application is available. Would you like to download it now?\n\n'
            'Uygulamanın yeni bir sürümü ($newVersion) mevcut. Şimdi indirmek ister misiniz?',
          ),
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
