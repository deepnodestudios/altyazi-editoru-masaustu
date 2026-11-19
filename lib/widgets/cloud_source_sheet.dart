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

class CloudSourceSheetResult {
  const CloudSourceSheetResult({
    required this.source,
    this.saveCloudAsZip = false,
  });

  final CloudSource source;
  final bool saveCloudAsZip;
}

String _stripCloudSuffix(String label) {
  return label.replaceAll(RegExp(r'\s*\([^\)]*\)\s*$'), '').trim();
}

String cloudSourceLabel(CloudSource source, Map<String, String> trans) {
  switch (source) {
    case CloudSource.device:
      return trans["cloud_source_device"] ?? "Bu Cihaz";
    case CloudSource.googleDrive:
      return _stripCloudSuffix(trans["cloud_source_drive"] ?? "Google Drive");
    case CloudSource.dropbox:
      return _stripCloudSuffix(trans["cloud_source_dropbox"] ?? "Dropbox");
    case CloudSource.yandexDisk:
      return _stripCloudSuffix(trans["cloud_source_yandex"] ?? "Yandex Disk");
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
  final TextEditingController controller =
      TextEditingController(text: defaultName);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(trans["save_as"] ?? "Farklı Kaydet"),
      content: TextField(
        controller: controller,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
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
  String? deviceLabelOverride,
}) {
  return showCloudSourceSheetWithOptions(
    context: context,
    trans: trans,
    isSave: isSave,
    deviceLabelOverride: deviceLabelOverride,
  ).then((result) => result?.source);
}

Future<CloudSourceSheetResult?> showCloudSourceSheetWithOptions({
  required BuildContext context,
  required Map<String, String> trans,
  required bool isSave,
  String? deviceLabelOverride,
  bool showCloudZipToggle = false,
  bool initialSaveCloudAsZip = false,
}) {
  final String title = isSave
      ? (trans["cloud_source_title_save"] ?? "Kaydetme Konumu Seç")
      : (trans["cloud_source_title_pick"] ?? "Dosya Kaynağı Seç");

  return showModalBottomSheet<CloudSourceSheetResult>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      var saveCloudAsZip = initialSaveCloudAsZip;

      CloudSourceSheetResult buildResult(CloudSource source) {
        return CloudSourceSheetResult(
          source: source,
          saveCloudAsZip: saveCloudAsZip,
        );
      }

      return StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (showCloudZipToggle && isSave)
                  SwitchListTile.adaptive(
                    value: saveCloudAsZip,
                    onChanged: (value) {
                      setModalState(() => saveCloudAsZip = value);
                    },
                    title: Text(
                      trans['cloud_source_zip_toggle'] ??
                          'Save to Cloud as ZIP',
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: Text(
                    deviceLabelOverride ??
                        cloudSourceLabel(CloudSource.device, trans),
                  ),
                  onTap: () => Navigator.pop(ctx, buildResult(CloudSource.device)),
                ),
                ListTile(
                  leading: const CloudProviderLogo(
                    asset: CloudProviderAssets.googleDrive,
                    monochrome: false,
                    semanticLabel: 'Google Drive',
                  ),
                  title: Text(cloudSourceLabel(CloudSource.googleDrive, trans)),
                  onTap: () =>
                      Navigator.pop(ctx, buildResult(CloudSource.googleDrive)),
                ),
                ListTile(
                  leading: const CloudProviderLogo(
                    asset: CloudProviderAssets.dropbox,
                    monochrome: false,
                    semanticLabel: 'Dropbox',
                  ),
                  title: Text(cloudSourceLabel(CloudSource.dropbox, trans)),
                  onTap: () {
                    final settings = ctx.read<AppSettings>();
                    if (!settings.hasDropboxOAuthConfig) {
                      final template = trans['cloud_config_missing'] ??
                          '{provider} is not configured. Set OAuth client id.';
                      final msg = template
                          .replaceAll('{provider}',
                              trans['cloud_source_dropbox'] ?? 'Dropbox')
                          .replaceAll('{redirect}', CloudOAuthConfig.redirectUri);
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text(msg)));
                      return;
                    }
                    Navigator.pop(ctx, buildResult(CloudSource.dropbox));
                  },
                ),
                ListTile(
                  leading: const CloudProviderLogo(
                    asset: CloudProviderAssets.yandexDisk,
                    monochrome: false,
                    semanticLabel: 'Yandex Disk',
                  ),
                  title: Text(cloudSourceLabel(CloudSource.yandexDisk, trans)),
                  onTap: () {
                    final settings = ctx.read<AppSettings>();
                    if (!settings.hasYandexOAuthConfig) {
                      final template = trans['cloud_config_missing'] ??
                          '{provider} is not configured. Set OAuth client id/secret.';
                      final msg = template
                          .replaceAll('{provider}',
                              trans['cloud_source_yandex'] ?? 'Yandex Disk')
                          .replaceAll('{redirect}',
                              CloudOAuthConfig.yandexVerificationCodeRedirectUri);
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text(msg)));
                      return;
                    }
                    Navigator.pop(ctx, buildResult(CloudSource.yandexDisk));
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
