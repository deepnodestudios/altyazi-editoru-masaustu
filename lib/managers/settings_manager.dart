import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/ai_language_options.dart';

class SettingsManager extends ChangeNotifier {
  static const String _prefKeyBatchSize = 'batchSize';
  static const String _prefKeyIsFreeSlow = 'isFreeSlow';
  static const String _prefKeyKeepScreenOn = 'keepScreenOn';
  static const String _prefKeySleepPreventionPrompted =
      'sleepPreventionPrompted';
  static const String _prefKeyBatteryOptimizationPrompted =
      'batteryOptimizationPrompted';
  static const String _prefKeySdhClear = 'sdhClear';
  static const String _prefKeySdhClearNoTrans = 'sdhClearNoTrans';
  static const String _prefKeyTargetLanguage = 'targetLanguage';

  int _batchSize = 150; // Token optimizasyonu için varsayılan değer artırıldı
  bool _isFreeSlow = false;
  bool _keepScreenOn = false;
  bool _sleepPreventionPrompted = false;
  bool _batteryOptimizationPrompted = false;
  bool _sdhClear = true;
  bool _sdhClearNoTrans = false;
  String _targetLanguage = "TR";

  // If the user changes SDH toggles while prefs are still loading, do not
  // overwrite their choice when the async load completes.
  bool _sdhClearTouched = false;
  bool _sdhClearNoTransTouched = false;

  // Getters
  int get batchSize => _batchSize;
  bool get isFreeSlow => _isFreeSlow;
  bool get keepScreenOn => _keepScreenOn;
  bool get sleepPreventionPrompted => _sleepPreventionPrompted;
  bool get batteryOptimizationPrompted => _batteryOptimizationPrompted;
  bool get sdhClear => _sdhClear;
  bool get sdhClearNoTrans => _sdhClearNoTrans;
  String get targetLanguage => _targetLanguage;

  // Setters with persistence
  void setBatchSize(int size) {
    if (_batchSize != size) {
      _batchSize = size;
      _saveBatchSize(size);
      notifyListeners();
    }
  }

  void setIsFreeSlow(bool value) {
    if (_isFreeSlow != value) {
      _isFreeSlow = value;
      _saveIsFreeSlow(value);
      notifyListeners();
    }
  }

  void setKeepScreenOn(bool value) {
    if (_keepScreenOn != value) {
      _keepScreenOn = value;
      _saveKeepScreenOn(value);
      notifyListeners();
    }
  }

  void setSleepPreventionPrompted(bool value) {
    if (_sleepPreventionPrompted != value) {
      _sleepPreventionPrompted = value;
      _saveSleepPreventionPrompted(value);
      notifyListeners();
    }
  }

  void setBatteryOptimizationPrompted(bool value) {
    if (_batteryOptimizationPrompted != value) {
      _batteryOptimizationPrompted = value;
      _saveBatteryOptimizationPrompted(value);
      notifyListeners();
    }
  }

  void setSdhClear(bool value) {
    _sdhClearTouched = true;
    if (_sdhClear != value) {
      _sdhClear = value;
      _saveSdhClear(value);
      notifyListeners();
    }
  }

  void setSdhClearNoTrans(bool value) {
    _sdhClearNoTransTouched = true;
    if (_sdhClearNoTrans != value) {
      _sdhClearNoTrans = value;
      _saveSdhClearNoTrans(value);
      notifyListeners();
    }
  }

  void setTargetLanguage(String language) {
    final normalizedLanguage = normalizeAiPanelLanguageCode(language);
    if (_targetLanguage != normalizedLanguage) {
      _targetLanguage = normalizedLanguage;
      _saveTargetLanguage(normalizedLanguage);
      notifyListeners();
    }
  }

  // Loading from preferences
  Future<void> loadSettingsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _batchSize = prefs.getInt(_prefKeyBatchSize) ?? 150;
    _isFreeSlow = prefs.getBool(_prefKeyIsFreeSlow) ?? false;
    _keepScreenOn = prefs.getBool(_prefKeyKeepScreenOn) ?? false;
    _sleepPreventionPrompted =
        prefs.getBool(_prefKeySleepPreventionPrompted) ?? false;
    _batteryOptimizationPrompted =
        prefs.getBool(_prefKeyBatteryOptimizationPrompted) ?? false;
    final loadedSdhClear = prefs.getBool(_prefKeySdhClear) ?? true;
    final loadedSdhClearNoTrans =
        prefs.getBool(_prefKeySdhClearNoTrans) ?? false;

    if (!_sdhClearTouched) {
      _sdhClear = loadedSdhClear;
    }
    if (!_sdhClearNoTransTouched) {
      _sdhClearNoTrans = loadedSdhClearNoTrans;
    }

    // Keep the flags mutually consistent even if legacy prefs had both enabled.
    if (_sdhClearNoTrans) {
      _sdhClear = false;
    }
    _targetLanguage = normalizeAiPanelLanguageCode(
      prefs.getString(_prefKeyTargetLanguage) ?? "TR",
    );

    notifyListeners();
  }

  // Private persistence methods
  Future<void> _saveBatchSize(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyBatchSize, value);
  }

  Future<void> _saveIsFreeSlow(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyIsFreeSlow, value);
  }

  Future<void> _saveKeepScreenOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyKeepScreenOn, value);
  }

  Future<void> _saveSleepPreventionPrompted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySleepPreventionPrompted, value);
  }

  Future<void> _saveBatteryOptimizationPrompted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyBatteryOptimizationPrompted, value);
  }

  Future<void> _saveSdhClear(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySdhClear, value);
  }

  Future<void> _saveSdhClearNoTrans(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySdhClearNoTrans, value);
  }

  Future<void> _saveTargetLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTargetLanguage, value);
  }
}
