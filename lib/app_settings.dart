import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/file_encoding_utils.dart';
import 'services/subtitle_parser.dart';
import 'services/subtitle_builder.dart';
import 'services/cloud_storage_service.dart';
import 'translations.dart';
import 'models/subtitle_block.dart';
import 'models/cloud_file_info.dart';
import 'managers/project_manager.dart';
import 'managers/theme_manager.dart';
import 'managers/settings_manager.dart';
import 'managers/ui_state_manager.dart';
import 'managers/translation_state_manager.dart';
import 'managers/api_config_manager.dart';
import 'managers/cloud_state_manager.dart';
import 'managers/notification_manager.dart';
import 'managers/editor_state_manager.dart';
import 'managers/crash_report_manager.dart';
import 'services/log_service.dart';
import 'utils/string_utils.dart';
import 'cloud_oauth_config.dart';

class DesktopUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String fileName;
  final String downloadUrl;
  final String? folderUrl;

  const DesktopUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.fileName,
    required this.downloadUrl,
    this.folderUrl,
  });
}

// TranslationProject sınıfı artık managers/project_manager.dart'ta

class AppSettings extends ChangeNotifier {
  static const String _prefKeyAlwaysOnTop = 'window_always_on_top';
  static const String _prefKeyMinimizeToTray = 'window_minimize_to_tray';
  static const String _prefKeyDesktopUpdateLastCheckMs =
      'desktop_update_last_check_ms';

  // ThemeManager is now injected
  final ThemeManager themeManager;

  // Manager instances
  late final ProjectManager _projectManager = ProjectManager();
  late final SettingsManager _settingsManager = SettingsManager();
  late final UIStateManager _uiStateManager = UIStateManager();
  late final TranslationStateManager _translationStateManager =
      TranslationStateManager();
  late final APIConfigManager _apiConfigManager = APIConfigManager();
  late final CloudStateManager _cloudStateManager = CloudStateManager();
  late final NotificationManager _notificationManager = NotificationManager();
  late final EditorStateManager _editorStateManager =
      EditorStateManager(_uiStateManager);
  late final CrashReportManager _crashReportManager = CrashReportManager();
  late final CloudStorageService _cloudStorageService =
      CloudStorageService(_cloudStateManager);

  // Service instances
  final LogService _logService = LogService();
  String? _selectedTranslationFile;
  String _selectedTranslationFilePath = '';
  String _translationSourceCachePath = '';
  List<SubtitleBlock> _sourceBlocks = [];
  List<SubtitleBlock> _processedBlocks = [];
  double _progress = 0.0;
  bool _isOffline = false;
  String get _selectedModel => _apiConfigManager.selectedModel;
  String get _selectedEngine => _apiConfigManager.selectedEngine;
  String get _targetLanguage => _settingsManager.targetLanguage;

  List<TranslationProject> get projects => _projectManager.projects;
  String get language => themeManager.language;
  Map<String, String> get trans => themeManager.trans;
  bool get oledMode => themeManager.oledMode;
  double get liveViewFontSize => themeManager.liveViewFontSize;
  double get editorFontSize => themeManager.editorFontSize;
  int get batchSize => _settingsManager.batchSize;
  bool get isFreeSlow => _settingsManager.isFreeSlow;
  bool get keepScreenOn => _settingsManager.keepScreenOn;
  bool get sleepPreventionPrompted => _settingsManager.sleepPreventionPrompted;
  bool get batteryOptimizationPrompted =>
      _settingsManager.batteryOptimizationPrompted;
  bool get sdhClear => _settingsManager.sdhClear;
  bool get sdhClearNoTrans => _settingsManager.sdhClearNoTrans;
  String get targetLanguage => _settingsManager.targetLanguage;

  // Delegation getters - UI State
  bool get isLiveViewActive => _uiStateManager.isLiveViewActive;
  String? get selectedEditorFile => _uiStateManager.selectedEditorFile;
  bool get isEditorDirty => _uiStateManager.isEditorDirty;
  int get lastTabIndex => _uiStateManager.lastTabIndex;
  int? get pendingTabIndex => _uiStateManager.pendingTabIndex;
  bool get tabRestored => _uiStateManager.tabRestored;
  bool get startupCheckDone => _uiStateManager.startupCheckDone;
  bool get onboardingShown => _uiStateManager.onboardingShown;

  // Delegation getters - Cloud Storage (expose service directly)
  CloudStorageService get cloudStorage => _cloudStorageService;

  // Delegation getters - Translation State
  String? get selectedTranslationFile =>
      _translationStateManager.selectedTranslationFile;
  String? get selectedTranslationFilePath =>
      _translationStateManager.selectedTranslationFilePath;
  String? get translationSourceCachePath =>
      _translationStateManager.translationSourceCachePath;
  bool get isTranslating => _translationStateManager.isTranslating;
  bool get isTranslationComplete =>
      _translationStateManager.isTranslationComplete;
  double get progress => _translationStateManager.progress;
  bool get translationForegroundActive =>
      _translationStateManager.translationForegroundActive;
  List<SubtitleBlock> get sourceBlocks => _translationStateManager.sourceBlocks;
  List<SubtitleBlock> get processedBlocks =>
      _translationStateManager.processedBlocks;
  bool get lastProcessWasTranslation =>
      _translationStateManager.lastProcessWasTranslation;
  bool get isWaitingForQuota => _translationStateManager.isWaitingForQuota;
  int get currentOutputIndex => _translationStateManager.currentOutputIndex;

  // Delegation getters - API Config
  String get selectedModel => _apiConfigManager.selectedModel;
  List<String> get availableModels => _apiConfigManager.availableModels;
  String get selectedEngine => _apiConfigManager.selectedEngine;

  // Delegation getters - Cloud State
  bool get isAuthLoading => _cloudStateManager.isAuthLoading;
  String? get loadingAuthProvider => _cloudStateManager.loadingAuthProvider;
  bool get isOffline => _cloudStateManager.isOffline;
  bool get isGDriveConnected => _cloudStateManager.isGDriveConnected;
  bool get isDropboxConnected => _cloudStateManager.isDropboxConnected;
  bool get isYandexConnected => _cloudStateManager.isYandexConnected;

  GoogleSignInAccount? get googleUser => _cloudStorageService.googleUser;
  bool get isGoogleSignedIn {
    if (_cloudStateManager.isGDriveConnected) return true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;

    // Desktop flows may briefly miss providerData even though Firebase session
    // is already authenticated. Keep UI stable by falling back to connected
    // state when we have a non-anonymous user.
    final hasGoogleProvider =
        user.providerData.any((info) => info.providerId == 'google.com');
    return hasGoogleProvider || _cloudStateManager.isGDriveConnected;
  }

  /// Google Sign In sonrasında kredileri transfer etmek için callback
  Future<void> Function(String googleUserId)? onGoogleSignInSuccess;

  Future<void> signInWithGoogle() async {
    await refreshCloudOAuthConfig();
    await _cloudStorageService.signInWithGoogle(
        onGoogleSignInSuccess: onGoogleSignInSuccess);
    notifyListeners();
  }

  Future<void> signOutGoogle() async {
    await _cloudStorageService.signOutGoogle();
    notifyListeners();
  }

  // Remaining properties
  bool _prefsLoaded = false;

  // Local-only fields
  DateTime? _translationStartTime;
  final bool _showSrt = false;

  // Editor state (remaining)

  // Logs and undo/redo
  final List<LogEntry> _logs = [];
  bool _tutorialTranslationShown = false;
  bool _tutorialEditorShown = false;
  bool _hideInfoButtons = false;
  bool _hideBatchTranslationInfo = false;
  bool _confirmDeletes = true;
  bool _showCrashWarnings = true;
  bool _alwaysOnTop = false;
  bool _minimizeToTray = true;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<User?>? _authStateSubscription;
  Timer? _authStatePollTimer;
  bool? _lastGoogleLinked;
  bool? _lastIsLoggedIn;

  bool get _useAuthStateStream => !(!kIsWeb && Platform.isWindows);
  bool get alwaysOnTop => _alwaysOnTop;
  bool get minimizeToTray => _minimizeToTray;
  bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static final RegExp _versionRegex = RegExp(
    r'(\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z.-]+)?)',
    caseSensitive: false,
  );

