import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_settings.dart';
import '../credit_history_page.dart';
import '../managers/project_manager.dart';
import '../models/subtitle_block.dart';
import '../services/subtitle_builder.dart';
import '../services/subtitle_parser.dart';
import '../controllers/translation_controller.dart';
import '../utils/string_utils.dart';
import '../widgets/cloud_source_sheet.dart';
import '../widgets/batch_file_detail_dialog.dart';

enum SortOption { date, name }
enum FilterOption { all, completed, partial }
enum _HistoryProjectMenuAction {
  openInEditor,
  compareWithSource,
  share,
  save,
  resume,
  delete
}

class _SelectAllVisibleIntent extends Intent {
  const _SelectAllVisibleIntent();
}

class _DeleteSelectedIntent extends Intent {
  const _DeleteSelectedIntent();
}

Future<void> showHistorySheet(BuildContext context) {
  // Be defensive: on some routes (or during transitions) `MaterialLocalizations`
  // or `MediaQuery` lookups can throw if the provided context is not under a
  // `MaterialApp`/`WidgetsApp` yet. We only need a barrier label for semantics,
  // so a stable fallback is acceptable.
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'History',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      final mediaQuery = MediaQuery.maybeOf(context);
      final screenSize = mediaQuery?.size ?? const Size(800, 600);
      final screenWidth = screenSize.width;
      // On phones, prefer a full-width sheet to avoid overly narrow layouts.
      final desiredWidth = screenWidth < 700 ? screenWidth : screenWidth * 0.575;

      return SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              bottomLeft: Radius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              width: desiredWidth,
              height: screenSize.height,
              child: const HistoryTab(),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      );
    },
  );
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab>
    with SingleTickerProviderStateMixin {
  static const double _marqueeDragThreshold = 6;

  SortOption _sortOption = SortOption.date;
  bool _ascending = false; // Default: Date Descending (Newest first)
  FilterOption _filterOption = FilterOption.all;
  late final TabController _tabController;
  int _activeTabIndex = 0;

  static String _platformDisplayName(String platform) {
    switch (platform.toLowerCase()) {
      case 'android': return 'Android';
      case 'ios': return 'iOS';
      case 'windows': return 'Windows';
      case 'macos': return 'macOS';
      case 'linux': return 'Linux';
      case 'fuchsia': return 'Fuchsia';
      default: return platform;
    }
  }

  // Search and selection states
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedProjectIds = {};
  bool _isSaving = false;
  final FocusNode _historyListFocusNode = FocusNode(
    debugLabel: 'historyListShortcuts',
  );
  final Map<String, GlobalKey<DragItemWidgetState>> _dragItemKeys = {};
  final Map<String, GlobalKey> _projectCardKeys = {};
  final GlobalKey _bodyStackKey = GlobalKey();

  bool _isMarqueeSelecting = false;
  bool _isMarqueeArmed = false;
  Offset? _lastPrimaryDownGlobal;
  Offset? _marqueeStartGlobal;
  Offset? _marqueeCurrentGlobal;
  Set<String> _marqueeInitialSelectedIds = <String>{};
  String? _hoveredProjectId;
  String? _lastSelectedProjectId;

  GlobalKey<DragItemWidgetState> _dragKeyForProject(String projectId) {
    return _dragItemKeys.putIfAbsent(
      projectId,
      () => GlobalKey<DragItemWidgetState>(),
    );
  }

  GlobalKey _cardKeyForProject(String projectId) {
    return _projectCardKeys.putIfAbsent(projectId, () => GlobalKey());
  }

  Rect? _globalRectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  Rect _rectFromPoints(Offset a, Offset b) {
    return Rect.fromLTRB(
      a.dx < b.dx ? a.dx : b.dx,
      a.dy < b.dy ? a.dy : b.dy,
      a.dx > b.dx ? a.dx : b.dx,
      a.dy > b.dy ? a.dy : b.dy,
    );
  }

  bool _isPointOnAnyProjectCard(
    Offset globalPoint,
    List<TranslationProject> visibleProjects,
  ) {
    for (final project in visibleProjects) {
      final rect = _globalRectForKey(_cardKeyForProject(project.id));
      if (rect != null && rect.contains(globalPoint)) {
        return true;
      }
    }
    return false;
  }

  TranslationProject? _projectAtPoint(
    Offset globalPoint,
    List<TranslationProject> visibleProjects,
  ) {
    for (final project in visibleProjects) {
      final rect = _globalRectForKey(_cardKeyForProject(project.id));
      if (rect != null && rect.contains(globalPoint)) {
        return project;
      }
    }
    return null;
  }

  Set<String> _projectIdsIntersectingRect(
    Rect selectionRect,
    List<TranslationProject> visibleProjects,
  ) {
    final ids = <String>{};
    for (final project in visibleProjects) {
      final rect = _globalRectForKey(_cardKeyForProject(project.id));
      if (rect != null && rect.overlaps(selectionRect)) {
        ids.add(project.id);
      }
    }
    return ids;
  }

  void _startMarqueeSelection(
    PointerDownEvent event,
    List<TranslationProject> visibleProjects,
  ) {
    final isPrimaryPressed = (event.buttons & kPrimaryMouseButton) != 0;
    if (!isPrimaryPressed) return;

    final startedOnCard = _isPointOnAnyProjectCard(event.position, visibleProjects);
    if (startedOnCard && !_isSelectionMode) {
      return;
    }

    // Seçim modundayken zaten seçili bir karta basılırsa marquee armalanmamalı.
    // O hareket drag-export gesture'ıdır; marquee devreye girirse seçim bozulur.
    if (startedOnCard && _isSelectionMode) {
      final tapped = _projectAtPoint(event.position, visibleProjects);
      if (tapped != null && _selectedProjectIds.contains(tapped.id)) {
        return;
      }
    }

    setState(() {
      _isMarqueeArmed = true;
      _isMarqueeSelecting = false;
      _marqueeStartGlobal = event.position;
      _marqueeCurrentGlobal = event.position;
      _marqueeInitialSelectedIds = Set<String>.from(_selectedProjectIds);
      _isSelectionMode = true;
    });
  }

  void _armMarqueeFromLongPress({
    required Offset globalPosition,
    required String projectId,
  }) {
    setState(() {
      _isSelectionMode = true;
      _selectedProjectIds.add(projectId);
      _lastSelectedProjectId = projectId;
      _isMarqueeArmed = true;
      _isMarqueeSelecting = false;
      _marqueeStartGlobal = globalPosition;
      _marqueeCurrentGlobal = globalPosition;
      _marqueeInitialSelectedIds = Set<String>.from(_selectedProjectIds);
    });
  }

  void _updateMarqueeSelection(
    PointerMoveEvent event,
    List<TranslationProject> visibleProjects,
  ) {
    if ((!_isMarqueeArmed && !_isMarqueeSelecting) || _marqueeStartGlobal == null) {
      return;
    }

    final isPrimaryPressed = (event.buttons & kPrimaryMouseButton) != 0;
    if (!isPrimaryPressed) {
      _finishMarqueeSelection();
      return;
    }

    final current = event.position;
    if (!_isMarqueeSelecting) {
      final distance = (current - _marqueeStartGlobal!).distance;
      if (distance < _marqueeDragThreshold) return;
      setState(() {
        _isMarqueeSelecting = true;
      });
    }

    final rect = _rectFromPoints(_marqueeStartGlobal!, current);
    final hitIds = _projectIdsIntersectingRect(rect, visibleProjects);
    final isCtrlOrCmdPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final merged = isCtrlOrCmdPressed
        ? {..._marqueeInitialSelectedIds, ...hitIds}
        : hitIds;

    setState(() {
      _marqueeCurrentGlobal = current;
      _selectedProjectIds
        ..clear()
        ..addAll(merged);
      _isSelectionMode =
          _selectedProjectIds.isNotEmpty || _isMarqueeSelecting || _isMarqueeArmed;
    });
  }

  void _finishMarqueeSelection() {
    if (!_isMarqueeSelecting && !_isMarqueeArmed) return;
    setState(() {
      _isMarqueeArmed = false;
      _isMarqueeSelecting = false;
      _marqueeStartGlobal = null;
      _marqueeCurrentGlobal = null;
      _marqueeInitialSelectedIds = <String>{};
      if (_selectedProjectIds.isEmpty) {
        _isSelectionMode = false;
        _lastSelectedProjectId = null;
      }
    });
  }

  void _toggleSelectAllVisible(List<TranslationProject> visibleProjects) {
    final visibleIds = visibleProjects.map((p) => p.id).toSet();
    if (visibleIds.isEmpty) return;

    final allVisibleSelected = visibleIds.every(_selectedProjectIds.contains);
    setState(() {
      if (allVisibleSelected) {
        _selectedProjectIds.removeAll(visibleIds);
        if (_selectedProjectIds.isEmpty) {
          _isSelectionMode = false;
          _lastSelectedProjectId = null;
        }
      } else {
        _selectedProjectIds.addAll(visibleIds);
        _isSelectionMode = true;
        _lastSelectedProjectId = visibleProjects.last.id;
      }
    });
  }

  Future<void> _deleteProjectFile(TranslationProject project) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final subtitlesDir = Directory(path.join(appDir.path, 'subtitles'));

      Future<void> deleteIfInternal(String? p) async {
        if (p == null || p.trim().isEmpty) return;
        
        // Yolları normalize et (Windows'ta büyük/küçük harf ve \ / farklarını giderir)
        final context = path.Context(style: Platform.isWindows ? path.Style.windows : path.Style.posix);
        final root = context.canonicalize(subtitlesDir.path);
        final target = context.canonicalize(p);

        // Dosya subtitles klasörünün içindeyse sil
        if (context.isWithin(root, target) || context.equals(context.dirname(target), root)) {
          final file = File(p);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      await deleteIfInternal(project.filePath);
      await deleteIfInternal(project.translationSourceCachePath);
    } catch (e) {
      debugPrint('Dosya silinirken hata: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (_activeTabIndex == nextIndex) return;
    setState(() {
      _activeTabIndex = nextIndex;
      if (_activeTabIndex != 0) {
        _isSelectionMode = false;
        _selectedProjectIds.clear();
        _lastSelectedProjectId = null;
      }
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _historyListFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<File?> _resolveResumeSourceFile(TranslationProject project) async {
    final directPath = project.filePath.trim();
    if (directPath.isNotEmpty) {
      final directFile = File(directPath);
      if (await directFile.exists()) return directFile;
    }

    final cachedPath = (project.translationSourceCachePath ?? '').trim();
    if (cachedPath.isNotEmpty) {
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists()) return cachedFile;
    }

    if (project.sourceBlocks.isEmpty) return null;

    final sourceContent = SubtitleBuilder.buildSrt(project.sourceBlocks);
    if (sourceContent.trim().isEmpty) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final subtitlesDir = Directory(path.join(appDir.path, 'subtitles'));
    if (!await subtitlesDir.exists()) {
      await subtitlesDir.create(recursive: true);
    }

    final originalName = project.fileName.trim().isEmpty
        ? 'subtitle.srt'
        : project.fileName.trim();
    final ext = path.extension(originalName).isNotEmpty
        ? path.extension(originalName)
        : '.srt';
    final base = path.basenameWithoutExtension(originalName);
    final hash = md5.convert(utf8.encode(sourceContent)).toString();
    final generatedPath = path.join(subtitlesDir.path, '${base}_$hash$ext');

    final generatedFile = File(generatedPath);
    if (!await generatedFile.exists()) {
      await generatedFile.writeAsString(sourceContent, flush: true);
    }

    project.filePath = generatedPath;
    project.translationSourceCachePath = generatedPath;

    if (!mounted) return generatedFile;
    await context.read<AppSettings>().addOrUpdateExternalProject(project);

    return generatedFile;
  }

  Future<void> _saveSelectedProjectsToFolder(
    List<TranslationProject> allProjects,
  ) async {
    final trans = context.read<AppSettings>().trans;
    setState(() => _isSaving = true);

    try {
      final selectedProjects = allProjects
          .where((p) => _selectedProjectIds.contains(p.id))
          .toList(growable: false);

      if (selectedProjects.isEmpty) {
        return;
      }

      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: trans['save_all_srt_dialog_title'] ??
            'Select folder to save all subtitles',
      );

      if (dirPath == null || dirPath.trim().isEmpty) {
        return;
      }

      // Farklı platformdan gelen projelerin bloklarını önceden lazy-load et
      if (!mounted) return;
      final settings = context.read<AppSettings>();
      final needLoad = selectedProjects.where((p) => p.processedBlocks.isEmpty && p.id.isNotEmpty).toList();
      if (needLoad.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(trans['loading'] ?? 'Yükleniyor...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
        for (final p in needLoad) {
          await settings.loadProjectBlocksIfNeeded(p.id);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Bloklar yüklendikten sonra güncel proje listesini kullan
      final resolvedProjects = selectedProjects.map((p) {
        if (p.processedBlocks.isNotEmpty) return p;
        return settings.projects.firstWhere((sp) => sp.id == p.id, orElse: () => p);
      }).toList(growable: false);

      final usedNames = <String>{};
      var savedCount = 0;

      for (final project in resolvedProjects) {
        if (project.processedBlocks.isEmpty) {
          continue;
        }

        var fileName = _buildProjectExportFileName(project);
        if (usedNames.contains(fileName)) {
          final dot = fileName.lastIndexOf('.');
          final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
          final ext = dot > 0 ? fileName.substring(dot) : '';
          var i = 2;
          while (usedNames.contains('$stem ($i)$ext')) {
            i++;
          }
          fileName = '$stem ($i)$ext';
        }
        usedNames.add(fileName);

        final srtContent = SubtitleBuilder.buildSrt(project.processedBlocks);
        final file = File(path.join(dirPath, fileName));
        await file.writeAsString(srtContent, flush: true);
        savedCount++;
      }

      if (!mounted) return;

      if (savedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trans['no_content_to_save_error'] ??
                  'Kaydedilecek içerik bulunamadı.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

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

      setState(() {
        _isSelectionMode = false;
        _selectedProjectIds.clear();
        _lastSelectedProjectId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trans['error_prefix'] ?? 'Hata'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _shareProject(TranslationProject project) async {
    try {
      // Farklı platformda tamamlanan projelerin blokları lazy-load ile gelir
      if (project.processedBlocks.isEmpty && project.id.isNotEmpty) {
        if (!mounted) return;
        final settings = context.read<AppSettings>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(settings.trans['loading'] ?? 'Yükleniyor...'),
              ],
            ),
            duration: const Duration(seconds: 15),
          ),
        );
        await settings.loadProjectBlocksIfNeeded(project.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final updated = settings.projects.firstWhere(
          (p) => p.id == project.id,
          orElse: () => project,
        );
        if (updated.processedBlocks.isEmpty) return;
        project = updated;
      }

      final srtContent = SubtitleBuilder.buildSrt(project.processedBlocks);
      final tempDir = await getTemporaryDirectory();
      final fileName = _buildProjectExportFileName(project);
          
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(srtContent);
      
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: fileName),
      );
    } catch (e) {
       if (mounted) {
         final settings = context.read<AppSettings>();
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text(
             (settings.trans['error_with_details'] ?? 'Error: {error}')
                 .replaceAll('{error}', e.toString()),
           ),
           backgroundColor: Colors.red,
         ));
       }
    }
  }

  Future<void> _showProjectDetailDialog(
    AppSettings settings,
    TranslationProject project,
  ) async {
    // Partial kayıtlar için her açılışta cloud resume payload'ını tercih et.
    if (project.id.isNotEmpty &&
        (project.isPartial ||
            project.processedBlocks.isEmpty ||
            project.sourceBlocks.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.trans['loading'] ?? 'Yükleniyor...'),
          duration: const Duration(seconds: 5),
        ),
      );
      await settings.loadProjectBlocksIfNeeded(
        project.id,
        forceCloudRefresh: project.isPartial,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      final updated = settings.projects.firstWhere(
        (p) => p.id == project.id,
        orElse: () => project,
      );
      if (updated.processedBlocks.isEmpty && updated.sourceBlocks.isEmpty) {
        return;
      }
      project = updated;
    }

    final translatedContent = project.processedBlocks.isNotEmpty
        ? SubtitleBuilder.buildSrt(project.processedBlocks)
        : '';
    // SDH temizleme: clearSdh aktifse kaynak bloklarını temizle
    List<SubtitleBlock>? sourceBlocks;
    if (project.sourceBlocks.isNotEmpty) {
      if (project.clearSdh) {
        try {
          final rawSrt = SubtitleBuilder.buildSrt(project.sourceBlocks, resequence: false);
          final cleaned = SubtitleParser.clearSdh(rawSrt);
          final cleanedBlocks = SubtitleParser.parseSrt(cleaned);
          sourceBlocks = cleanedBlocks.isNotEmpty ? cleanedBlocks : project.sourceBlocks;
        } catch (_) {
          sourceBlocks = project.sourceBlocks;
        }
      } else {
        sourceBlocks = project.sourceBlocks;
      }
    }

    await showDialog(
      context: context,
      builder: (_) => BatchFileDetailDialog(
        fileName: _displayFileName(project.fileName),
        translatedContent: translatedContent,
        sourceBlocks: sourceBlocks,
      ),
    );
  }

  String _displayFileName(String name) {
    // Eski batch kopyalama: <timestamp>_foo.srt -> foo.srt
    // Kalıcı depolama hash'ini ekranda göstermeyelim: foo_<md5>.srt -> foo.srt
    final withoutTimestamp = name.replaceFirst(RegExp(r'^\d{10,}_(?=.+\.[^.]+$)'), '');
    return withoutTimestamp.replaceFirst(
      RegExp(r'_[a-f0-9]{32}(?=\.[^.]+$)', caseSensitive: false),
      '',
    );
  }

  bool get _supportsDesktopDragOut {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  String _buildProjectExportFileName(TranslationProject project) {
    final fileNameRaw = project.fileName;
    final ext = path.extension(fileNameRaw);
    final base = fileNameRaw.replaceAll(RegExp(r'\.[^.]*$'), '');

    final noGenerated = StringUtils.stripGeneratedPrefixAndHash(base);
    final stripped = StringUtils.stripLanguageSuffix(noGenerated).trim();
    final safeBase = stripped.isEmpty ? 'subtitle' : stripped;
    final target = project.targetLanguage.trim().toUpperCase();
    final safeExt = ext.isNotEmpty ? ext : '.srt';

    return '${safeBase}_${target.isEmpty ? 'TR' : target}$safeExt';
  }

  Future<File> _writeDragExportTempFile(TranslationProject project, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(path.join(tempDir.path, 'history_drag_exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final content = SubtitleBuilder.buildSrt(project.processedBlocks);
    final filePath = path.join(exportDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<DragItem?> _buildDragItemForProject(TranslationProject project) async {
    // Farklı platformda tamamlanan projelerin blokları lazy-load ile gelir
    if (project.processedBlocks.isEmpty && project.id.isNotEmpty) {
      if (!mounted) return null;
      final settings = context.read<AppSettings>();
      await settings.loadProjectBlocksIfNeeded(project.id);
      if (!mounted) return null;
      final updated = settings.projects.firstWhere(
        (p) => p.id == project.id,
        orElse: () => project,
      );
      project = updated;
    }
    if (project.processedBlocks.isEmpty) return null;

    final fileName = _buildProjectExportFileName(project);
    final file = await _writeDragExportTempFile(project, fileName);

    final item = DragItem(
      suggestedName: fileName,
      localData: {'projectId': project.id},
    );
    item.add(Formats.fileUri(Uri.file(file.path)));
    return item;
  }

  Future<void> _saveProjectWithCloudChoice(
    BuildContext context,
    AppSettings settings,
    TranslationProject project,
  ) async {
    final trans = settings.trans;

    // Farklı platformda tamamlanan projelerin blokları lazy-load ile gelir
    if (project.processedBlocks.isEmpty && project.id.isNotEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(trans['loading'] ?? 'Yükleniyor...'),
            ],
          ),
          duration: const Duration(seconds: 15),
        ),
      );
      await settings.loadProjectBlocksIfNeeded(project.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final updated = settings.projects.firstWhere(
        (p) => p.id == project.id,
        orElse: () => project,
      );
      if (updated.processedBlocks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans['error_loading_project'] ?? 'Proje yüklenemedi veya içerik boş.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      project = updated;
    }

    final content = SubtitleBuilder.buildSrt(project.processedBlocks);
    final fileName = _buildProjectExportFileName(project);

    final bytes = Uint8List.fromList(utf8.encode(content));
    final isAndroidIos = Platform.isAndroid || Platform.isIOS;
    final dialogTitle =
        cloudSourceDialogTitle(CloudSource.device, trans, isSave: true);
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      bytes: isAndroidIos ? bytes : null,
    );
    if (savedPath != null && !isAndroidIos) {
      await File(savedPath).writeAsBytes(bytes, flush: true);
    }
    if (savedPath != null) {
      settings.addLog('log_saved', isAndroidIos ? fileName : savedPath);
    }
  }

  Future<void> _resumeProject(
    AppSettings settings,
    TranslationController controller,
    TranslationProject project,
  ) async {
    if (!mounted) return;
    final trans = settings.trans;
    final messenger = ScaffoldMessenger.of(context);

    final hasCloudResume = project.resumeStateJson != null && project.resumeStateJson!.isNotEmpty;
    File? file;
    var clearSdhForRun = settings.sdhClear;
    var usedLocalCacheResume = false;

    if (hasCloudResume) {
      final r = await controller.prepareResumeFromCloudState(project: project);
      if (!r.ok) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              trans['resume_failed_try_again'] ??
                  'Devam ettirme başlatılamadı. İnternet/giriş/bakiye durumunu kontrol edip tekrar deneyin.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: trans['delete'] ?? 'Sil',
              textColor: Colors.white,
              onPressed: () {
                settings.deleteProject(project.id);
                if (mounted) {
                  context.read<TranslationController>().clearResumeCache();
                }
              },
            ),
          ),
        );
        return;
      }
      clearSdhForRun = r.clearSdh;
      final p = controller.selectedFile?.path ?? project.filePath;
      file = p.trim().isEmpty ? null : File(p);
    } else {
      file = await _resolveResumeSourceFile(project);
      if (file == null || !await file.exists()) {
        final localRes =
            await controller.prepareResumeFromLocalCacheForProject(project: project);
        if (localRes.ok) {
          clearSdhForRun = localRes.clearSdh;
          file = controller.selectedFile;
          usedLocalCacheResume = true;
        }
      }

      if (file == null || !await file.exists()) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              trans['file_not_found'] ??
                  'Dosya bulunamadı. Cache temizlenmiş olabilir.\nLütfen dosyayı yeniden seçin ve çeviriyi başlatın.',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: trans['delete'] ?? 'Sil',
              textColor: Colors.white,
              onPressed: () {
                settings.deleteProject(project.id);
                if (mounted) {
                  context.read<TranslationController>().clearResumeCache();
                }
              },
            ),
          ),
        );
        return;
      }
    }

    await settings.resumePartialTranslation(project);
    if (!mounted) return;

    controller.onLog = (key, [param]) => settings.addLog(key, param);
    controller.onProgress = settings.showProgressNotification;
    controller.onError = (title, message) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(settings.trans['ok'] ?? 'Tamam'),
            ),
          ],
        ),
      );
    };
    controller.onWakelock = (enabled) {
      if (enabled) {
        if (settings.keepScreenOn) {
          settings.setWakelockEnabled(true);
        }
        return;
      }
      settings.setWakelockEnabled(false);
    };

    if (!hasCloudResume && !usedLocalCacheResume) {
      await controller.prepareResumeFromBlocks(
        file: file!,
        alreadyTranslatedBlocks: project.processedBlocks,
        clearSdh: clearSdhForRun,
        targetLanguage: project.targetLanguage,
        expectedSourceBlockCount: project.sourceBlocks.length,
      );
    }

    if (!mounted) return;

    final permanentPath = controller.selectedFile?.path ?? project.filePath;

    final displayFileName = StringUtils.normalizeDisplayFileName(project.fileName);

    await settings.addFileToBatchTranslation(
      displayFileName,
      permanentPath,
      insertAtTop: true,
    );

    if (!mounted) return;

    unawaited(
      controller.startBatchTranslationQueue(
        files: [
          BatchFile(
            name: displayFileName,
            path: permanentPath,
          ),
        ],
        clearSdh: clearSdhForRun,
        targetLanguage: project.targetLanguage,
        playCompletionSound: true,
      ),
    );

    settings.requestTabSwitch(0);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (!mounted) return;
    final resumeFileText = (trans['resume_file'] ?? 'Dosya: {fileName}')
        .replaceAll('{fileName}', _displayFileName(project.fileName));
    final resumeSuccessText =
        trans['resume_success'] ?? 'Kaldığınız yerden devam ediliyor...';
    messenger.showSnackBar(
      SnackBar(
        content: Text('$resumeSuccessText\n$resumeFileText'),
        duration: const Duration(seconds: 3),
      ),
    );

    // Hide from History only if translation actually started.
    // If start fails, keep it visible and clear the active flag.
    final sourceHash = (project.sourceHash ?? '').trim();
    final canMarkActive = sourceHash.isNotEmpty;
    if (canMarkActive) {
      settings.addOrUpdateExternalProject(project.copyWith(isActive: true));
    }
    unawaited(() async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      final isStarted = controller.status == TranslationStatus.running ||
          controller.status == TranslationStatus.paused;

      if (canMarkActive) {
        try {
          await controller.setUserHistoryActive(
            sourceHash: sourceHash,
            targetLanguage: project.targetLanguage,
            isActive: isStarted,
          );
        } catch (_) {
          // Best-effort; queue retry.
        }

        if (!mounted) return;
        settings.addOrUpdateExternalProject(project.copyWith(isActive: isStarted));
      }

      if (!isStarted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              trans['resume_failed_try_again'] ??
                  'Devam ettirme başlatılamadı. İnternet/giriş/bakiye durumunu kontrol edip tekrar deneyin.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }());
  }

  Future<void> _deleteProjectFromHistory(
    AppSettings settings,
    TranslationProject project,
    ColorScheme colorScheme,
  ) async {
    final trans = settings.trans;
    final translationController = context.read<TranslationController>();

    void syncSelectionAfterDelete() {
      if (!mounted) return;
      setState(() {
        _selectedProjectIds.remove(project.id);
        _isSelectionMode = _selectedProjectIds.isNotEmpty;
        if (_selectedProjectIds.isEmpty) {
          _lastSelectedProjectId = null;
        }
      });
    }

    if (!settings.confirmDeletes) {
      await _deleteProjectFile(project);
      if (!mounted) return;
      settings.deleteProject(project.id);
      syncSelectionAfterDelete();
      translationController.clearResumeCache();
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans['delete_project_title'] ?? 'Projeyi Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trans['delete_project_confirm'] ?? 'Bu proje silinecek.'),
            const SizedBox(height: 12),
            Text(
              trans['delete_permanent_warning'] ??
                  'Bu işlem geri alınamaz!',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(trans['btn_cancel'] ?? 'İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteProjectFile(project);
              if (!mounted) return;
              settings.deleteProject(project.id);
              syncSelectionAfterDelete();
              translationController.clearResumeCache();
            },
            child: Text(trans['delete'] ?? 'Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProjectsFromHistory(
    AppSettings settings,
    List<TranslationProject> projects,
    ColorScheme colorScheme,
  ) async {
    if (projects.isEmpty) return;

    final trans = settings.trans;
    final translationController = context.read<TranslationController>();

    if (!settings.confirmDeletes) {
      for (final project in projects) {
        await _deleteProjectFile(project);
        if (!mounted) return;
        settings.deleteProject(project.id);
      }
      if (!mounted) return;
      setState(() {
        _selectedProjectIds.removeWhere(
          (id) => projects.any((project) => project.id == id),
        );
        _isSelectionMode = _selectedProjectIds.isNotEmpty;
        if (_selectedProjectIds.isEmpty) {
          _lastSelectedProjectId = null;
        }
      });
      translationController.clearResumeCache();
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans['delete_project_title'] ?? 'Projeyi Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projects.length > 1
                  ? (trans['delete_all_permanent_warning'] ??
                      'Tüm öğeler kalıcı olarak silinecek ve geri getirilemeyecek.')
                  : (trans['delete_project_confirm'] ?? 'Bu proje silinecek.'),
            ),
            const SizedBox(height: 12),
            Text(
              trans['delete_permanent_warning'] ??
                  'Bu işlem geri alınamaz!',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(trans['btn_cancel'] ?? 'İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              for (final project in projects) {
                await _deleteProjectFile(project);
                if (!mounted) return;
                settings.deleteProject(project.id);
              }
              if (!mounted) return;
              setState(() {
                _selectedProjectIds.removeWhere(
                  (id) => projects.any((project) => project.id == id),
                );
                _isSelectionMode = _selectedProjectIds.isNotEmpty;
                if (_selectedProjectIds.isEmpty) {
                  _lastSelectedProjectId = null;
                }
              });
              translationController.clearResumeCache();
            },
            child: Text(trans['delete'] ?? 'Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProjectContextMenu({
    required Offset globalPosition,
    required AppSettings settings,
    required TranslationController controller,
    required TranslationProject project,
    required ColorScheme colorScheme,
  }) async {
    final trans = settings.trans;
    final hasMultiSelection = _selectedProjectIds.length > 1;
    final action = await showMenu<_HistoryProjectMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        if (project.isCompleted && !hasMultiSelection)
          PopupMenuItem<_HistoryProjectMenuAction>(
            value: _HistoryProjectMenuAction.openInEditor,
            child: Row(
              children: [
                const Icon(Icons.edit_document, size: 18),
                const SizedBox(width: 8),
                Text(trans['btn_open_in_editor'] ?? 'Editörde Aç'),
              ],
            ),
          ),
        if (!hasMultiSelection)
          PopupMenuItem<_HistoryProjectMenuAction>(
            value: _HistoryProjectMenuAction.compareWithSource,
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, size: 18),
                const SizedBox(width: 8),
                Text(trans['compare_with_source'] ?? 'Kaynak ile Karşılaştır'),
              ],
            ),
          ),
        // Windows'ta Share butonu gizlenir (masaüstünde sistem paylaşımı yerine Kaydet kullanılır)
        if (project.isCompleted && !Platform.isWindows)
          PopupMenuItem<_HistoryProjectMenuAction>(
            value: _HistoryProjectMenuAction.share,
            child: Row(
              children: [
                const Icon(Icons.share, size: 18),
                const SizedBox(width: 8),
                Text(trans['share'] ?? 'Paylaş'),
              ],
            ),
          ),
        if (project.isCompleted)
          PopupMenuItem<_HistoryProjectMenuAction>(
            value: _HistoryProjectMenuAction.save,
            child: Row(
              children: [
                const Icon(Icons.save, size: 18),
                const SizedBox(width: 8),
                Text(trans['save'] ?? trans['btn_save'] ?? 'Kaydet'),
              ],
            ),
          ),
        if (!project.isCompleted)
          PopupMenuItem<_HistoryProjectMenuAction>(
            value: _HistoryProjectMenuAction.resume,
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, size: 18),
                const SizedBox(width: 8),
                Text(trans['btn_resume'] ?? 'Devam Et'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<_HistoryProjectMenuAction>(
          value: _HistoryProjectMenuAction.delete,
          child: Row(
            children: [
              const Icon(Icons.delete, size: 18, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(trans['delete'] ?? 'Sil'),
            ],
          ),
        ),
      ],
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _HistoryProjectMenuAction.openInEditor:
        _openInEditor(settings, project);
        return;
      case _HistoryProjectMenuAction.compareWithSource:
        await _showProjectDetailDialog(settings, project);
        return;
      case _HistoryProjectMenuAction.share:
        _shareProject(project);
        return;
      case _HistoryProjectMenuAction.save:
        await _saveProjectWithCloudChoice(context, settings, project);
        return;
      case _HistoryProjectMenuAction.resume:
        await _resumeProject(settings, controller, project);
        return;
      case _HistoryProjectMenuAction.delete:
        if (_selectedProjectIds.contains(project.id) &&
            _selectedProjectIds.length > 1) {
          final selectedProjects = settings.projects
              .where((p) => _selectedProjectIds.contains(p.id))
              .toList(growable: false);
          await _deleteProjectsFromHistory(
            settings,
            selectedProjects,
            colorScheme,
          );
        } else {
          await _deleteProjectFromHistory(settings, project, colorScheme);
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final controller = context.watch<TranslationController>();
    final trans = settings.trans;
    final colorScheme = Theme.of(context).colorScheme;

    final allProjects = List<TranslationProject>.from(settings.projects)
      .where((p) => !p.isActive)
      .toList(growable: false);

    String normalizePath(String path) {
      final normalized = path.replaceAll('/', Platform.pathSeparator);
      return Platform.isWindows ? normalized.toLowerCase() : normalized;
    }

    String normalizeSearchText(String value) {
      const replacements = {
        'Á': 'A',
        'À': 'A',
        'Â': 'A',
        'Ã': 'A',
        'Ä': 'A',
        'Å': 'A',
        'á': 'a',
        'à': 'a',
        'â': 'a',
        'ã': 'a',
        'ä': 'a',
        'å': 'a',
        'Ç': 'C',
        'ç': 'c',
        'É': 'E',
        'È': 'E',
        'Ê': 'E',
        'Ë': 'E',
        'é': 'e',
        'è': 'e',
        'ê': 'e',
        'ë': 'e',
        'Í': 'I',
        'Ì': 'I',
        'Î': 'I',
        'Ï': 'I',
        'í': 'i',
        'ì': 'i',
        'î': 'i',
        'ï': 'i',
        'Ñ': 'N',
        'ñ': 'n',
        'Ó': 'O',
        'Ò': 'O',
        'Ô': 'O',
        'Õ': 'O',
        'Ö': 'O',
        'ó': 'o',
        'ò': 'o',
        'ô': 'o',
        'õ': 'o',
        'ö': 'o',
        'Ú': 'U',
        'Ù': 'U',
        'Û': 'U',
        'Ü': 'U',
        'ú': 'u',
        'ù': 'u',
        'û': 'u',
        'ü': 'u',
        'Ý': 'Y',
        'ý': 'y',
        'ÿ': 'y',
      };

      final buffer = StringBuffer();
      for (final ch in value.split('')) {
        buffer.write(replacements[ch] ?? ch);
      }

      return buffer
          .toString()
          .replaceAll('I', 'i')
          .replaceAll('İ', 'i')
          .replaceAll('ı', 'i')
          .toLowerCase();
    }

    final normalizedSearchQuery = normalizeSearchText(_searchQuery.trim());

    final activePath = controller.selectedFile?.path;
    final activePathNorm = activePath == null ? null : normalizePath(activePath);
    final hideActive = controller.status == TranslationStatus.running ||
        controller.status == TranslationStatus.paused;

    final filteredProjects = allProjects.where((p) {
      if (hideActive && activePathNorm != null) {
        if (normalizePath(p.filePath) == activePathNorm) return false;
      }
      if (normalizedSearchQuery.isNotEmpty) {
        final normalizedFileName = normalizeSearchText(p.fileName);
        if (!normalizedFileName.contains(normalizedSearchQuery)) return false;
      }
      if (_filterOption == FilterOption.completed) {
        if (!p.isCompleted) return false;
      } else if (_filterOption == FilterOption.partial) {
        if (!p.isPartial) return false;
      }
      return true;
    }).toList();

    filteredProjects.sort((a, b) {
      int cmp;
      if (_sortOption == SortOption.date) {
        cmp = a.lastUpdated.compareTo(b.lastUpdated);
      } else {
        cmp = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
      }
      return _ascending ? cmp : -cmp;
    });

    return Scaffold(
      appBar: _buildAppBar(
        settings,
        trans,
        allProjects,
        filteredProjects,
        tokenHistory: controller.showTokenWalletUi,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTranslationHistoryBody(
            settings,
            controller,
            trans,
            colorScheme,
            allProjects,
            filteredProjects,
          ),
          const CreditHistoryBody(),
        ],
      ),
    );
  }

  Widget _buildTranslationHistoryBody(
    AppSettings settings,
    TranslationController controller,
    Map<String, String> trans,
    ColorScheme colorScheme,
    List<TranslationProject> allProjects,
    List<TranslationProject> filteredProjects,
  ) {
    return Stack(
      key: _bodyStackKey,
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: trans['search_history_hint'] ?? 'Geçmişte ara...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        ),
                      PopupMenuButton<FilterOption>(
                        icon: Icon(
                          _filterOption == FilterOption.all
                              ? Icons.filter_list
                              : Icons.filter_alt,
                          color: _filterOption == FilterOption.all
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.primary,
                        ),
                        tooltip: _localizedOrSafeFallback(
                          settings: settings,
                          trans: trans,
                          key: 'filter_tooltip',
                          trFallback: 'Filtrele',
                          englishValue: 'Filter',
                        ),
                        onSelected: (FilterOption result) {
                          setState(() {
                            _filterOption = result;
                          });
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<FilterOption>>[
                          PopupMenuItem<FilterOption>(
                            value: FilterOption.all,
                            child: Text(
                              _localizedOrSafeFallback(
                                settings: settings,
                                trans: trans,
                                key: 'filter_all',
                                trFallback: 'Tümü',
                                englishValue: 'All',
                              ),
                            ),
                          ),
                          PopupMenuItem<FilterOption>(
                            value: FilterOption.completed,
                            child: Text(
                              _localizedOrSafeFallback(
                                settings: settings,
                                trans: trans,
                                key: 'filter_completed',
                                trFallback: 'Tamamlananlar',
                                englishValue: 'Completed',
                              ),
                            ),
                          ),
                          PopupMenuItem<FilterOption>(
                            value: FilterOption.partial,
                            child: Text(
                              _localizedOrSafeFallback(
                                settings: settings,
                                trans: trans,
                                key: 'filter_partial',
                                trFallback: 'Yarım Kalanlar',
                                englishValue: 'Partial',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(
                    LogicalKeyboardKey.keyA,
                    control: true,
                  ): _SelectAllVisibleIntent(),
                  SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: true,
                  ): _SelectAllVisibleIntent(),
                  SingleActivator(
                    LogicalKeyboardKey.delete,
                  ): _DeleteSelectedIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _SelectAllVisibleIntent:
                        CallbackAction<_SelectAllVisibleIntent>(
                      onInvoke: (intent) {
                        _toggleSelectAllVisible(filteredProjects);
                        return null;
                      },
                    ),
                    _DeleteSelectedIntent:
                        CallbackAction<_DeleteSelectedIntent>(
                      onInvoke: (intent) {
                        if (_selectedProjectIds.isEmpty) {
                          return null;
                        }

                        final selectedProjects = settings.projects
                            .where((p) => _selectedProjectIds.contains(p.id))
                            .toList(growable: false);
                        if (selectedProjects.isEmpty) {
                          return null;
                        }

                        unawaited(() async {
                          if (selectedProjects.length == 1) {
                            await _deleteProjectFromHistory(
                              settings,
                              selectedProjects.first,
                              colorScheme,
                            );
                            return;
                          }

                          await _deleteProjectsFromHistory(
                            settings,
                            selectedProjects,
                            colorScheme,
                          );
                        }());

                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    focusNode: _historyListFocusNode,
                    autofocus: true,
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) {
                        _historyListFocusNode.requestFocus();
                        final isPrimaryPressed =
                            (event.buttons & kPrimaryMouseButton) != 0;
                        if (isPrimaryPressed) {
                          _lastPrimaryDownGlobal = event.position;
                        }
                        _startMarqueeSelection(event, filteredProjects);
                      },
                      onPointerMove: (event) {
                        _updateMarqueeSelection(event, filteredProjects);
                      },
                      onPointerUp: (_) {
                        _lastPrimaryDownGlobal = null;
                        _finishMarqueeSelection();
                      },
                      onPointerCancel: (_) {
                        _lastPrimaryDownGlobal = null;
                        _finishMarqueeSelection();
                      },
                      child: filteredProjects.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: colorScheme.onSurface.withAlpha(50),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? (trans['history_no_results'] ??
                                            'Arama sonucu bulunamadı.')
                                        : (trans['history_no_projects'] ??
                                            'Henüz kayıtlı proje yok.'),
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withAlpha(
                                        150,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              itemCount: filteredProjects.length,
                              itemBuilder: (context, index) {
                                final project = filteredProjects[index];
                                final dragItemKey =
                                    _dragKeyForProject(project.id);
                                final cardKey = _cardKeyForProject(project.id);
                                final displayFileName =
                                    _displayFileName(project.fileName);
                                int derivedTranslated =
                                    project.translatedLines;
                                int derivedTotal = project.totalLines;

                                final resume = project.resumeStateJson;
                                if (!project.isCompleted && resume != null) {
                                  if (derivedTranslated <= 0) {
                                    final blocksRaw =
                                        resume['translatedBlocks'];
                                    if (blocksRaw is List) {
                                      derivedTranslated = blocksRaw.length;
                                    }
                                  }
                                  if (derivedTotal <= 0) {
                                    final totalBlocksRaw = resume['totalBlocks'];
                                    if (totalBlocksRaw is num) {
                                      derivedTotal = totalBlocksRaw.toInt();
                                    }
                                    if (derivedTotal <= 0) {
                                      final sourceContent =
                                          (resume['sourceContent'] as String?) ??
                                              '';
                                      if (sourceContent.trim().isNotEmpty) {
                                        derivedTotal = SubtitleParser.parseSrt(
                                          sourceContent,
                                        ).length;
                                      }
                                    }
                                    if (derivedTotal <= 0) {
                                      final totalRaw = resume['totalLines'];
                                      if (totalRaw is num) {
                                        derivedTotal = totalRaw.toInt();
                                      }
                                    }
                                  }
                                }

                                final percent = project.isCompleted
                                    ? 100
                                    : (derivedTotal > 0
                                        ? ((derivedTranslated / derivedTotal) *
                                                100)
                                            .toInt()
                                        : 0);
                                final progressValue =
                                    (project.isCompleted || derivedTotal <= 0)
                                        ? 1.0
                                        : (derivedTranslated / derivedTotal)
                                            .clamp(0.0, 1.0);
                                final isSelected =
                                    _selectedProjectIds.contains(project.id);
                                final isHovered = _supportsDesktopDragOut &&
                                    _hoveredProjectId == project.id;

                                final card = MouseRegion(
                                  onEnter: (_) {
                                    if (!_supportsDesktopDragOut) return;
                                    if (_hoveredProjectId == project.id) return;
                                    setState(
                                      () => _hoveredProjectId = project.id,
                                    );
                                  },
                                  onExit: (_) {
                                    if (!_supportsDesktopDragOut) return;
                                    if (_hoveredProjectId != project.id) return;
                                    setState(() => _hoveredProjectId = null);
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: isHovered ? 2.0 : 1.0,
                                    color: isSelected
                                        ? colorScheme.primaryContainer
                                            .withAlpha(100)
                                        : (isHovered
                                            ? colorScheme.surfaceContainerHigh
                                                .withAlpha(180)
                                            : null),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      hoverColor: _supportsDesktopDragOut
                                          ? colorScheme.primary
                                              .withValues(alpha: 0.06)
                                          : null,
                                      onLongPress: () {
                                        final startPoint =
                                            _lastPrimaryDownGlobal;
                                        if (startPoint == null) {
                                          setState(() {
                                            _isSelectionMode = true;
                                            _selectedProjectIds.add(project.id);
                                            _lastSelectedProjectId = project.id;
                                          });
                                          return;
                                        }

                                        _armMarqueeFromLongPress(
                                          globalPosition: startPoint,
                                          projectId: project.id,
                                        );
                                      },
                                      onSecondaryTapDown: (details) {
                                        if (!_supportsDesktopDragOut) return;
                                        unawaited(
                                          _showProjectContextMenu(
                                            globalPosition:
                                                details.globalPosition,
                                            settings: settings,
                                            controller: controller,
                                            project: project,
                                            colorScheme: colorScheme,
                                          ),
                                        );
                                      },
                                      onTap: () {
                                        final isCtrlOrCmdPressed =
                                            HardwareKeyboard
                                                    .instance.isControlPressed ||
                                                HardwareKeyboard
                                                    .instance.isMetaPressed;
                                        final isShiftPressed = HardwareKeyboard
                                            .instance.isShiftPressed;

                                        if (isShiftPressed &&
                                            _lastSelectedProjectId != null) {
                                          final anchorIndex = filteredProjects
                                              .indexWhere(
                                            (p) =>
                                                p.id == _lastSelectedProjectId,
                                          );
                                          if (anchorIndex != -1) {
                                            final start = anchorIndex < index
                                                ? anchorIndex
                                                : index;
                                            final end = anchorIndex > index
                                                ? anchorIndex
                                                : index;

                                            setState(() {
                                              if (!isCtrlOrCmdPressed) {
                                                _selectedProjectIds.clear();
                                              }
                                              for (var i = start;
                                                  i <= end;
                                                  i++) {
                                                _selectedProjectIds.add(
                                                  filteredProjects[i].id,
                                                );
                                              }
                                              _isSelectionMode = true;
                                              _lastSelectedProjectId =
                                                  project.id;
                                            });
                                            return;
                                          }
                                        }

                                        if (isCtrlOrCmdPressed) {
                                          setState(() {
                                            _isSelectionMode = true;
                                            if (isSelected) {
                                              _selectedProjectIds.remove(
                                                project.id,
                                              );
                                              if (_selectedProjectIds.isEmpty) {
                                                _isSelectionMode = false;
                                                _lastSelectedProjectId = null;
                                              }
                                            } else {
                                              _selectedProjectIds.add(project.id);
                                            }
                                            _lastSelectedProjectId = project.id;
                                          });
                                          return;
                                        }

                                        if (_isSelectionMode) {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedProjectIds.remove(
                                                project.id,
                                              );
                                              if (_selectedProjectIds.isEmpty) {
                                                _isSelectionMode = false;
                                                _lastSelectedProjectId = null;
                                              }
                                            } else {
                                              _selectedProjectIds.add(project.id);
                                            }
                                            _lastSelectedProjectId = project.id;
                                          });
                                        } else {
                                          _lastSelectedProjectId = project.id;
                                          unawaited(
                                            _showProjectDetailDialog(
                                              settings,
                                              project,
                                            ),
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 140,
                                                  ),
                                                  curve: Curves.easeOut,
                                                  width: _isSelectionMode
                                                      ? 34
                                                      : 0,
                                                  height: 24,
                                                  child: _isSelectionMode
                                                      ? Checkbox(
                                                          value: isSelected,
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          materialTapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                          onChanged:
                                                              (bool? value) {
                                                            setState(() {
                                                              if (value ==
                                                                  true) {
                                                                _selectedProjectIds
                                                                    .add(
                                                                  project.id,
                                                                );
                                                                _lastSelectedProjectId =
                                                                    project.id;
                                                              } else {
                                                                _selectedProjectIds
                                                                    .remove(
                                                                  project.id,
                                                                );
                                                                if (_selectedProjectIds
                                                                    .isEmpty) {
                                                                  _isSelectionMode =
                                                                      false;
                                                                  _lastSelectedProjectId =
                                                                      null;
                                                                }
                                                              }
                                                            });
                                                          },
                                                        )
                                                      : null,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    displayFileName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.fade,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          "${trans['language_title']}: ${project.targetLanguage}  •  %$percent",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (project.isPartial) ...[
                                                        const SizedBox(width: 6),
                                                        Tooltip(
                                                          message: trans[
                                                                  'partial_drag_not_supported_hint'] ??
                                                              'Yarım çeviriler sürüklenemez.',
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.orange
                                                                  .withAlpha(50),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                4,
                                                              ),
                                                              border: Border.all(
                                                                color: Colors.orange,
                                                                width: 1,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              trans['partial'] ??
                                                                  'Yarım',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.orange,
                                                                fontWeight:
                                                                    FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                if (!_isSelectionMode) ...[
                                                  const SizedBox(width: 8),
                                                  if (project.isCompleted)
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          _openInEditor(
                                                        settings,
                                                        project,
                                                      ),
                                                      icon: const Icon(
                                                        Icons.edit_document,
                                                        color: Colors.blue,
                                                        size: 18,
                                                      ),
                                                      label: Text(
                                                        trans['btn_open_in_editor'] ??
                                                            'Editörde Aç',
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor:
                                                            Colors.blue,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                  if (project.isCompleted)
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          _shareProject(project),
                                                      icon: const Icon(
                                                        Icons.share,
                                                        color: Colors.green,
                                                        size: 18,
                                                      ),
                                                      label: Text(
                                                        trans['share'] ??
                                                            'Paylaş',
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor:
                                                            Colors.green,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                  if (project.isCompleted)
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          _saveProjectWithCloudChoice(
                                                        context,
                                                        settings,
                                                        project,
                                                      ),
                                                      icon: const Icon(
                                                        Icons.save,
                                                        color: Colors.teal,
                                                        size: 18,
                                                      ),
                                                      label: Text(
                                                        trans['save'] ??
                                                            trans['btn_save'] ??
                                                            'Kaydet',
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor:
                                                            Colors.teal,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    )
                                                  else ...[
                                                    Tooltip(
                                                      message:
                                                          trans['btn_resume'] ??
                                                              'Devam Et',
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.play_circle_fill,
                                                          color: Colors.orange,
                                                          size: 22,
                                                        ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets.all(
                                                          2,
                                                        ),
                                                        constraints:
                                                            const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 28,
                                                        ),
                                                        onPressed: () =>
                                                            _resumeProject(
                                                          settings,
                                                          controller,
                                                          project,
                                                        ),
                                                      ),
                                                    ),
                                                    Tooltip(
                                                      message:
                                                          trans['delete'] ??
                                                              'Sil',
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.redAccent,
                                                          size: 20,
                                                        ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets.all(
                                                          2,
                                                        ),
                                                        constraints:
                                                            const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 28,
                                                        ),
                                                        onPressed: () =>
                                                            _deleteProjectFromHistory(
                                                          settings,
                                                          project,
                                                          colorScheme,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  if (project.isCompleted)
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          _deleteProjectFromHistory(
                                                        settings,
                                                        project,
                                                        colorScheme,
                                                      ),
                                                      icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.redAccent,
                                                        size: 18,
                                                      ),
                                                      label: Text(
                                                        trans['delete'] ?? 'Sil',
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor:
                                                            Colors.redAccent,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                ],
                                              ],
                                            ),
                                            if (project.isPartial) ...[
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                child: LinearProgressIndicator(
                                                  value: progressValue,
                                                  minHeight: 3,
                                                  backgroundColor: colorScheme
                                                      .onSurfaceVariant
                                                      .withAlpha(45),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    project.lastUpdated
                                                        .split('.')
                                                        .first,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: colorScheme
                                                          .onSurfaceVariant
                                                          .withAlpha(150),
                                                    ),
                                                  ),
                                                ),
                                                if (project.completedPlatform !=
                                                        null &&
                                                    project.completedPlatform!
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 4,
                                                    ),
                                                    child: Text(
                                                      _platformDisplayName(
                                                        project
                                                            .completedPlatform!,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: colorScheme
                                                            .onSurfaceVariant
                                                            .withAlpha(150),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                                final keyedCard = KeyedSubtree(
                                  key: cardKey,
                                  child: card,
                                );

                                if (project.isCompleted &&
                                    _supportsDesktopDragOut) {
                                  return DragItemWidget(
                                    key: dragItemKey,
                                    allowedOperations: () =>
                                        [DropOperation.copy],
                                    dragItemProvider: (request) async {
                                      return _buildDragItemForProject(project);
                                    },
                                    dragBuilder: (ctx, _) {
                                      final cs = Theme.of(ctx).colorScheme;
                                      return Material(
                                        elevation: 6,
                                        borderRadius: BorderRadius.circular(8),
                                        color: cs.surfaceContainerHigh,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.subtitles_outlined,
                                                size: 18,
                                                color: cs.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                  maxWidth: 260,
                                                ),
                                                child: Text(
                                                  displayFileName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: cs.onSurface,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: DraggableWidget(
                                      dragItemsProvider: (context) {
                                        if (!isSelected ||
                                            !_isSelectionMode ||
                                            _selectedProjectIds.length <= 1) {
                                          final current =
                                              dragItemKey.currentState;
                                          return current != null
                                              ? [current]
                                              : const <DragItemWidgetState>[];
                                        }

                                        final states =
                                            <DragItemWidgetState>[];
                                        for (final projectId
                                            in _selectedProjectIds) {
                                          final state = _dragItemKeys[projectId]
                                              ?.currentState;
                                          if (state != null) {
                                            states.add(state);
                                          }
                                        }

                                        if (states.isEmpty) {
                                          final current =
                                              dragItemKey.currentState;
                                          return current != null
                                              ? [current]
                                              : const <DragItemWidgetState>[];
                                        }

                                        return states;
                                      },
                                      child: keyedCard,
                                    ),
                                  );
                                }

                                return keyedCard;
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isMarqueeSelecting &&
            _marqueeStartGlobal != null &&
            _marqueeCurrentGlobal != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SelectionMarqueePainter(
                  startGlobal: _marqueeStartGlobal!,
                  currentGlobal: _marqueeCurrentGlobal!,
                  referenceKey: _bodyStackKey,
                  colorScheme: colorScheme,
                ),
              ),
            ),
          ),
        if (_isSaving)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        trans['saving_files_progress'] ??
                            'Dosyalar hazırlanıyor...',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<bool> _confirmReplaceDirtyEditorIfNeeded(AppSettings settings) async {
    final hasUnsavedWork = settings.isEditorDirty;
    if (!hasUnsavedWork) {
      return true;
    }

    final trans = settings.trans;

    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(
            trans['editor_unsaved_warning_title'] ??
                'Unsaved changes detected',
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
              child: Text(trans['editor_unsaved_discard'] ?? 'Kaydetmeden Aç'),
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

    if (!mounted) return false;

    if (decision == 'save') {
      await settings.saveResult(isEditorSave: true);
      if (!mounted) return false;
      return !settings.isEditorDirty;
    }

    return decision == 'discard';
  }

  void _openInEditor(AppSettings settings, TranslationProject project) async {
    final canReplace = await _confirmReplaceDirtyEditorIfNeeded(settings);
    if (!canReplace || !mounted) return;

    // Cloud'dan gelen projede bloklar henüz yüklenmemişse veya eksikse önce çek
    // (processedBlocks boşsa ve ID geçerliyse)
    if (project.processedBlocks.isEmpty && project.id.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(settings.trans['loading'] ?? 'Yükleniyor...'),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );

      // Blokları yükle (yerel cache yoksa Cloud'dan çeker)
      await settings.loadProjectBlocksIfNeeded(project.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Yükleme sonrası güncel proje nesnesini al
      final updated = settings.projects.firstWhere(
        (p) => p.id == project.id,
        orElse: () => project,
      );

      // Bloklar hala boşsa (hata veya veri yok), kullanıcıya bildir
      if (updated.processedBlocks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settings.trans['error_loading_project'] ?? 'Proje yüklenemedi veya içerik boş.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Güncellenmiş proje ile devam et
      project = updated;
    }

    await settings.openProjectInEditorAsync(project);
    if (mounted) {
      settings.requestTabSwitch(1);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  bool _isEnglishUi(AppSettings settings) {
    final code = settings.language.trim().toLowerCase();
    return code == 'en' || code.startsWith('en_') || code.startsWith('en-');
  }

  String _localizedOrSafeFallback({
    required AppSettings settings,
    required Map<String, String> trans,
    required String key,
    required String trFallback,
    String? englishValue,
  }) {
    final value = trans[key];
    if (value == null || value.trim().isEmpty || value == key) {
      return trFallback;
    }

    if (!_isEnglishUi(settings)) {
      final normalized = value.trim().toLowerCase();
      final exactEnglishMatch = englishValue != null &&
          normalized == englishValue.trim().toLowerCase();
      final likelyEnglishByKey = switch (key) {
        'sort_tooltip' => normalized.startsWith('sort'),
        'filter_tooltip' => normalized.startsWith('filter'),
        'sort_date_desc' || 'sort_date_asc' => normalized.startsWith('date'),
        'sort_name_asc' || 'sort_name_desc' => normalized.startsWith('name'),
        'filter_all' => normalized == 'all',
        'filter_completed' => normalized == 'completed',
        'filter_partial' => normalized == 'partial',
        'back' => normalized == 'back',
        _ => false,
      };

      if (exactEnglishMatch || likelyEnglishByKey) {
        return trFallback;
      }
    }

    return value;
  }

  AppBar _buildAppBar(
    AppSettings settings,
    Map<String, String> trans,
    List<TranslationProject> allProjects,
    List<TranslationProject> visibleProjects, {
    bool tokenHistory = false,
  }) {
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        );
    final unselectedLabelStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            );
    final tabs = TabBar(
      controller: _tabController,
      isScrollable: false,
      indicatorSize: TabBarIndicatorSize.tab,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      labelStyle: labelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      tabs: [
        _buildHistoryTabLabel(trans['history_title'] ?? 'Çeviri Geçmişi'),
        _buildHistoryTabLabel(
          tokenHistory
              ? (trans['credit_history_title_tokens'] ??
                  trans['credit_history_title'] ??
                  'Token Geçmişi')
              : (trans['credit_history_title'] ?? 'Kredi Geçmişi'),
        ),
      ],
    );

    if (_isSelectionMode && _activeTabIndex == 0) {
      final visibleIds = visibleProjects.map((p) => p.id).toSet();
      final canToggleSelectAll = visibleIds.isNotEmpty;
      final allVisibleSelected =
          canToggleSelectAll && visibleIds.every(_selectedProjectIds.contains);
      final selectedProjects = allProjects
          .where((p) => _selectedProjectIds.contains(p.id))
          .toList(growable: false);
      final canBulkDelete = selectedProjects.length > 1;

      return AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _isSelectionMode = false;
              _selectedProjectIds.clear();
              _lastSelectedProjectId = null;
            });
          },
        ),
        title: Text(
          (trans['n_items_selected'] ?? '{count} öğe seçildi')
              .replaceAll('{n}', _selectedProjectIds.length.toString())
              .replaceAll('{count}', _selectedProjectIds.length.toString()),
        ),
        bottom: tabs,
        actions: [
          IconButton(
            icon: Icon(allVisibleSelected ? Icons.deselect : Icons.select_all),
            tooltip: allVisibleSelected
                ? (trans['deselect_all'] ?? 'Seçimi Kaldır')
                : (trans['select_all'] ?? 'Tümünü Seç'),
            onPressed: !canToggleSelectAll
                ? null
                : () {
                    _toggleSelectAllVisible(visibleProjects);
                  },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: TextButton.icon(
                onPressed: _selectedProjectIds.isEmpty
                    ? null
                    : () => _saveSelectedProjectsToFolder(allProjects),
                icon: const Icon(Icons.save, size: 18),
                label: Text(
                  trans['save_selected'] ?? 'Seçilenleri Kaydet',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: trans['delete'] ?? 'Sil',
            onPressed: !canBulkDelete
                ? null
                : () async {
                    await _deleteProjectsFromHistory(
                      settings,
                      selectedProjects,
                      Theme.of(context).colorScheme,
                    );
                  },
          ),
        ],
      );
    } else {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _localizedOrSafeFallback(
            settings: settings,
            trans: trans,
            key: 'back',
            trFallback: 'Geri',
            englishValue: 'Back',
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(trans['history'] ?? 'Geçmiş'),
        bottom: tabs,
        actions: _activeTabIndex == 0
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: _localizedOrSafeFallback(
                    settings: settings,
                    trans: trans,
                    key: 'sort_tooltip',
                    trFallback: 'Sırala',
                    englishValue: 'Sort',
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val == 'date_desc') {
                        _sortOption = SortOption.date;
                        _ascending = false;
                      } else if (val == 'date_asc') {
                        _sortOption = SortOption.date;
                        _ascending = true;
                      } else if (val == 'name_asc') {
                        _sortOption = SortOption.name;
                        _ascending = true;
                      } else if (val == 'name_desc') {
                        _sortOption = SortOption.name;
                        _ascending = false;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'date_desc',
                      child: Text(
                        _localizedOrSafeFallback(
                          settings: settings,
                          trans: trans,
                          key: 'sort_date_desc',
                          trFallback: 'Tarih (Yeni > Eski)',
                          englishValue: 'Date (New > Old)',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'date_asc',
                      child: Text(
                        _localizedOrSafeFallback(
                          settings: settings,
                          trans: trans,
                          key: 'sort_date_asc',
                          trFallback: 'Tarih (Eski > Yeni)',
                          englishValue: 'Date (Old > New)',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'name_asc',
                      child: Text(
                        _localizedOrSafeFallback(
                          settings: settings,
                          trans: trans,
                          key: 'sort_name_asc',
                          trFallback: 'İsim (A > Z)',
                          englishValue: 'Name (A > Z)',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'name_desc',
                      child: Text(
                        _localizedOrSafeFallback(
                          settings: settings,
                          trans: trans,
                          key: 'sort_name_desc',
                          trFallback: 'İsim (Z > A)',
                          englishValue: 'Name (Z > A)',
                        ),
                      ),
                    ),
                  ],
                ),
                if (settings.projects.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: trans['clear_history_title'] ?? 'Geçmişi Temizle',
                    onPressed: () async {
                      if (!settings.confirmDeletes) {
                        final projectsToDelete =
                            List<TranslationProject>.from(settings.projects);
                        for (final p in projectsToDelete) {
                          await _deleteProjectFile(p);
                        }
                        settings.clearAllProjects();
                        return;
                      }

                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            trans['clear_history_title'] ?? 'Geçmişi Temizle',
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trans['clear_history_confirm'] ??
                                    'Tüm geçmiş silinecek.',
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer
                                      .withAlpha(40),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        trans['delete_all_permanent_warning'] ??
                                            'Tüm dosyalar diskten kalıcı olarak silinecek ve geri getirilemeyecek!',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(trans['btn_cancel'] ?? 'İptal'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final projectsToDelete =
                                    List<TranslationProject>.from(
                                  settings.projects,
                                );
                                for (final p in projectsToDelete) {
                                  await _deleteProjectFile(p);
                                }
                                settings.clearAllProjects();
                                if (context.mounted) Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: Text(trans['yes_delete_all'] ?? 'Evet, Sil'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ]
            : null,
      );
    }

  }

  Tab _buildHistoryTabLabel(String text) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _SelectionMarqueePainter extends CustomPainter {
  final Offset startGlobal;
  final Offset currentGlobal;
  final GlobalKey referenceKey;
  final ColorScheme colorScheme;

  const _SelectionMarqueePainter({
    required this.startGlobal,
    required this.currentGlobal,
    required this.referenceKey,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final context = referenceKey.currentContext;
    if (context == null) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final localStart = startGlobal - origin;
    final localCurrent = currentGlobal - origin;
    final rect = Rect.fromLTRB(
      localStart.dx < localCurrent.dx ? localStart.dx : localCurrent.dx,
      localStart.dy < localCurrent.dy ? localStart.dy : localCurrent.dy,
      localStart.dx > localCurrent.dx ? localStart.dx : localCurrent.dx,
      localStart.dy > localCurrent.dy ? localStart.dy : localCurrent.dy,
    );

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.primary.withAlpha(45);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colorScheme.primary;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SelectionMarqueePainter oldDelegate) {
    return oldDelegate.startGlobal != startGlobal ||
        oldDelegate.currentGlobal != currentGlobal ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.referenceKey != referenceKey;
  }
}
