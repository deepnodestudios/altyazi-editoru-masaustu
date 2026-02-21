import 'package:flutter/foundation.dart';
import '../models/subtitle_block.dart';

class TranslationStateManager extends ChangeNotifier {
  // Translation file selection
  String? _selectedTranslationFile;
  String? _selectedTranslationFilePath;
  String? _translationSourceCachePath;

  // Translation process state
  bool _isTranslating = false;
  bool _isTranslationComplete = false;
  double _progress = 0.0;
  bool _translationForegroundActive = false;

  // Subtitle blocks
  List<SubtitleBlock> _sourceBlocks = [];
  List<SubtitleBlock> _processedBlocks = [];
  bool _lastProcessWasTranslation = true;

  // API state
  bool _isWaitingForQuota = false;
  int _currentOutputIndex = 1;

  // Getters - File Selection
  String? get selectedTranslationFile => _selectedTranslationFile;
  String? get selectedTranslationFilePath => _selectedTranslationFilePath;
  String? get translationSourceCachePath => _translationSourceCachePath;

  // Getters - Translation Process
  bool get isTranslating => _isTranslating;
  bool get isTranslationComplete => _isTranslationComplete;
  double get progress => _progress;
  bool get translationForegroundActive => _translationForegroundActive;

  // Getters - Subtitle Blocks
  List<SubtitleBlock> get sourceBlocks => _sourceBlocks;
  List<SubtitleBlock> get processedBlocks => _processedBlocks;
  bool get lastProcessWasTranslation => _lastProcessWasTranslation;

  // Getters - API State
  bool get isWaitingForQuota => _isWaitingForQuota;
  int get currentOutputIndex => _currentOutputIndex;

  // Setters - File Selection
  void setSelectedTranslationFile(String? file) {
    if (_selectedTranslationFile != file) {
      _selectedTranslationFile = file;
      notifyListeners();
    }
  }

  void setSelectedTranslationFilePath(String? path) {
    if (_selectedTranslationFilePath != path) {
      _selectedTranslationFilePath = path;
      notifyListeners();
    }
  }

  void setTranslationSourceCachePath(String? path) {
    if (_translationSourceCachePath != path) {
      _translationSourceCachePath = path;
      notifyListeners();
    }
  }

  // Setters - Translation Process
  void setIsTranslating(bool value) {
    if (_isTranslating != value) {
      _isTranslating = value;
      notifyListeners();
    }
  }

  void setIsTranslationComplete(bool value) {
    if (_isTranslationComplete != value) {
      _isTranslationComplete = value;
      notifyListeners();
    }
  }

  void setProgress(double value) {
    if (_progress != value) {
      _progress = value;
      notifyListeners();
    }
  }

  void setTranslationForegroundActive(bool value) {
    if (_translationForegroundActive != value) {
      _translationForegroundActive = value;
      notifyListeners();
    }
  }

  // Setters - Subtitle Blocks
  void setSourceBlocks(List<SubtitleBlock> blocks) {
    _sourceBlocks = blocks;
    notifyListeners();
  }

  void setProcessedBlocks(List<SubtitleBlock> blocks) {
    _processedBlocks = blocks;
    notifyListeners();
  }

  void setLastProcessWasTranslation(bool value) {
    if (_lastProcessWasTranslation != value) {
      _lastProcessWasTranslation = value;
      notifyListeners();
    }
  }

  // Setters - API State
  void setIsWaitingForQuota(bool value) {
    if (_isWaitingForQuota != value) {
      _isWaitingForQuota = value;
      notifyListeners();
    }
  }

  void setCurrentOutputIndex(int index) {
    if (_currentOutputIndex != index) {
      _currentOutputIndex = index;
      notifyListeners();
    }
  }

  void incrementCurrentOutputIndex() {
    _currentOutputIndex++;
    notifyListeners();
  }

  // Reset translation state
  Future<void> resetTranslationState() async {
    _selectedTranslationFile = null;
    _selectedTranslationFilePath = null;
    _translationSourceCachePath = null;
    _isTranslating = false;
    _isTranslationComplete = false;
    _progress = 0.0;
    _translationForegroundActive = false;
    _sourceBlocks = [];
    _processedBlocks = [];
    _lastProcessWasTranslation = true;
    _isWaitingForQuota = false;
    _currentOutputIndex = 1;
    notifyListeners();
  }

  // Reset progress
  void resetProgress() {
    _progress = 0.0;
    _currentOutputIndex = 1;
    notifyListeners();
  }
}
