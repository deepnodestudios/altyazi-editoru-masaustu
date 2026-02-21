import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/subtitle_block.dart';
import '../services/editor_service.dart';
import '../services/subtitle_parser.dart';
import 'ui_state_manager.dart';

class _EditorDiff {
  final int start;
  final List<SubtitleBlock> before;
  final List<SubtitleBlock> after;

  _EditorDiff({
    required this.start,
    required this.before,
    required this.after,
  });
}

class EditorStateManager extends ChangeNotifier {
  final UIStateManager _uiStateManager;
  final EditorService _editorService = EditorService();
  
  // Callback for logging to the main AppSettings log list
  Function(String key, [String? param])? onLog;

  EditorStateManager(this._uiStateManager);

  // State Variables
  List<SubtitleBlock> _editorBlocks = [];
  String _editorEncoding = "";
  
  // Search State
  String _searchQuery = "";
  final List<int> _searchResultsIndices = [];
  int _currentSearchIndex = -1;
  bool _isCaseSensitive = false;
  bool _isRegexSearch = false;

  // Undo/Redo State
  static const int _maxUndoLevels = 50;
  final List<_EditorDiff> _undoStack = [];
  final List<_EditorDiff> _redoStack = [];
  DateTime? _lastEditTime;
  int? _lastEditBlockIndex;
  int? _activeTypingUndoIndex;

  // Loading State
  bool _isOpeningEditor = false;
  double _editorOpenProgress = 0.0;

  // Getters
  List<SubtitleBlock> get editorBlocks => _editorBlocks;
  String get editorEncoding => _editorEncoding;
  bool get isOpeningEditor => _isOpeningEditor;
  double get editorOpenProgress => _editorOpenProgress;
  
  String get searchQuery => _searchQuery;
  bool get isCaseSensitive => _isCaseSensitive;
  bool get isRegexSearch => _isRegexSearch;
  
  int get currentSearchMatchIndex => _currentSearchIndex;
  int get totalSearchMatches => _searchResultsIndices.length;
  int get currentMatchedBlockIndex => (_currentSearchIndex >= 0 &&
          _currentSearchIndex < _searchResultsIndices.length)
      ? _searchResultsIndices[_currentSearchIndex]
      : -1;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  List<SubtitleBlock> get filteredEditorBlocks => _editorService.filterBlocks(
        _editorBlocks,
        _searchQuery,
        _isCaseSensitive,
        _isRegexSearch,
      );

  // Methods

  void setEditorFile(String name, String content, {String encoding = "UTF-8"}) {
    _uiStateManager.setSelectedEditorFile(name);
    _editorEncoding = encoding;
    _editorBlocks = SubtitleParser.parseSrt(content);
    _uiStateManager.setEditorDirty(false);
    _resetSearch();
    _clearHistory();
    onLog?.call("log_editor_file_loaded");
    notifyListeners();
  }

  void clearEditorFile() {
    _uiStateManager.setSelectedEditorFile(null);
    _editorEncoding = "";
    _editorBlocks.clear();
    _uiStateManager.setEditorDirty(false);
    _resetSearch();
    _clearHistory();
    onLog?.call("log_editor_file_removed");
    notifyListeners();
  }

  Future<void> loadBlocksIntoEditorAsync(
    String name,
    List<SubtitleBlock> blocks, {
    int chunkSize = 250,
  }) async {
    if (_isOpeningEditor) return;

    _isOpeningEditor = true;
    _editorOpenProgress = 0.0;
    _uiStateManager.setSelectedEditorFile(name);
    _editorEncoding = "Generated";
    _editorBlocks = [];
    _uiStateManager.setEditorDirty(true);
    _resetSearch();
    _clearHistory();
    notifyListeners();

    final int total = blocks.length;
    if (total == 0) {
      _editorOpenProgress = 1.0;
      _isOpeningEditor = false;
      onLog?.call("log_editor_file_loaded", name);
      notifyListeners();
      return;
    }

    final Stopwatch notifyThrottle = Stopwatch()..start();

    for (int i = 0; i < total; i += chunkSize) {
      final int end = (i + chunkSize) > total ? total : (i + chunkSize);
      for (int j = i; j < end; j++) {
        final b = blocks[j];
        _editorBlocks.add(
          SubtitleBlock(index: b.index, timecode: b.timecode, text: b.text),
        );
      }

      _editorOpenProgress = end / total;
      if (end == total || notifyThrottle.elapsedMilliseconds >= 33) {
        notifyListeners();
        notifyThrottle.reset();
      }

      await Future<void>.delayed(Duration.zero);
    }

    _editorOpenProgress = 1.0;
    _isOpeningEditor = false;
    onLog?.call("log_editor_file_loaded", name);
    notifyListeners();
  }

