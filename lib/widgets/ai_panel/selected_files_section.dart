import 'dart:async';
import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_settings.dart';
import '../../models/batch_file_item.dart';
import 'file_content_dialog.dart';
import '../cloud_provider_logo.dart';

class AiPanelSelectedFilesSection extends StatefulWidget {
  final AppSettings settings;
  final ColorScheme colorScheme;

  final List<BatchFileItem> selectedFiles;
  final int activeIndex;
  final bool isTranslationRunning;

  final VoidCallback onClearAll;
  final Future<void> Function(String path) onRemoveByPath;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onTapPreview;
  final Future<void> Function(int index) onStartTranslation;
  final bool scrollableList;
  final String Function(String path)? onGetOriginalPath;

  const AiPanelSelectedFilesSection({
    super.key,
    required this.settings,
    required this.colorScheme,
    required this.selectedFiles,
    required this.activeIndex,
    required this.isTranslationRunning,
    required this.onClearAll,
    required this.onRemoveByPath,
    required this.onReorder,
    required this.onTapPreview,
    required this.onStartTranslation,
    this.scrollableList = false,
    this.onGetOriginalPath,
  });

  @override
  State<AiPanelSelectedFilesSection> createState() =>
      _AiPanelSelectedFilesSectionState();
}

class _AiPanelSelectedFilesSectionState extends State<AiPanelSelectedFilesSection> {
  static const double _desktopTileHeight = 46;
  static const double _marqueeDragThreshold = 6;

  final FocusNode _focusNode = FocusNode(debugLabel: 'ai_selected_files_list');
  final GlobalKey _listStackKey = GlobalKey();
  final Map<String, GlobalKey> _tileKeys = {};
  final Set<String> _selectedPaths = <String>{};

  bool _isMarqueeActive = false;
  bool _marqueeArmed = false;
  Offset? _marqueeStartGlobal;
  Offset? _marqueeCurrentGlobal;
  Set<String> _baseSelectionAtDragStart = <String>{};
  int? _marqueePointerId;
  bool _marqueePointerDownOnEmptySpace = false;
  int? _suppressMarqueePointerId;
  int? _hoveredIndex;
  String? _lastSelectedPath;

  bool get _isDesktopLayout => widget.scrollableList;

