import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:altyazi_editoru/app_settings.dart';
import 'package:altyazi_editoru/models/subtitle_block.dart';
import 'package:altyazi_editoru/utils/string_utils.dart';
import 'package:altyazi_editoru/widgets/batch_file_detail_dialog.dart';


class BatchSaveDialog extends StatefulWidget {
  final Map<String, String> results;

  const BatchSaveDialog({super.key, required this.results});

  @override
  State<BatchSaveDialog> createState() => _BatchSaveDialogState();
}

class _BatchSaveDialogState extends State<BatchSaveDialog> {
  bool _isSavingAll = false;
  int? _savingIndex;

  final Set<int> _selectedIndices = <int>{};
  int? _lastSelectedIndex;

  bool _isMarqueeSelecting = false;
  Offset? _marqueeStartGlobal;
  Offset? _marqueeStartLocal;
  Offset? _marqueeCurrentLocal;
  Set<int> _marqueeInitialSelectedIndices = <int>{};

  final Map<int, GlobalKey> _tileKeys = <int, GlobalKey>{};
  final Map<int, GlobalKey<DragItemWidgetState>> _dragItemKeys =
      <int, GlobalKey<DragItemWidgetState>>{};

  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _supportsDesktopDragOut => _isDesktopPlatform;

  GlobalKey _tileKeyForIndex(int index) {
    return _tileKeys.putIfAbsent(index, () => GlobalKey());
  }

  GlobalKey<DragItemWidgetState> _dragKeyForIndex(int index) {
    return _dragItemKeys.putIfAbsent(index, () => GlobalKey<DragItemWidgetState>());
  }

