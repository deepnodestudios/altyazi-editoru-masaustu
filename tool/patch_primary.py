import codecs
with codecs.open(r"lib\widgets\ai_panel\primary_actions_section.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("final VoidCallback onStartTranslation;", "final VoidCallback onStartTranslation;\n  final VoidCallback onStartBatchTranslation;")
text = text.replace("required this.onStartTranslation,", "required this.onStartTranslation,\n    required this.onStartBatchTranslation,")

button_code = """
    final canStart = !(controller.isLoading || isBulkProcessing || selectedFilesCount == 0);
    final bool canStartBatch = selectedFilesCount > 1 && canStart && !controller.isCloudBatchMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: kAiPanelPrimaryButtonHeight,
                child: ElevatedButton.icon(
                  onPressed: canStart ? onStartTranslation : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: AutoSizeText(
                      '${settings.trans['start_translation'] ?? 'Çeviriyi Başlat'} (1 ${settings.trans['credit'] ?? 'Kredi'})',
                      maxLines: 1,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: disabledBg,
                    disabledForegroundColor: disabledFg,
                    elevation: 3,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
                    ),
                  ),
                ),
              ),
            ),
            if (selectedFilesCount > 1) ...[
              const SizedBox(width: kAiPanelInlineGap),
              Expanded(
                child: SizedBox(
                  height: kAiPanelPrimaryButtonHeight,
                  child: ElevatedButton.icon(
                    onPressed: canStartBatch ? onStartBatchTranslation : null,
                    icon: const Icon(Icons.batch_prediction, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: AutoSizeText(
                        settings.trans['batch_translation_beta'] ?? 'Toplu Çeviri',
                        maxLines: 1,
                        minFontSize: 10,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: disabledBg,
                      disabledForegroundColor: disabledFg,
                      elevation: 3,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: kAiPanelSectionGap),
      ],
    );
"""

start_idx = text.find("final canStart =")
text = text[:start_idx] + button_code + "  }\n}\n"

with codecs.open(r"lib\widgets\ai_panel\primary_actions_section.dart", "w", encoding="utf-8") as f:
    f.write(text)