  @override
  void didUpdateWidget(covariant AiPanelSelectedFilesSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPaths = oldWidget.selectedFiles.map((f) => f.path).toSet();
    for (final item in widget.selectedFiles) {
      final path = item.path;
      if (path.isEmpty) continue;
      if (!oldPaths.contains(path)) {
        preloadAiPanelFileContentPreview(path);
      }
    }

    final allowed = widget.selectedFiles.map((f) => f.path).toSet();
    _selectedPaths.removeWhere((p) => !allowed.contains(p));
    if (_lastSelectedPath != null && !allowed.contains(_lastSelectedPath)) {
      _lastSelectedPath = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isCtrlPressed =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  GlobalKey _keyForPath(String filePath) {
    return _tileKeys.putIfAbsent(filePath, () => GlobalKey());
  }

  Rect? _rectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  Rect? _marqueeRectGlobal() {
    final start = _marqueeStartGlobal;
    final current = _marqueeCurrentGlobal;
    if (start == null || current == null) return null;
    final left = start.dx < current.dx ? start.dx : current.dx;
    final top = start.dy < current.dy ? start.dy : current.dy;
    final right = start.dx > current.dx ? start.dx : current.dx;
    final bottom = start.dy > current.dy ? start.dy : current.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _updateSelectionFromMarquee(Offset currentGlobalPosition) {
    _marqueeCurrentGlobal = currentGlobalPosition;
    final marquee = _marqueeRectGlobal();
    if (marquee == null) {
      setState(() {});
      return;
    }

    final next = <String>{..._baseSelectionAtDragStart};
    for (final item in widget.selectedFiles) {
      final rect = _rectForKey(_keyForPath(item.path));
      if (rect != null && rect.overlaps(marquee)) {
        next.add(item.path);
      }
    }

    setState(() {
      if (!setEquals(next, _selectedPaths)) {
        _selectedPaths
          ..clear()
          ..addAll(next);
      }
    });
  }

  void _startMarquee(Offset globalPosition) {
    _focusNode.requestFocus();
    _marqueeArmed = true;
    _isMarqueeActive = false;
    _marqueeStartGlobal = globalPosition;
    _marqueeCurrentGlobal = globalPosition;
    _baseSelectionAtDragStart = {..._selectedPaths};
  }

  void _endMarquee({bool clearSelection = false}) {
    if (!_isMarqueeActive && !_marqueeArmed) {
      if (!clearSelection) return;
      if (_selectedPaths.isEmpty) return;
      setState(() {
        _selectedPaths.clear();
        _lastSelectedPath = null;
      });
      return;
    }

    setState(() {
      _marqueeArmed = false;
      _isMarqueeActive = false;
      _marqueeStartGlobal = null;
      _marqueeCurrentGlobal = null;
      _baseSelectionAtDragStart = <String>{};
      _marqueePointerId = null;
      _marqueePointerDownOnEmptySpace = false;

      if (clearSelection) {
        _selectedPaths.clear();
        _lastSelectedPath = null;
      }
    });
  }

  bool _hitTestsAnyTile(Offset globalPosition) {
    for (final item in widget.selectedFiles) {
      final rect = _rectForKey(_keyForPath(item.path));
      if (rect != null && rect.contains(globalPosition)) return true;
    }
    return false;
  }

  void _suppressMarqueeForPointer(int pointer) {
    _suppressMarqueePointerId = pointer;
    _marqueePointerId = null;
    _marqueePointerDownOnEmptySpace = false;
    _endMarquee();
  }

  Rect? _marqueeRectLocal() {
    final globalRect = _marqueeRectGlobal();
    if (globalRect == null) return null;

    final context = _listStackKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final origin = renderObject.localToGlobal(Offset.zero);
    return globalRect.shift(-origin);
  }

  Future<void> _deleteSelectedByKeyboard() async {
    if (_selectedPaths.isEmpty) return;

    final activePath = (widget.activeIndex >= 0 &&
            widget.activeIndex < widget.selectedFiles.length)
        ? widget.selectedFiles[widget.activeIndex].path
        : null;

    final removable = _selectedPaths
        .where((p) => activePath == null || p != activePath)
        .toList(growable: false);
    if (removable.isEmpty) return;

    setState(() {
      _selectedPaths.removeAll(removable);
    });

    await Future.wait(removable.map(widget.onRemoveByPath));
  }

  void _showContextMenu(BuildContext context, Offset globalPosition, BatchFileItem fileInfo, int index) {
    final trans = widget.settings.trans;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final isSingleSelection =
        _selectedPaths.isEmpty ||
        (_selectedPaths.length == 1 && _selectedPaths.contains(fileInfo.path));
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry>[
        if (isSingleSelection && !widget.isTranslationRunning)
          PopupMenuItem(
            onTap: () => unawaited(widget.onStartTranslation(index)),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill, size: 18, color: widget.colorScheme.primary),
                const SizedBox(width: 12),
                Text(trans['start_translation'] ?? 'Çeviriyi Başlat'),
              ],
            ),
          ),
        if (isSingleSelection && !widget.isTranslationRunning)
          const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () {
            var path = fileInfo.path;
            if (widget.onGetOriginalPath != null) {
              final original = widget.onGetOriginalPath!(path);
              if (original.isNotEmpty) path = original;
            }
            if (Platform.isWindows) {
              final windowsPath = path.replaceAll('/', '\\');
              Process.run('explorer.exe', ['/select,', windowsPath]);
            } else if (Platform.isMacOS) {
              Process.run('open', ['-R', path]);
            } else if (Platform.isLinux) {
              final dir = File(path).parent.path;
              Process.run('xdg-open', [dir]);
            }
          },
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18, color: widget.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text(trans['open_file_location'] ?? 'Dosya Konumunu Aç'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Clipboard.setData(ClipboardData(text: fileInfo.name));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(trans['log_copied'] ?? 'Panoya kopyalandı'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: widget.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text(trans['copy'] ?? 'Kopyala'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => unawaited(_confirmAndRemoveFromContext(fileInfo.path)),
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: widget.colorScheme.error),
              const SizedBox(width: 12),
              Text(
                trans['delete'] ?? 'Sil',
                style: TextStyle(color: widget.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndRemoveFromContext(String clickedPath) async {
    final selectedIncludesClicked = _selectedPaths.contains(clickedPath);
    final multiSelected = _selectedPaths.length > 1;
    final targets = (selectedIncludesClicked && multiSelected)
        ? _selectedPaths.toList(growable: false)
        : <String>[clickedPath];

    await _confirmAndRemoveMany(targets);
  }

  Future<void> _confirmAndRemove(String path) async {
    await _confirmAndRemoveMany(<String>[path]);
  }

  Future<void> _confirmAndRemoveMany(List<String> paths) async {
    if (paths.isEmpty) return;

    if (!widget.settings.confirmDeletes) {
      setState(() {
        _selectedPaths.removeAll(paths);
      });
      await Future.wait(paths.map(widget.onRemoveByPath));
      return;
    }

    if (!mounted) return;
    final trans = widget.settings.trans;
    final isMulti = paths.length > 1;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans['delete'] ?? 'Sil'),
        content: Text(
          isMulti
              ? (trans['delete_all_permanent_warning'] ??
                  'Tüm öğeler kalıcı olarak silinecek ve geri getirilemeyecek.')
              : (trans['delete_confirm'] ??
                  'Bu dosya silinecek. Emin misiniz?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(trans['btn_cancel'] ?? 'İptal')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: widget.colorScheme.error), onPressed: () => Navigator.pop(ctx, true), child: Text(trans['delete'] ?? 'Sil')),
        ],
      ),
    );
    
    if (result == true) {
      setState(() {
        _selectedPaths.removeAll(paths);
      });
      await Future.wait(paths.map(widget.onRemoveByPath));
    }
  }

  Future<void> _confirmAndClearAll() async {
    if (widget.selectedFiles.isEmpty) return;

    if (!widget.settings.confirmDeletes) {
      widget.onClearAll();
      return;
    }

    if (!mounted) return;
    final trans = widget.settings.trans;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans['clear_list'] ?? 'Listeyi Temizle'),
        content: Text(
          trans['clear_list_confirm'] ??
              trans['delete_all_permanent_warning'] ??
              'Tüm öğeler kalıcı olarak silinecek ve geri getirilemeyecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(trans['btn_cancel'] ?? 'İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: widget.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(trans['delete'] ?? 'Sil'),
          ),
        ],
      ),
    );

    if (result == true) {
      widget.onClearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        
        if (event.logicalKey != LogicalKeyboardKey.delete) {
          if (event.logicalKey == LogicalKeyboardKey.keyA && 
             (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
               setState(() {
                 _selectedPaths.clear();
                 _selectedPaths.addAll(widget.selectedFiles.map((f) => f.path));
               });
               return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        unawaited(_deleteSelectedByKeyboard());
        return KeyEventResult.handled;
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.surfaceContainerLow.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.selectedFiles.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _isDesktopLayout ? 8 : 10,
                  _isDesktopLayout ? 6 : 8,
                  _isDesktopLayout ? 8 : 10,
                  _isDesktopLayout ? 6 : 8,
                ),
                child: SizedBox(
                  height: _isDesktopLayout ? 22 : 24,
                  child: _buildHeader(),
                ),
              ),
              Divider(height: 1, color: widget.colorScheme.outlineVariant),
              SizedBox(height: _isDesktopLayout ? 4 : 8),
            ],
            if (widget.scrollableList)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _isDesktopLayout ? 8 : 10,
                    0,
                    _isDesktopLayout ? 8 : 10,
                    _isDesktopLayout ? 8 : 10,
                  ),
                  child: _buildContent(),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _isDesktopLayout ? 8 : 10,
                  0,
                  _isDesktopLayout ? 8 : 10,
                  _isDesktopLayout ? 8 : 10,
                ),
                child: _buildContent(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.selectedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_check_circle_rounded,
              size: 48,
              color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              widget.settings.trans['empty_translation_list_hint'] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    return _buildList();
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: widget.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${widget.selectedFiles.length}',
            style: TextStyle(
              color: widget.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AutoSizeText(
            widget.settings.trans['click_for_content_long'] ??
              'Tap a subtitle to preview its content',
            style: TextStyle(color: widget.colorScheme.onSurfaceVariant, fontSize: 12),
            maxLines: 1,
            minFontSize: 10,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: widget.settings.trans['clear_list'] ?? 'Listeyi Temizle',
          onPressed: widget.selectedFiles.isEmpty
              ? null
              : () => unawaited(_confirmAndClearAll()),
          icon: Icon(
            Icons.delete_sweep,
            color: widget.selectedFiles.isEmpty
                ? widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                : Colors.red.shade700,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        ),
      ],
    );
  }