  void updateBlockText(SubtitleBlock block, String t) {
    if (block.text != t) {
      final int index = _editorBlocks.indexOf(block);
      if (index < 0) return;

      final now = DateTime.now();
      final bool startsNewTypingGroup =
          _lastEditBlockIndex != index ||
          _lastEditTime == null ||
          now.difference(_lastEditTime!).inMilliseconds > 1000;

      if (startsNewTypingGroup) {
        final beforeBlock = _cloneBlock(block);
        block.text = t;
        final afterBlock = _cloneBlock(block);
        _pushUndoDiff(
          _EditorDiff(start: index, before: [beforeBlock], after: [afterBlock]),
        );
        _activeTypingUndoIndex = _undoStack.length - 1;
      } else {
        block.text = t;
        if (_activeTypingUndoIndex != null &&
            _activeTypingUndoIndex! >= 0 &&
            _activeTypingUndoIndex! < _undoStack.length) {
          _undoStack[_activeTypingUndoIndex!].after[0] = _cloneBlock(block);
        }
      }

      _lastEditBlockIndex = index;
      _lastEditTime = now;
      _uiStateManager.setEditorDirty(true);
      notifyListeners();
    }
  }

  void updateBlockTimecode(SubtitleBlock block, String newTimecode) {
    if (block.timecode != newTimecode) {
      final before = _cloneBlocks(_editorBlocks);
      block.timecode = newTimecode;
      _recordUndoFromBefore(before);
      _uiStateManager.setEditorDirty(true);
      notifyListeners();
    }
  }

  void shiftBlockTimecode(SubtitleBlock block, int offsetMs) {
    if (offsetMs == 0) return;
    final before = _cloneBlocks(_editorBlocks);

    List<String> parts = block.timecode.split('-->');
    if (parts.length == 2) {
      String start = _shiftTimecodeString(parts[0].trim(), offsetMs);
      String end = _shiftTimecodeString(parts[1].trim(), offsetMs);
      block.timecode = "$start --> $end";
    }
    _recordUndoFromBefore(before);
    _uiStateManager.setEditorDirty(true);
    notifyListeners();
  }

  void shiftAllTimecodes(int offsetMs) {
    if (offsetMs == 0) return;
    final before = _cloneBlocks(_editorBlocks);

    for (var block in _editorBlocks) {
      List<String> parts = block.timecode.split('-->');
      if (parts.length == 2) {
        String start = _shiftTimecodeString(parts[0].trim(), offsetMs);
        String end = _shiftTimecodeString(parts[1].trim(), offsetMs);
        block.timecode = "$start --> $end";
      }
    }
    _recordUndoFromBefore(before);
    _uiStateManager.setEditorDirty(true);
    notifyListeners();
  }

  void deleteBlock(SubtitleBlock block) {
    final before = _cloneBlocks(_editorBlocks);
    _editorBlocks.remove(block);
    _renumberBlocks();
    _recordUndoFromBefore(before);
    _uiStateManager.setEditorDirty(true);
    _findMatches();
    notifyListeners();
  }

  void cleanSdhInEditor() {
    final before = _cloneBlocks(_editorBlocks);
    
    final cleaned = _editorService.cleanSdhFromBlocks(_editorBlocks);
    bool changed = cleaned.length != _editorBlocks.length ||
        !_editorBlocks.asMap().entries.every((entry) =>
            entry.key < cleaned.length &&
            entry.value.text == cleaned[entry.key].text);

    if (changed) {
      _editorBlocks = cleaned;
      _recordUndoFromBefore(before);
      _uiStateManager.setEditorDirty(true);
      _findMatches();
      onLog?.call("log_sdh_complete");
      notifyListeners();
    }
  }

  // Search & Replace Methods

  void updateSearchQuery(String q) {
    _searchQuery = q;
    _findMatches();
    notifyListeners();
  }

  void toggleCaseSensitivity(bool v) {
    _isCaseSensitive = v;
    _findMatches();
    notifyListeners();
  }

  void toggleRegexSearch(bool v) {
    _isRegexSearch = v;
    _findMatches();
    notifyListeners();
  }

  void nextSearchMatch() {
    if (_searchResultsIndices.isEmpty) return;
    if (_currentSearchIndex < _searchResultsIndices.length - 1) {
      _currentSearchIndex++;
    } else {
      _currentSearchIndex = 0;
    }
    notifyListeners();
  }

