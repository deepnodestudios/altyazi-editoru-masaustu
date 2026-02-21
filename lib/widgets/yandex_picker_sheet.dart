import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_settings.dart';
import '../models/cloud_file_info.dart';
import 'cloud_breadcrumbs.dart';
import 'cloud_provider_logo.dart';

Future<YandexDiskFileInfo?> showYandexDiskSubtitlePickerSheet(
  BuildContext context, {
  required AppSettings settings,
  required Map<String, String> trans,
}) {
  return showModalBottomSheet<YandexDiskFileInfo>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Consumer<AppSettings>(
            builder: (context, _, __) {
              final trans = context.read<AppSettings>().trans;
              return _YandexDiskPickerContent(settings: settings, trans: trans);
            },
          ),
        ),
      );
    },
  );
}

Future<List<YandexDiskFileInfo>?> showYandexDiskSubtitleMultiPickerSheet(
  BuildContext context, {
  required AppSettings settings,
  required Map<String, String> trans,
}) {
  return showModalBottomSheet<List<YandexDiskFileInfo>>(
    context: context,
    enableDrag: false,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Consumer<AppSettings>(
            builder: (context, _, __) {
              final trans = context.read<AppSettings>().trans;
              return _YandexDiskMultiPickerContent(settings: settings, trans: trans);
            },
          ),
        ),
      );
    },
  );
}

Future<String?> showYandexDiskFolderPickerSheet(
  BuildContext context, {
  required AppSettings settings,
  required Map<String, String> trans,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Consumer<AppSettings>(
            builder: (context, _, __) {
              final trans = context.read<AppSettings>().trans;
              return _YandexDiskFolderPickerContent(settings: settings, trans: trans);
            },
          ),
        ),
      );
    },
  );
}

class _YandexDiskFolderPickerContent extends StatefulWidget {
  const _YandexDiskFolderPickerContent({
    required this.settings,
    required this.trans,
  });

  final AppSettings settings;
  final Map<String, String> trans;

  @override
  State<_YandexDiskFolderPickerContent> createState() =>
      _YandexDiskFolderPickerContentState();
}