  int _compareVersions(String a, String b) {
    List<int> parseCore(String value) {
      final core = value.split(RegExp(r'[-+]')).first.trim();
      return core
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList(growable: false);
    }

    final pa = parseCore(a);
    final pb = parseCore(b);
    final maxLen = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < maxLen; i++) {
      final ai = i < pa.length ? pa[i] : 0;
      final bi = i < pb.length ? pb[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }

  String? _extractVersionFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
    final matches = _versionRegex.allMatches(baseName).toList(growable: false);
    if (matches.isEmpty) return null;
    return matches.last.group(0);
  }

  String _resolveUpdateFolderId() {
    final direct = CloudOAuthConfig.googleDriveUpdateFolderId.trim();
    if (direct.isNotEmpty) return direct;

    final url = CloudOAuthConfig.googleDriveUpdateFolderUrl.trim();
    if (url.isEmpty) return '';

    final match = RegExp(r'/folders/([^/?#]+)', caseSensitive: false)
        .firstMatch(url);
    return (match?.group(1) ?? '').trim();
  }

  String _resolveUpdateFolderUrl(String folderId) {
    final configured = CloudOAuthConfig.googleDriveUpdateFolderUrl.trim();
    if (configured.isNotEmpty) return configured;
    if (folderId.isEmpty) return '';
    return 'https://drive.google.com/drive/folders/$folderId?usp=sharing';
  }

  List<String> _extractInstallerNamesFromDriveHtml(String html) {
    final result = <String>[];
    final seen = <String>{};

    final pattern = RegExp(
      r'([A-Za-z0-9 _+&().-]{3,}\.(?:exe|msi|zip))',
      caseSensitive: false,
    );

    void collectFrom(String source) {
      for (final match in pattern.allMatches(source)) {
        final name = (match.group(1) ?? '').trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (seen.add(key)) result.add(name);
      }
    }

    collectFrom(html);
    try {
      collectFrom(Uri.decodeFull(html));
    } catch (_) {}

    return result;
  }

  Future<DesktopUpdateInfo?> checkDesktopUpdateFromGoogleDrive({
    Duration minimumCheckInterval = const Duration(hours: 4),
  }) async {
    if (!isDesktopPlatform || !(Platform.isWindows)) return null;

    final folderId = _resolveUpdateFolderId();
    if (folderId.isEmpty) return null;
    final folderUrl = _resolveUpdateFolderUrl(folderId);
    if (folderUrl.isEmpty) return null;

    final folderUri = Uri.tryParse(folderUrl);
    if (folderUri == null ||
        (folderUri.scheme != 'http' && folderUri.scheme != 'https')) {
      // Defensive: avoid accidentally passing file:/// (or other) URIs into
      // the HTTP client, which throws "No host specified".
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastCheckMs = prefs.getInt(_prefKeyDesktopUpdateLastCheckMs) ?? 0;
    if (lastCheckMs > 0 &&
        nowMs - lastCheckMs < minimumCheckInterval.inMilliseconds) {
      return null;
    }
    await prefs.setInt(_prefKeyDesktopUpdateLastCheckMs, nowMs);

    try {
      addLog('log_update_check_started');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      final response = await http
          .get(folderUri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        addLog(
          'log_update_check_failed_param',
          jsonEncode({'error': 'HTTP ${response.statusCode}'}),
        );
        return null;
      }

      final installerNames =
          _extractInstallerNamesFromDriveHtml(response.body);

      String? bestFileName;
      String? bestVersion;
      for (final name in installerNames) {
        final version = _extractVersionFromFileName(name);
        if (version == null || version.isEmpty) continue;
        if (_compareVersions(version, currentVersion) <= 0) continue;

        if (bestVersion == null || _compareVersions(version, bestVersion) > 0) {
          bestVersion = version;
          bestFileName = name;
        }
      }

      if (bestFileName == null || bestVersion == null) {
        addLog(
          'log_update_not_available_param',
          jsonEncode({'current': currentVersion}),
        );
        return null;
      }

      addLog(
        'log_update_available_param',
        jsonEncode({
          'current': currentVersion,
          'latest': bestVersion,
          'file': bestFileName,
        }),
      );

      return DesktopUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: bestVersion,
        fileName: bestFileName,
        downloadUrl: folderUrl,
        folderUrl: folderUrl,
      );
    } catch (e) {
      addLog(
        'log_update_check_failed_param',
        jsonEncode({'error': e.toString()}),
      );
      return null;
    }
  }

  bool _hasGoogleProvider(User user) {
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  AppSettings({
    required this.themeManager,
    bool enablePersistence = true,
    bool enableNotifications = true,
    bool tutorialTranslationShown = false,
    bool tutorialEditorShown = false,
  }) {
    _tutorialTranslationShown = tutorialTranslationShown;
    _tutorialEditorShown = tutorialEditorShown;

    _editorStateManager.onLog = (key, [param]) => addLog(key, param);
    _editorStateManager.addListener(notifyListeners);
    _projectManager.addListener(notifyListeners);

    // ThemeManager değişikliklerini (dil, tema vs.) dinle
    themeManager.addListener(notifyListeners);

    _cloudStorageService.onLog = (key, [param]) => addLog(key, param);
    _cloudStorageService.onGetTranslations = () => trans;

    // Best-effort: pull OAuth client ids (and optional Yandex secret) from
    // Firebase Remote Config so they are not hardcoded in the repo.
    // NOTE: This hides them from the *source code*, but does not make them
    // truly secret against reverse-engineering.
    unawaited(_applyRemoteOAuthOverrides());

    // Firebase Auth state değişimlerini dinle (session restore için)
    if (_useAuthStateStream) {
      _authStateSubscription =
          FirebaseAuth.instance.authStateChanges().listen((_) {
        unawaited(_syncGoogleConnectionStateFromAuth());
      });
    } else {
      unawaited(_syncGoogleConnectionStateFromAuth());
      _authStatePollTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
        unawaited(_syncGoogleConnectionStateFromAuth());
      });
    }