  void prevSearchMatch() {
    if (_searchResultsIndices.isEmpty) return;
    if (_currentSearchIndex > 0) {
      _currentSearchIndex--;
    } else {
      _currentSearchIndex = _searchResultsIndices.length - 1;
    }
    notifyListeners();
  }

  int replaceSingleInEditor(String replacement) {
    // Logic copied from AppSettings but using local state
    for (int i = 0; i < _editorBlocks.length; i++) {
      final block = _editorBlocks[i];
      if (_isRegexSearch) {
        try {
          final regex = RegExp(_searchQuery,
              caseSensitive: _isCaseSensitive, multiLine: true);
          if (regex.hasMatch(block.text)) {
            final before = _cloneBlocks(_editorBlocks);
            block.text = block.text.replaceFirst(regex, replacement);
            _recordUndoFromBefore(before);
            _uiStateManager.setEditorDirty(true);
            onLog?.call("log_replaced_single");
            notifyListeners();
            return 1;
          }
        } catch (_) {}
      } else {
        if (_isCaseSensitive
            ? block.text.contains(_searchQuery)
            : block.text.toLowerCase().contains(_searchQuery.toLowerCase())) {
          final before = _cloneBlocks(_editorBlocks);
          block.text = _isCaseSensitive
              ? block.text.replaceFirst(_searchQuery, replacement)
              : block.text.replaceFirst(
                  RegExp(_searchQuery, caseSensitive: false), replacement);
          _recordUndoFromBefore(before);
          _uiStateManager.setEditorDirty(true);
          onLog?.call("log_replaced_single");
          notifyListeners();
          return 1;
        }
      }
    }
    return 0;
  }

  int replaceAllInEditor(String replacement) {
    final before = _cloneBlocks(_editorBlocks);
    bool changed = false;
    int totalCount = 0;
    // Logic copied from AppSettings
    // ... (Implementation identical to AppSettings logic)
    // Simplified for brevity in diff, but assumes full logic transfer
    for (var block in _editorBlocks) {
       // ... (Same logic as AppSettings.replaceAllInEditor)
       // Re-implementing core logic here for correctness in new file
       if (_isRegexSearch) {
        try {
          final regex = RegExp(_searchQuery,
              caseSensitive: _isCaseSensitive, multiLine: true);
          int count = regex.allMatches(block.text).length;
          if (count > 0) {
            block.text = block.text.replaceAll(regex, replacement);
            changed = true;
            totalCount += count;
          }
        } catch (_) {}
      } else {
        String text = block.text;
        String query = _searchQuery;
        if (!_isCaseSensitive) {
          text = text.toLowerCase();
          query = query.toLowerCase();
        }
        if (text.contains(query)) {
          int count = RegExp(RegExp.escape(_searchQuery),
                  caseSensitive: _isCaseSensitive)
              .allMatches(block.text)
              .length;
          if (count > 0) {
            block.text = block.text.replaceAll(
                _isCaseSensitive
                    ? _searchQuery
                    : RegExp(RegExp.escape(_searchQuery), caseSensitive: false),
                replacement);
            changed = true;
            totalCount += count;
          }
        }
      }
    }

    if (changed) {
      _recordUndoFromBefore(before);
      _uiStateManager.setEditorDirty(true);
      onLog?.call("log_replaced_all");
      notifyListeners();
    }
    return totalCount;
  }

  // Undo/Redo Methods

  void undo() {
    if (_undoStack.isEmpty) return;

    final diff = _undoStack.removeLast();
    _applyInverseDiff(diff);
    _redoStack.add(diff);
    _activeTypingUndoIndex = null;
    _uiStateManager.setEditorDirty(true);
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    final diff = _redoStack.removeLast();
    _applyForwardDiff(diff);
    _undoStack.add(diff);
    _activeTypingUndoIndex = null;
    _uiStateManager.setEditorDirty(true);
    notifyListeners();
  }

  // Private Helpers

  void _resetSearch() {
    _searchQuery = "";
    _searchResultsIndices.clear();
    _currentSearchIndex = -1;
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _activeTypingUndoIndex = null;
    _lastEditBlockIndex = null;
    _lastEditTime = null;
  }

  void _renumberBlocks() {
    for (int i = 0; i < _editorBlocks.length; i++) {
      _editorBlocks[i].index = i + 1;
    }
  }