  Widget _buildList() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _focusNode.requestFocus();
        if (!_isDesktopLayout) return;
        if (event.buttons != kPrimaryMouseButton) return;

        if (_suppressMarqueePointerId == event.pointer) {
          return;
        }

        _marqueePointerId = event.pointer;
        _marqueePointerDownOnEmptySpace = !_hitTestsAnyTile(event.position);
        _startMarquee(event.position);
      },
      onPointerMove: (event) {
        if (_suppressMarqueePointerId == event.pointer) return;
        if (!_marqueeArmed || _marqueeStartGlobal == null) return;
        if (!_isMarqueeActive) {
          final distance = (event.position - _marqueeStartGlobal!).distance;
          if (distance < _marqueeDragThreshold) {
            return;
          }
          setState(() {
            _isMarqueeActive = true;
            if (!_isCtrlPressed) {
              _selectedPaths.clear();
            }
          });
        }
        _updateSelectionFromMarquee(event.position);
      },
      onPointerUp: (event) {
        if (_suppressMarqueePointerId == event.pointer) {
          _suppressMarqueePointerId = null;
          return;
        }

        final isClickWithoutMarquee =
            !_isMarqueeActive && _marqueeArmed && _marqueePointerId == event.pointer;

        final shouldClearMultiSelectOnEmptyClick =
            isClickWithoutMarquee &&
            _marqueePointerDownOnEmptySpace &&
          _selectedPaths.isNotEmpty &&
            !_isCtrlPressed &&
            !HardwareKeyboard.instance.isShiftPressed;

        _endMarquee(clearSelection: shouldClearMultiSelectOnEmptyClick);
      },
      onPointerCancel: (event) {
        if (_suppressMarqueePointerId == event.pointer) {
          _suppressMarqueePointerId = null;
        }
        _endMarquee();
      },
      child: Stack(
        key: _listStackKey,
        children: [
          ReorderableListView.builder(
      shrinkWrap: !widget.scrollableList,
      physics: widget.scrollableList
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widget.selectedFiles.length,
      onReorder: widget.onReorder,
      itemBuilder: (context, index) {
        final isActive = index == widget.activeIndex;
        final fileInfo = widget.selectedFiles[index];
        final filePath = fileInfo.path;
        final isSelected = _selectedPaths.contains(filePath);

        return Dismissible(
          key: ObjectKey(fileInfo),
          direction: (isActive || _isDesktopLayout) ? DismissDirection.none : DismissDirection.horizontal,
          background: _buildDismissBackground(left: true),
          secondaryBackground: _buildDismissBackground(left: false),
          onDismissed: (_) => unawaited(widget.onRemoveByPath(filePath)),
          child: _buildTile(
            index: index,
            isActive: isActive,
            isSelected: isSelected,
            fileInfo: fileInfo,
            tileKey: _keyForPath(filePath),
          ),
        );
      },
    ),
          if (_isMarqueeActive && _marqueeRectLocal() != null)
            Positioned.fromRect(
              rect: _marqueeRectLocal()!,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.colorScheme.primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: widget.colorScheme.primary,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDismissBackground({required bool left}) {
    return Container(
      margin: EdgeInsets.only(bottom: _isDesktopLayout ? 4 : 8),
      decoration: BoxDecoration(
        color: widget.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Icon(Icons.delete, color: widget.colorScheme.onErrorContainer),
    );
  }

  String _sourceLabel(String sourceKey) {
    final trans = widget.settings.trans;
    switch (sourceKey) {
      case 'googleDrive':
        return trans['cloud_source_drive'] ?? 'Google Drive';
      case 'dropbox':
        return trans['cloud_source_dropbox'] ?? 'Dropbox';
      case 'yandexDisk':
        return trans['cloud_source_yandex'] ?? 'Yandex Disk';
      default:
        return trans['cloud_source_device'] ?? 'This device';
    }
  }

  Widget _sourceIcon(String sourceKey) {
    switch (sourceKey) {
      case 'googleDrive':
        return const CloudProviderLogo(
          asset: CloudProviderAssets.googleDrive,
          size: 16,
          semanticLabel: 'Google Drive',
        );
      case 'dropbox':
        return const CloudProviderLogo(
          asset: CloudProviderAssets.dropbox,
          size: 16,
          semanticLabel: 'Dropbox',
        );
      case 'yandexDisk':
        return const CloudProviderLogo(
          asset: CloudProviderAssets.yandexDisk,
          size: 16,
          semanticLabel: 'Yandex Disk',
        );
      default:
        final isDesktopPlatform =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;
        return Icon(
          isDesktopPlatform ? Icons.desktop_windows_rounded : Icons.phone_android,
          size: 16,
          color: widget.colorScheme.onSurfaceVariant,
        );
    }
  }

  Widget _buildTile({
    required int index,
    required bool isActive,
    required bool isSelected,
    required BatchFileItem fileInfo,
    required GlobalKey tileKey,
  }) {
    final isHovered = _hoveredIndex == index;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final idleTileColor = isLightMode
      ? widget.colorScheme.surfaceContainerLow
      : widget.colorScheme.surface;
    final idleBorderColor = isLightMode
      ? widget.colorScheme.outline.withValues(alpha: 0.85)
      : widget.colorScheme.outlineVariant.withValues(alpha: 0.55);

    return MouseRegion(
      onEnter: (_) {
        if (_isDesktopLayout) setState(() => _hoveredIndex = index);
      },
      onExit: (_) {
        if (_isDesktopLayout) setState(() => _hoveredIndex = null);
      },
      child: Container(
        key: tileKey,
        alignment: Alignment.center,
        constraints: _isDesktopLayout
            ? const BoxConstraints(minHeight: _desktopTileHeight)
            : null,
        margin: EdgeInsets.only(bottom: _isDesktopLayout ? 2 : 8),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : (isActive
                  ? widget.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : (isHovered && _isDesktopLayout
                      ? widget.colorScheme.onSurface.withValues(alpha: 0.12)
                      : idleTileColor)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? widget.colorScheme.primary
                : (isActive
                    ? widget.colorScheme.primary.withValues(alpha: 0.5)
                    : idleBorderColor),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: (isActive || isSelected)
              ? [
                  BoxShadow(
                    color: widget.colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: GestureDetector(
          onSecondaryTapUp: (details) {
            if (_isDesktopLayout) {
              _showContextMenu(context, details.globalPosition, fileInfo, index);
            }
          },
          child: ListTile(
        dense: _isDesktopLayout,
        visualDensity: _isDesktopLayout
            ? const VisualDensity(horizontal: -2, vertical: -3)
            : VisualDensity.standard,
        minVerticalPadding: _isDesktopLayout ? 0 : 4,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isDesktopLayout ? 8 : 12,
          vertical: _isDesktopLayout ? 0 : 4,
        ),
        leading: null,
        title: Tooltip(
          message: fileInfo.name,
          waitDuration: const Duration(milliseconds: 500),
          child: Row(
            children: [
              Tooltip(
                message: _sourceLabel(fileInfo.source),
                waitDuration: const Duration(milliseconds: 500),
                child: _sourceIcon(fileInfo.source),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileInfo.name,
                  style: TextStyle(
                    color: widget.colorScheme.onSurface,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: _isDesktopLayout ? 12 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          _focusNode.requestFocus();
          if (_isDesktopLayout &&
              HardwareKeyboard.instance.isShiftPressed &&
              _lastSelectedPath != null) {
            final anchorIndex = widget.selectedFiles.indexWhere(
              (f) => f.path == _lastSelectedPath,
            );
            if (anchorIndex != -1) {
              final start = anchorIndex < index ? anchorIndex : index;
              final end = anchorIndex > index ? anchorIndex : index;
              setState(() {
                if (!_isCtrlPressed) {
                  _selectedPaths.clear();
                }
                for (var i = start; i <= end; i++) {
                  _selectedPaths.add(widget.selectedFiles[i].path);
                }
                _lastSelectedPath = fileInfo.path;
              });
              widget.onTapPreview(index);
              return;
            }
          }
          if (_isDesktopLayout && _isCtrlPressed) {
            setState(() {
              if (isSelected) {
                _selectedPaths.remove(fileInfo.path);
              } else {
                _selectedPaths.add(fileInfo.path);
              }
              _lastSelectedPath = fileInfo.path;
            });
            return;
          }
          setState(() {
            _selectedPaths
              ..clear()
              ..add(fileInfo.path);
            _lastSelectedPath = fileInfo.path;
          });
          widget.onTapPreview(index);
        },
        onLongPress: () {
          if (!_isDesktopLayout) return;
          setState(() {
            _selectedPaths.add(fileInfo.path);
            _lastSelectedPath = fileInfo.path;
          });
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDesktopLayout && !isActive) ...[
              IconButton(
                icon: Icon(
                  Icons.delete,
                  size: 20,
                  color: Colors.red,
                ),
                tooltip: widget.settings.trans['delete'] ?? 'Sil',
                onPressed: () => unawaited(_confirmAndRemove(fileInfo.path)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
              const SizedBox(width: 4),
            ],
            if (!isActive)
              ReorderableDragStartListener(
                index: index,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if (!_isDesktopLayout) return;
                    if (event.buttons != kPrimaryMouseButton) return;
                    _suppressMarqueeForPointer(event.pointer);
                  },
                  onPointerUp: (event) {
                    if (_suppressMarqueePointerId == event.pointer) {
                      _suppressMarqueePointerId = null;
                    }
                  },
                  onPointerCancel: (event) {
                    if (_suppressMarqueePointerId == event.pointer) {
                      _suppressMarqueePointerId = null;
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(_isDesktopLayout ? 4 : 8),
                    color: Colors.transparent,
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: widget.colorScheme.outline,
                      size: _isDesktopLayout ? 18 : 22,
                    ),
                  ),
                ),
              )
            else if (widget.isTranslationRunning)
              Padding(
                padding: EdgeInsets.all(_isDesktopLayout ? 6 : 8),
                child: SizedBox(
                  width: _isDesktopLayout ? 12 : 14,
                  height: _isDesktopLayout ? 12 : 14,
                  child: CircularProgressIndicator(
                    strokeWidth: _isDesktopLayout ? 1.8 : 2,
                    color: widget.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
