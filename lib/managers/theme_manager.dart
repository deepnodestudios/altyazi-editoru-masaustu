import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../translations.dart';

class ThemeManager extends ChangeNotifier {
  late SharedPreferences _prefs;

  static const String _prefKeyLanguage = 'language';
  static final Set<String> _supportedUiLanguages =
      Translations.supportedUiLanguages.toSet();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  String _language = "EN";
  String get language => _language;

  Map<String, String> get trans => Translations.getWithGlobalFallback(language);

  bool _oledMode = false;
  bool get oledMode => _oledMode;

  double _liveViewFontSize = 14.0;
  double get liveViewFontSize => _liveViewFontSize;

  double _editorFontSize = 16.0;
  double get editorFontSize => _editorFontSize;

  double _uiScale = 1.0;
  double get uiScale => _uiScale;

  ThemeManager() {
    _loadPreferences();
  }

  String _normalizeLanguageCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (code == 'HI') return 'IN';
    if (code == 'ZH') return 'CN';
    return code;
  }

  String _resolveInitialLanguage({String? savedLanguage, Locale? systemLocale}) {
    final saved = savedLanguage == null ? '' : _normalizeLanguageCode(savedLanguage);
    if (saved.isNotEmpty && _supportedUiLanguages.contains(saved)) {
      return saved;
    }

    if (systemLocale != null) {
      final systemCode = _normalizeLanguageCode(systemLocale.languageCode);
      if (_supportedUiLanguages.contains(systemCode)) {
        return systemCode;
      }
    }

    return 'EN';
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = (_prefs.getBool('is_dark_mode') ?? true) ? ThemeMode.dark : ThemeMode.light;
    _language = _resolveInitialLanguage(
      savedLanguage: _prefs.getString(_prefKeyLanguage),
      systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
    );
    await _prefs.setString(_prefKeyLanguage, _language);
    _oledMode = _prefs.getBool('oled_mode') ?? false;
    _liveViewFontSize = _prefs.getDouble('live_view_font_size') ?? 14.0;
    _editorFontSize = _prefs.getDouble('editor_font_size') ?? 16.0;
    _uiScale = (_prefs.getDouble('ui_scale') ?? 1.0).clamp(0.75, 1.25);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.setBool('is_dark_mode', mode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    final normalized = _normalizeLanguageCode(lang);
    if (!_supportedUiLanguages.contains(normalized)) return;
    if (_language == normalized) return;
    _language = normalized;
    await _prefs.setString(_prefKeyLanguage, normalized);
    Translations.clearCache();
    notifyListeners();
  }

  void toggleTheme() {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    if (newMode == ThemeMode.light && _oledMode) {
      setOledMode(false);
    }
    setThemeMode(newMode);
  }

  Future<void> setOledMode(bool enabled) async {
    if (_oledMode == enabled) return;
    _oledMode = enabled;
    await _prefs.setBool('oled_mode', enabled);
    notifyListeners();
  }

  Future<void> setLiveViewFontSize(double size) async {
    final clampedSize = size.clamp(8.0, 32.0);
    if (_liveViewFontSize == clampedSize) return;
    _liveViewFontSize = clampedSize;
    await _prefs.setDouble('live_view_font_size', clampedSize);
    notifyListeners();
  }

  Future<void> setEditorFontSize(double size) async {
    final clampedSize = size.clamp(8.0, 32.0);
    if (_editorFontSize == clampedSize) return;
    _editorFontSize = clampedSize;
    await _prefs.setDouble('editor_font_size', clampedSize);
    notifyListeners();
  }

  // ─── Ölçek animasyonu: Şeffaf Pencere + Animasyonlu Kutu Modu ───
  double? _appWidth;
  double? _appHeight;

  double? get appWidth => _appWidth;
  double? get appHeight => _appHeight;

  void setAppSize(double width, double height) {
    _appWidth = width;
    _appHeight = height;
    notifyListeners();
  }

  void clearAppSize() {
    _appWidth = null;
    _appHeight = null;
    notifyListeners();
  }

  Future<void> setUiScale(double scale) async {
    final clamped = scale.clamp(0.75, 1.25);
    if (_uiScale == clamped) return;
    _uiScale = clamped;
    await _prefs.setDouble('ui_scale', clamped);
    notifyListeners();
  }
}