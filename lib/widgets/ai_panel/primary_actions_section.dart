import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../controllers/translation_controller.dart';
import '../../services/token_wallet_math.dart';
import 'layout_constants.dart';

String walletUiStartLabel(
  Map<String, String> trans,
  bool tokenUi, {
  bool willChargeFileCredit = false,
  int estimatedTokens = 0,
}) {
  final start = trans['start_translation'] ?? 'Start Translation';
  String tokenLabel() {
    if (estimatedTokens <= 0) return start;
    final tokens = formatTokenCount(estimatedTokens, grouping: '.');
    final unit = trans['wallet_token_label'] ?? 'Token';
    return '$start ($tokens $unit)';
  }

  if (tokenUi && willChargeFileCredit) {
    return '$start (1 ${trans['credit'] ?? 'Credit'})';
  }
  if (tokenUi) {
    return tokenLabel();
  }
  return '$start (1 ${trans['credit'] ?? 'Credit'})';
}

class AiPanelPrimaryActionsSection extends StatelessWidget {
  final AppSettings settings;
  final TranslationController controller;

  final bool isBulkProcessing;
  final int selectedFilesCount;
  final int estimatedTokenTotal;

  final VoidCallback onSave;
  final VoidCallback onNewTranslation;
  final VoidCallback onStartTranslation;
  final VoidCallback onStartBatchTranslation;
  final Future<void> Function() onPauseOrResume;
  final Future<void> Function() onStop;

  const AiPanelPrimaryActionsSection({
    super.key,
    required this.settings,
    required this.controller,
    required this.isBulkProcessing,
    required this.selectedFilesCount,
    this.estimatedTokenTotal = 0,
    required this.onSave,
    required this.onNewTranslation,
    required this.onStartTranslation,
    required this.onStartBatchTranslation,
    required this.onPauseOrResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledBg = isDark ? Colors.grey.shade800 : Colors.grey.shade400;
    final disabledFg = isDark ? Colors.grey.shade500 : Colors.grey.shade600;

    if (controller.isTranslationComplete) {
      return const SizedBox.shrink();
    }

    if (controller.isLoading || isBulkProcessing) {
      final isClientSideRunning = !controller.isCloudBatchMode;
      
      if (isClientSideRunning) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: kAiPanelPrimaryButtonHeight,
                    child: ElevatedButton.icon(
                      onPressed: () => onPauseOrResume(),
                      icon: Icon(
                        controller.status == TranslationStatus.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                        size: 18,
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
                const SizedBox(width: kAiPanelInlineGap),
                Expanded(
                  child: SizedBox(
                    height: kAiPanelPrimaryButtonHeight,
                    child: ElevatedButton.icon(
                      onPressed: () => onStop(),
                      icon: const Icon(Icons.stop, size: 18),
                      label: Text(settings.trans['stop'] ?? 'Durdur'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
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
            ),
            const SizedBox(height: kAiPanelSectionGap),
          ],
        );
      }
    }

    final canStartNormal = !(controller.isLoading || isBulkProcessing) && selectedFilesCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: kAiPanelPrimaryButtonHeight,
                child: ElevatedButton.icon(
                  onPressed: canStartNormal ? onStartTranslation : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: AutoSizeText(
                      walletUiStartLabel(
                        settings.trans,
                        controller.showTokenWalletUi,
                        willChargeFileCredit:
                            controller.showTokenWalletUi &&
                                controller.displayFileCredits > 0,
                        estimatedTokens: estimatedTokenTotal,
                      ),
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
          ],
        ),
        const SizedBox(height: kAiPanelSectionGap),
      ],
    );
  }
}