  Rect? _globalRectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final render = context.findRenderObject();
    if (render is! RenderBox) return null;
    if (!render.hasSize) return null;
    final topLeft = render.localToGlobal(Offset.zero);
    return topLeft & render.size;
  }

  Rect _rectFromPoints(Offset a, Offset b) {
    final left = a.dx < b.dx ? a.dx : b.dx;
    final right = a.dx > b.dx ? a.dx : b.dx;
    final top = a.dy < b.dy ? a.dy : b.dy;
    final bottom = a.dy > b.dy ? a.dy : b.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _isPointOnAnyTile(Offset globalPoint) {
    for (var i = 0; i < widget.results.length; i++) {
      final rect = _globalRectForKey(_tileKeyForIndex(i));
      if (rect != null && rect.contains(globalPoint)) {
        return true;
      }
    }
    return false;
  }

  Set<int> _tileIndicesIntersectingRect(Rect selectionRect) {
    final hit = <int>{};
    for (var i = 0; i < widget.results.length; i++) {
      final rect = _globalRectForKey(_tileKeyForIndex(i));
      if (rect != null && rect.overlaps(selectionRect)) {
        hit.add(i);
      }
    }
    return hit;
  }

  void _startMarqueeSelection(PointerDownEvent event) {
    final isPrimaryPressed = (event.buttons & kPrimaryMouseButton) != 0;
    if (!isPrimaryPressed) return;
    if (!_isDesktopPlatform) return;

    if (_isPointOnAnyTile(event.position)) {
      return;
    }

    final isCtrlOrCmdPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    setState(() {
      _isMarqueeSelecting = true;
      _marqueeStartGlobal = event.position;
      _marqueeStartLocal = event.localPosition;
      _marqueeCurrentLocal = event.localPosition;

      // Clicking empty space should cancel the current selection.
      // But if Ctrl/Cmd is pressed, preserve selection so marquee can toggle.
      if (!isCtrlOrCmdPressed) {
        _selectedIndices.clear();
        _lastSelectedIndex = null;
        _marqueeInitialSelectedIndices = <int>{};
      } else {
        _marqueeInitialSelectedIndices = Set<int>.from(_selectedIndices);
      }
    });
  }

  void _updateMarqueeSelection(PointerMoveEvent event) {
    if (!_isMarqueeSelecting || _marqueeStartGlobal == null) return;

    final isPrimaryPressed = (event.buttons & kPrimaryMouseButton) != 0;
    if (!isPrimaryPressed) {
      _finishMarqueeSelection();
      return;
    }

    final current = event.position;
    final rect = _rectFromPoints(_marqueeStartGlobal!, current);
    final hit = _tileIndicesIntersectingRect(rect);
    final isCtrlOrCmdPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    Set<int> merged;
    if (!isCtrlOrCmdPressed) {
      merged = hit;
    } else {
      merged = Set<int>.from(_marqueeInitialSelectedIndices);
      for (final i in hit) {
        if (merged.contains(i)) {
          merged.remove(i);
        } else {
          merged.add(i);
        }
      }
    }

    setState(() {
      _marqueeCurrentLocal = event.localPosition;
      _selectedIndices
        ..clear()
        ..addAll(merged);
      if (_selectedIndices.isEmpty) {
        _lastSelectedIndex = null;
      }
    });
  }

  void _finishMarqueeSelection() {
    if (!_isMarqueeSelecting) return;
    setState(() {
      _isMarqueeSelecting = false;
      _marqueeStartGlobal = null;
      _marqueeStartLocal = null;
      _marqueeCurrentLocal = null;
      _marqueeInitialSelectedIndices = <int>{};
      if (_selectedIndices.isEmpty) {
        _lastSelectedIndex = null;
      }
    });
  }

  void _handleTileTap(int index) {
    final isCtrlOrCmdPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isShiftPressed || isCtrlOrCmdPressed) {
      // Çoklu seçim modu
      setState(() {
        if (isShiftPressed && _lastSelectedIndex != null) {
          final start = _lastSelectedIndex!;
          final lo = start < index ? start : index;
          final hi = start > index ? start : index;
          _selectedIndices
            ..clear()
            ..addAll(List<int>.generate(hi - lo + 1, (i) => lo + i));
        } else if (isCtrlOrCmdPressed) {
          if (_selectedIndices.contains(index)) {
            _selectedIndices.remove(index);
          } else {
            _selectedIndices.add(index);
          }
          _lastSelectedIndex = index;
        }

        if (_selectedIndices.isEmpty) {
          _lastSelectedIndex = null;
        }
      });
    } else {
      // Normal tek tıklama → dosya detay dialogu aç
      _openFileDetailDialog(index);
    }
  }

  void _openFileDetailDialog(int index) {
    final entries = widget.results.entries.toList();
    final fileName = entries[index].key;
    final content = entries[index].value;

    // Kaynak bloklarını settings.projects'den bul
    final settings = context.read<AppSettings>();
    List<SubtitleBlock>? sourceBlocks;
    try {
      final project = settings.projects.firstWhere(
        (p) => p.fileName == fileName,
      );
      if (project.sourceBlocks.isNotEmpty) {
        sourceBlocks = project.sourceBlocks;
      }
    } catch (_) {
      // Proje bulunamadı, karşılaştırma sekmesi gizlenecek
    }

    showDialog(
      context: context,
      builder: (_) => BatchFileDetailDialog(
        fileName: fileName,
        translatedContent: content,
        sourceBlocks: sourceBlocks,
      ),
    );
  }

  Future<void> _saveSingleFile(String fileName, String content, int index) async {
    setState(() {
      _savingIndex = index;
    });

    try {
      final trans = context.read<AppSettings>().trans;
      final exportName = _buildExportFileName(fileName);
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: StringUtils.fillTemplate(
          trans['save_subtitle_dialog_title'] ?? 'Save subtitle: {name}',
          {'name': exportName},
        ),
        fileName: exportName,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                StringUtils.fillTemplate(
                  trans['snackbar_saved_file'] ?? 'Saved: {name}',
                  {'name': exportName},
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final trans = context.read<AppSettings>().trans;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              StringUtils.fillTemplate(
                trans['error_with_details'] ?? 'Error: {error}',
                {'error': e.toString()},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingIndex = null;
        });
      }
    }
  }

  // ZIP export removed: app no longer uses ZIP output.

  String _sanitizeFileName(String rawName) {
    // Keep it conservative for Windows/macOS/Linux.
    // Replace common invalid filename characters with '_' and trim.
    var name = rawName.trim();
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001F]'), '_');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) name = 'subtitle.srt';
    if (!name.toLowerCase().endsWith('.srt')) {
      name = '$name.srt';
    }
    return name;
  }

  String _buildExportFileName(String rawName) {
    final target = _resolveTargetLanguageForFile(rawName);

    // Keep only the last segment, then normalize to .srt.
    final base = rawName.split(RegExp(r'[\\/]')).last;
    final nameWithoutExt = base.replaceAll(RegExp(r'\.[^.]*$'), '');

    final noGenerated = StringUtils.stripGeneratedPrefixAndHash(nameWithoutExt);

    // Remove any language markers (source or previous target) then append target.
    final stripped = StringUtils.stripLanguageSuffix(noGenerated).trim();
    final withTarget = target.isEmpty ? stripped : '${stripped}_$target';

    return _sanitizeFileName('$withTarget.srt');
  }

  String _resolveTargetLanguageForFile(String rawName) {
    final settings = context.read<AppSettings>();

    // Prefer the project-specific target language (matches normal save behaviour).
    try {
      final project = settings.projects.firstWhere(
        (p) => p.fileName == rawName,
      );
      final projectTarget = project.targetLanguage.trim().toUpperCase();
      if (projectTarget.isNotEmpty) return projectTarget;
    } catch (_) {
      // No matching project; fall back to current settings.
    }

    return settings.targetLanguage.trim().toUpperCase();
  }

  Future<File> _writeDragExportTempFile(String fileName, String content) async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(path.join(tempDir.path, 'completion_drag_exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final filePath = path.join(exportDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<DragItem?> _buildDragItemForIndex(int index) async {
    if (!_supportsDesktopDragOut) return null;

    final rawName = widget.results.keys.elementAt(index);
    final content = widget.results.values.elementAt(index);
    final fileName = _buildExportFileName(rawName);
    final file = await _writeDragExportTempFile(fileName, content);

    final item = DragItem(
      suggestedName: fileName,
      localData: {'index': index},
    );
    item.add(Formats.fileUri(Uri.file(file.path)));
    return item;
  }

  Future<void> _saveAllAsSrtFiles() async {
    setState(() {
      _isSavingAll = true;
    });

    try {
      final trans = context.read<AppSettings>().trans;
      final String? dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: trans['save_all_srt_dialog_title'] ??
            'Select folder to save all subtitles',
      );

      if (dirPath == null || dirPath.trim().isEmpty) {
        return;
      }

      final usedNames = <String>{};
      var savedCount = 0;
      for (final entry in widget.results.entries) {
        var name = _buildExportFileName(entry.key);

        if (usedNames.contains(name)) {
          final dot = name.lastIndexOf('.');
          final stem = dot > 0 ? name.substring(0, dot) : name;
          final ext = dot > 0 ? name.substring(dot) : '';
          var i = 2;
          while (usedNames.contains('$stem ($i)$ext')) {
            i++;
          }
          name = '$stem ($i)$ext';
        }
        usedNames.add(name);

        final file = File('$dirPath${Platform.pathSeparator}$name');
        await file.writeAsString(entry.value);
        savedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              StringUtils.fillTemplate(
                trans['snackbar_saved_all_files'] ??
                    'Saved {count} files to: {folder}',
                {
                  'count': savedCount.toString(),
                  'folder': dirPath,
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final trans = context.read<AppSettings>().trans;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              StringUtils.fillTemplate(
                trans['error_with_details'] ?? 'Error: {error}',
                {'error': e.toString()},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAll = false;
        });
      }
    }
  }

  Widget _buildTile(
    int index,
    String fileName,
    String content,
    bool isSavingThis,
    bool isSelected,
    Map<String, String> trans,
    ColorScheme colorScheme,
  ) {
    Widget tile = Card(
      key: _tileKeyForIndex(index),
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? colorScheme.primary.withAlpha(20) : null,
      child: ListTile(
        selected: isSelected,
        selectedColor: colorScheme.onSurface,
        leading: _supportsDesktopDragOut
            ? MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _handleTileTap(index),
        trailing: isSavingThis
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: () => _saveSingleFile(fileName, content, index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(trans['save'] ?? 'Kaydet'),
              ),
      ),
    );

    if (_supportsDesktopDragOut) {
      tile = DragItemWidget(
        key: _dragKeyForIndex(index),
        allowedOperations: () => [DropOperation.copy],
        dragItemProvider: (request) async {
          return _buildDragItemForIndex(index);
        },
        child: DraggableWidget(
          dragItemsProvider: (context) {
            if (!_selectedIndices.contains(index) ||
                _selectedIndices.length <= 1) {
              final current = _dragKeyForIndex(index).currentState;
              return current != null ? [current] : const <DragItemWidgetState>[];
            }

            final states = <DragItemWidgetState>[];
            for (final i in _selectedIndices) {
              final state = _dragItemKeys[i]?.currentState;
              if (state != null) {
                states.add(state);
              }
            }

            if (states.isEmpty) {
              final current = _dragKeyForIndex(index).currentState;
              return current != null ? [current] : const <DragItemWidgetState>[];
            }

            return states;
          },
          child: tile,
        ),
      );
    }

    return tile;
  }

  @override
  Widget build(BuildContext context) {
    final trans = context.read<AppSettings>().trans;
    final colorScheme = Theme.of(context).colorScheme;

    final dialogMaxWidth = 720.0;
    final availableWidth = MediaQuery.of(context).size.width - 40; // insetPadding horizontal*2
    final dialogWidth = availableWidth.clamp(320.0, dialogMaxWidth).toDouble();
    final savingProgressText =
      (trans['saving_files_progress'] ?? 'Dosyalar kaydediliyor...');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      actionsPadding: const EdgeInsets.only(bottom: 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trans['batch_complete_title'] ?? 'Çeviri Tamamlandı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            if (_isSavingAll)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(savingProgressText),
                  ],
                ),
              )
            else if (widget.results.length > 1 && _isDesktopPlatform) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveAllAsSrtFiles,
                        icon: const Icon(Icons.save),
                        label: Text(
                          trans['batch_save_all_srt'] ?? 'Tümünü Kaydet',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.length == widget.results.length) {
                            _selectedIndices.clear();
                          } else {
                            _selectedIndices.addAll(
                                List.generate(widget.results.length, (i) => i));
                          }
                        });
                      },
                      tooltip: _selectedIndices.length == widget.results.length
                          ? (trans['deselect_all'] ?? 'Seçimi Kaldır')
                          : (trans['select_all'] ?? 'Tümünü Seç'),
                      icon: Icon(
                        _selectedIndices.length == widget.results.length
                            ? Icons.deselect
                            : Icons.select_all,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                trans['batch_save_individual_prompt'] ?? 'Veya listeden tek tek kaydedin:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                const tileHeight = 68.0;
                final desiredListHeight = widget.results.length * tileHeight;
                final maxListHeight = MediaQuery.of(context).size.height * 0.48;
                final listHeight = desiredListHeight.clamp(0, maxListHeight).toDouble();

                return Stack(
                  children: [
                    SizedBox(
                      height: listHeight,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: _startMarqueeSelection,
                        onPointerMove: _updateMarqueeSelection,
                        onPointerUp: (_) => _finishMarqueeSelection(),
                        onPointerCancel: (_) => _finishMarqueeSelection(),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.results.length,
                          itemBuilder: (context, index) {
                            final fileName = widget.results.keys.elementAt(index);
                            final content = widget.results.values.elementAt(index);
                            final isSavingThis = _savingIndex == index;
                            final isSelected = _selectedIndices.contains(index);

                            return _buildTile(
                              index,
                              fileName,
                              content,
                              isSavingThis,
                              isSelected,
                              trans,
                              colorScheme,
                            );
                          },
                        ),
                      ),
                    ),
                    if (_isMarqueeSelecting &&
                        _marqueeStartLocal != null &&
                        _marqueeCurrentLocal != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SelectionMarqueePainter(
                              start: _marqueeStartLocal!,
                              current: _marqueeCurrentLocal!,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
          child: Text(trans['hide'] ?? 'Gizle'),
        ),
      ],
    );
  }
}

class _SelectionMarqueePainter extends CustomPainter {
  const _SelectionMarqueePainter({
    required this.start,
    required this.current,
    required this.color,
  });

  final Offset start;
  final Offset current;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, current);
    final fill = Paint()..color = color.withAlpha(28);
    final stroke = Paint()
      ..color = color.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _SelectionMarqueePainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.current != current ||
        oldDelegate.color != color;
  }
}
