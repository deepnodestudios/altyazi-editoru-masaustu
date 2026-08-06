import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../controllers/translation_controller.dart';
import 'layout_constants.dart';

class AiPanelFooter extends StatefulWidget {
  final AppSettings settings;
  final TranslationController controller;

  final bool selectedFilesNotEmpty;
  final String estimatedTimeText;

  const AiPanelFooter({
    super.key,
    required this.settings,
    required this.controller,
    required this.selectedFilesNotEmpty,
    required this.estimatedTimeText,
  });

  @override
  State<AiPanelFooter> createState() => _AiPanelFooterState();
}

class _AiPanelFooterState extends State<AiPanelFooter> {
  String _localizeEstimatedTimeUnit(String rawValue, String minuteShort) {
    final trimmed = rawValue.trim();
    final match = RegExp(r'^(~?\d+)\s+(.+)$').firstMatch(trimmed);
    if (match == null) return rawValue;
    final numberPart = match.group(1);
    if (numberPart == null || numberPart.isEmpty) return rawValue;
    return '$numberPart $minuteShort';
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final controller = widget.controller;
    final selectedFilesNotEmpty = widget.selectedFilesNotEmpty;
    final estimatedTimeText = widget.estimatedTimeText;

    final trans = settings.trans;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    String rightText = controller.remainingTime;
    final estimatedPrefix = trans['estimated_prefix'] ?? 'Estimated';
    final minuteShort = trans['minute_short'] ?? 'min';
    final localizedEstimatedTimeText = _localizeEstimatedTimeUnit(
      estimatedTimeText,
      minuteShort,
    );
    // İşlem başlamadıysa ve dosya seçiliyse statik tahmini göster
    if (!controller.isLoading &&
        !controller.isTranslationComplete &&
        selectedFilesNotEmpty) {
      rightText = '$estimatedPrefix: $localizedEstimatedTimeText';
    }

    // Cloud Batch modunda kalan süreyi gizle
    if (controller.isCloudBatchMode && controller.isLoading) {
      rightText = '';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // İlerleme Çubuğu ve Zamanlayıcılar
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(
              0, kAiPanelSectionGap, 0, kAiPanelSectionGap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aktif dosya adı
              if ((controller.status == TranslationStatus.running ||
                      controller.status == TranslationStatus.paused) &&
                  controller.currentFileName != null &&
                  !controller.isBatchProcessing)
                Padding(
                  padding: const EdgeInsets.only(bottom: kAiPanelSectionGap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      controller.currentFileName!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              // İlerleme Çubuğu
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: controller.progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  final rawProgress = value.clamp(0.0, 1.0);
                  const minVisibleProgress = 0.008;
                  final progressFill = rawProgress == 0
                      ? 0.0
                      : rawProgress.clamp(minVisibleProgress, 1.0);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;

                      // Ortak metin oluşturucu (Hizalamayı garanti etmek için)
                      Widget buildTexts(Color color, [List<Shadow>? shadows]) {
                        return Stack(
                          children: [
                            // Yüzde (Orta) veya Sunucu metni
                            Center(
                              child: Text(
                                controller.isTranslationComplete
                                    ? (trans['log_translation_complete'] ?? 'Çeviri Tamamlandı')
                                    : (controller.isCloudBatchMode && controller.isLoading)
                                        ? (trans['batch_cloud_processing_text'] ?? 'Çeviri sunucuda devam ediyor...')
                                        : '${(value * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  shadows: shadows,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                            // Geçen Süre (Sol)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  controller.elapsedTime,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    shadows: shadows,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Kalan Süre (Sağ)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  rightText,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    shadows: shadows,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 0),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // KATMAN 1: Boş Kısım Metinleri (Tema rengi / Siyah)
                            buildTexts(colorScheme.onSurface),

                            // KATMAN 2: Dolu Kısım ve Üzerindeki Metinler (Maskelenmiş)
                            if (progressFill > 0)
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progressFill,
                                  child: OverflowBox(
                                    maxWidth: maxWidth,
                                    minWidth: maxWidth,
                                    alignment: Alignment.centerLeft,
                                    child: Stack(
                                      children: [
                                        // Gradient Arka Plan
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.orange.shade800,
                                                Colors.green.shade600,
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                          ),
                                        ),
                                        // Siyah/Beyaz Metinler (Temaya göre)
                                        buildTexts(
                                          isDark ? Colors.white : Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
