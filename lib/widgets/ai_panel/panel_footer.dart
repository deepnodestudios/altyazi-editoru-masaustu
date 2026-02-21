import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_settings.dart';
import '../../controllers/translation_controller.dart';
import '../adaptive_text.dart';

class AiPanelFooter extends StatefulWidget {
  final AppSettings settings;
  final TranslationController controller;

  final bool selectedFilesNotEmpty;
  final String estimatedTimeText;

  final bool isLogExpanded;
  final VoidCallback onToggleLogExpanded;

  const AiPanelFooter({
    super.key,
    required this.settings,
    required this.controller,
    required this.selectedFilesNotEmpty,
    required this.estimatedTimeText,
    required this.isLogExpanded,
    required this.onToggleLogExpanded,
  });

  @override
  State<AiPanelFooter> createState() => _AiPanelFooterState();
}

class _AiPanelFooterState extends State<AiPanelFooter> {
  final ScrollController _logScrollController = ScrollController();
  bool _shouldAutoScrollLogs = true;

  String _localizeEstimatedTimeUnit(String rawValue, String minuteShort) {
    final trimmed = rawValue.trim();
    final match = RegExp(r'^(~?\d+)\s+(.+)$').firstMatch(trimmed);
    if (match == null) return rawValue;
    final numberPart = match.group(1);
    if (numberPart == null || numberPart.isEmpty) return rawValue;
    return '$numberPart $minuteShort';
  }

  void _handleLogScrollChanged() {
    if (!_logScrollController.hasClients) return;
    final position = _logScrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    const threshold = 24.0;
    _shouldAutoScrollLogs = distanceToBottom <= threshold;
  }

  void _scrollLogsToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_logScrollController.hasClients) return;
      _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
    });
  }

  @override
  void initState() {
    super.initState();
    _logScrollController.addListener(_handleLogScrollChanged);
    if (widget.isLogExpanded) {
      _shouldAutoScrollLogs = true;
      _scrollLogsToLatest();
    }
  }

  @override
  void didUpdateWidget(covariant AiPanelFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final expandedNow = widget.isLogExpanded;
    final wasExpanded = oldWidget.isLogExpanded;
    final logsChanged = widget.settings.logs.length != oldWidget.settings.logs.length;
    if (expandedNow && !wasExpanded) {
      _shouldAutoScrollLogs = true;
      _scrollLogsToLatest();
      return;
    }

    if (expandedNow && logsChanged && _shouldAutoScrollLogs) {
      _scrollLogsToLatest();
    }
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final controller = widget.controller;
    final selectedFilesNotEmpty = widget.selectedFilesNotEmpty;
    final estimatedTimeText = widget.estimatedTimeText;
    final isLogExpanded = widget.isLogExpanded;
    final onToggleLogExpanded = widget.onToggleLogExpanded;

    final trans = settings.trans;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    void copyAllLogsToClipboard() {
      if (settings.logs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trans['system_log_empty'] ?? 'Sistem günlüğünde kopyalanacak kayıt yok.',
            ),
          ),
        );
        return;
      }

        final allLogs = settings.logs
          .reversed
          .map((log) => settings.formatLogLine(log))
          .join('\n');

      Clipboard.setData(ClipboardData(text: allLogs));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trans['system_log_copied'] ?? 'Sistem günlüğü panoya kopyalandı.',
          ),
        ),
      );
    }

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // İlerleme Çubuğu ve Zamanlayıcılar
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aktif dosya adı
              if ((controller.status == TranslationStatus.running ||
                      controller.status == TranslationStatus.paused) &&
                  controller.currentFileName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
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
                            // Yüzde (Orta)
                            Center(
                              child: Text(
                                '${(value * 100).toStringAsFixed(1)}%',
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
                              offset: const Offset(0, 1),
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isLogExpanded ? MediaQuery.of(context).size.height * 0.33 : 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 5,
                color: Theme.of(context)
                    .colorScheme
                    .shadow
                    .withValues(alpha: 0.12),
                offset: const Offset(0, -2),
              )
            ],
          ),
          child: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: InkWell(
                  onTap: onToggleLogExpanded,
                  child: Container(
                    height: 49,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                isLogExpanded
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_up,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              AdaptiveText(
                                trans['system_log'] ?? 'Sistem Günlüğü',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                minFontSize: 10,
                              ),
                            ],
                          ),
                        ),
                        if (!isLogExpanded && settings.logs.isNotEmpty)
                          Expanded(
                            child: AdaptiveText(
                              settings.formatLogLine(
                                settings.logs.first,
                                includeTime: false,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              minFontSize: 8,
                            ),
                          ),
                        if (isLogExpanded)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_all),
                                tooltip: trans['copy'] ?? 'Kopyala',
                                onPressed: copyAllLogsToClipboard,
                              ),
                              IconButton(
                                icon: const Icon(Icons.save_alt),
                                tooltip: trans['save_log'],
                                onPressed: () => settings.saveLogsToFile(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isLogExpanded)
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    width: double.infinity,
                    child: SelectionArea(
                      child: SingleChildScrollView(
                        controller: _logScrollController,
                        padding: const EdgeInsets.all(8),
                        child: SelectableText(
                            settings.logs
                              .reversed
                              .map((log) => settings.formatLogLine(log))
                              .join('\n'),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Courier',
                            color: Theme.of(context).colorScheme.primary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
