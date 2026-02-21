import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../repositories/subtitle_repository.dart';
import '../../services/subtitle_parser.dart';
import '../subtitle_preview_list.dart';

class AiPanelFileContentPreviewPanel extends StatefulWidget {
  final Map<String, String> trans;
  final String filePath;
  final String fileName;
  final VoidCallback? onClose;
  final bool useCardDecoration;
  final bool showBottomCloseButton;

  const AiPanelFileContentPreviewPanel({
    super.key,
    required this.trans,
    required this.filePath,
    required this.fileName,
    this.onClose,
    this.useCardDecoration = true,
    this.showBottomCloseButton = false,
  });

  @override
  State<AiPanelFileContentPreviewPanel> createState() =>
      _AiPanelFileContentPreviewPanelState();
}

class _AiPanelFileContentPreviewPanelState
    extends State<AiPanelFileContentPreviewPanel> {
  final SubtitleRepository _subtitleRepo = SubtitleRepository();
  final ScrollController _scrollController = ScrollController();
  static final Map<String, Future<({
    String content,
    String encoding,
    bool truncated,
    int totalBytes,
  })>> _previewContentCache =
      <String, Future<({
        String content,
        String encoding,
        bool truncated,
        int totalBytes,
      })>>{};
  static final Map<String, Future<List<_PreviewRow>>> _fullRowsCache =
      <String, Future<List<_PreviewRow>>>{};
  static final Queue<String> _preloadQueue = Queue<String>();
  static final Set<String> _queuedPreloadPaths = <String>{};
  static final int _maxPreloadWorkers = _resolvePreloadWorkerCount();
  static int _activePreloadWorkers = 0;

  String _encoding = '';
  List<_PreviewRow> _rows = const <_PreviewRow>[];
  bool _isLoading = true;
  Object? _error;

  Future<({
    String content,
    String encoding,
    bool truncated,
    int totalBytes,
  })> _loadFullPreview(String filePath) async {
    final full = await _subtitleRepo.readFileWithEncoding(filePath);
    final totalBytes = await File(filePath).length();
    return (
      content: full.content,
      encoding: full.encoding,
      truncated: false,
      totalBytes: totalBytes,
    );
  }

  Future<({String content, String encoding, bool truncated, int totalBytes})>
      _getPreviewContentFuture(String filePath) {
    return _previewContentCache.putIfAbsent(
      filePath,
      () => _loadFullPreview(filePath),
    );
  }

  Future<List<_PreviewRow>> _getFullRowsFuture(
    String filePath,
    String content,
  ) {
    return _fullRowsCache.putIfAbsent(
      filePath,
      () => Isolate.run<List<_PreviewRow>>(
        () => _parseRowsForPreview(content),
      ),
    );
  }

  Future<void> _loadAndPreparePreview(String filePath) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _rows = const <_PreviewRow>[];
    });

    try {
      final preview = await _getPreviewContentFuture(filePath);
      if (!mounted || widget.filePath != filePath) return;

      final fullRows = await _getFullRowsFuture(filePath, preview.content);
      if (!mounted || widget.filePath != filePath) return;

      setState(() {
        _encoding = preview.encoding;
        _rows = fullRows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || widget.filePath != filePath) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadAndPreparePreview(widget.filePath));
  }

  @override
  void didUpdateWidget(covariant AiPanelFileContentPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      unawaited(_loadAndPreparePreview(widget.filePath));
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.fileName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: widget.trans['close'] ?? 'Kapat',
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
                  ? Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        (widget.trans['error_with_details'] ?? 'Error: {error}')
                            .replaceAll('{error}', '$_error'),
                        style: TextStyle(color: colorScheme.error),
                      ),
                    )
                  : (_rows.isEmpty)
                      ? Center(
                          child: Text(
                            widget.trans['empty_translation_list_hint'] ??
                                'Preview not available.',
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        )
                      : Column(
                          children: [
                            if (_encoding.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                color: colorScheme.surfaceContainerLow,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.code,
                                      size: 16,
                                      color: colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        (widget.trans['encoding_label'] ??
                                                'Encoding: {encoding}')
                                            .replaceAll(
                                              '{encoding}',
                                              _encoding,
                                            ),
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: SubtitlePreviewList(
                                controller: _scrollController,
                                primaryCount: _rows.length,
                                primaryRowAt: (i) {
                                  final row = _rows[i];
                                  return SubtitlePreviewRowData(
                                    index: row.index,
                                    timecode: row.timecode,
                                    text: row.text,
                                  );
                                },
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
        ),
        if (widget.showBottomCloseButton && widget.onClose != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: widget.onClose,
                child: Text(widget.trans['close'] ?? 'Kapat'),
              ),
            ),
          ),
      ],
    );

    if (!widget.useCardDecoration) return content;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  static int _resolvePreloadWorkerCount() {
    // Full-file reads + SRT parsing are CPU-heavy. Keeping preload concurrency
    // low avoids UI jank while the user scrolls the sidebar.
    final cpuCount = Platform.numberOfProcessors;
    if (cpuCount <= 4) return 1;
    return 2;
  }

  static void _startPreloadWorkersIfNeeded() {
    while (_activePreloadWorkers < _maxPreloadWorkers &&
        _preloadQueue.isNotEmpty) {
      _activePreloadWorkers += 1;
      unawaited(_runFullPreloadWorker());
    }
  }

  static Future<void> _runFullPreloadWorker() async {
    try {
      while (_preloadQueue.isNotEmpty) {
        final filePath = _preloadQueue.removeFirst();
        _queuedPreloadPaths.remove(filePath);

        try {
          final previewFuture = _previewContentCache.putIfAbsent(
            filePath,
            () async {
              final full = await SubtitleRepository().readFileWithEncoding(
                filePath,
              );
              final totalBytes = await File(filePath).length();
              return (
                content: full.content,
                encoding: full.encoding,
                truncated: false,
                totalBytes: totalBytes,
              );
            },
          );

          final preview = await previewFuture;

          await _fullRowsCache.putIfAbsent(
            filePath,
            () => Isolate.run<List<_PreviewRow>>(
              () => _parseRowsForPreview(preview.content),
            ),
          );
        } catch (_) {
          _previewContentCache.remove(filePath);
          _fullRowsCache.remove(filePath);
        }

        // Give the UI thread breathing room between heavy files.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _activePreloadWorkers = (_activePreloadWorkers - 1).clamp(0, 9999);
      _startPreloadWorkersIfNeeded();
    }
  }
}

