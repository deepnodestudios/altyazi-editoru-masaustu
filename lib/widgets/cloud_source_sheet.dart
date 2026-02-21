import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:altyazi_editoru/cloud_oauth_config.dart';
import 'package:altyazi_editoru/app_settings.dart';

import 'cloud_provider_logo.dart';

enum CloudSource {
  device,
  googleDrive,
  dropbox,
  yandexDisk,
}

String cloudSourceLabel(CloudSource source, Map<String, String> trans) {
  switch (source) {
    case CloudSource.device:
      return trans["cloud_source_device"] ?? "Bu Cihaz";
    case CloudSource.googleDrive:
      return trans["cloud_source_drive"] ?? "Google Drive";
    case CloudSource.dropbox:
      return trans["cloud_source_dropbox"] ?? "Dropbox";
    case CloudSource.yandexDisk:
      return trans["cloud_source_yandex"] ?? "Yandex Disk";
  }
}

String cloudSourceDialogTitle(
  CloudSource source,
  Map<String, String> trans, {
  required bool isSave,
}) {
  final String action = isSave
      ? (trans["cloud_source_save"] ?? "Kaydet")
      : (trans["cloud_source_pick"] ?? "Dosya Seç");
  return "${cloudSourceLabel(source, trans)} - $action";
}

void maybeShowCloudPickerHint(
  BuildContext context,
  CloudSource source,
  Map<String, String> trans,
) {
  if (source == CloudSource.device) return;
  final String label = cloudSourceLabel(source, trans);
  final String template = trans["cloud_source_hint"] ??
      "Not: Seçimden sonra açılan dosya seçicide {provider} seçebilirsiniz.";
  final String message = template.replaceAll("{provider}", label);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}

Future<String?> showSaveNameDialog(
    BuildContext context, String defaultName, Map<String, String> trans) {
  final TextEditingController controller = TextEditingController(text: defaultName);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(trans["save_as"] ?? "Farklı Kaydet"),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: trans["file_name"] ?? "Dosya Adı",
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(trans["btn_cancel"] ?? "İptal"),
        ),
        ElevatedButton(
          onPressed: () {
            String name = controller.text.trim();
            if (name.isEmpty) name = defaultName;
            if (!name.toLowerCase().endsWith(".srt")) {
               name += ".srt";
            }
            Navigator.pop(ctx, name);
          },
          child: Text(trans["btn_save"] ?? "Kaydet"),
        ),
      ],
    ),
  );
}

Future<CloudSource?> showCloudSourceSheet({
  required BuildContext context,
  required Map<String, String> trans,
  required bool isSave,
}) {
  final String title = isSave
      ? (trans["cloud_source_title_save"] ?? "Kaydetme Konumu Seç")
      : (trans["cloud_source_title_pick"] ?? "Dosya Kaynağı Seç");

  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Widget buildContent(BuildContext ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(ctx).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        ListTile(
          leading: Icon(
            isDesktop ? Icons.computer : Icons.phone_android,
          ),
          title: Text(cloudSourceLabel(CloudSource.device, trans)),
          onTap: () => Navigator.pop(ctx, CloudSource.device),
        ),
        ListTile(
          leading: const CloudProviderLogo(
            asset: CloudProviderAssets.googleDrive,
            monochrome: false,
            semanticLabel: 'Google Drive',
          ),
          title: Text(cloudSourceLabel(CloudSource.googleDrive, trans)),
          onTap: () => Navigator.pop(ctx, CloudSource.googleDrive),
        ),
        ListTile(
          leading: const CloudProviderLogo(
            asset: CloudProviderAssets.dropbox,
            monochrome: false,
            semanticLabel: 'Dropbox',
          ),
          title: Text(cloudSourceLabel(CloudSource.dropbox, trans)),
          onTap: () async {
            final settings = ctx.read<AppSettings>();
            if (settings.isProviderLoading('dropbox')) return;
            await settings.refreshCloudOAuthConfig();
            if (!ctx.mounted) return;
            if (settings.effectiveDropboxClientId.trim().isEmpty) {
              final template = trans['cloud_config_missing'] ??
                  '{provider} is not configured. Set OAuth client id.';
              final msg = template
                  .replaceAll('{provider}',
                      trans['cloud_source_dropbox'] ?? 'Dropbox')
                  .replaceAll('{redirect}', CloudOAuthConfig.redirectUri);
              settings.addLog('log_error', msg);
              return;
            }

            if (!settings.isDropboxConnected) {
              await settings.toggleDropboxConnection();
              if (!ctx.mounted) return;
              if (!settings.isDropboxConnected) return;
            }
            Navigator.pop(ctx, CloudSource.dropbox);
          },
        ),
        ListTile(
          leading: const CloudProviderLogo(
            asset: CloudProviderAssets.yandexDisk,
            monochrome: false,
            semanticLabel: 'Yandex Disk',
          ),
          title: Text(cloudSourceLabel(CloudSource.yandexDisk, trans)),
          onTap: () async {
            final settings = ctx.read<AppSettings>();
            if (settings.isProviderLoading('yandex')) return;
            await settings.refreshCloudOAuthConfig();
            if (!ctx.mounted) return;
            if (settings.effectiveYandexClientId.trim().isEmpty ||
              settings.effectiveYandexClientSecret.trim().isEmpty) {
              final template = trans['cloud_config_missing'] ??
                  '{provider} is not configured. Set OAuth client id/secret.';
              final msg = template
                  .replaceAll(
                      '{provider}', trans['cloud_source_yandex'] ?? 'Yandex Disk')
                    .replaceAll(
                      '{redirect}',
                      CloudOAuthConfig.yandexVerificationCodeRedirectUri);
              settings.addLog('log_error', msg);
              return;
            }

            if (!settings.isYandexConnected) {
              await settings.toggleYandexConnectionWithContext(ctx);
              if (!ctx.mounted) return;
              if (!settings.isYandexConnected) return;
            }
            Navigator.pop(ctx, CloudSource.yandexDisk);
          },
        ),
      ],
    );
  }

  if (isDesktop) {
    return showDialog<CloudSource>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: buildContent(ctx),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<CloudSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: buildContent(ctx),
      ),
    ),
  );
}
