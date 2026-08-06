import codecs

with open(r'lib\tabs\ai_panel.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_code = """      onStartBatchTranslation: () {
        final pendingSelected = _selectedFiles
            .where((f) => !controller.activeBatchFilePaths.contains(f.path))
            .toList();
        if (pendingSelected.isNotEmpty) {
          final files = pendingSelected.map((f) => File(f.path)).toList();"""

new_code = """      onStartBatchTranslation: () async {
        final pendingSelected = _selectedFiles
            .where((f) => !controller.activeBatchFilePaths.contains(f.path))
            .toList();
        if (pendingSelected.isNotEmpty) {
          if (!settings.hideBatchTranslationInfo) {
            bool dontShowAgain = false;
            await showDialog(
              context: context,
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Row(
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              settings.trans['batch_info_dialog_title'] ?? 'Bilgilendirme',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            settings.trans['batch_info_dialog_message'] ?? 
                            'Çeviriniz sunucuda arka planda gerçekleştirilmektedir. Tamamlandığında bildirim ile haber verilecektir.\\n\\nDilerseniz diğer işlerinize devam edebilirsiniz.',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: dontShowAgain,
                                onChanged: (val) {
                                  setState(() { dontShowAgain = val ?? false; });
                                },
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() { dontShowAgain = !dontShowAgain; });
                                  },
                                  child: Text(settings.trans['dont_show_again'] ?? 'Bir daha gösterme'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(settings.trans['hide'] ?? 'Gizle'),
                        ),
                      ],
                    );
                  }
                );
              }
            );
            if (dontShowAgain) {
              await settings.setHideBatchTranslationInfo(true);
            }
          }

          final files = pendingSelected.map((f) => File(f.path)).toList();"""

if old_code in text:
    text = text.replace(old_code, new_code)
    with open(r'lib\tabs\ai_panel.dart', 'w', encoding='utf-8') as f:
        f.write(text)
    print("Replaced successfully!")
else:
    print("Could not find the target string!")