  void _findMatches() {
    _searchResultsIndices.clear();
    _currentSearchIndex = -1;
    if (_searchQuery.isEmpty) return;
    
    final indices = _editorService.findSearchResultIndices(
      _editorBlocks, 
      _searchQuery, 
      _isRegexSearch, 
      _isCaseSensitive
    );
    
    _searchResultsIndices.addAll(indices);

    if (_searchResultsIndices.isNotEmpty) {
      _currentSearchIndex = 0;
    }
  }

  void _recordUndoFromBefore(List<SubtitleBlock> before) {
    _activeTypingUndoIndex = null;
    final diff = _createDiff(before, _editorBlocks);
    if (diff == null) return;
    _pushUndoDiff(diff);
  }

  void _pushUndoDiff(_EditorDiff diff) {
    _undoStack.add(diff);
    if (_undoStack.length > _maxUndoLevels) {
      _undoStack.removeAt(0);
      if (_activeTypingUndoIndex != null) {
        _activeTypingUndoIndex = _activeTypingUndoIndex! - 1;
        if (_activeTypingUndoIndex! < 0) {
          _activeTypingUndoIndex = null;
        }
      }
    }
    _redoStack.clear();
  }

  _EditorDiff? _createDiff(
    List<SubtitleBlock> before,
    List<SubtitleBlock> after,
  ) {
    int start = 0;
    final minLen = before.length < after.length ? before.length : after.length;

    while (start < minLen && _blocksEqual(before[start], after[start])) {
      start++;
    }

    int beforeEnd = before.length - 1;
    int afterEnd = after.length - 1;
    while (beforeEnd >= start &&
        afterEnd >= start &&
        _blocksEqual(before[beforeEnd], after[afterEnd])) {
      beforeEnd--;
      afterEnd--;
    }

    final beforeSlice = beforeEnd >= start
        ? before.sublist(start, beforeEnd + 1).map(_cloneBlock).toList()
        : <SubtitleBlock>[];
    final afterSlice = afterEnd >= start
        ? after.sublist(start, afterEnd + 1).map(_cloneBlock).toList()
        : <SubtitleBlock>[];

    if (beforeSlice.isEmpty && afterSlice.isEmpty) {
      return null;
    }

    return _EditorDiff(start: start, before: beforeSlice, after: afterSlice);
  }

  void _applyForwardDiff(_EditorDiff diff) {
    _replaceRange(diff.start, diff.before.length, diff.after);
  }

  void _applyInverseDiff(_EditorDiff diff) {
    _replaceRange(diff.start, diff.after.length, diff.before);
  }

  void _replaceRange(int start, int removeCount, List<SubtitleBlock> insert) {
    int safeStart = start;
    if (safeStart < 0) safeStart = 0;
    if (safeStart > _editorBlocks.length) safeStart = _editorBlocks.length;

    int safeEnd = safeStart + removeCount;
    if (safeEnd > _editorBlocks.length) safeEnd = _editorBlocks.length;

    _editorBlocks.replaceRange(
      safeStart,
      safeEnd,
      insert.map(_cloneBlock),
    );
  }

  List<SubtitleBlock> _cloneBlocks(List<SubtitleBlock> source) {
    return source.map(_cloneBlock).toList();
  }

  SubtitleBlock _cloneBlock(SubtitleBlock block) {
    return SubtitleBlock(
      index: block.index,
      timecode: block.timecode,
      text: block.text,
    );
  }

  bool _blocksEqual(SubtitleBlock a, SubtitleBlock b) {
    return a.index == b.index && a.timecode == b.timecode && a.text == b.text;
  }

  String _shiftTimecodeString(String timecode, int offsetMs) {
    try {
      String clean = timecode.replaceAll(',', '.');
      List<String> parts = clean.split(':');
      if (parts.length == 3) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        List<String> sParts = parts[2].split('.');
        int s = int.parse(sParts[0]);
        int ms = 0;
        if (sParts.length > 1) {
          ms = int.parse(sParts[1]);
        }

        int total = h * 3600000 + m * 60000 + s * 1000 + ms;
        total += offsetMs;
        if (total < 0) total = 0;

        int newH = total ~/ 3600000;
        total %= 3600000;
        int newM = total ~/ 60000;
        total %= 60000;
        int newS = total ~/ 1000;
        int newMs = total % 1000;

        return "${newH.toString().padLeft(2, '0')}:${newM.toString().padLeft(2, '0')}:${newS.toString().padLeft(2, '0')},${newMs.toString().padLeft(3, '0')}";
      }
    } catch (_) {}
    return timecode;
  }
}