List<_PreviewRow> _parseRowsForPreview(String content) {
  final blocks = SubtitleParser.parseSrt(content);
  return blocks
      .map(
        (block) => _PreviewRow(
          index: block.index,
          timecode: block.timecode,
          text: block.text.replaceAll('\n', ' ').trim(),
        ),
      )
      .toList(growable: false);
}

void preloadAiPanelFileContentPreview(String filePath) {
  if (filePath.isEmpty) return;

  if (_AiPanelFileContentPreviewPanelState._fullRowsCache
          .containsKey(filePath) ||
      _AiPanelFileContentPreviewPanelState._previewContentCache
          .containsKey(filePath)) {
    return;
  }

  if (_AiPanelFileContentPreviewPanelState._queuedPreloadPaths.add(filePath)) {
    _AiPanelFileContentPreviewPanelState._preloadQueue.add(filePath);
    _AiPanelFileContentPreviewPanelState._startPreloadWorkersIfNeeded();
  }
}

class _PreviewRow {
  final int index;
  final String timecode;
  final String text;

  const _PreviewRow({
    required this.index,
    required this.timecode,
    required this.text,
  });
}

Future<void> showAiPanelFileContentDialog({
  required BuildContext context,
  required Map<String, String> trans,
  required String filePath,
  required String fileName,
}) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          trans['file_not_found_short'] ?? 'File not found',
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
        backgroundColor: colorScheme.errorContainer,
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final media = MediaQuery.of(ctx).size;

      return Dialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: (media.width * 0.8).clamp(360.0, 980.0),
          height: (media.height * 0.82).clamp(360.0, 900.0),
          child: AiPanelFileContentPreviewPanel(
            trans: trans,
            filePath: filePath,
            fileName: fileName,
            onClose: () => Navigator.pop(ctx),
            useCardDecoration: false,
            showBottomCloseButton: true,
          ),
        ),
      );
    },
  );
}
