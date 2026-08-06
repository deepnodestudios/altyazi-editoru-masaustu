import re

with open(r"lib\tabs\ai_panel.dart", "r", encoding="utf-8") as f:
    text = f.read()

cb_str = """
      onStartBatchTranslation: () {
        final pendingSelected = _selectedFiles
            .where((f) => !controller.activeBatchFilePaths.contains(f.path))
            .toList();
        if (pendingSelected.isNotEmpty) {
          final files = pendingSelected.map((f) => File(f.path)).toList();
          final snackMsg = (settings.trans['batch_starting_snackbar'] ??
                  '{count} dosya için Toplu Çeviri başlatılıyor...')
              .replaceAll('{count}', files.length.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(snackMsg),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
          controller.startBatchTranslationTest(
            inputSrtFiles: files,
            targetLanguage: settings.targetLanguage,
            clearSdh: settings.sdhClear,
            onFileCompleted: (file) {
              _removeFileByPath(file.path);
            },
          );
          _saveFilesList();
        }
      },
"""

if "onStartBatchTranslation:" not in text:
    text = text.replace("onStartTranslation: () => _startBulkProcess(controller),", "onStartTranslation: () => _startBulkProcess(controller),\n" + cb_str)
    with open(r"lib\tabs\ai_panel.dart", "w", encoding="utf-8") as f:
        f.write(text)
