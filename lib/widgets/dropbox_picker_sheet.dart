import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_settings.dart';
import '../models/cloud_file_info.dart';
import 'cloud_breadcrumbs.dart';
import 'cloud_provider_logo.dart';

Future<DropboxFileInfo?> showDropboxSubtitlePickerSheet(
  BuildContext context, {
  required AppSettings settings,
  required Map<String, String> trans,
}) {
  return showModalBottomSheet<DropboxFileInfo>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: SafeArea(
          child: Consumer<AppSettings>(
            builder: (context, _, __) {
              final trans = context.read<AppSettings>().trans;
              return _DropboxPickerContent(settings: settings, trans: trans);
            },
          ),
        ),
      );
    },
  );
}

Future<List<DropboxFileInfo>?> showDropboxSubtitleMultiPickerSheet(
  BuildContext context, {
  required AppSettings settings,
  required Map<String, String> trans,
}) {
  return showModalBottomSheet<List<DropboxFileInfo>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: SafeArea(
          child: Consumer<AppSettings>(
            builder: (context, _, __) {
              final trans = context.read<AppSettings>().trans;
              return _DropboxMultiPickerContent(
                  settings: settings, trans: trans);
            },
          ),
        ),
      );
    },
  );
}

Future<String?> showDropboxFolderPickerSheet(
  BuildContext context, {
  required AppSettings settings,
  required Map<String, String> trans,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: SafeArea(
          child: Consumer<AppSettings>(
            builder: (context, _, __) {
              final trans = context.read<AppSettings>().trans;
              return _DropboxFolderPickerContent(
                  settings: settings, trans: trans);
            },
          ),
        ),
      );
    },
  );
}

class _DropboxFolderPickerContent extends StatefulWidget {
  const _DropboxFolderPickerContent({
    required this.settings,
    required this.trans,
  });

  final AppSettings settings;
  final Map<String, String> trans;

  @override
  State<_DropboxFolderPickerContent> createState() =>
      _DropboxFolderPickerContentState();
}

class _DropboxFolderPickerContentState
    extends State<_DropboxFolderPickerContent> {
  late Future<List<DropboxFileInfo>> _future;
  bool _didAutoClose = false;

  final List<({String path, String label})> _folderStack =
      <({String path, String label})>[
    (path: '', label: 'Root'),
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

  Future<List<DropboxFileInfo>> _load() async {
    final items = await widget.settings.cloudStorage
        .listDropboxFolderItems(path: _folderStack.last.path);
    if (!widget.settings.isDropboxConnected && !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const <DropboxFileInfo>[];
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

  void _enterFolder(DropboxFileInfo folder) {
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
                asset: CloudProviderAssets.dropbox,
                monochrome: false,
                semanticLabel: 'Dropbox',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trans['cloud_source_dropbox'] ?? 'Dropbox'} · ${trans['select_folder'] ?? 'Select folder'} · ${_folderStack.last.label}',
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
                  label: Text(
                    trans['save_here'] ??
                        trans['select_this_folder'] ??
                        'Save here',
                  ),
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
            child: FutureBuilder<List<DropboxFileInfo>>(
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

                final items = snapshot.data ?? const <DropboxFileInfo>[];
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

class _DropboxPickerContent extends StatefulWidget {
  const _DropboxPickerContent({
    required this.settings,
    required this.trans,
  });

  final AppSettings settings;
  final Map<String, String> trans;

  @override
  State<_DropboxPickerContent> createState() => _DropboxPickerContentState();
}

class _DropboxPickerContentState extends State<_DropboxPickerContent> {
  late Future<List<DropboxFileInfo>> _future;
  bool _didAutoClose = false;

  final List<({String path, String label})> _folderStack =
      <({String path, String label})>[
    (path: '', label: 'Root'),
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

  Future<List<DropboxFileInfo>> _load() async {
    final List<DropboxFileInfo> items;
    if (_searchMode) {
      items = await widget.settings.cloudStorage
          .searchDropboxSubtitleFiles(_searchController.text);
    } else {
      items = await widget.settings.cloudStorage
          .listDropboxFolderItems(path: _folderStack.last.path);
    }

    if (!widget.settings.isDropboxConnected && !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const <DropboxFileInfo>[];
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

  void _enterFolder(DropboxFileInfo folder) {
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
                asset: CloudProviderAssets.dropbox,
                monochrome: false,
                semanticLabel: 'Dropbox',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _searchMode
                      ? '${trans['cloud_source_dropbox'] ?? 'Dropbox'} · ${trans['search'] ?? 'Search'}'
                      : '${trans['cloud_source_dropbox'] ?? 'Dropbox'} · ${_folderStack.last.label}',
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
                  autocorrect: false,
                  enableSuggestions: false,
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
            child: FutureBuilder<List<DropboxFileInfo>>(
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

                final items = snapshot.data ?? const <DropboxFileInfo>[];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        trans['cloud_dropbox_empty'] ??
                            'No .srt / .vtt files found in Dropbox.',
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

class _DropboxMultiPickerContent extends StatefulWidget {
  const _DropboxMultiPickerContent({
    required this.settings,
    required this.trans,
  });

  final AppSettings settings;
  final Map<String, String> trans;

  @override
  State<_DropboxMultiPickerContent> createState() =>
      _DropboxMultiPickerContentState();
}

class _DropboxMultiPickerContentState
    extends State<_DropboxMultiPickerContent> {
  late Future<List<DropboxFileInfo>> _future;
  bool _didAutoClose = false;

  final List<({String path, String label})> _folderStack =
      <({String path, String label})>[
    (path: '', label: 'Root'),
  ];

  final List<List<({String path, String label})>> _history =
      <List<({String path, String label})>>[];
  int _historyIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  bool _searchMode = false;

  final Map<String, DropboxFileInfo> _selected = <String, DropboxFileInfo>{};

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

  Future<List<DropboxFileInfo>> _load() async {
    final List<DropboxFileInfo> items;
    if (_searchMode) {
      items = await widget.settings.cloudStorage
          .searchDropboxSubtitleFiles(_searchController.text);
    } else {
      items = await widget.settings.cloudStorage
          .listDropboxFolderItems(path: _folderStack.last.path);
    }

    if (!widget.settings.isDropboxConnected && !_didAutoClose) {
      _didAutoClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const <DropboxFileInfo>[];
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

  void _enterFolder(DropboxFileInfo folder) {
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

  void _toggleSelected(DropboxFileInfo file) {
    if (file.path.isEmpty) return;
    setState(() {
      if (_selected.containsKey(file.path)) {
        _selected.remove(file.path);
      } else {
        _selected[file.path] = file;
      }
    });
  }

  void _selectAndClose() {
    final out = _selected.values.toList(growable: false);
    Navigator.pop(context, out);
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
                asset: CloudProviderAssets.dropbox,
                monochrome: false,
                semanticLabel: 'Dropbox',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _searchMode
                      ? '${trans['cloud_source_dropbox'] ?? 'Dropbox'} · ${trans['search'] ?? 'Search'}'
                      : '${trans['cloud_source_dropbox'] ?? 'Dropbox'} · ${_folderStack.last.label}',
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autocorrect: false,
                  enableSuggestions: false,
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
            child: FutureBuilder<List<DropboxFileInfo>>(
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

                final items = snapshot.data ?? const <DropboxFileInfo>[];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        trans['cloud_dropbox_empty'] ??
                            'No .srt / .vtt files found in Dropbox.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
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
                    return ListTile(
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
                        onChanged: (_) => _toggleSelected(item),
                      ),
                      onTap: () => _toggleSelected(item),
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
