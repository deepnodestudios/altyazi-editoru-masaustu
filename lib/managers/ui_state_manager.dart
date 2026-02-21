import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UIStateManager extends ChangeNotifier {
  static const String _prefKeyLastTabIndex = 'lastTabIndex';
  static const String _prefKeyOnboardingShown = 'onboardingShown';
  static const String _prefKeyStartupCheckDone = 'startupCheckDone';

  // Live subtitle viewer state
  bool _isLiveViewActive = false;

  // Editor state
  String? _selectedEditorFile;
  bool _isEditorDirty = false;

  // Tab navigation
  int _lastTabIndex = 0;
  int? _pendingTabIndex;
  bool _tabRestored = false;

  // Startup state
  bool _startupCheckDone = false;
  bool _onboardingShown = true;

  // Getters - Live View
  bool get isLiveViewActive => _isLiveViewActive;

  // Getters - Editor
  String? get selectedEditorFile => _selectedEditorFile;
  bool get isEditorDirty => _isEditorDirty;

  // Getters - Tab Navigation
  int get lastTabIndex => _lastTabIndex;
  int? get pendingTabIndex => _pendingTabIndex;
  bool get tabRestored => _tabRestored;

  // Getters - Startup
  bool get startupCheckDone => _startupCheckDone;
  bool get onboardingShown => _onboardingShown;

  // Setters - Live View
  void setLiveViewActive(bool value) {
    if (_isLiveViewActive != value) {
      _isLiveViewActive = value;
      notifyListeners();
    }
  }

  // Setters - Editor
  void setSelectedEditorFile(String? filePath) {
    if (_selectedEditorFile != filePath) {
      _selectedEditorFile = filePath;
      notifyListeners();
    }
  }

  void setEditorDirty(bool value) {
    if (_isEditorDirty != value) {
      _isEditorDirty = value;
      notifyListeners();
    }
  }

  // Setters - Tab Navigation
  void setLastTabIndex(int index) {
    if (_lastTabIndex != index) {
      _lastTabIndex = index;
      _saveLastTabIndex(index);
      notifyListeners();
    }
  }

  void setPendingTabIndex(int? index) {
    if (_pendingTabIndex != index) {
      _pendingTabIndex = index;
      notifyListeners();
    }
  }

  void setTabRestored(bool value) {
    if (_tabRestored != value) {
      _tabRestored = value;
      notifyListeners();
    }
  }

  // Setters - Startup
  void setStartupCheckDone(bool value) {
    if (_startupCheckDone != value) {
      _startupCheckDone = value;
      _saveStartupCheckDone(value);
      notifyListeners();
    }
  }

  void setOnboardingShown(bool value) {
    if (_onboardingShown != value) {
      _onboardingShown = value;
      _saveOnboardingShown(value);
      notifyListeners();
    }
  }

  // Loading from preferences
  Future<void> loadUIStateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    _lastTabIndex = prefs.getInt(_prefKeyLastTabIndex) ?? 0;
    _onboardingShown = prefs.getBool(_prefKeyOnboardingShown) ?? true;
    _startupCheckDone = prefs.getBool(_prefKeyStartupCheckDone) ?? false;
    
    _isLiveViewActive = false;
    _selectedEditorFile = null;
    _isEditorDirty = false;
    _pendingTabIndex = null;
    _tabRestored = false;
    
    notifyListeners();
  }

  // Reset editor state
  void resetEditorState() {
    _selectedEditorFile = null;
    _isEditorDirty = false;
    notifyListeners();
  }

  // Reset live view state
  void resetLiveViewState() {
    _isLiveViewActive = false;
    notifyListeners();
  }

  // Private persistence methods
  Future<void> _saveLastTabIndex(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLastTabIndex, value);
  }

  Future<void> _saveOnboardingShown(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyOnboardingShown, value);
  }

  Future<void> _saveStartupCheckDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyStartupCheckDone, value);
  }
}