    if (enablePersistence) {
      _loadPreferences();
    } else {
      // Allow the app to render immediately when persistence is disabled.
      _prefsLoaded = true;
    }
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      checkConnectivity();
    });

    if (enableNotifications) {
      _notificationManager.initNotifications(
        addLog: (String key, [String? param]) => addLog(key, param),
      );
    }

    if (!enablePersistence) {
      notifyListeners();
    }
  }

  static String _sanitizeRemoteOAuthValue(String value) {
    final v = value.trim().replaceAll(RegExp(r'\s+'), '');
    if (v.isEmpty) return '';
    final upper = v.toUpperCase();
    if (upper == 'PASTE_HERE' || upper.contains('PASTE_HERE')) return '';
    return v;
  }

  Future<void> _prepareRemoteConfig(FirebaseRemoteConfig rc) async {
    try {
      await rc.setDefaults(<String, dynamic>{
        'dropbox_client_id': '',
        'google_desktop_client_id': '',
        'google_oauth_client_id': '',
        'google_client_id': '',
        'yandex_client_id': '',
        'yandex_client_secret': '',
      });
    } catch (_) {}

    try {
      final minFetchInterval = (!kIsWeb &&
              (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
          ? const Duration(seconds: 10)
          : const Duration(hours: 1);
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: minFetchInterval,
      ));
    } catch (_) {}

    try {
      await rc.fetchAndActivate();
    } catch (_) {}
  }

  String _safeRemoteConfigString(FirebaseRemoteConfig rc, String key) {
    try {
      return _sanitizeRemoteOAuthValue(rc.getString(key));
    } catch (_) {
      return '';
    }
  }

  Future<void> _applyRemoteOAuthOverrides() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await _prepareRemoteConfig(rc);

      final dropboxClientId = _safeRemoteConfigString(rc, 'dropbox_client_id');
        final googleDesktop =
          _safeRemoteConfigString(rc, 'google_desktop_client_id');
      final googlePrimary =
          _safeRemoteConfigString(rc, 'google_oauth_client_id');
      final googleLegacy = _safeRemoteConfigString(rc, 'google_client_id');
        final googleOauthClientId = googleDesktop.isNotEmpty
          ? googleDesktop
          : (googlePrimary.isNotEmpty ? googlePrimary : googleLegacy);
      final yandexClientId = _safeRemoteConfigString(rc, 'yandex_client_id');
      final yandexClientSecret =
          _safeRemoteConfigString(rc, 'yandex_client_secret');

      if (dropboxClientId.isEmpty &&
          googleOauthClientId.isEmpty &&
          yandexClientId.isEmpty &&
          yandexClientSecret.isEmpty) {
        return;
      }

      await _cloudStorageService.setOAuthOverrides(
        dropboxClientId: dropboxClientId.isEmpty ? null : dropboxClientId,
        googleOauthClientId:
            googleOauthClientId.isEmpty ? null : googleOauthClientId,
        yandexClientId: yandexClientId.isEmpty ? null : yandexClientId,
        yandexClientSecret:
            yandexClientSecret.isEmpty ? null : yandexClientSecret,
      );
    } catch (e) {
      // Keep startup silent; user can still paste overrides in Settings.
      addLog('log_oauth_remote_config_failed',
          jsonEncode({'error': e.toString()}));
    }
  }

  Future<void> refreshCloudOAuthConfig() async {
    await _applyRemoteOAuthOverrides();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _authStateSubscription?.cancel();
    _authStatePollTimer?.cancel();
    themeManager.removeListener(notifyListeners);
    _projectManager.removeListener(notifyListeners);
    super.dispose();
  }

  Future<void> _syncGoogleConnectionStateFromAuth() async {
    // Prefs yüklenmeden önce GDrive durumunu değiştirme – değer ezilir.
    if (!_prefsLoaded) return;

    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;
    final isGoogleLinked = isLoggedIn &&
      (_hasGoogleProvider(user) ||
        (_cloudStateManager.isGDriveConnected &&
          (user.email?.trim().isNotEmpty ?? false)));

    // --- GDrive state (tracked separately) ---
    if (_lastGoogleLinked != isGoogleLinked) {
      _lastGoogleLinked = isGoogleLinked;
      if (isGoogleLinked) {
        if (!_cloudStateManager.isGDriveConnected) {
          _cloudStateManager.setIsGDriveConnected(true);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_gdrive_connected', true);
          notifyListeners();
        }
      } else if (_cloudStateManager.isGDriveConnected) {
        // Desktop: oturum restore tamamlanmadan GDrive'ı kapatma.
        // Firebase oturumu henüz kurulmamış olabilir, token ile geri
        // yüklenecektir.
        if (isDesktopPlatform) return;
        _cloudStateManager.setIsGDriveConnected(false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_gdrive_connected', false);
        notifyListeners();
      }
    }

    // --- Firestore sync state (any non-anonymous login, not just Google) ---
    if (_lastIsLoggedIn == isLoggedIn) return;
    _lastIsLoggedIn = isLoggedIn;

    if (isLoggedIn) {
      // Kullanıcı giriş yaptı — tüm provider'lar için sync başlat
      _projectManager.startFirestoreSync();
    } else {
      // Kullanıcı çıkış yaptı
      _projectManager.stopFirestoreSync();
      unawaited(_projectManager.clearProjectsForLogout());
    }
  }

  Future<void> requestNotificationPermission() async {
    await _notificationManager.requestNotificationPermission();
  }

  Future<void> showProgressNotification(int current, int total,
      {bool isComplete = false, String? fileName}) async {
    await _notificationManager.showProgressNotification(
      current,
      total,
      isComplete: isComplete,
      fileName: fileName,
      language: language,
      translationForegroundActive:
          _translationStateManager.translationForegroundActive,
      setTranslationForegroundActive:
          _translationStateManager.setTranslationForegroundActive,
    );
  }

  Future<void> cancelNotification() async {
    await _notificationManager.cancelNotification(
      translationForegroundActive:
          _translationStateManager.translationForegroundActive,
      setTranslationForegroundActive:
          _translationStateManager.setTranslationForegroundActive,
    );
  }

  ThemeMode get themeMode => themeManager.themeMode;
  List<LogEntry> get logs => _logs;
  bool get showSrt => _showSrt;
  // projects getter artık _projectManager üzerinden sağlanıyor (yukarıda tanımlı)
  List<SubtitleBlock> get editorBlocks => _editorStateManager.editorBlocks;
  bool get isOpeningEditor => _editorStateManager.isOpeningEditor;
  double get editorOpenProgress => _editorStateManager.editorOpenProgress;

  List<SubtitleBlock> get filteredEditorBlocks =>
      _editorStateManager.filteredEditorBlocks;

  bool get isCaseSensitive => _editorStateManager.isCaseSensitive;
  bool get isRegexSearch => _editorStateManager.isRegexSearch;
  String get searchQuery => _editorStateManager.searchQuery;
  int get currentSearchMatchIndex =>
      _editorStateManager.currentSearchMatchIndex;
  int get totalSearchMatches => _editorStateManager.totalSearchMatches;
  int get currentMatchedBlockIndex =>
      _editorStateManager.currentMatchedBlockIndex;
  DateTime? get translationStartTime => _translationStartTime;
  bool get tutorialTranslationShown => _tutorialTranslationShown;
  bool get tutorialEditorShown => _tutorialEditorShown;
  bool get hideInfoButtons => _hideInfoButtons;
  bool get hideBatchTranslationInfo => _hideBatchTranslationInfo;
  bool get confirmDeletes => _confirmDeletes;
  bool get showCrashWarnings => _showCrashWarnings;
  bool get canUndo => _editorStateManager.canUndo;
  bool get canRedo => _editorStateManager.canRedo;
  bool get prefsLoaded => _prefsLoaded;
  String get editorEncoding => _editorStateManager.editorEncoding;

  static const String _crashLogFileName = 'crash_log.txt';

  static Future<File> getCrashLogFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$_crashLogFileName');
  }

  Future<void> triggerCrashTest() async {
    try {
      final file = await getCrashLogFile();
      final now = DateTime.now().toIso8601String();
      final payload =
          '\n[$now] CrashTest\nUser triggered crash test\n--------------------------------\n';
      await file.writeAsString(payload, mode: FileMode.append, flush: true);
    } catch (_) {
      // Ignore logging failures for test.
    }

    // Close the app to simulate a crash without throwing from the UI thread.
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
      return;
    }

    exit(0);
  }

  Future<void> promptCrashReportIfAvailable(BuildContext context) async {
    if (!_showCrashWarnings) return;
    if (!await _crashReportManager.hasCrashLog()) return;

    // Check if we already prompted for this specific crash session
    final prefs = await SharedPreferences.getInstance();
    final forcePrompt = prefs.getBool('crash_report_force_prompt') ?? false;
    final file = await _crashReportManager.getCrashLogFile();
    final crashSize = await file.length();
    final lastPromptedSize = prefs.getInt('crash_report_prompted_size') ?? -1;

    // If the crash log size matches what we last prompted, skip
    if (!forcePrompt && lastPromptedSize == crashSize) return;

    // Mark this crash log size as prompted
    await prefs.setInt('crash_report_prompted_size', crashSize);

    if (forcePrompt) {
      // Reset immediately; if the user crashes again before dismissing/sending,
      // next startup will re-set this flag.
      await prefs.setBool('crash_report_force_prompt', false);
    } else {
      // If it's not a forced prompt (like a native crash), we don't want to show it
      // just because there's a log file. We only want to show it for real crashes.
      return;
    }

    if (!context.mounted) return;

    final t = trans;
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          title: Text(t["crash_report_title"] ?? "Çökme Raporu"),
        content: Text(
          t["crash_report_message"] ??
            "Uygulama daha önce çöktü. Çökme günlüğü geliştiriciye gönderilsin mi?",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _crashReportManager.clearCrashLog();
            },
            child: Text(t["crash_report_dismiss"] ?? "Kapat"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final sent = await _crashReportManager
                  .shareCrashLog(context, file, language: language);
              if (sent) {
                await _crashReportManager.clearCrashLog();
              }
            },
            child: Text(t["crash_report_send"] ?? "Gönder"),
          ),
        ],
      ),
    );
  }

  Future<TranslationProject?> promptPartialTranslationIfAvailable(
      BuildContext context) async {
    // Check for partial translations in projects
    final partialProjects = _projectManager.getPartialProjects();
    if (partialProjects.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final lastPromptTime = prefs.getInt('partial_translation_prompt_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Only prompt once per 6 hours to avoid annoying the user
    if (now - lastPromptTime < 6 * 60 * 60 * 1000) return null;

    await prefs.setInt('partial_translation_prompt_time', now);

    if (!context.mounted) return null;

    final t = trans;
    final project = partialProjects.first; // Show the most recent one
    return showDialog<TranslationProject?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t["partial_translation_title"] ?? "Yarım Kalan Çeviri"),
        content: Text(
          "${t["partial_translation_message"] ?? "Yarım kalan çeviriniz var"}: ${project.fileName}\n\n${t["partial_translation_continue"] ?? "Devam etmek ister misiniz?"}",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, null);
            },
            child: Text(t["cancel"] ?? "İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              // Projeyi döndür, işlemi MainScreen/Controller yapsın
              Navigator.pop(ctx, project);
            },
            child: Text(t["continue"] ?? "Devam Et"),
          ),
        ],
      ),
    );
  }

  Future<void> resumePartialTranslation(TranslationProject project) async {
    // Load the project into the editor
    _selectedTranslationFile = project.fileName;
    _selectedTranslationFilePath = project.filePath;
    _translationSourceCachePath = project.translationSourceCachePath ?? '';
    _settingsManager.setTargetLanguage(project.targetLanguage);
    _sourceBlocks = project.sourceBlocks;
    _processedBlocks = project.processedBlocks;
    // _currentOutputIndex is now managed by TranslationStateManager
    // No need to set it here as it's derived from processedBlocks.length

    notifyListeners();
  }

  bool isProviderLoading(String provider) =>
      _cloudStateManager.isProviderLoading(provider);

  String get effectiveDropboxClientId =>
      _cloudStorageService.effectiveDropboxClientId;
  String get effectiveGoogleOauthClientId =>
      _cloudStorageService.effectiveGoogleOauthClientId;
  String get effectiveYandexClientId =>
      _cloudStorageService.effectiveYandexClientId;
  String get effectiveYandexClientSecret =>
      _cloudStorageService.effectiveYandexClientSecret;

  bool get hasDropboxOAuthConfig => _cloudStorageService.hasDropboxOAuthConfig;
  bool get hasGoogleOAuthConfig => _cloudStorageService.hasGoogleOAuthConfig;
  bool get hasYandexOAuthConfig => _cloudStorageService.hasYandexOAuthConfig;

  Future<void> setOAuthOverrides({
    String? dropboxClientId,
    String? googleOauthClientId,
    String? yandexClientId,
    String? yandexClientSecret,
  }) async {
    await _cloudStorageService.setOAuthOverrides(
        dropboxClientId: dropboxClientId,
        googleOauthClientId: googleOauthClientId,
        yandexClientId: yandexClientId,
        yandexClientSecret: yandexClientSecret);
    notifyListeners();
  }

  Future<String?> _promptForYandexConfirmationCode(
    BuildContext context, {
    required Uri authUri,
  }) async {
    final controller = TextEditingController();
    try {
      final t = trans;
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text(t['yandex_code_title'] ?? 'Yandex Disk Authorization'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['yandex_code_help'] ??
                        'A browser window will open and show a confirmation code. Copy it and paste it here.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: t['yandex_code_label'] ?? 'Confirmation code',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t['btn_cancel'] ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // Avoid awaiting a platform call inside a dialog button.
                  unawaited(
                    launchUrl(authUri, mode: LaunchMode.externalApplication),
                  );
                },
                child: Text(t['yandex_code_open_browser'] ?? 'Open browser'),
              ),
              ElevatedButton(
                onPressed: () {
                  final code = controller.text.trim();
                  Navigator.pop(ctx, code.isEmpty ? null : code);
                },
                child: Text(t['btn_continue'] ?? 'Continue'),
              ),
            ],
          );
        },
      );
    } finally {
      // The dialog route may still be animating out for a frame after
      // Navigator.pop(). Disposing immediately can trip debug asserts.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 400))
            .then((_) => controller.dispose()),
      );
    }
  }

  Future<void> saveResultToDropbox({
    required bool isEditorSave,
    required String fileName,
    String? folderPath,
  }) async {
    final content = _buildSrtContent(isEditorSave: isEditorSave);
    await _cloudStorageService.uploadTextFileToDropbox(
        fileName: fileName, content: content, folderPath: folderPath);
    final t = trans;
    addLog(
      "log_saved",
      StringUtils.fillTemplate(
        t["log_saved_to_provider"] ?? "{provider}: {name}",
        {
          'provider': t['cloud_source_dropbox'] ?? 'Dropbox',
          'name': fileName,
        },
      ),
    );
    if (isEditorSave) {
      _editorStateManager.markSaved();
    }
  }

  Future<void> saveResultToYandexDisk({
    required bool isEditorSave,
    required String fileName,
    String? folderPath,
  }) async {
    final content = _buildSrtContent(isEditorSave: isEditorSave);
    await _cloudStorageService.uploadTextFileToYandexDisk(
        fileName: fileName, content: content, folderPath: folderPath);
    final t = trans;
    addLog(
      "log_saved",
      StringUtils.fillTemplate(
        t["log_saved_to_provider"] ?? "{provider}: {name}",
        {
          'provider': t['cloud_source_yandex'] ?? 'Yandex Disk',
          'name': fileName,
        },
      ),
    );
    if (isEditorSave) {
      _editorStateManager.markSaved();
    }
  }

  Future<void> changeLanguage(String lang) async {
    await themeManager.setLanguage(lang);
    notifyListeners();
  }

  Future<void> setOledMode(bool value) async {
    await themeManager.setOledMode(value);
    notifyListeners();
  }

  Future<void> toggleGDriveConnection() async {
    if (isAuthLoading) return;
    _cloudStateManager.setLoadingAuthProvider('google_drive');
    notifyListeners();

    try {
      if (_cloudStateManager.isGDriveConnected) {
        await _cloudStorageService.disconnectGDrive();
        addLog("log_gdrive_disconnected");
      } else {
        final isDesktop =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;

        if (isDesktop) {
          // Desktop: PKCE akışı ile hem Firebase Auth hem GDrive erişimi
          // sağlanır. Böylece kredi sistemi de aktif olur.
          // manageLoadingState: false → loading state'i biz yönetiyoruz,
          // hata olursa rethrow edilir ve catch bloğumuz yakalar.
          await refreshCloudOAuthConfig();
          await _cloudStorageService.signInWithGoogle(
            onGoogleSignInSuccess: onGoogleSignInSuccess,
            manageLoadingState: false,
          );

          final user = FirebaseAuth.instance.currentUser;
          if (user != null && !user.isAnonymous) {
            addLog("log_gdrive_connected", user.email);
          }
        } else {
          // Mobil: GoogleSignIn eklentisi ile bağlan.
          await refreshCloudOAuthConfig();
          final account =
              await _cloudStorageService.ensureGDriveAccount(interactive: true);
          if (account == null) {
            addLog("log_error", "log_gdrive_signin_null");
          } else {
            addLog("log_gdrive_connected", account.email);
          }
        }
      }
    } catch (e) {
      final t = trans;
      final msg = StringUtils.formatGoogleSignInError(e);
      addLog(
        "log_error",
        StringUtils.fillTemplate(
          t['log_auth_error_param'] ?? '{provider} auth error: {error}',
          {
            'provider': t['cloud_source_drive'] ?? 'Google Drive',
            'error': msg,
          },
        ),
      );
    } finally {
      _cloudStateManager.setLoadingAuthProvider(null);
      // State persistence is handled by CloudStorageService/CloudStateManager
      notifyListeners();
    }
  }

  String _buildSrtContent({required bool isEditorSave}) {
    final List<SubtitleBlock> blocks = isEditorSave
        ? editorBlocks
        : (_processedBlocks.isNotEmpty
            ? _processedBlocks
            : [
                SubtitleBlock(
                    index: 1,
                    timecode: "00:00:00 --> 00:00:00",
                      text: trans["empty_subtitle_text"] ?? "Boş")
              ]);
    return SubtitleBuilder.buildSrt(blocks, resequence: false);
  }

  Future<void> saveResultToGoogleDrive({
    required bool isEditorSave,
    required String fileName,
    String? folderId,
  }) async {
    final content = _buildSrtContent(isEditorSave: isEditorSave);
    await _cloudStorageService.uploadTextFileToGDrive(
        fileName: fileName, content: content, folderId: folderId);
    final t = trans;
    addLog(
      "log_saved",
      StringUtils.fillTemplate(
        t["log_saved_to_provider"] ?? "{provider}: {name}",
        {
          'provider': t['cloud_source_drive'] ?? 'Google Drive',
          'name': fileName,
        },
      ),
    );
    if (isEditorSave) {
      _editorStateManager.markSaved();
    }
  }

  Future<void> toggleDropboxConnection() async {
    if (isAuthLoading) return;
    _cloudStateManager.setLoadingAuthProvider('dropbox');
    notifyListeners();

    try {
      if (_cloudStateManager.isDropboxConnected) {
        await _cloudStorageService.disconnectDropbox();
        addLog("log_dropbox_disconnected");
      } else {
        await refreshCloudOAuthConfig();
        await _cloudStorageService.connectDropbox();
        addLog("log_dropbox_connected");
      }
    } catch (e) {
      final t = trans;
      addLog(
        "log_error",
        StringUtils.fillTemplate(
          t['log_auth_error_param'] ?? '{provider} auth error: {error}',
          {
            'provider': t['cloud_source_dropbox'] ?? 'Dropbox',
            'error': e.toString(),
          },
        ),
      );
    } finally {
      _cloudStateManager.setLoadingAuthProvider(null);
      notifyListeners();
    }
  }

  Future<void> toggleYandexConnection() async {
    if (isAuthLoading) return;
    _cloudStateManager.setLoadingAuthProvider('yandex');
    notifyListeners();

    try {
      if (_cloudStateManager.isYandexConnected) {
        await _cloudStorageService.disconnectYandex();
        addLog("log_yandex_disconnected");
      } else {
        throw Exception(
            'Yandex connect requires a UI context. Use toggleYandexConnectionWithContext(context).');
      }
    } catch (e) {
      final t = trans;
      addLog(
        "log_error",
        StringUtils.fillTemplate(
          t['log_auth_error_param'] ?? '{provider} auth error: {error}',
          {
            'provider': t['cloud_source_yandex'] ?? 'Yandex Disk',
            'error': e.toString(),
          },
        ),
      );
    } finally {
      _cloudStateManager.setLoadingAuthProvider(null);
      notifyListeners();
    }
  }

  Future<void> toggleYandexConnectionWithContext(BuildContext context) async {
    if (isAuthLoading) return;
    _cloudStateManager.setLoadingAuthProvider('yandex');
    notifyListeners();

    try {
      if (_cloudStateManager.isYandexConnected) {
        await _cloudStorageService.disconnectYandex();
        addLog('log_yandex_disconnected');
      } else {
        await refreshCloudOAuthConfig();
        if (!context.mounted) return;
        await _cloudStorageService.connectYandex(
          context,
          onCodeRequired: (uri) =>
              _promptForYandexConfirmationCode(context, authUri: uri),
        );
        addLog('log_yandex_connected');
      }
    } catch (e) {
      final t = trans;
      addLog(
        'log_error',
        StringUtils.fillTemplate(
          t['log_auth_error_param'] ?? '{provider} auth error: {error}',
          {
            'provider': t['cloud_source_yandex'] ?? 'Yandex Disk',
            'error': e.toString(),
          },
        ),
      );
    } finally {
      _cloudStateManager.setLoadingAuthProvider(null);
      notifyListeners();
    }
  }

  Future<void> setHideInfoButtons(bool value) async {
    _hideInfoButtons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_info_buttons', value);
    if (!value) {
      _hideBatchTranslationInfo = false;
      await prefs.setBool('hide_batch_info', false);
    }
    notifyListeners();
  }

  Future<void> setHideBatchTranslationInfo(bool value) async {
    _hideBatchTranslationInfo = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_batch_info', value);
    notifyListeners();
  }

  Future<void> setConfirmDeletes(bool value) async {
    _confirmDeletes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('confirm_deletes', value);
    notifyListeners();
  }

  Future<void> setShowCrashWarnings(bool value) async {
    _showCrashWarnings = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_crash_warnings', value);
    notifyListeners();
  }

  String get saveButtonLabel {
    if (lastProcessWasTranslation) {
      return Translations.getWithGlobalFallback(language)["save_trans"]!;
    }
    return Translations.getWithGlobalFallback(language)["save_cleaned"]!;
  }

  String get liveViewButtonLabel {
    if (sdhClearNoTrans) {
      return Translations.getWithGlobalFallback(language)["preview"]!;
    }
    if (isTranslating) {
      return Translations.getWithGlobalFallback(language)["live_view"]!;
    }
    return Translations.getWithGlobalFallback(language)["preview"]!;
  }

  bool get _isDesktopPlatformForLogs =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static const Set<String> _desktopHiddenCreditLogKeys = {
    'log_starter_credits_added',
    'log_starter_credits_failed',
    'log_credit_transfer_complete',
    'log_credit_transfer_message',
    'log_credit_transfer_failed',
  };

  void addLog(String key, [String? param]) {
    if (_isDesktopPlatformForLogs && _desktopHiddenCreditLogKeys.contains(key)) {
      return;
    }
    String time =
        "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}";
    _logs.insert(0, LogEntry(time, key, param));
    notifyListeners();
  }

  void markStartupCheckDone() {
    _uiStateManager.setStartupCheckDone(true);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _uiStateManager.setOnboardingShown(true);
    notifyListeners();
  }

  void setTabRestored() {
    _uiStateManager.setTabRestored(true);
  }

  Future<void> setLastTabIndex(int index) async {
    _uiStateManager.setLastTabIndex(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_tab_index', index);
  }

  void requestTabSwitch(int index) {
    _uiStateManager.setPendingTabIndex(index);
    notifyListeners();
  }

  void consumeTabSwitchRequest() {
    _uiStateManager.setPendingTabIndex(null);
  }

  Future<void> completeTranslationTutorial() async {
    _tutorialTranslationShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_translation_shown', true);
    notifyListeners();
  }

  Future<void> completeEditorTutorial() async {
    _tutorialEditorShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_editor_shown', true);
    notifyListeners();
  }

  void increaseLiveViewFontSize() {
    if (liveViewFontSize < 40) {
      themeManager.setLiveViewFontSize(liveViewFontSize + 2);
      notifyListeners();
    }
  }

  void decreaseLiveViewFontSize() {
    if (liveViewFontSize > 8) {
      themeManager.setLiveViewFontSize(liveViewFontSize - 2);
      notifyListeners();
    }
  }

  void increaseEditorFontSize() {
    if (editorFontSize < 40) {
      themeManager.setEditorFontSize(editorFontSize + 2);
      notifyListeners();
    }
  }

  void decreaseEditorFontSize() {
    if (editorFontSize > 8) {
      themeManager.setEditorFontSize(editorFontSize - 2);
      notifyListeners();
    }
  }

  void toggleTheme() {
    themeManager.toggleTheme();
    addLog("log_theme_changed");
  }

  Future<void> _fetchModelsFromApi() async {
    await _apiConfigManager.fetchModelsFromApi(
      isFreeSlow: _settingsManager.isFreeSlow,
      addLog: (String key, [String? param]) => addLog(key, param),
    );
    notifyListeners();
  }

  void setSelectedModel(String model) {
    _apiConfigManager.setSelectedModel(model);
    addLog("log_model_selected", model);
    notifyListeners();
  }

  void setSelectedEngine(String engine) {
    _apiConfigManager.setSelectedEngine(engine);
    final t = trans;
    addLog(
      "log_engine_changed",
      engine == "gemini"
          ? (t['engine_gemini'] ?? 'Gemini AI')
          : (t['engine_google'] ?? 'Google Translate (Web)'),
    );
    notifyListeners();
  }

  Future<void> setTranslationFile(String name, String path) async {
    _selectedTranslationFile = name;
    _selectedTranslationFilePath = path;
    _progress = 0.0;
    // _isTranslationComplete is now managed by TranslationStateManager
    _translationStateManager.setIsTranslationComplete(false);
    try {
      var result = await readFileWithEncoding(path);
      _sourceBlocks = _parseSubtitle(result['content']!);
      _translationSourceCachePath = await _writeTranslationCache(
            path,
            result['content'] ?? '',
          ) ??
          '';
      _processedBlocks = [];
      // _currentOutputIndex is derived from processedBlocks.length
      addLog("log_subtitle_selected", name);
    } catch (e) {
      final t = trans;
      addLog(
        "log_error",
        StringUtils.fillTemplate(
          t['log_file_read_failed'] ?? 'File could not be read: {error}',
          {'error': e.toString()},
        ),
      );
    }
    notifyListeners();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    _alwaysOnTop = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAlwaysOnTop, value);

    if (isDesktopPlatform) {
      try {
        await windowManager.setAlwaysOnTop(value);
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyMinimizeToTray, value);
    notifyListeners();
  }

  void clearTranslationFile() {
    _selectedTranslationFile = null;
    _selectedTranslationFilePath = '';
    _translationSourceCachePath = '';
    _sourceBlocks = [];
    _processedBlocks = [];
    _translationStateManager.setIsTranslationComplete(false);
    _progress = 0.0;
    addLog("log_subtitle_removed");
    notifyListeners();
  }

  /// Bulut servislerinden çoklu dosya içe aktarma

  void setTranslationConfig({String? lang, int? batch}) {
    if (lang != null) {
      _settingsManager.setTargetLanguage(lang);
    }
    if (batch != null) {
      _settingsManager.setBatchSize(batch);
    }
    notifyListeners();
  }

  void toggleSpeedMode(bool isFree) {
    _settingsManager.setIsFreeSlow(isFree);
    addLog("log_speed_mode_changed", isFree ? "Free" : "API Fast");
    _apiConfigManager.fetchModelsFromApi(
      isFreeSlow: isFree,
      addLog: (String key, [String? param]) => addLog(key, param),
    );
    notifyListeners();
  }

  void setWakelockEnabled(bool enabled) {
    // Avoid MissingPluginException on desktop platforms.
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    final Future<void> future =
        enabled ? WakelockPlus.enable() : WakelockPlus.disable();
    unawaited(future.catchError((_) {}));
  }

  Future<void> setKeepScreenOnPreference(bool enabled) async {
    _settingsManager.setKeepScreenOn(enabled);
    notifyListeners();
  }

  Future<void> setSleepPreventionPrompted(bool prompted) async {
    _settingsManager.setSleepPreventionPrompted(prompted);
    notifyListeners();
  }

  Future<void> setBatteryOptimizationPrompted(bool prompted) async {
    _settingsManager.setBatteryOptimizationPrompted(prompted);
    notifyListeners();
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    return _notificationManager.isIgnoringBatteryOptimizations();
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    return _notificationManager.requestIgnoreBatteryOptimizations();
  }

  Future<bool> openBatteryOptimizationSettings() async {
    return _notificationManager.openBatteryOptimizationSettings();
  }

  Future<bool> openAppDetailsSettings() async {
    return _notificationManager.openAppDetailsSettings();
  }

  void toggleScreenOn(bool val) {
    // Legacy toggle: keep for compatibility, but persist it.
    unawaited(setKeepScreenOnPreference(val));
    if (val) {
      addLog("log_screen_on");
    } else {
      addLog("log_screen_normal");
    }
  }

  void toggleSdhClear(bool val) {
    _settingsManager.setSdhClear(val);
    if (val) {
      _settingsManager.setSdhClearNoTrans(false);
    }
    notifyListeners();
  }

  void toggleSdhClearNoTrans(bool val) {
    _settingsManager.setSdhClearNoTrans(val);
    if (val) {
      _settingsManager.setSdhClear(false);
    }
    notifyListeners();
  }

  void toggleLiveView(bool val) {
    _uiStateManager.setLiveViewActive(val);
    notifyListeners();
  }

  // Proje yönetimi metodları artık ProjectManager'da
  // AppSettings sadece bridges olarak kullanılıyor

  Future<void> updateCurrentProject(bool completed) async {
    if (_selectedTranslationFilePath.isEmpty) {
      return;
    }
    String projectId = _selectedTranslationFilePath;
    String timestamp = DateTime.now().toString();
    TranslationProject newProj = TranslationProject(
      id: projectId,
      fileName: _selectedTranslationFile ?? "Bilinmeyen",
      filePath: _selectedTranslationFilePath,
      translationSourceCachePath: _translationSourceCachePath,
      targetLanguage: _targetLanguage,
      isCompleted: completed,
      totalLines: _sourceBlocks.length,
      translatedLines: _processedBlocks.length,
      lastUpdated: timestamp,
      sourceBlocks: _sourceBlocks,
      processedBlocks: _processedBlocks,
      usedModel: _selectedEngine == "gemini" ? _selectedModel : null,
    );
    await _projectManager.addOrUpdateProject(newProj);
    notifyListeners();
  }

  Future<void> addOrUpdateExternalProject(TranslationProject project) async {
    await _projectManager.addOrUpdateProject(project);
    notifyListeners();
  }

  void deleteProject(String id) {
    _projectManager.deleteProject(id);
    notifyListeners();
  }

  /// Geçerli projenin bloklarını (SRT içeriğini) gerekirse lazy olarak yükler.
  /// Bloklar zaten yüklüyse anında döner. Firestore'dan getirildiğinde
  /// ProjectManager notifyListeners() çağırır, UI otomatik güncellenir.
    Future<bool> loadProjectBlocksIfNeeded(String projectId,
        {bool forceCloudRefresh = false}) =>
      _projectManager.loadBlocksIfNeeded(projectId,
        forceCloudRefresh: forceCloudRefresh);

  void restoreProject(TranslationProject project) {
    _projectManager.restoreProject(project);
    notifyListeners();
  }

  void clearAllProjects() {
    _projectManager.clearAllProjects();
    _progress = 0.0; // Progress sıfırla
    notifyListeners();
  }

  int _batchFilesRevision = 0;
  int get batchFilesRevision => _batchFilesRevision;

  void _bumpBatchFilesRevision() {
    _batchFilesRevision++;
    notifyListeners();
  }

  /// Dosyayı AI Panel'deki batch çeviri listesine ekler.
  ///
  /// Varsayılan davranış, dosyayı listenin sonuna eklemektir.
  /// `insertAtTop=true` ise (örn. History -> Devam Et), dosya en üste taşınır.
  /// Aynı path zaten varsa önce silinip yeniden eklenir (duplicate oluşmaz).
  Future<void> addFileToBatchTranslation(
    String fileName,
    String filePath, {
    bool insertAtTop = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getStringList('batch_files') ?? [];

      String normalize(String p) =>
          p.trim().replaceAll('\\\\', '/').toLowerCase();

      final targetNorm = normalize(filePath);
      final kept = <String>[];
      for (final jsonStr in filesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
          final p = map['path']?.toString() ?? '';
          if (p.isNotEmpty && normalize(p) == targetNorm) {
            // Drop duplicates (we will re-insert once below).
            continue;
          }
          kept.add(jsonStr);
        } catch (_) {
          // Keep malformed entries; don't risk data loss.
          kept.add(jsonStr);
        }
      }

      final newEntry = jsonEncode({
        'name': fileName,
        'path': filePath,
      });

      // Yeni dosyayı JSON olarak ekle (üst/alt)
      final updated = <String>[];
      if (insertAtTop) {
        updated.add(newEntry);
        updated.addAll(kept);
      } else {
        updated.addAll(kept);
        updated.add(newEntry);
      }

      // SharedPreferences'a kaydet
      await prefs.setStringList('batch_files', updated);

      addLog('log_batch_file_added', jsonEncode({'name': fileName}));
      _bumpBatchFilesRevision();
    } catch (e) {
      debugPrint('Batch listesine dosya eklenirken hata: $e');
      addLog('log_batch_file_add_failed', jsonEncode({'error': e.toString()}));
    }
  }

  /// Batch listesinden dosyaları siler (path eşleşmesine göre).
  Future<void> removeFilesFromBatchTranslation(Iterable<String> paths) async {
    try {
      final toRemove = paths.where((p) => p.isNotEmpty).toSet();
      if (toRemove.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getStringList('batch_files') ?? [];
      if (filesJson.isEmpty) return;

      final kept = <String>[];
      for (final jsonStr in filesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
          final p = map['path']?.toString() ?? '';
          if (p.isNotEmpty && toRemove.contains(p)) {
            continue;
          }
          kept.add(jsonStr);
        } catch (_) {
          // If an entry is malformed, keep it (don't risk data loss).
          kept.add(jsonStr);
        }
      }

      if (kept.length == filesJson.length) return;
      await prefs.setStringList('batch_files', kept);
      _bumpBatchFilesRevision();
    } catch (e) {
      debugPrint('Batch listesinden dosya silinirken hata: $e');
      addLog(
          'log_batch_file_remove_failed', jsonEncode({'error': e.toString()}));
    }
  }

  Future<void> resumeProject(TranslationProject project) async {
    _selectedTranslationFile = project.fileName;
    _selectedTranslationFilePath = project.filePath;
    _translationSourceCachePath = project.translationSourceCachePath ?? '';
    if (_selectedTranslationFilePath.isNotEmpty &&
        !File(_selectedTranslationFilePath).existsSync() &&
        _translationSourceCachePath.isNotEmpty &&
        File(_translationSourceCachePath).existsSync()) {
      _selectedTranslationFilePath = _translationSourceCachePath;
    }
    _settingsManager.setTargetLanguage(project.targetLanguage);

    // Listeleri sıfırla ve UI'ı temizle
    _sourceBlocks = [];
    _processedBlocks = [];
    notifyListeners();

    // Büyük listeleri parça parça (chunked) yükle
    int chunkSize = 500;
    for (int i = 0; i < project.sourceBlocks.length; i += chunkSize) {
      int end = (i + chunkSize < project.sourceBlocks.length)
          ? i + chunkSize
          : project.sourceBlocks.length;
      _sourceBlocks.addAll(project.sourceBlocks.sublist(i, end));
      await Future.delayed(const Duration(milliseconds: 1));
    }

    for (int i = 0; i < project.processedBlocks.length; i += chunkSize) {
      int end = (i + chunkSize < project.processedBlocks.length)
          ? i + chunkSize
          : project.processedBlocks.length;
      _processedBlocks.addAll(project.processedBlocks.sublist(i, end));
      await Future.delayed(const Duration(milliseconds: 1));
    }

    // _currentOutputIndex is managed by TranslationStateManager and derived from processedBlocks.length
    _progress = _sourceBlocks.isNotEmpty
        ? _processedBlocks.length / _sourceBlocks.length
        : 0.0;
    _translationStateManager.setIsTranslationComplete(project.isCompleted);
    _translationStateManager.setIsTranslating(false);
    addLog("log_project_loaded",
        "${project.fileName} (%${(_progress * 100).toInt()})");
    notifyListeners();
  }

  Future<String?> _writeTranslationCache(
    String sourcePath,
    String content,
  ) async {
    if (content.trim().isEmpty) return null;
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory(
      '${dir.path}${Platform.pathSeparator}translation_cache',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final hash = md5.convert(utf8.encode(sourcePath)).toString();
    final file = File(
      '${cacheDir.path}${Platform.pathSeparator}$hash.srt',
    );
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  TranslationProject? getLatestIncompleteProject() {
    final latest = _projectManager.getLatestProject();
    if (latest == null || latest.isCompleted || latest.translatedLines <= 0) {
      return null;
    }
    return latest;
  }

  Future<void> downloadCompletedProject(TranslationProject project) async {
    _sourceBlocks = project.sourceBlocks;
    _processedBlocks = project.processedBlocks;
    _selectedTranslationFile = project.fileName;
    _selectedTranslationFilePath = project.filePath;
    _settingsManager.setTargetLanguage(project.targetLanguage);

    // Dosya adını dil kısaltması ile oluştur
    String nameWithoutExt =
        project.fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
    String nameStripped = StringUtils.stripLanguageSuffix(nameWithoutExt);
    String customFileName = "${nameStripped}_${project.targetLanguage}.srt";

    await saveResult(isEditorSave: false, customFileName: customFileName);
  }

  void cleanSdhInEditor() {
    _editorStateManager.cleanSdhInEditor();
  }

  String getLogsContent() =>
      _logService.buildLogsContent(_logs, trans, language);

  Future<void> copyLogsToClipboard() async {
    await _logService.copyLogsToClipboard(
      _logs,
      trans,
      language,
      (String key, [String? param]) => addLog(key, param),
    );
  }

  Future<void> saveLogsToFile() async {
    await _logService.saveLogsToFile(
      _logs,
      trans,
      language,
      (String key, [String? param]) => addLog(key, param),
    );
  }

  Future<void> shareLogs() async {
    await _logService.shareLogs(
      _logs,
      trans,
      language,
      (String key, [String? param]) => addLog(key, param),
    );
  }

  String formatLogLine(LogEntry log, {bool includeTime = true}) {
    return _logService.formatLogLine(log, trans, language,
        includeTime: includeTime);
  }

  Future<void> stopProcess() async {
    _translationStateManager.setIsTranslating(false);
    _translationStateManager.setIsTranslationComplete(false);
    addLog("log_process_stopped");
    _translationStartTime = null;
    cancelNotification();
    if (_sourceBlocks.isNotEmpty) {
      updateCurrentProject(false);
    }
    notifyListeners();
  }

  void setEditorFile(String name, String content, {String encoding = "UTF-8"}) {
    _editorStateManager.setEditorFile(name, content, encoding: encoding);
  }

  void clearEditorFile() {
    _editorStateManager.clearEditorFile();
  }

  Future<void> loadBlocksIntoEditorAsync(
    String name,
    List<SubtitleBlock> blocks, {
    int chunkSize = 250,
  }) async {
    await _editorStateManager.loadBlocksIntoEditorAsync(name, blocks,
        chunkSize: chunkSize);
  }

  Future<void> openProjectInEditorAsync(TranslationProject project) async {
    await loadBlocksIntoEditorAsync(project.fileName, project.processedBlocks);
  }

  Future<void> openCurrentTranslationInEditorAsync() async {
    if (_processedBlocks.isEmpty) return;
    String name = _selectedTranslationFile ?? "Cevrilen_Altyazi.srt";
    await loadBlocksIntoEditorAsync(name, _processedBlocks);
  }

  Future<Map<String, String>> readFileWithEncoding(String path,
      {int? limit}) async {
    final file = File(path);
    List<int> bytes;
    if (limit != null) {
      // Önizleme için sadece belirli bir miktarını oku (örn: 10KB)
      final stream = file.openRead(0, limit);
      final BytesBuilder builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } else {
      bytes = await file.readAsBytes();
    }

    // Arka planda (isolate) çözümleme yap
    return compute(decodeFileContent, bytes);
  }

  Future<List<int>> readFileBytesRange(
    String path, {
    required int start,
    required int length,
  }) async {
    if (start < 0) start = 0;
    if (length <= 0) return <int>[];

    final file = File(path);
    final int totalBytes = await file.length();
    if (start >= totalBytes) return <int>[];

    final int endExclusive =
        (start + length) > totalBytes ? totalBytes : (start + length);

    final stream = file.openRead(start, endExclusive);
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<List<SubtitleBlock>> loadSubtitleBlocksForPreview(String path) async {
    final result = await readFileWithEncoding(path);
    return _parseSubtitle(result['content'] ?? '');
  }

  List<SubtitleBlock> _parseSubtitle(String content) {
    return SubtitleParser.parseSrt(content);
  }

  // Public wrapper: expose subtitle parsing to other widgets/controllers
  List<SubtitleBlock> parseSubtitle(String content) => _parseSubtitle(content);

  void updateBlockText(SubtitleBlock block, String t) {
    _editorStateManager.updateBlockText(block, t);
  }

  void updateBlockTimecode(SubtitleBlock block, String newTimecode) {
    _editorStateManager.updateBlockTimecode(block, newTimecode);
  }

  void shiftBlockTimecode(SubtitleBlock block, int offsetMs) {
    _editorStateManager.shiftBlockTimecode(block, offsetMs);
  }

  void shiftAllTimecodes(int offsetMs) {
    debugPrint(
      '[ShiftAll] AppSettings.shiftAllTimecodes offsetMs=$offsetMs searchQuery="${_editorStateManager.searchQuery}" blocks=${_editorStateManager.editorBlocks.length}',
    );
    _editorStateManager.shiftAllTimecodes(offsetMs);
  }

  void deleteBlock(SubtitleBlock block) {
    _editorStateManager.deleteBlock(block);
  }

  void updateSearchQuery(String q) {
    _editorStateManager.updateSearchQuery(q);
  }

  void toggleCaseSensitivity(bool v) {
    _editorStateManager.toggleCaseSensitivity(v);
  }

  void toggleRegexSearch(bool v) {
    _editorStateManager.toggleRegexSearch(v);
  }

  int replaceSingleInEditor(String replacement) {
    return _editorStateManager.replaceSingleInEditor(replacement);
  }

  int replaceAllInEditor(String replacement) {
    return _editorStateManager.replaceAllInEditor(replacement);
  }

  void nextSearchMatch() {
    _editorStateManager.nextSearchMatch();
  }

  void prevSearchMatch() {
    _editorStateManager.prevSearchMatch();
  }

  void undo() {
    _editorStateManager.undo();
  }

  void redo() {
    _editorStateManager.redo();
  }

  String getDefaultSaveFileName({required bool isEditorSave}) {
    String defaultFileName = "output.srt";
    if (isEditorSave && selectedEditorFile != null) {
      final fileName =
          selectedEditorFile!.split('/').last.split('\\').last.trim();
      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');

      final noGenerated =
          StringUtils.stripGeneratedPrefixAndHash(nameWithoutExt);
      final noEdited = noGenerated.replaceFirst(
          RegExp(r'_edited$', caseSensitive: false), '');
          
      final base = noEdited.trim().isEmpty ? 'output' : noEdited.trim();

      // We always generate SRT content currently.
      defaultFileName = "${base}_edited.srt";
    } else if (!isEditorSave && _selectedTranslationFilePath.isNotEmpty) {
      String fileName =
          _selectedTranslationFilePath.split('/').last.split('\\').last;
      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
      final noGenerated =
          StringUtils.stripGeneratedPrefixAndHash(nameWithoutExt);
      final nameStripped = StringUtils.stripLanguageSuffix(noGenerated);
      final base = nameStripped.trim().isEmpty ? 'output' : nameStripped.trim();
      if (!lastProcessWasTranslation) {
        defaultFileName = "${base}_cleaned_sdh.srt";
      } else {
        defaultFileName = "${base}_$_targetLanguage.srt";
      }
    }
    return defaultFileName;
  }

  Future<void> saveResult(
      {required bool isEditorSave,
      String? dialogTitle,
      String? customFileName}) async {
    final String content = _buildSrtContent(isEditorSave: isEditorSave);

    String defaultFileName =
        customFileName ?? getDefaultSaveFileName(isEditorSave: isEditorSave);

    final bytes = Uint8List.fromList(utf8.encode(content));
    final isAndroidIos = Platform.isAndroid || Platform.isIOS;
    String? f = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle ?? (trans["dialog_save"] ?? 'Kaydet'),
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      bytes: isAndroidIos ? bytes : null,
    );
    if (f != null) {
      if (!isAndroidIos) {
        await File(f).writeAsBytes(bytes, flush: true);
      }
      addLog("log_saved", isAndroidIos ? defaultFileName : f);
      if (isEditorSave) {
        _editorStateManager.markSaved();
      }
    }
  }

  Future<void> checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    final bool isOffline = connectivityResult.contains(ConnectivityResult.none);
    if (_isOffline && !isOffline) {
      addLog("log_connection_restored");
    }
    _isOffline = isOffline;
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final sw = Stopwatch()..start();
    debugPrint('⏱️ AppSettings._loadPreferences START');
    final prefs = await SharedPreferences.getInstance();
    debugPrint('⏱️ [${sw.elapsedMilliseconds}ms] _loadPreferences: SharedPreferences');

    // Load all manager states
    await Future.wait<void>([
      _projectManager.loadProjectsFromPrefs(),
      // _themeManager.loadThemeFromPrefs(), // Removed: ThemeManager loads in constructor
      _settingsManager.loadSettingsFromPrefs(),
      _uiStateManager.loadUIStateFromPrefs(),
      _translationStateManager.resetTranslationState(),
      _apiConfigManager.loadAPIConfigFromPrefs(),
      _cloudStateManager.loadCloudStateFromPrefs(),
    ]);
    debugPrint('⏱️ [${sw.elapsedMilliseconds}ms] _loadPreferences: Future.wait managers');

    // Load legacy cloud connectivity states
    _cloudStateManager
        .setIsGDriveConnected(prefs.getBool('is_gdrive_connected') ?? false);
    _cloudStateManager
        .setIsDropboxConnected(prefs.getBool('is_dropbox_connected') ?? false);
    _cloudStateManager
        .setIsYandexConnected(prefs.getBool('is_yandex_connected') ?? false);

    // Load UI toggles
    _hideInfoButtons = prefs.getBool('hide_info_buttons') ?? false;
    _hideBatchTranslationInfo = prefs.getBool('hide_batch_info') ?? false;
    _confirmDeletes = prefs.getBool('confirm_deletes') ?? true;
    _showCrashWarnings = prefs.getBool('show_crash_warnings') ?? true;
    _alwaysOnTop = prefs.getBool(_prefKeyAlwaysOnTop) ?? false;
    _minimizeToTray = prefs.getBool(_prefKeyMinimizeToTray) ?? true;

    if (isDesktopPlatform) {
      try {
        await windowManager.setAlwaysOnTop(_alwaysOnTop);
      } catch (_) {}
    }
    debugPrint('⏱️ [${sw.elapsedMilliseconds}ms] _loadPreferences: pre-prefsLoaded');

    // Sessizce Google oturumunu geri yükle:
    // • Pref true ise zaten restore etmeliyiz.
    // • Pref false olsa bile Firebase'de hâlâ Google kullanıcısı olabilir
    //   (pref, race-condition ile ezilmiş olabilir).
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final hasGoogleFirebase = firebaseUser != null &&
        !firebaseUser.isAnonymous &&
        firebaseUser.providerData.any((p) => p.providerId == 'google.com');

    // [OPTIMİZASYON] UI'ın hemen açılması için prefsLoaded'i true yapıp bildiriyoruz.
    // Google oturum geri yükleme ve Firestore sync arka planda yapılacak.
    _prefsLoaded = true;
    notifyListeners();
    debugPrint('⏱️ [${sw.elapsedMilliseconds}ms] _loadPreferences: prefsLoaded=true, UI should render now');

    // Google oturumunu arka planda geri yükle (UI'ı bloklamaz).
    if (_cloudStateManager.isGDriveConnected || hasGoogleFirebase) {
      try {
        await _cloudStorageService.restoreGoogleSession();
      } catch (_) {}
    }

    // Uygulama başlangıcında kullanıcı zaten giriş yapmışsa Firestore geçmiş
    // senkronizasyonunu hemen başlat (Windows dahil tüm platformlar için).
    final startupUser = FirebaseAuth.instance.currentUser;
    if (startupUser != null && !startupUser.isAnonymous) {
      _projectManager.startFirestoreSync();
    }

    // Prefs yüklendikten sonra auth durumunu bir kez daha senkronla ki
    // login yoksa cloud-only history hemen temizlensin.
    unawaited(_syncGoogleConnectionStateFromAuth());

    // Single-mode: models are fetched using developer Remote Config key.
    // Best-effort: if key is not configured, this will no-op.
    _fetchModelsFromApi();
    checkConnectivity();
  }
}