class _YandexDiskFolderPickerContentState
    extends State<_YandexDiskFolderPickerContent> {
  late Future<List<YandexDiskFileInfo>> _future;
  bool _didAutoClose = false;

  final List<({String path, String label})> _folderStack =
      <({String path, String label})>[
    (path: 'disk:/', label: 'Root'),
  ];

  final List<List<({String path, String label})>> _history =
      <List<({String path, String label})>>[];
  int _historyIndex = 0;

  @override
  void initState() {
    super.initState();
    _history.add(List.of(_folderStack));
    _future = _load();
  }

  Future<List<YandexDiskFileInfo>> _load() async {
    final items = await widget.settings.cloudStorage.listYandexDiskFolderItems(
        path: _folderStack.last.path, context: context);
    if (!widget.settings.isYandexConnected && !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const <YandexDiskFileInfo>[];
    }
    return items.where((e) => e.isFolder).toList(growable: false);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _pushHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(List.of(_folderStack));
    _historyIndex = _history.length - 1;
  }

  void _goBack() {
    if (_historyIndex <= 0) return;
    setState(() {
      _historyIndex -= 1;
      _folderStack
        ..clear()
        ..addAll(_history[_historyIndex]);
      _future = _load();
    });
  }

  void _goForward() {
    if (_historyIndex >= _history.length - 1) return;
    setState(() {
      _historyIndex += 1;
      _folderStack
        ..clear()
        ..addAll(_history[_historyIndex]);
      _future = _load();
    });
  }

  void _jumpToCrumb(int index) {
    if (index < 0 || index >= _folderStack.length) return;
    setState(() {
      _folderStack.removeRange(index + 1, _folderStack.length);
      _pushHistory();
      _future = _load();
    });
  }

  Widget _buildBreadcrumbs(Map<String, String> trans) {
    return CloudBreadcrumbs(
      labels: _folderStack.map((e) => e.label).toList(),
      onBreadcrumbTap: _jumpToCrumb,
      rootLabel: trans['root'] ?? 'Root',
    );
  }

  void _enterFolder(YandexDiskFileInfo folder) {
    setState(() {
      _folderStack.add((path: folder.path, label: folder.name));
      _pushHistory();
      _future = _load();
    });
  }

  void _goUp() {
    if (_folderStack.length <= 1) return;
    setState(() {
      _folderStack.removeLast();
      _pushHistory();
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trans = widget.trans;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              const CloudProviderLogo(
                asset: CloudProviderAssets.yandexDisk,
                monochrome: false,
                semanticLabel: 'Yandex Disk',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trans['cloud_source_yandex'] ?? 'Yandex Disk'} · ${trans['select_folder'] ?? 'Select folder'} · ${_folderStack.last.label}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, _folderStack.last.path);
                  },
                  icon: const Icon(Icons.check),
                  label:
                      Text(trans['select_this_folder'] ?? 'Select this folder'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: trans['back'] ?? 'Back',
                onPressed: _historyIndex <= 0 ? null : _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: trans['forward'] ?? 'Forward',
                onPressed:
                    _historyIndex >= _history.length - 1 ? null : _goForward,
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: trans['up_folder'] ?? 'Up',
                onPressed: _folderStack.length <= 1 ? null : _goUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              Expanded(child: _buildBreadcrumbs(trans)),
              IconButton(
                tooltip: trans['refresh'] ?? 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<YandexDiskFileInfo>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${trans['log_error'] ?? 'Hata'}: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: Text(trans['btn_retry'] ?? 'Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? const <YandexDiskFileInfo>[];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        trans['cloud_folder_empty'] ?? 'No folders found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final folder = items[index];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _enterFolder(folder),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _YandexDiskPickerContent extends StatefulWidget {
  const _YandexDiskPickerContent({
    required this.settings,
    required this.trans,
  });

  final AppSettings settings;
  final Map<String, String> trans;

  @override
  State<_YandexDiskPickerContent> createState() =>
      _YandexDiskPickerContentState();
}

class _YandexDiskPickerContentState extends State<_YandexDiskPickerContent> {
  late Future<List<YandexDiskFileInfo>> _future;
  bool _didAutoClose = false;

  final List<({String path, String label})> _folderStack =
      <({String path, String label})>[
    (path: 'disk:/', label: 'Root'),
  ];

  final List<List<({String path, String label})>> _history =
      <List<({String path, String label})>>[];
  int _historyIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  bool _searchMode = false;

  @override
  void initState() {
    super.initState();
    _history.add(List.of(_folderStack));
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<YandexDiskFileInfo>> _load() async {
    final List<YandexDiskFileInfo> items;
    if (_searchMode) {
      items = await widget.settings.cloudStorage.searchYandexDiskSubtitleFiles(
          _searchController.text,
          context: context);
    } else {
      items = await widget.settings.cloudStorage.listYandexDiskFolderItems(
          path: _folderStack.last.path, context: context);
    }

    if (!widget.settings.isYandexConnected && !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const <YandexDiskFileInfo>[];
    }

    return items;
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _pushHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(List.of(_folderStack));
    _historyIndex = _history.length - 1;
  }

  void _goBack() {
    if (_historyIndex <= 0) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _historyIndex -= 1;
      _folderStack
        ..clear()
        ..addAll(_history[_historyIndex]);
      _future = _load();
    });
  }

  void _goForward() {
    if (_historyIndex >= _history.length - 1) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _historyIndex += 1;
      _folderStack
        ..clear()
        ..addAll(_history[_historyIndex]);
      _future = _load();
    });
  }

  void _jumpToCrumb(int index) {
    if (index < 0 || index >= _folderStack.length) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _folderStack.removeRange(index + 1, _folderStack.length);
      _pushHistory();
      _future = _load();
    });
  }

  Widget _buildBreadcrumbs(Map<String, String> trans) {
    return CloudBreadcrumbs(
      labels: _folderStack.map((e) => e.label).toList(),
      onBreadcrumbTap: _searchMode ? null : _jumpToCrumb,
      rootLabel: trans['root'] ?? 'Root',
    );
  }

  void _enterFolder(YandexDiskFileInfo folder) {
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _folderStack.add((path: folder.path, label: folder.name));
      _pushHistory();
      _future = _load();
    });
  }

  void _goUp() {
    if (_folderStack.length <= 1) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _folderStack.removeLast();
      _pushHistory();
      _future = _load();
    });
  }

  void _startSearch() {
    setState(() {
      _searchMode = true;
      _future = _load();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trans = widget.trans;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              const CloudProviderLogo(
                asset: CloudProviderAssets.yandexDisk,
                monochrome: false,
                semanticLabel: 'Yandex Disk',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _searchMode
                      ? '${trans['cloud_source_yandex'] ?? 'Yandex Disk'} · ${trans['search'] ?? 'Search'}'
                      : '${trans['cloud_source_yandex'] ?? 'Yandex Disk'} · ${_folderStack.last.label}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: trans['search'] ?? 'Search',
                onPressed: () {
                  if (_searchMode) {
                    _clearSearch();
                  } else {
                    _startSearch();
                  }
                },
                icon: Icon(_searchMode ? Icons.close : Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: trans['back'] ?? 'Back',
                onPressed: (_searchMode || _historyIndex <= 0) ? null : _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: trans['forward'] ?? 'Forward',
                onPressed: (_searchMode || _historyIndex >= _history.length - 1)
                    ? null
                    : _goForward,
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: trans['up_folder'] ?? 'Up',
                onPressed:
                    (_searchMode || _folderStack.length <= 1) ? null : _goUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              Expanded(child: _buildBreadcrumbs(trans)),
              IconButton(
                tooltip: trans['refresh'] ?? 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: trans['search_hint'] ?? 'Search…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: trans['clear'] ?? 'Clear',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              if (_searchMode) _refresh();
                              setState(() {});
                            },
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _startSearch(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<YandexDiskFileInfo>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${trans['log_error'] ?? 'Hata'}: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: Text(trans['btn_retry'] ?? 'Retry'),
                        )
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? const <YandexDiskFileInfo>[];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        trans['cloud_yandex_empty'] ??
                            'No .srt / .vtt files found in Yandex Disk.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = items[index];
                    return ListTile(
                      leading:
                          Icon(file.isFolder ? Icons.folder : Icons.subtitles),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: file.isFolder
                          ? Text(trans['folder'] ?? 'Folder')
                          : (file.modifiedTime != null
                              ? Text(file.modifiedTime!.toLocal().toString())
                              : null),
                      onTap: () {
                        if (file.isFolder) {
                          _enterFolder(file);
                        } else {
                          Navigator.pop(context, file);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _YandexDiskMultiPickerContent extends StatefulWidget {
  const _YandexDiskMultiPickerContent({
    required this.settings,
    required this.trans,
  });

  final AppSettings settings;
  final Map<String, String> trans;

  @override
  State<_YandexDiskMultiPickerContent> createState() =>
      _YandexDiskMultiPickerContentState();
}

class _YandexDiskMultiPickerContentState
    extends State<_YandexDiskMultiPickerContent> {
  late Future<List<YandexDiskFileInfo>> _future;
  bool _didAutoClose = false;

  final List<({String path, String label})> _folderStack =
      <({String path, String label})>[
    (path: 'disk:/', label: 'Root'),
  ];

  final List<List<({String path, String label})>> _history =
      <List<({String path, String label})>>[];
  int _historyIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  bool _searchMode = false;

  final Map<String, YandexDiskFileInfo> _selected =
      <String, YandexDiskFileInfo>{};
  String? _lastSelectedFilePath;
  final FocusNode _focusNode = FocusNode(debugLabel: 'yandex_multi_picker');
  final GlobalKey _listAreaKey = GlobalKey();
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};
  List<YandexDiskFileInfo> _visibleItems = const <YandexDiskFileInfo>[];
  static const double _marqueeDragThreshold = 6;
  bool _isMarqueeArmed = false;
  bool _isMarqueeActive = false;
  Offset? _marqueeStartGlobal;
  Offset? _marqueeCurrentGlobal;
  Map<String, YandexDiskFileInfo> _marqueeBaseSelection =
      <String, YandexDiskFileInfo>{};
  bool _marqueeIsAdditive = false;

  @override
  void initState() {
    super.initState();
    _history.add(List.of(_folderStack));
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  GlobalKey _keyForFile(String filePath) {
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

  bool _isPointOverFileTile(Offset globalPoint) {
    for (final key in _tileKeys.values) {
      final rect = _rectForKey(key);
      if (rect != null && rect.contains(globalPoint)) {
        return true;
      }
    }
    return false;
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

  Rect? _marqueeRectLocal() {
    final globalRect = _marqueeRectGlobal();
    if (globalRect == null) return null;

    final context = _listAreaKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final origin = renderObject.localToGlobal(Offset.zero);
    return globalRect.shift(-origin);
  }

  void _startMarquee(Offset globalPosition) {
    _focusNode.requestFocus();
    final isCtrlOrMeta =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    setState(() {
      _isMarqueeArmed = true;
      _isMarqueeActive = false;
      _marqueeStartGlobal = globalPosition;
      _marqueeCurrentGlobal = globalPosition;
      _marqueeIsAdditive = isCtrlOrMeta;
      _marqueeBaseSelection = Map<String, YandexDiskFileInfo>.from(_selected);
    });
  }

  void _updateMarquee(Offset globalPosition) {
    if (_marqueeStartGlobal == null || (!_isMarqueeArmed && !_isMarqueeActive)) {
      return;
    }

    if (!_isMarqueeActive) {
      final distance = (globalPosition - _marqueeStartGlobal!).distance;
      if (distance < _marqueeDragThreshold) return;
      setState(() {
        _isMarqueeActive = true;
        if (!_marqueeIsAdditive) {
          _selected.clear();
          _lastSelectedFilePath = null;
        }
      });
    }

    final next = <String, YandexDiskFileInfo>{};
    _marqueeCurrentGlobal = globalPosition;
    final marquee = _marqueeRectGlobal();
    if (marquee != null) {
      for (final item in _visibleItems) {
        if (item.isFolder || item.path.isEmpty) continue;
        final rect = _rectForKey(_keyForFile(item.path));
        if (rect != null && rect.overlaps(marquee)) {
          next[item.path] = item;
        }
      }
    }
    setState(() {
      if (_marqueeIsAdditive) {
        _selected
          ..clear()
          ..addAll(_marqueeBaseSelection)
          ..addAll(next);
      } else {
        _selected
          ..clear()
          ..addAll(next);
      }
      if (_selected.isEmpty) {
        _lastSelectedFilePath = null;
      }
    });
  }

  void _endMarquee() {
    if (!_isMarqueeActive && !_isMarqueeArmed) return;
    setState(() {
      _isMarqueeArmed = false;
      _isMarqueeActive = false;
      _marqueeStartGlobal = null;
      _marqueeCurrentGlobal = null;
      _marqueeBaseSelection = <String, YandexDiskFileInfo>{};
      _marqueeIsAdditive = false;
    });
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrlOrMeta =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyA) {
      final selectable = _visibleItems
          .where((e) => !e.isFolder && e.path.isNotEmpty)
          .toList(growable: false);
      setState(() {
        _selected
          ..clear()
          ..addEntries(selectable.map((f) => MapEntry(f.path, f)));
        _lastSelectedFilePath =
            selectable.isNotEmpty ? selectable.last.path : null;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter && _selected.isNotEmpty) {
      _selectAndClose();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isSubtitleFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.srt') || lower.endsWith('.vtt');
  }

  Future<List<YandexDiskFileInfo>> _load() async {
    final List<YandexDiskFileInfo> items;
    if (_searchMode) {
      // Search API not present; fallback to listing current folder.
      items = await widget.settings.cloudStorage.listYandexDiskFolderItems(
        path: _folderStack.last.path,
        context: context,
      );
    } else {
      items = await widget.settings.cloudStorage.listYandexDiskFolderItems(
        path: _folderStack.last.path,
        context: context,
      );
    }

    if (!widget.settings.isYandexConnected && !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const <YandexDiskFileInfo>[];
    }

    // Filter to folders + subtitle files.
    return items
        .where((e) => e.isFolder || _isSubtitleFileName(e.name))
        .toList(growable: false);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _pushHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(List.of(_folderStack));
    _historyIndex = _history.length - 1;
  }

  void _goBack() {
    if (_historyIndex <= 0) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _historyIndex -= 1;
      _folderStack
        ..clear()
        ..addAll(_history[_historyIndex]);
      _future = _load();
    });
  }

  void _goForward() {
    if (_historyIndex >= _history.length - 1) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _historyIndex += 1;
      _folderStack
        ..clear()
        ..addAll(_history[_historyIndex]);
      _future = _load();
    });
  }

  void _jumpToCrumb(int index) {
    if (index < 0 || index >= _folderStack.length) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _folderStack.removeRange(index + 1, _folderStack.length);
      _pushHistory();
      _future = _load();
    });
  }

  Widget _buildBreadcrumbs(Map<String, String> trans) {
    return CloudBreadcrumbs(
      labels: _folderStack.map((e) => e.label).toList(),
      onBreadcrumbTap: _searchMode ? null : _jumpToCrumb,
      rootLabel: trans['root'] ?? 'Root',
    );
  }

  void _enterFolder(YandexDiskFileInfo folder) {
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _folderStack.add((path: folder.path, label: folder.name));
      _pushHistory();
      _future = _load();
    });
  }

  void _goUp() {
    if (_folderStack.length <= 1) return;
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _folderStack.removeLast();
      _pushHistory();
      _future = _load();
    });
  }

  void _toggleSelected(YandexDiskFileInfo file) {
    if (file.path.isEmpty) return;
    setState(() {
      if (_selected.containsKey(file.path)) {
        _selected.remove(file.path);
      } else {
        _selected[file.path] = file;
      }
      _lastSelectedFilePath = _selected.isEmpty ? null : file.path;
    });
  }

  void _toggleSelectedAtIndex(
    YandexDiskFileInfo file,
    int index,
    List<YandexDiskFileInfo> items,
  ) {
    if (file.path.isEmpty) return;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isCtrlOrMeta =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isShiftPressed && _lastSelectedFilePath != null) {
      final selectable = items
          .where((e) => !e.isFolder && e.path.isNotEmpty)
          .toList(growable: false);
      final anchorIndex =
          selectable.indexWhere((e) => e.path == _lastSelectedFilePath);
      final currentIndex = selectable.indexWhere((e) => e.path == file.path);
      if (anchorIndex != -1 && currentIndex != -1) {
        final start = anchorIndex < currentIndex ? anchorIndex : currentIndex;
        final end = anchorIndex > currentIndex ? anchorIndex : currentIndex;
        setState(() {
          if (!isCtrlOrMeta) {
            _selected.clear();
          }
          for (var i = start; i <= end; i++) {
            final item = selectable[i];
            _selected[item.path] = item;
          }
          _lastSelectedFilePath = file.path;
        });
        return;
      }
    }
    if (isCtrlOrMeta) {
      _toggleSelected(file);
      return;
    }
    setState(() {
      _selected
        ..clear()
        ..[file.path] = file;
      _lastSelectedFilePath = file.path;
    });
  }

  void _addWithDoubleClick(YandexDiskFileInfo file) {
    if (file.path.isEmpty) return;
    if (!_selected.containsKey(file.path)) {
      setState(() {
        _selected[file.path] = file;
      });
    }
    _lastSelectedFilePath = file.path;
    _selectAndClose();
  }

  void _selectAndClose() {
    final out = _selected.values.toList(growable: false);
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final trans = widget.trans;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _onKeyEvent(event),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              const CloudProviderLogo(
                asset: CloudProviderAssets.yandexDisk,
                monochrome: false,
                semanticLabel: 'Yandex Disk',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trans['cloud_source_yandex'] ?? 'Yandex Disk'} · ${_folderStack.last.label}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selected.isEmpty ? null : _selectAndClose,
                  icon: const Icon(Icons.check),
                  label: Text(
                    '${trans['select'] ?? 'Select'} (${_selected.length})',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(trans['cancel'] ?? 'Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: trans['back'] ?? 'Back',
                onPressed: (_searchMode || _historyIndex <= 0) ? null : _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: trans['forward'] ?? 'Forward',
                onPressed: (_searchMode || _historyIndex >= _history.length - 1)
                    ? null
                    : _goForward,
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: trans['up_folder'] ?? 'Up',
                onPressed:
                    (_searchMode || _folderStack.length <= 1) ? null : _goUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              Expanded(child: _buildBreadcrumbs(trans)),
              IconButton(
                tooltip: trans['refresh'] ?? 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<YandexDiskFileInfo>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${trans['log_error'] ?? 'Hata'}: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: Text(trans['btn_retry'] ?? 'Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? const <YandexDiskFileInfo>[];
                _visibleItems = items;
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        trans['cloud_yandex_empty'] ??
                            'No .srt / .vtt files found in Yandex Disk.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    _focusNode.requestFocus();
                    if (event.buttons != 1) return;
                    if (_isPointOverFileTile(event.position) && _selected.isEmpty) {
                      return;
                    }
                    _startMarquee(event.position);
                  },
                  onPointerMove: (event) => _updateMarquee(event.position),
                  onPointerUp: (_) => _endMarquee(),
                  onPointerCancel: (_) => _endMarquee(),
                  child: Stack(
                    key: _listAreaKey,
                    children: [
                      ListView.separated(
                        physics: _isMarqueeActive
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item.isFolder) {
                            return ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _enterFolder(item),
                            );
                          }

                          final isSelected = _selected.containsKey(item.path);
                          return GestureDetector(
                            key: _keyForFile(item.path),
                            onDoubleTap: () => _addWithDoubleClick(item),
                            child: ListTile(
                              leading: const Icon(Icons.subtitles),
                              title: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: item.modifiedTime != null
                                  ? Text(item.modifiedTime!.toLocal().toString())
                                  : null,
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) =>
                                    _toggleSelectedAtIndex(item, index, items),
                              ),
                              onTap: () =>
                                  _toggleSelectedAtIndex(item, index, items),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
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
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
