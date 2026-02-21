import 'package:flutter/material.dart';
import 'dart:math';

import 'package:provider/provider.dart';
import 'package:altyazi_editoru/app_settings.dart';
import 'package:altyazi_editoru/models/subtitle_block.dart';
import 'package:altyazi_editoru/services/subtitle_parser.dart';
import 'package:altyazi_editoru/widgets/subtitle_preview_list.dart';

/// İşlem Tamamlandı ekranında dosya üstüne tıklanınca açılan
/// Önizleme / Kaydet / Karşılaştır sekmeli dialog.
class BatchFileDetailDialog extends StatefulWidget {
  final String fileName;
  final String translatedContent;

  /// null ise karşılaştırma sekmesi gizlenir.
  final List<SubtitleBlock>? sourceBlocks;

  const BatchFileDetailDialog({
    super.key,
    required this.fileName,
    required this.translatedContent,
    this.sourceBlocks,
  });

  @override
  State<BatchFileDetailDialog> createState() => _BatchFileDetailDialogState();
}

class _BatchFileDetailDialogState extends State<BatchFileDetailDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final ScrollController _previewScrollController = ScrollController();
  final ScrollController _compareScrollController = ScrollController();

  late final List<SubtitleBlock> _translatedBlocks;
  late final bool _hasSourceBlocks;

  @override
  void initState() {
    super.initState();
    _translatedBlocks = SubtitleParser.parseSrt(widget.translatedContent);
    _hasSourceBlocks =
        widget.sourceBlocks != null && widget.sourceBlocks!.isNotEmpty;
    _tabController = TabController(
      length: _hasSourceBlocks ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _previewScrollController.dispose();
    _compareScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── Önizleme sekmesi ───
  Widget _buildPreviewTab(ColorScheme colorScheme) {
    if (_translatedBlocks.isEmpty) {
      return Center(
        child: Text(
          '—',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SubtitlePreviewList(
      controller: _previewScrollController,
      primaryCount: _translatedBlocks.length,
      primaryRowAt: (i) {
        final b = _translatedBlocks[i];
        return SubtitlePreviewRowData(
          index: b.index,
          timecode: b.timecode,
          text: b.text,
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  // ─── Karşılaştır sekmesi ───
  Widget _buildCompareTab(
    Map<String, String> trans,
    ColorScheme colorScheme,
  ) {
    final sourceBlocks = widget.sourceBlocks!;
    final rowCount = max(sourceBlocks.length, _translatedBlocks.length);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  trans['live_view_source'] ?? 'Kaynak',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              Expanded(
                child: Text(
                  trans['live_view_translation'] ?? 'Çeviri',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _compareScrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _compareScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: rowCount,
              itemBuilder: (context, index) {
                final source =
                    index < sourceBlocks.length ? sourceBlocks[index] : null;
                final target =
                    index < _translatedBlocks.length ? _translatedBlocks[index] : null;

                final rowTimecode = source?.timecode ?? target?.timecode ?? '-';
                final rowIndex = source?.index ?? target?.index ?? (index + 1);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$rowIndex',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rowTimecode,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                source?.text.trim().isNotEmpty == true
                                    ? source!.text
                                    : '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                target?.text.trim().isNotEmpty == true
                                    ? target!.text
                                    : '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (index < rowCount - 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trans = context.read<AppSettings>().trans;
    final colorScheme = Theme.of(context).colorScheme;

    final previewLabel =
        trans['translation_preview_label']?.replaceAll(':', '').trim() ??
            'Önizleme';
    final compareLabel =
        trans['compare_with_source'] ?? 'Kaynak ile Karşılaştır';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: trans['close'] ?? 'Kapat',
                  ),
                ],
              ),
            ),
            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorColor: colorScheme.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.preview, size: 18),
                  text: previewLabel,
                ),
                if (_hasSourceBlocks)
                  Tab(
                    icon: const Icon(Icons.compare_arrows, size: 18),
                    text: compareLabel,
                  ),
              ],
            ),
            // Tab body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPreviewTab(colorScheme),
                  if (_hasSourceBlocks)
                    _buildCompareTab(trans, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
