import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:altyazi_editoru/app_settings.dart';
import '../widgets/adaptive_text.dart';
import '../widgets/cloud_source_sheet.dart';
import '../widgets/editor_text_field.dart';
import '../models/subtitle_block.dart';
import '../utils/string_utils.dart';

class EditorTab extends StatefulWidget {
  const EditorTab({super.key});

  @override
  State<EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<EditorTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isDropZoneActive = false;
  bool _isSwitchingEditorFile = false;
  final TextEditingController _replaceCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastSearchMatchIndex = -1;
  int? _hoveredEditorBlockIndex;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  Future<bool> _confirmRemoveDirtyEditorIfNeeded(
    BuildContext context,
    AppSettings settings,
  ) async {
    if (!mounted || !context.mounted) return false;

    final hasUnsavedWork = settings.isEditorDirty;
    if (!hasUnsavedWork) {
      return true;
    }

    final trans = settings.trans;

    String? decision;
    try {
      decision = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            title: Text(
              trans['editor_unsaved_warning_title'] ?? 'Kaydedilmemiş değişiklikler var',
            ),
            content: Text(
              trans['editor_unsaved_warning_body'] ??
                  'Mevcut altyazıda kaydedilmemiş değişiklikler var. Yine de kaldırmak istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                child: Text(trans['btn_cancel'] ?? 'İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('remove'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onErrorContainer,
                  backgroundColor: colorScheme.errorContainer,
                ),
                child: Text(
                  trans['editor_unsaved_discard'] ?? 'Kaydetmeden Aç',
                ),
              ),
            ],
          );
        },
      );
    } catch (_) {
      return false;
    }

    if (!mounted || !context.mounted) return false;
    return decision == 'remove';
  }

  Widget _buildFileInfo(BuildContext context, AppSettings settings) {
    if (settings.selectedEditorFile == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              _displayFileName(settings.selectedEditorFile!),
              style: TextStyle(
                fontSize: settings.editorFontSize,
                fontWeight: FontWeight.w700,
                color: Colors.orange,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withAlpha(77),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                settings.editorEncoding,
                style: TextStyle(
                    fontSize: (settings.editorFontSize * 0.75).clamp(10.0, 14.0),
                    color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmReplaceDirtyEditorIfNeeded(
    BuildContext context,
    AppSettings settings,
  ) async {
    if (!mounted || !context.mounted) return false;
    final hasUnsavedWork = settings.isEditorDirty;
    if (!hasUnsavedWork) {
      return true;
    }

    final trans = settings.trans;

    String? decision;
    try {
      decision = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            title: Text(
              trans['editor_unsaved_warning_title'] ?? 'Unsaved changes detected',
            ),
            content: Text(
              trans['editor_unsaved_warning_body'] ??
              'The current subtitle has unsaved changes. What would you like to do before opening a new file?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary.withValues(alpha: 0.78),
                ),
                child: Text(trans['btn_cancel'] ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('discard'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onErrorContainer,
                  backgroundColor: colorScheme.errorContainer,
                ),
                child: Text(trans['editor_unsaved_discard'] ?? 'Open Without Saving'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop('save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: Text(trans['btn_save'] ?? 'Kaydet'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      return false;
    }

    if (!mounted || !context.mounted) return false;

    if (decision == 'save') {
      try {
        await _saveEditorFileWithSource(context, settings);
      } catch (_) {
        return false;
      }
      if (!mounted || !context.mounted) return false;
      return !settings.isEditorDirty;
    }

    return decision == 'discard';
  }

  String? _normalizeDroppedFilePath(String rawPath) {
    final raw = rawPath.trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('file:')) {
      final uri = Uri.tryParse(raw);
      if (uri == null) return null;
      try {
        final filePath = uri.toFilePath(windows: Platform.isWindows);
        return filePath.trim().isEmpty ? null : filePath;
      } catch (_) {
        return null;
      }
    }

    var decoded = Uri.decodeFull(raw).trim();
    if (decoded.isEmpty) return null;

    if (Platform.isWindows) {
      if (RegExp(r'^/[a-zA-Z]:[/\\]').hasMatch(decoded)) {
        decoded = decoded.substring(1);
      }
      decoded = decoded.replaceAll('/', r'\');
    }

    return decoded;
  }

  Future<Uri?> _readDroppedFileUri(DropItem item) async {
    final reader = item.dataReader;
    if (reader == null) return null;

    final completer = Completer<Uri?>();
    final progress = reader.getValue<Uri>(
      Formats.fileUri,
      (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) return null;
    return completer.future;
  }

  Future<List<String>> _extractDroppedPaths(PerformDropEvent event) async {
    final unique = <String>{};
    for (final item in event.session.items) {
      final uri = await _readDroppedFileUri(item);
      if (uri == null || uri.scheme.toLowerCase() != 'file') continue;
      final normalized = _normalizeDroppedFilePath(uri.toString());
      if (normalized != null && normalized.isNotEmpty) {
        unique.add(normalized);
      }
    }
    return unique.toList(growable: false);
  }

  Future<void> _openEditorFileFromLocalPath(
    BuildContext context,
    AppSettings settings,
    String filePath,
  ) async {
    if (_isSwitchingEditorFile) return;
    _isSwitchingEditorFile = true;

    final trans = settings.trans;
    final fileName = filePath.split(RegExp(r'[\\/]')).last;

    try {
      if (!StringUtils.isSubtitleFileName(fileName)) {
        if (!context.mounted) return;
        final onlySrtVtt =
            trans['only_srt_vtt_supported'] ?? 'Only .srt / .vtt supported.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(onlySrtVtt),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final canReplace = await _confirmReplaceDirtyEditorIfNeeded(context, settings);
      if (!canReplace || !context.mounted) return;

      final result = await settings.readFileWithEncoding(filePath);
      settings.setEditorFile(
        fileName,
        result['content'] ?? '',
        encoding: result['encoding'] ?? 'UTF-8',
      );
    } catch (e) {
      if (!context.mounted) return;
      final template = trans['snackbar_file_read_error'] ??
          'File read error: {error}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(template.replaceAll('{error}', e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isSwitchingEditorFile = false;
    }
  }

  Future<void> _handleEditorDrop(
    BuildContext context,
    AppSettings settings,
    List<String> droppedPaths,
  ) async {
    final trans = settings.trans;
    if (droppedPaths.length > 1) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trans['editor_drop_single_file_warning'] ??
                'You can only drop one file into the editor.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (droppedPaths.isEmpty) return;
    await _openEditorFileFromLocalPath(context, settings, droppedPaths.first);
  }

  void _scheduleEditorDropHandling(
    AppSettings settings,
    List<String> droppedPaths,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 16), () async {
          if (!mounted) return;
          try {
            if (droppedPaths.length > 1) {
              await _handleEditorDrop(
                context,
                settings,
                const ['__MULTI__', '__MULTI__'],
              );
              return;
            }

            if (droppedPaths.isEmpty) return;

            await _handleEditorDrop(
              context,
              settings,
              <String>[droppedPaths.first],
            );
          } catch (e) {
            if (!mounted) return;
            final template = settings.trans['snackbar_file_read_error'] ??
                'File read error: {error}';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(template.replaceAll('{error}', e.toString())),
                backgroundColor: Colors.red,
              ),
            );
          }
        }),
      );
    });
  }

  String _displayFileName(String name) {
    // Eski batch kopyalama: <timestamp>_foo.srt -> foo.srt
    // Kalıcı depolama hash'ini ekranda göstermeyelim: foo_<md5>.srt -> foo.srt
    final withoutTimestamp =
        name.replaceFirst(RegExp(r'^\d{10,}_(?=.+\.[^.]+$)'), '');
    final cleaned = withoutTimestamp.replaceFirst(
      RegExp(r'_[a-f0-9]{32}(?=\.[^.]+$)', caseSensitive: false),
      '',
    );
    // Allow line breaks at dots by adding a zero-width space after each dot.
    // This makes long filenames prefer breaking at '.' instead of mid-word.
    return cleaned.replaceAll('.', '.\u200B');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _replaceCtrl.dispose();
    _scrollController.dispose();
    _editorFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showTimecodeEditDialog(
      BuildContext context, AppSettings settings, SubtitleBlock block) {
    final trans = settings.trans;
    final TextEditingController timeCtrl =
        TextEditingController(text: block.timecode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(trans["editor_edit_timecode_title"] ?? "Zaman Kodunu Düzenle"),
        content: TextField(
          controller: timeCtrl,
          decoration: InputDecoration(
            labelText: trans["editor_edit_timecode_label"] ?? "Zaman Kodu",
            hintText: "00:00:00,000 --> 00:00:00,000",
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AdaptiveText(
              trans["btn_cancel"] ?? "İptal",
              maxLines: 1,
              minFontSize: 10,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              settings.updateBlockTimecode(block, timeCtrl.text);
              Navigator.pop(ctx);
            },
            child: AdaptiveText(
              trans["btn_save"] ?? "Kaydet",
              maxLines: 1,
              minFontSize: 10,
            ),
          ),
        ],
      ),
    ).then((_) {
      // Dialog closing animation can still be using the controller.
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        timeCtrl.dispose();
      });
    });
  }

  Future<void> _showShiftTimeDialog(
    BuildContext context,
    AppSettings settings,
  ) async {
    final trans = settings.trans;
    final TextEditingController offsetCtrl = TextEditingController();
    final int? ms = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans["editor_shift_time_title"] ?? "Tüm Zamanları Kaydır"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: offsetCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: trans["editor_shift_time_label"] ?? "Süre (ms)",
                hintText: "500, -1000...",
                helperText: trans["editor_shift_time_helper"] ??
                    "Geri almak için eksi kullanın",
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(trans["btn_cancel"] ?? "İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              final int? parsedMs = int.tryParse(offsetCtrl.text);
              debugPrint('[ShiftAll] dialogApply parsedMs=$parsedMs');
              Navigator.pop(ctx, parsedMs);
            },
            child: Text(trans["btn_apply"] ?? "Uygula"),
          ),
        ],
      ),
    );

    // Dialog closing animation can still be using the controller.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      offsetCtrl.dispose();
    });

    if (!context.mounted || ms == null || ms == 0) {
      return;
    }

    debugPrint('[ShiftAll] dialogClosed applying ms=$ms');
    settings.shiftAllTimecodes(ms);
  }

  void _showRegexHelpDialog(BuildContext context, AppSettings settings) {
    final trans = settings.trans;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans["editor_regex_help_title"] ?? "Regex Hızlı Rehber"),
        content: SingleChildScrollView(
          child: MarkdownBody(data: trans["editor_regex_help_content"] ?? ""),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AdaptiveText(
              trans["ok"] ?? "Tamam",
              maxLines: 1,
              minFontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickEditorFileWithSource(
      BuildContext context, AppSettings settings) async {
    final trans = settings.trans;
    final dialogTitle = cloudSourceDialogTitle(
      CloudSource.device,
      trans,
      isSave: false,
    );
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      dialogTitle: dialogTitle,
    );
    if (res != null && res.files.single.path != null) {
      if (!context.mounted) return;
      await _openEditorFileFromLocalPath(
        context,
        settings,
        res.files.single.path!,
      );
    }
  }

  Future<void> _saveEditorFileWithSource(
      BuildContext context, AppSettings settings) async {
    final trans = settings.trans;

    String defaultName = settings.getDefaultSaveFileName(isEditorSave: true);
    String? chosenName = await showSaveNameDialog(context, defaultName, trans);
    if (chosenName == null) return;
    if (!context.mounted) return;

    final dialogTitle = cloudSourceDialogTitle(
      CloudSource.device,
      trans,
      isSave: true,
    );
    await settings.saveResult(
      isEditorSave: true,
      dialogTitle: dialogTitle,
      customFileName: chosenName,
    );
  }

  Widget _buildTopControls(
      BuildContext context, AppSettings settings, Map<String, String> trans) {
    const double topButtonHeight = 48;
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          Row(
            children: [
              // Dosya Seç
              Expanded(
                child: SizedBox(
                  height: topButtonHeight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_open, size: 20),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AdaptiveText(
                          trans["cloud_source_pick"] ?? "Dosya Seç",
                          maxLines: 1,
                          minFontSize: 10,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'SRT - VTT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () async {
                      await _pickEditorFileWithSource(context, settings);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Kaldır / Kapat
              Expanded(
                child: SizedBox(
                  height: topButtonHeight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.close, size: 20),
                    label: AdaptiveText(
                      trans["editor_close_tooltip"] ?? "Kapat",
                      maxLines: 1,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: settings.selectedEditorFile != null
                        ? () async {
                            final allowRemove =
                                await _confirmRemoveDirtyEditorIfNeeded(
                                    context, settings);
                            if (!mounted || !context.mounted || !allowRemove) {
                              return;
                            }
                            settings.clearEditorFile();
                          }
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Kaydet
              Expanded(
                child: SizedBox(
                  height: topButtonHeight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 20),
                    label: AdaptiveText(
                      trans["editor_save_tooltip"] ?? "Kaydet",
                      maxLines: 1,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: settings.isEditorDirty
                        ? () => _saveEditorFileWithSource(context, settings)
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // Araç Çubuğu (Zaman Kaydır, Undo, Redo, Zoom) - Her zaman görünür
          Row(
            children: [
              // SDH Temizle Butonu
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(trans["clear_sdh"] ?? "SDH Temizle"),
                  ),
                  onPressed: settings.selectedEditorFile != null
                      ? () {
                          settings.cleanSdhInEditor();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(trans["log_sdh_complete"] ?? "SDH Temizliği Tamamlandı"),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(128)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                flex: 3,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.timer, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                          trans["editor_shift_time_tooltip"] ?? "Zaman Kaydır"),
                    ),
                    onPressed: settings.selectedEditorFile != null
                        ? () => _showShiftTimeDialog(context, settings)
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(128)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Geri Al / Yinele
              Expanded(
                child: Tooltip(
                  message: trans["editor_undo_tooltip"] ?? "Geri Al",
                  child: OutlinedButton(
                    onPressed: (settings.selectedEditorFile != null &&
                            settings.canUndo)
                        ? settings.undo
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(128)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.undo, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Tooltip(
                  message: trans["editor_redo_tooltip"] ?? "Yinele",
                  child: OutlinedButton(
                    onPressed: (settings.selectedEditorFile != null &&
                            settings.canRedo)
                        ? settings.redo
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(128)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.redo, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Yakınlaştır / Uzaklaştır
              Expanded(
                child: Tooltip(
                  message: trans["editor_zoom_out_tooltip"] ?? "Küçült",
                  child: OutlinedButton(
                    onPressed: settings.selectedEditorFile != null
                        ? settings.decreaseEditorFontSize
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(128)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.remove_circle_outline, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Tooltip(
                  message: trans["editor_zoom_in_tooltip"] ?? "Büyüt",
                  child: OutlinedButton(
                    onPressed: settings.selectedEditorFile != null
                        ? settings.increaseEditorFontSize
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(128)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(BuildContext context, AppSettings settings,
      Map<String, String> trans, bool isRegexError) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: trans["editor_search_hint"] ?? "Aranacak...",
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: settings.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              settings.updateSearchQuery("");
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    enabledBorder: isRegexError
                        ? const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red))
                        : null,
                    focusedBorder: isRegexError
                        ? const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2))
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  ),
                  onChanged: (val) => settings.updateSearchQuery(val),
                ),
              ),
              if (settings.totalSearchMatches > 0) ...[
                const SizedBox(width: 8),
                Text(
                    "${settings.currentSearchMatchIndex + 1}/${settings.totalSearchMatches}",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  tooltip: trans['editor_search_prev_tooltip'] ?? 'Previous',
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    settings.prevSearchMatch();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  tooltip: trans['editor_search_next_tooltip'] ?? 'Next',
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    settings.nextSearchMatch();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.abc,
                    color:
                        settings.isCaseSensitive ? Colors.green : Colors.grey),
                tooltip: trans['editor_case_sensitive_tooltip'] ?? 'Case Sensitive',
                onPressed: () =>
                    settings.toggleCaseSensitivity(!settings.isCaseSensitive),
              ),
              IconButton(
                icon: Icon(Icons.code,
                    color: settings.isRegexSearch ? Colors.green : Colors.grey),
                tooltip: trans["editor_regex_tooltip"] ?? "Regex",
                onPressed: () =>
                    settings.toggleRegexSearch(!settings.isRegexSearch),
              ),
              if (settings.isRegexSearch)
                IconButton(
                  icon: const Icon(Icons.help_outline,
                      size: 20, color: Colors.grey),
                  tooltip: trans["editor_regex_help_title"] ?? "Regex Yardım",
                  onPressed: () => _showRegexHelpDialog(context, settings),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replaceCtrl,
                  decoration: InputDecoration(
                    hintText: trans["editor_replace_hint"] ?? "Yeni Değer...",
                    isDense: true,
                    prefixIcon: const Icon(Icons.edit, size: 20),
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  int count = settings.replaceSingleInEditor(_replaceCtrl.text);
                  if (count > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text((trans["editor_replaced_count"] ??
                                  "{count} changes made")
                              .replaceAll("{count}", count.toString())),
                          duration: const Duration(seconds: 2)),
                    );
                  }
                  if (settings.filteredEditorBlocks.isEmpty) {
                    _searchCtrl.clear();
                    _replaceCtrl.clear();
                    settings.updateSearchQuery("");
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
                child: AdaptiveText(
                  trans["editor_replace_btn"] ?? "Değiştir",
                  maxLines: 1,
                  minFontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  int count = settings.replaceAllInEditor(_replaceCtrl.text);
                  if (count > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text((trans["editor_replaced_count"] ??
                                  "{count} changes made")
                              .replaceAll("{count}", count.toString())),
                          duration: const Duration(seconds: 2)),
                    );
                  }
                  if (settings.filteredEditorBlocks.isEmpty) {
                    _searchCtrl.clear();
                    _replaceCtrl.clear();
                    settings.updateSearchQuery("");
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
                child: AdaptiveText(
                  trans["editor_replace_all_btn"] ?? "Tümü",
                  maxLines: 1,
                  minFontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorList(
      BuildContext context, AppSettings settings, Map<String, String> trans) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final filteredBlocks = settings.filteredEditorBlocks;
    if (settings.selectedEditorFile == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(26)),
              const SizedBox(height: 16),
              Text(
                trans["editor_empty_state_title"] ?? "",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              MarkdownBody(
                data: trans["editor_empty_state_desc"] ?? "",
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  strong: const TextStyle(
                      color: Colors.orangeAccent, fontWeight: FontWeight.w600),
                  h3: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: filteredBlocks.length,
        itemBuilder: (context, index) {
        final block = filteredBlocks[index];
        final bool isCurrentMatch = settings.currentMatchedBlockIndex != -1 &&
            settings.currentMatchedBlockIndex < settings.editorBlocks.length &&
            settings.editorBlocks[settings.currentMatchedBlockIndex] == block;
        final bool isHovered = isDesktop && _hoveredEditorBlockIndex == index;
        final ColorScheme colorScheme = Theme.of(context).colorScheme;

        return MouseRegion(
          onEnter: (_) {
            if (!isDesktop || _hoveredEditorBlockIndex == index) return;
            setState(() => _hoveredEditorBlockIndex = index);
          },
          onExit: (_) {
            if (!isDesktop || _hoveredEditorBlockIndex != index) return;
            setState(() => _hoveredEditorBlockIndex = null);
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: isHovered ? 2.0 : 1.0,
            color: isCurrentMatch
                ? colorScheme.primaryContainer.withAlpha(95)
                : (isHovered
                    ? colorScheme.surfaceContainerHigh.withAlpha(180)
                    : null),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    InkWell(
                      hoverColor: colorScheme.primary.withValues(alpha: 0.08),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: block.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(trans["editor_line_copied"] ??
                                  "Metin panoya kopyalandı"),
                              duration: const Duration(seconds: 1)),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withAlpha(77),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: AdaptiveText(
                          block.index.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                          maxLines: 1,
                          minFontSize: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                          color: Theme.of(context)
                            .dividerColor
                            .withAlpha((0.5 * 255).round())),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            hoverColor:
                              colorScheme.primary.withValues(alpha: 0.08),
                            onTap: () => settings.shiftBlockTimecode(
                                block, -100), // -100ms
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(6)),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(Icons.remove,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          InkWell(
                            hoverColor:
                              colorScheme.primary.withValues(alpha: 0.08),
                            onTap: () => _showTimecodeEditDialog(
                                context, settings, block),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: AdaptiveText(
                                block.timecode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                minFontSize: 8,
                              ),
                            ),
                          ),
                          InkWell(
                            hoverColor:
                              colorScheme.primary.withValues(alpha: 0.08),
                            onTap: () => settings.shiftBlockTimecode(
                                block, 100), // +100ms
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(6)),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(Icons.add,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          size: 18, color: Colors.redAccent),
                      tooltip:
                          trans["editor_delete_line_tooltip"] ?? "Satırı Sil",
                      onPressed: () => settings.deleteBlock(block),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                  EditorTextField(
                    initialText: block.text,
                    onChanged: (val) => settings.updateBlockText(block, val),
                    searchQuery: _searchCtrl.text,
                    isCaseSensitive: settings.isCaseSensitive,
                    isRegexSearch: settings.isRegexSearch,
                    fontSize: settings.editorFontSize,
                    isCurrentMatch: isCurrentMatch,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final trans = settings.trans;
    final width = MediaQuery.of(context).size.width;
    final bool isTablet = width > 750;
    final bool isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    const double desktopPaneWidth = 470;
    const double desktopSplitFrameWidth = 980;
    final bool useFixedDesktopSplit =
      isDesktop && width >= desktopSplitFrameWidth;

    // Regex validasyon kontrolü
    bool isRegexError = false;
    if (settings.isRegexSearch && settings.searchQuery.isNotEmpty) {
      try {
        RegExp(settings.searchQuery);
      } catch (_) {
        isRegexError = true;
      }
    }

    // Otomatik kaydırma mantığı
    if (settings.currentSearchMatchIndex != -1 &&
        settings.currentSearchMatchIndex != _lastSearchMatchIndex) {
      _lastSearchMatchIndex = settings.currentSearchMatchIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Tahmini yükseklik: 150 piksel (Kart + Padding)
          double itemHeight = 150.0;
          double viewportHeight = _scrollController.position.viewportDimension;
          double offset = (_lastSearchMatchIndex * itemHeight) -
              (viewportHeight / 2) +
              (itemHeight / 2);

          if (offset < 0) offset = 0;
          if (offset > _scrollController.position.maxScrollExtent) {
            offset = _scrollController.position.maxScrollExtent;
          }
          _scrollController.animateTo(offset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        }
      });
    }

    // Editör Arayüzü
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Ctrl+S — Kaydet
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (settings.isEditorDirty) {
            _saveEditorFileWithSource(context, settings);
          }
        },
        // Ctrl+Shift+S — Farklı Kaydet
        const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () {
          if (settings.selectedEditorFile != null) {
            _saveEditorFileWithSource(context, settings);
          }
        },
        // Ctrl+O — Dosya Aç
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          _pickEditorFileWithSource(context, settings);
        },
        // Ctrl+Z — Geri Al
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (settings.selectedEditorFile != null && settings.canUndo) {
            settings.undo();
          }
        },
        // Ctrl+Y — Yinele
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          if (settings.selectedEditorFile != null && settings.canRedo) {
            settings.redo();
          }
        },
        // Ctrl+Shift+Z — Yinele (alternatif)
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
          if (settings.selectedEditorFile != null && settings.canRedo) {
            settings.redo();
          }
        },
        // Ctrl+F — Arama alanına odaklan
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (settings.selectedEditorFile != null) {
            _searchFocusNode.requestFocus();
          }
        },
        // Ctrl+= / Ctrl+Plus — Zoom in
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () {
          if (settings.selectedEditorFile != null) {
            settings.increaseEditorFontSize();
          }
        },
        // Ctrl+Minus — Zoom out
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () {
          if (settings.selectedEditorFile != null) {
            settings.decreaseEditorFontSize();
          }
        },
      },
      child: Focus(
        autofocus: true,
        focusNode: _editorFocusNode,
        child: DropRegion(
          formats: const [Formats.fileUri],
          onDropOver: (event) {
            if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              return DropOperation.none;
            }
            if (!_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = true);
            }
            if (event.session.allowedOperations.contains(DropOperation.copy)) {
              return DropOperation.copy;
            }
            if (event.session.allowedOperations.contains(DropOperation.move)) {
              return DropOperation.move;
            }
            return DropOperation.none;
          },
          onDropLeave: (_) {
            if (_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = false);
            }
          },
          onDropEnded: (_) {
            if (_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = false);
            }
          },
          onPerformDrop: (event) async {
            if (_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = false);
            }
            if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              return;
            }
            try {
              final droppedPaths = await _extractDroppedPaths(event);
              if (!mounted) return;
              _scheduleEditorDropHandling(settings, droppedPaths);
            } catch (e) {
              if (!mounted) return;
              final template = settings.trans['snackbar_file_read_error'] ??
                  'File read error: {error}';
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(template.replaceAll('{error}', e.toString())),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Stack(
                children: [
                Column(
                  children: [
                    Expanded(
                        child: useFixedDesktopSplit
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: desktopPaneWidth,
                                    child: Column(
                                      children: [
                                        _buildTopControls(context, settings, trans),
                                        if (settings.selectedEditorFile != null) ...[
                                          _buildSearchPanel(
                                            context,
                                            settings,
                                            trans,
                                            isRegexError,
                                          ),
                                          _buildFileInfo(context, settings),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const VerticalDivider(width: 1, thickness: 1),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: _buildEditorList(context, settings, trans),
                                    ),
                                  ),
                                ],
                              )
                            : isTablet
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 400,
                                        child: Column(
                                          children: [
                                            _buildTopControls(context, settings, trans),
                                            if (settings.selectedEditorFile != null) ...[
                                              _buildSearchPanel(
                                                  context, settings, trans, isRegexError),
                                              _buildFileInfo(context, settings),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const VerticalDivider(width: 1),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: _buildEditorList(context, settings, trans),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildTopControls(context, settings, trans),
                                      if (settings.selectedEditorFile != null) ...[
                                        _buildSearchPanel(
                                            context, settings, trans, isRegexError),
                                        _buildFileInfo(context, settings),
                                      ],
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: _buildEditorList(context, settings, trans),
                                        ),
                                      ),
                                    ],
                                  )),
                  ],
                ),
          
                  if (_isDropZoneActive)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08),
                        ),
                      ),
                    ),
          
                  // Loading overlay when bringing a project into the editor.
                  if (settings.isOpeningEditor)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: false,
                        child: Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      trans["editor_loading"] ?? "Editör yükleniyor…",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: settings.editorOpenProgress.clamp(0.0, 1.0),
                                      minHeight: 8,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${(settings.editorOpenProgress * 100).clamp(0, 100).toStringAsFixed(0)}%",
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
