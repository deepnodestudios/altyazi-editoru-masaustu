import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _geminiFlashLiteLatest = "gemini-3.1-flash-lite";

class APIConfigManager extends ChangeNotifier {
  static const String _prefKeySelectedModel = 'selectedModel';
  static const String _prefKeySelectedEngine = 'selectedEngine';
  static const String _prefKeyAvailableModels = 'availableModels';

  // NOTE: App works in single-mode (server-managed API key).
  // We intentionally do NOT store any API key on-device.
  String _selectedModel = _geminiFlashLiteLatest;
  List<String> _availableModels = [_geminiFlashLiteLatest];
  String _selectedEngine = "gemini";

  // Getters
  String get selectedModel => _selectedModel;
  List<String> get availableModels => _availableModels;
  String get selectedEngine => _selectedEngine;

  void setSelectedModel(String model) {
    if (_selectedModel != model) {
      _selectedModel = model;
      _saveSelectedModel(model);
      notifyListeners();
    }
  }

  void setAvailableModels(List<String> models) {
    if (!_listEquals(_availableModels, models)) {
      _availableModels = models;
      _saveAvailableModels(models);
      notifyListeners();
    }
  }

  void setSelectedEngine(String engine) {
    if (_selectedEngine != engine) {
      _selectedEngine = engine;
      _saveSelectedEngine(engine);
      notifyListeners();
    }
  }

  // Loading from preferences
  Future<void> loadAPIConfigFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Cleanup legacy keys if they exist from older app versions.
    await prefs.remove('apiKey');
    await prefs.remove('isApiEntered');

    _selectedModel = prefs.getString(_prefKeySelectedModel) ?? _geminiFlashLiteLatest;
    _selectedEngine = prefs.getString(_prefKeySelectedEngine) ?? "gemini";
    
    final modelsJson = prefs.getStringList(_prefKeyAvailableModels);
    _availableModels = modelsJson ?? [_geminiFlashLiteLatest];
    
    notifyListeners();
  }

  // Reset API configuration
  Future<void> clearAPIConfig() async {
    _selectedModel = _geminiFlashLiteLatest;
    _availableModels = [_geminiFlashLiteLatest];
    _selectedEngine = "gemini";

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeySelectedModel);
    await prefs.remove(_prefKeySelectedEngine);
    await prefs.remove(_prefKeyAvailableModels);
    await prefs.remove('apiKey');
    await prefs.remove('isApiEntered');
    
    notifyListeners();
  }

  // Helper method for list comparison
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> fetchModelsFromApi({required bool isFreeSlow, required Function(String, String?) addLog}) async {
    // Client no longer fetches models from Gemini API to avoid exposing API keys.
    _availableModels = [_geminiFlashLiteLatest];
    if (!_availableModels.contains(_selectedModel)) {
      _selectedModel = _availableModels.first;
    }
    _saveAvailableModels(_availableModels);
    notifyListeners();
  }

  Future<void> _saveSelectedModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySelectedModel, value);
  }

  Future<void> _saveSelectedEngine(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySelectedEngine, value);
  }

  Future<void> _saveAvailableModels(List<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKeyAvailableModels, values);
  }
}
