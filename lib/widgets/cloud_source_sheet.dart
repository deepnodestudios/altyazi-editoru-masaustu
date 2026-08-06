import 'package:flutter/material.dart';

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
  return Future<CloudSource?>.value(CloudSource.device);
}
