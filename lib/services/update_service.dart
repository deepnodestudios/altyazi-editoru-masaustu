import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/desktop_update_progress_dialog.dart';

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
  /// Fallback: web üzerindeki statik sürüm dosyası (GitHub API erişilemezse).
  static const String fallbackUrl =
      'https://deepnodestudios.net/windows_version.json';

  static bool get supportsInAppInstall =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<DesktopUpdateInfo?> fetchLatestRelease() async {
    String? latestVersion;
    String? downloadUrl;
    String? fileName;

    try {
      final response = await http
          .get(Uri.parse(releasesApiUrl))
          .timeout(const Duration(seconds: 15));
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
          downloadUrl ??= releasesLatestPage;
          fileName ??= 'desktop_installer.exe';
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
      fileName: fileName ?? 'desktop_installer.exe',
      downloadUrl: downloadUrl,
      folderUrl: releasesLatestPage,
    );
  }

  static Future<void> checkForUpdates(BuildContext context) async {
    final update = await fetchLatestRelease();
    if (update == null) return;

    if (isUpdateAvailable(update.currentVersion, update.latestVersion)) {
      if (context.mounted) {
        await promptAndApplyUpdate(
          context,
          update: update,
          trans: const {},
        );
      }
    }
  }

  static Future<bool> promptAndApplyUpdate(
    BuildContext context, {
    required DesktopUpdateInfo update,
    required Map<String, String> trans,
  }) async {
    final openNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans['update_title'] ?? 'Update found'),
        content: Text(
          '${trans['update_new_version'] ?? 'New version'}: ${update.latestVersion}\n'
          '${trans['update_current_version'] ?? 'Current version'}: ${update.currentVersion}\n\n'
          '${update.fileName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(trans['update_later'] ?? 'Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(trans['update_action'] ?? 'Update'),
          ),
        ],
      ),
    );

    if (openNow != true || !context.mounted) return false;

    if (supportsInAppInstall && _looksLikeInstallerFile(update)) {
      return downloadAndInstall(
        context,
        update: update,
        trans: trans,
      );
    }

    return _openExternalDownload(update.downloadUrl);
  }

  static bool _looksLikeInstallerFile(DesktopUpdateInfo update) {
    final fileName = update.fileName.toLowerCase();
    if (fileName.endsWith('.exe')) return Platform.isWindows;
    if (fileName.endsWith('.zip')) return true;
    return false;
  }

  static Future<bool> downloadAndInstall(
    BuildContext context, {
    required DesktopUpdateInfo update,
    required Map<String, String> trans,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = ValueNotifier<double?>(0);

    navigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) {
          return ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, _) {
              final percent = value == null
                  ? null
                  : (value * 100).clamp(0, 100).toStringAsFixed(0);
              final message = percent == null
                  ? (trans['update_downloading'] ?? 'Downloading update')
                  : '${trans['update_downloading'] ?? 'Downloading update'} %$percent';
              return DesktopUpdateProgressDialog(
                title: trans['update_title'] ?? 'Update found',
                message: message,
                progress: value,
              );
            },
          );
        },
      ),
    );

    try {
      final installerPath = await _downloadInstallerFile(
        update,
        onProgress: (received, total) {
          if (total > 0) {
            progress.value = received / total;
          } else {
            progress.value = null;
          }
        },
      );

      progress.value = 1;
      if (!context.mounted) return false;

      navigator.pop();
      return _launchInstaller(installerPath);
    } catch (e) {
      debugPrint('In-app update failed: $e');
      if (navigator.canPop()) {
        navigator.pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trans['update_download_failed'] ??
                  'Could not download the update. Opening in browser.',
            ),
          ),
        );
      }
      return _openExternalDownload(update.downloadUrl);
    } finally {
      progress.dispose();
    }
  }

  static Future<String> _downloadInstallerFile(
    DesktopUpdateInfo update, {
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = Uri.parse(update.downloadUrl);
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request).timeout(const Duration(minutes: 20));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final safeName = p.basename(update.fileName).trim().isEmpty
          ? 'desktop_update.exe'
          : p.basename(update.fileName);
      final file = File(p.join(tempDir.path, safeName));
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.close();

      if (!await file.exists() || await file.length() == 0) {
        throw const FileSystemException('Downloaded installer is empty');
      }

      return file.path;
    } finally {
      client.close();
    }
  }

  static Future<bool> _launchInstaller(String installerPath) async {
    if (Platform.isWindows && installerPath.toLowerCase().endsWith('.exe')) {
      await Process.start(
        installerPath,
        const [
          '/VERYSILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
          '/CLOSEAPPLICATIONS',
        ],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }

    if (Platform.isMacOS) {
      await Process.start('open', [installerPath], mode: ProcessStartMode.detached);
      return true;
    }

    if (Platform.isLinux) {
      await Process.start(installerPath, [], mode: ProcessStartMode.detached);
      return true;
    }

    return _openExternalDownload(Uri.file(installerPath).toString());
  }

  static Future<bool> _openExternalDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
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
}
