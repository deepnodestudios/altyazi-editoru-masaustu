import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../controllers/translation_controller.dart';
import 'layout_constants.dart';

class AiPanelPrimaryActionsSection extends StatelessWidget {
  final AppSettings settings;
  final TranslationController controller;

  final bool isBulkProcessing;
  final int selectedFilesCount;

  final VoidCallback onSave;
  final VoidCallback onNewTranslation;
  final VoidCallback onStartTranslation;
  final Future<void> Function() onPauseOrResume;
  final Future<void> Function() onStop;

  const AiPanelPrimaryActionsSection({
    super.key,
    required this.settings,
    required this.controller,
    required this.isBulkProcessing,
    required this.selectedFilesCount,
    required this.onSave,
    required this.onNewTranslation,
    required this.onStartTranslation,
    required this.onPauseOrResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabledBg = colorScheme.surfaceContainerHighest;
    final disabledFg = colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    if (controller.isTranslationComplete) {
      return const SizedBox.shrink();
    }

    if (controller.isLoading || isBulkProcessing) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onPauseOrResume(),
                  icon: Icon(
                    controller.status == TranslationStatus.paused
                        ? Icons.play_arrow
                        : Icons.pause,
                    size: 20,
                  ),
                  label: Text(
                    controller.status == TranslationStatus.paused
                        ? (settings.trans['resume'] ?? 'Devam Et')
                        : (settings.trans['pause'] ?? 'Duraklat'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: controller.status == TranslationStatus.paused
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onStop(),
                  icon: const Icon(Icons.stop, size: 20),
                  label: Text(settings.trans['stop'] ?? 'Durdur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kAiPanelSectionGap),
        ],
      );
    }

    final canStart = !(controller.isLoading || isBulkProcessing || selectedFilesCount == 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: canStart ? onStartTranslation : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: disabledBg,
                  disabledForegroundColor: disabledFg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
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
            ),
          ],
        ),
        const SizedBox(height: kAiPanelSectionGap),
      ],
    );
  }
}
