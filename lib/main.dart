import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'utils/single_instance_win.dart' as single_instance;
import 'app_settings.dart';
import 'managers/theme_manager.dart';
import 'app_theme.dart';
import 'controllers/translation_controller.dart';
import 'tabs/translation_tab.dart';
import 'tabs/editor_tab.dart';
import 'settings.dart';
import 'widgets/adaptive_text.dart';
import 'translations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'cloud_oauth_config.dart';

const String _kPrefAppInForeground = 'app_in_foreground';
const String _kPrefCrashForcePrompt = 'crash_report_force_prompt';
const String _kPrefWindowAlwaysOnTop = 'window_always_on_top';

const double _kDesktopMinWidth = 1120;
const double _kDesktopMinHeight = 720;

const MethodChannel _desktopWindowChannel =
    MethodChannel('com.deepnode.altyaziceviri/window');

String _normalizeUiLanguageCode(String rawCode) {
  final code = rawCode.trim().toUpperCase();
  if (code == 'HI') return 'IN';
  if (code == 'ZH') return 'CN';
  return code;
}

String _resolveStartupLanguageCode(SharedPreferences prefs) {
  final saved = _normalizeUiLanguageCode(prefs.getString('language') ?? '');
  if (saved.isNotEmpty && Translations.supportedUiLanguages.contains(saved)) {
    return saved;
  }

  final system =
      _normalizeUiLanguageCode(WidgetsBinding.instance.platformDispatcher.locale.languageCode);
  if (Translations.supportedUiLanguages.contains(system)) {
    return system;
  }

  return 'EN';
}

String _resolveStartupAppTitle(SharedPreferences prefs) {
  final lang = _resolveStartupLanguageCode(prefs);
  final trans = Translations.getWithGlobalFallback(lang);
  return Translations.resolveAppName(lang, trans: trans);
}

Rect? _rectFromVirtualScreenMap(Map<dynamic, dynamic>? map) {
  if (map == null) return null;
  double? readDouble(String key) {
    final v = map[key];
    if (v is num) return v.toDouble();
    return null;
  }

  final left = readDouble('left');
  final top = readDouble('top');
  final width = readDouble('width');
  final height = readDouble('height');
  if (left == null || top == null || width == null || height == null) {
    return null;
  }
  if (width <= 0 || height <= 0) return null;
  return Rect.fromLTWH(left, top, width, height);
}

Future<bool> _tryRestoreGoogleFirebaseSession(FirebaseAuth auth) async {
  if (kIsWeb) return false;
  if (auth.currentUser != null) return true;

  try {
    // On desktop, google_sign_in_dartio requires registration per-process.
    // If we don't register before signInSilently(), the cached session won't
    // be discovered and we'll incorrectly fall back to anonymous.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        await GoogleSignInDart.register(clientId: CloudOAuthConfig.googleOauthClientId);
      } catch (e) {
        debugPrint('GoogleSignInDart register failed (startup restore): $e');
      }
    }

    // Use the same scopes as the Drive integration so the cached account (if
    // any) matches what the user previously authorized.
    final googleSignIn = GoogleSignIn(
      scopes: const [
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/drive.appdata',
      ],
    );

    final account = await googleSignIn.signInSilently();
    if (account == null) return false;

    final googleAuth = await account.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;
    final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
    final hasIdToken = idToken != null && idToken.isNotEmpty;
    if (!hasAccessToken && !hasIdToken) return false;

    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );
    await auth.signInWithCredential(credential);
    return auth.currentUser != null;
  } catch (e) {
    debugPrint('Google silent restore failed: $e');
    return false;
  }
}

Future<Rect?> _getDesktopVirtualScreenBounds() async {
  if (!Platform.isWindows) return null;
  try {
    final raw = await _desktopWindowChannel
        .invokeMapMethod<dynamic, dynamic>('getVirtualScreenBounds');
    return _rectFromVirtualScreenMap(raw);
  } catch (_) {
    return null;
  }
}

Offset _centerPositionWithin(Rect bounds, Size windowSize) {
  final x = bounds.left + ((bounds.width - windowSize.width) / 2.0);
  final y = bounds.top + ((bounds.height - windowSize.height) / 2.0);
  return Offset(x, y);
}

bool _isWindowRectLikelyVisibleOn(Rect virtualBounds, Rect windowRect) {
  // Require some overlap so at least a portion of the title bar is reachable.
  // Using a small deflate makes this less sensitive to exact edges.
  final safe = virtualBounds.deflate(24);
  if (safe.width <= 0 || safe.height <= 0) return virtualBounds.overlaps(windowRect);
  return safe.overlaps(windowRect);
}

class _ForegroundFlagObserver extends WidgetsBindingObserver {
  _ForegroundFlagObserver(this._prefs);

  final SharedPreferences _prefs;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Treat "resumed" as foreground. Other states mean we're not actively in the foreground.
    if (state == AppLifecycleState.resumed) {
      // Don't await; this runs on lifecycle callbacks.
      unawaited(_prefs.setBool(_kPrefAppInForeground, true));
      return;
    }

    // `hidden` exists on some platforms; keep it grouped with background-ish states.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_prefs.setBool(_kPrefAppInForeground, false));
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows: tek örnek kontrolü.
  // Not: Debug/profile modlarında hot-restart ve geliştirme akışını bozabildiği
  // için yalnızca release build'de aktif.
  if (Platform.isWindows && kReleaseMode) {
    if (!single_instance.ensureSingleInstance()) {
      exit(0);
    }
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check: blocks emulator/automation from calling sensitive Cloud Functions.
  // - Android: Play Integrity
  // - iOS: DeviceCheck
  // Debug builds use debug providers (register the debug token in Firebase Console).
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
  } catch (e) {
    debugPrint('Firebase App Check failed: $e');
  }

  final firebaseApp = Firebase.app();
  final auth = FirebaseAuth.instanceFor(app: firebaseApp);

  if (!kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    final desktopClientId = CloudOAuthConfig.googleOauthClientId.trim();
    if (desktopClientId.isNotEmpty) {
      try {
        await GoogleSignInDart.register(clientId: desktopClientId);
      } catch (e) {
        debugPrint('GoogleSignInDart register failed: $e');
      }
    }
  }

  // Firebase Auth session'ını kontrol et (app restart sonrasında restore ediliyor mu?)
  final currentUser = auth.currentUser;
  if (currentUser != null) {
    debugPrint(
        '✅ Firebase Auth session restored: ${currentUser.uid} (${currentUser.email})');
  } else {
    debugPrint('⚠️ Firebase Auth session not found - anonymous or new user');
  }

  // Emülatör Bağlantısı (Global Ayar)
  // NOT: Gerçek verileri görmek için bu bloğu yorum satırına aldık.
  // if (kDebugMode) {
  //   try {
  //     // Android Emulator için '10.0.2.2', iOS Simülatör ve diğerleri için 'localhost'
  //     final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
  //
  //     FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  //     FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  //
  //     debugPrint('🚀 Firebase Emulator bağlandı: $host (Functions: 5001, Firestore: 8080)');
  //   } catch (e) {
  //     debugPrint('⚠️ Emulator bağlantı uyarısı: $e');
  //   }
  // }

  if (Platform.isAndroid || Platform.isIOS || kIsWeb) {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint("Remote Config failed: $e");
    }
  }

  try {
    // Give Firebase Auth a brief chance to restore persisted sessions on desktop
    // before we force an anonymous user.
    User? restoredUser = auth.currentUser;
    if (restoredUser == null) {
      try {
        restoredUser = await auth
            .authStateChanges()
            .where((u) => u != null)
            .first
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ignore timeouts/stream errors; we'll fall back to anonymous.
      }
    }

    if (restoredUser == null) {
      // If we don't have a Firebase user yet, try restoring a cached Google
      // session (best-effort). Only then fall back to anonymous.
      final restoredGoogle = await _tryRestoreGoogleFirebaseSession(auth);
      restoredUser = auth.currentUser;

      if (restoredUser == null && !restoredGoogle) {
        // Oturum yoksa anonim giriş yap
        await auth.signInAnonymously();
        restoredUser = auth.currentUser;
      }
    }

    if (restoredUser != null) {
      // Oturum varsa, token'ı tazelemeyi dene (Opsiyonel güvenlik önlemi)
      try {
        await auth.currentUser?.reload();
      } on FirebaseAuthException catch (e) {
        // Don't sign the user out on transient network errors.
        // Only reset the session for clearly-invalid/disabled users.
        const invalidCodes = <String>{
          'user-disabled',
          'user-not-found',
          'invalid-user-token',
          'user-token-expired',
          'invalid-credential',
        };

        if (invalidCodes.contains(e.code)) {
          debugPrint("⚠️ Oturum geçersiz (${
              e.code
            }), temizleniyor: $e");
          await auth.signOut();
          await auth.signInAnonymously();
        } else {
          debugPrint('⚠️ Oturum yenileme başarısız (${e.code}); oturum korunuyor: $e');
        }
      } catch (e) {
        // Unknown reload error: keep existing session to avoid logging the user out.
        debugPrint('⚠️ Oturum yenileme beklenmeyen hata; oturum korunuyor: $e');
      }
    }
  } catch (e) {
    debugPrint("Firebase Auth failed: $e");
  }

  final prefs = await SharedPreferences.getInstance();

  // Persist crash/Flutter framework errors to a file so we can inspect the full
  // overflow/assert output even if the device disconnects.
  Future<void> appendFlutterError(String header, Object error,
      [StackTrace? stack]) async {
    final now = DateTime.now().toIso8601String();
    final lang = prefs.getString('app_language') ?? 'TR';
    final String stackText = stack == null ? '' : stack.toString();
    final String payload =
        '\n[$now] $header\napp_language=$lang\n$error\n$stackText\n--------------------------------\n';
    try {
      final file = await AppSettings.getCrashLogFile();
      await file.writeAsString(payload, mode: FileMode.append, flush: true);
    } catch (_) {
      // Ignore logging failures.
    }
  }

  // If the previous run ended while the app was still considered foreground,
  // it likely terminated unexpectedly (native crash, SIGSEGV, etc.) and would
  // NOT be captured by FlutterError/PlatformDispatcher.
  // In that case, append a marker entry and force the crash report prompt.
  final wasForeground = prefs.getBool(_kPrefAppInForeground) ?? false;
  if (wasForeground) {
    // Force prompt even if crash_log.txt size matches a previously prompted log.
    await prefs.setBool(_kPrefCrashForcePrompt, true);
    await prefs.remove('crash_report_prompted_size');
    await appendFlutterError(
      'Previous run ended unexpectedly',
      'Detected app_in_foreground=true at startup (likely native crash/kill).',
    );
  }

  // Reset startup state and install lifecycle observer.
  await prefs.setBool(_kPrefAppInForeground, false);
  WidgetsBinding.instance.addObserver(_ForegroundFlagObserver(prefs));

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    unawaited(
      appendFlutterError(
          'FlutterError.onError', details.toString(), details.stack),
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(appendFlutterError('PlatformDispatcher.onError', error, stack));
    return false;
  };

    final double savedScale = (prefs.getDouble('ui_scale') ?? 1.0).clamp(0.75, 1.25);
    final double scaledMinW = (_kDesktopMinWidth * savedScale).roundToDouble();
    final double scaledMinH = (_kDesktopMinHeight * savedScale).roundToDouble();

    final double width =
      (prefs.getDouble('window_width') ?? 1280).clamp(scaledMinW, double.infinity);
    final double height =
      (prefs.getDouble('window_height') ?? 720).clamp(scaledMinH, double.infinity);
  final double? x = prefs.getDouble('window_x');
  final double? y = prefs.getDouble('window_y');
  final bool isMaximized = prefs.getBool('window_maximized') ?? false;
  final bool isAlwaysOnTop = prefs.getBool(_kPrefWindowAlwaysOnTop) ?? false;
  final String startupAppTitle = _resolveStartupAppTitle(prefs);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = WindowOptions(
      size: Size(width, height),
      center: x == null,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(
        Size(scaledMinW, scaledMinH),
      );
      await windowManager.setPreventClose(true);
      await windowManager.setTitle(startupAppTitle);
      await windowManager.setAlwaysOnTop(isAlwaysOnTop);
      if (isMaximized) {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.maximize();
      } else {
        // If a saved window position is off-screen (monitor layout changes),
        // the app will look like it "won't open" while still running.
        Offset? target;
        if (x != null && y != null) {
          final virtualBounds = await _getDesktopVirtualScreenBounds();
          if (virtualBounds != null) {
            final rect = Rect.fromLTWH(x, y, width, height);
            if (_isWindowRectLikelyVisibleOn(virtualBounds, rect)) {
              target = Offset(x, y);
            } else {
              target = _centerPositionWithin(virtualBounds, Size(width, height));
            }
          } else {
            // Fallback: still attempt the saved position.
            target = Offset(x, y);
          }
        }

        if (target != null) {
          await windowManager.setPosition(target);
        }
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeManager()),
        ChangeNotifierProvider(create: (_) => TranslationController()),
      ],
      child: ChangeNotifierProvider(
        create: (context) => AppSettings(
          themeManager: context.read<ThemeManager>(),
        ),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener, TrayListener {
  Timer? _saveTimer;
  Timer? _startupSplashTimer;
  Timer? _trayStartupRetryTimer;
  Timer? _startupVisibilityGuardTimer;
  bool _forceStartupSplash = false;
  String? _lastWindowTitle;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _trayReady = false;
  bool _isQuitRequested = false;
  bool _isShuttingDown = false;
  bool _userHiddenToTray = false;
  bool _desktopUpdatePromptShown = false;
  AppSettings? _traySettingsListenerRef;
  String? _lastTrayTooltip;
  String? _lastTrayMenuSignature;

  void _activateStartupVisibilityGuard() {
    _startupVisibilityGuardTimer?.cancel();
    _startupVisibilityGuardTimer = Timer(const Duration(seconds: 10), () {
      _startupVisibilityGuardTimer = null;
    });
  }

  void _deactivateStartupVisibilityGuard() {
    _startupVisibilityGuardTimer?.cancel();
    _startupVisibilityGuardTimer = null;
  }

  void _syncDesktopWindowTitle(String nextTitle) {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    final normalized = nextTitle.trim();
    if (normalized.isEmpty || normalized == _lastWindowTitle) {
      return;
    }
    _lastWindowTitle = normalized;
    unawaited(windowManager.setTitle(normalized));
  }

  String _normalizeDisplayFileName(String rawName) {
    final leaf = rawName.split(RegExp(r'[\\/]')).last.trim();
    if (leaf.isEmpty) return '';
    return leaf.replaceFirst(
      RegExp(r'_[a-f0-9]{32}(?=\.[^.]+$)', caseSensitive: false),
      '',
    );
  }

  String _resolveWindowTitle({
    required String appTitle,
    required AppSettings settings,
    required TranslationController controller,
  }) {
    final editorFile = _normalizeDisplayFileName(settings.selectedEditorFile ?? '');
    if (editorFile.isNotEmpty) {
      return '$editorFile — $appTitle';
    }

    final isTranslating = controller.status == TranslationStatus.running ||
        controller.status == TranslationStatus.paused;
    if (isTranslating) {
      final activeTranslationFile =
          _normalizeDisplayFileName(controller.currentFileName ?? '');
      if (activeTranslationFile.isNotEmpty) {
        return '$activeTranslationFile — $appTitle';
      }
    }

    return appTitle;
  }

  String _trayTextForLanguage(String language, String key) {
    const labels = {
      'EN': {
        'restore': 'Restore',
        'exit': 'Exit',
        'translating_progress': 'Translating: {percent}%'
      },
      'TR': {
        'restore': 'Geri getir',
        'exit': 'Çıkış',
        'translating_progress': 'Çeviri: %{percent}'
      },
      'FR': {
        'restore': 'Restaurer',
        'exit': 'Quitter',
        'translating_progress': 'Traduction : {percent}%'
      },
      'DE': {
        'restore': 'Wiederherstellen',
        'exit': 'Beenden',
        'translating_progress': 'Übersetzung: {percent}%'
      },
      'IT': {
        'restore': 'Ripristina',
        'exit': 'Esci',
        'translating_progress': 'Traduzione: {percent}%'
      },
      'ES': {
        'restore': 'Restaurar',
        'exit': 'Salir',
        'translating_progress': 'Traducción: {percent}%'
      },
      'PT': {
        'restore': 'Restaurar',
        'exit': 'Sair',
        'translating_progress': 'Tradução: {percent}%'
      },
      'RU': {
        'restore': 'Восстановить',
        'exit': 'Выход',
        'translating_progress': 'Перевод: {percent}%'
      },
      'EL': {
        'restore': 'Επαναφορά',
        'exit': 'Έξοδος',
        'translating_progress': 'Μετάφραση: {percent}%'
      },
      'AR': {
        'restore': 'استعادة',
        'exit': 'خروج',
        'translating_progress': 'الترجمة: {percent}%'
      },
      'IN': {
        'restore': 'पुनर्स्थापित करें',
        'exit': 'बाहर निकलें',
        'translating_progress': 'अनुवाद: {percent}%'
      },
      'ID': {
        'restore': 'Pulihkan',
        'exit': 'Keluar',
        'translating_progress': 'Menerjemahkan: {percent}%'
      },
      'CN': {
        'restore': '还原',
        'exit': '退出',
        'translating_progress': '翻译：{percent}%'
      },
      'JA': {
        'restore': '復元',
        'exit': '終了',
        'translating_progress': '翻訳: {percent}%'
      },
      'KO': {
        'restore': '복원',
        'exit': '종료',
        'translating_progress': '번역: {percent}%'
      },
      'NL': {
        'restore': 'Herstellen',
        'exit': 'Afsluiten',
        'translating_progress': 'Vertalen: {percent}%'
      },
      'SV': {
        'restore': 'Återställ',
        'exit': 'Avsluta',
        'translating_progress': 'Översätter: {percent}%'
      },
      'PL': {
        'restore': 'Przywróć',
        'exit': 'Zamknij',
        'translating_progress': 'Tłumaczenie: {percent}%'
      },
      'TH': {
        'restore': 'เรียกคืน',
        'exit': 'ออก',
        'translating_progress': 'กำลังแปล: {percent}%'
      },
      'VI': {
        'restore': 'Khôi phục',
        'exit': 'Thoát',
        'translating_progress': 'Đang dịch: {percent}%'
      },
      'HE': {
        'restore': 'שחזר',
        'exit': 'יצא',
        'translating_progress': 'מתרגם: {percent}%'
      },
      'FA': {
        'restore': 'بازیابی',
        'exit': 'خروج',
        'translating_progress': 'در حال ترجمه: {percent}%'
      },
      'TA': {
        'restore': 'மீட்டமை',
        'exit': 'வெளியேறு',
        'translating_progress': 'மொழிபெயர்க்கப்படுகிறது: {percent}%'
      },
      'TE': {
        'restore': 'పునరుద్ధరించు',
        'exit': 'నిష్క్రమించు',
        'translating_progress': 'అనువదిస్తోంది: {percent}%'
      },
      'ML': {
        'restore': 'പുനഃസ്ഥാപിക്കുക',
        'exit': 'പുറത്തുകടക്കുക',
        'translating_progress': 'പരിഭാഷപ്പെടുത്തുന്നു: {percent}%'
      },
      'KN': {
        'restore': 'ಮರುಸ್ಥಾಪಿಸಿ',
        'exit': 'ನಿರ್ಗಮಿಸಿ',
        'translating_progress': 'ಅನುವಾದಿಸುತ್ತಿದೆ: {percent}%'
      },
      'PA': {
        'restore': 'ਬਹਾਲ ਕਰੋ',
        'exit': 'ਬਾਹਰ ਨਿਕਲੋ',
        'translating_progress': 'ਅਨੁਵਾਦ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ: {percent}%'
      },
      'GU': {
        'restore': 'પુનઃસ્થાપિત કરો',
        'exit': 'બહાર નીકળો',
        'translating_progress': 'અનુવાદ કરી રહ્યા છીએ: {percent}%'
      },
      'MR': {
        'restore': 'पुन्हा स्थापित करा',
        'exit': 'बाहेर पडा',
        'translating_progress': 'भाषांतर करत आहे: {percent}%'
      },
    };
    final map = labels[language] ?? labels['EN']!;
    return map[key] ?? labels['EN']![key] ?? key;
  }

  String _translationProgressLabel(AppSettings settings, int percent) {
    return _trayTextForLanguage(settings.language, 'translating_progress')
        .replaceAll('{percent}', '$percent');
  }

  Future<void> _syncTrayProgress(AppSettings settings) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    if (_isShuttingDown || !mounted) return;
    if (!_trayReady) return;

    final appName = Translations.resolveAppName(
      settings.language,
      trans: settings.trans,
    );
    final isTranslating = settings.isTranslating;
    final percent = (settings.progress * 100).clamp(0, 100).round();
    final progressLabel = _translationProgressLabel(settings, percent);
    final tooltip = isTranslating ? '$appName • $progressLabel' : appName;

    final menuSignature =
        '${settings.language}|$isTranslating|$percent|${_trayTextForLanguage(settings.language, 'restore')}|${_trayTextForLanguage(settings.language, 'exit')}';

    if (tooltip != _lastTrayTooltip) {
      try {
        await trayManager.setToolTip(tooltip);
      } catch (_) {
        return;
      }
      _lastTrayTooltip = tooltip;
    }

    if (menuSignature != _lastTrayMenuSignature) {
      final items = <MenuItem>[];
      if (isTranslating) {
        items.add(MenuItem(key: 'progress', label: progressLabel));
        items.add(MenuItem.separator());
      }
      items.add(
        MenuItem(
          key: 'restore',
          label: _trayTextForLanguage(settings.language, 'restore'),
        ),
      );
      items.add(MenuItem.separator());
      items.add(
        MenuItem(
          key: 'exit',
          label: _trayTextForLanguage(settings.language, 'exit'),
        ),
      );

      try {
        await trayManager.setContextMenu(Menu(items: items));
      } catch (_) {
        return;
      }
      _lastTrayMenuSignature = menuSignature;
    }
  }

  void _onTraySourceSettingsChanged() {
    final settings = _traySettingsListenerRef;
    if (settings == null) return;
    unawaited(_syncTrayProgress(settings));
  }

  Future<void> _checkDesktopUpdateOnStartup(AppSettings settings) async {
    if (!Platform.isWindows || _desktopUpdatePromptShown) return;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _isShuttingDown || _desktopUpdatePromptShown) return;

    final update = await settings.checkDesktopUpdateFromGoogleDrive(
      minimumCheckInterval: Duration.zero,
    );
    if (update == null || !mounted || _isShuttingDown) return;

    _desktopUpdatePromptShown = true;
    if (!context.mounted) return;

    final trans = settings.trans;
    final openLabel = trans['update_action'] ?? 'Update';
    final laterLabel = trans['update_later'] ?? 'Later';
    final newVersionLabel = trans['update_new_version'] ?? 'New version';
    final currentVersionLabel =
      trans['update_current_version'] ?? 'Current version';

    final openNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans['update_title'] ?? 'Yeni sürüm bulundu'),
        content: Text(
          '$newVersionLabel: ${update.latestVersion}\n'
          '$currentVersionLabel: ${update.currentVersion}\n\n'
          '${update.fileName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(laterLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(openLabel),
          ),
        ],
      ),
    );

    if (openNow != true) return;

    final folderTarget =
        update.folderUrl == null ? null : Uri.tryParse(update.folderUrl!);
    if (folderTarget != null) {
      await launchUrl(folderTarget, mode: LaunchMode.externalApplication);
      return;
    }

    final fallback = Uri.tryParse(update.downloadUrl);
    if (fallback != null) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  void _ensureTrayReadyOnStartup({int attempt = 0}) {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    if (!mounted || _isShuttingDown || _trayReady) return;

    unawaited(() async {
      final initialized = await _initSystemTray();
      if (!mounted || _isShuttingDown || _trayReady || initialized) {
        return;
      }
      if (attempt >= 6) return;
      _trayStartupRetryTimer?.cancel();
      _trayStartupRetryTimer =
          Timer(Duration(milliseconds: 500 * (attempt + 1)), () {
        _ensureTrayReadyOnStartup(attempt: attempt + 1);
      });
    }());
  }

  @override
  void initState() {
    super.initState();

    // On mobile, prefs can load very fast; ensure the full-screen splash is
    // visible for at least a short moment (hybrid splash strategy).
    if (Platform.isAndroid || Platform.isIOS) {
      _forceStartupSplash = true;
      _startupSplashTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _forceStartupSplash = false);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppSettings>();
      final controller = context.read<TranslationController>();
      controller.attachSettings(settings);
      final isDesktopPlatform =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      settings.onGoogleSignInSuccess = isDesktopPlatform
        ? null
        : controller.billingService.transferDeviceCreditsToGoogleAccount;
      _traySettingsListenerRef = settings;
      settings.addListener(_onTraySourceSettingsChanged);
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        unawaited(_syncTrayProgress(settings));
        _ensureTrayReadyOnStartup();
        unawaited(_checkDesktopUpdateOnStartup(settings));
      }
    });

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _activateStartupVisibilityGuard();
      _ensureTrayReadyOnStartup();
      unawaited(_ensureDesktopWindowVisibleOnStartup());
    }
  }

  @override
  void dispose() {
    _traySettingsListenerRef?.removeListener(_onTraySourceSettingsChanged);
    _traySettingsListenerRef = null;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    _saveTimer?.cancel();
    _startupSplashTimer?.cancel();
    _trayStartupRetryTimer?.cancel();
    _startupVisibilityGuardTimer?.cancel();
    super.dispose();
  }

  @override
  void onWindowResize() => _saveState();
  @override
  void onWindowMove() => _saveState();
  @override
  void onWindowMaximize() => _saveState();
  @override
  void onWindowUnmaximize() => _saveState();

  @override
  void onWindowMinimize() async {
    _saveState();
  }

  @override
  void onWindowClose() async {
    if (!mounted) {
      _isShuttingDown = true;
      await windowManager.destroy();
      return;
    }

    final settings = context.read<AppSettings>();
    final controller = context.read<TranslationController>();
    if (_isQuitRequested) {
      _isShuttingDown = true;
      await windowManager.destroy();
      return;
    }

    if (settings.minimizeToTray) {
      final minimized = await _minimizeToTray();
      if (minimized) {
        _userHiddenToTray = true;
        return;
      }
      await windowManager.minimize();
      return;
    }

    final trans = settings.trans;

    final bool isTranslating =
        controller.status == TranslationStatus.running ||
        controller.status == TranslationStatus.paused;
    final bool hasUnsavedEditor =
        settings.isEditorDirty || settings.canUndo;

    // Hiçbir engel yoksa doğrudan kapat
    if (!isTranslating && !hasUnsavedEditor) {
      _isShuttingDown = true;
      _isQuitRequested = true;
      
      // Uygulama normal şekilde kapatıldığında foreground bayrağını temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefAppInForeground, false);
      
      await windowManager.destroy();
      return;
    }

    if (!context.mounted) {
      _isShuttingDown = true;
      _isQuitRequested = true;
      
      // Uygulama normal şekilde kapatıldığında foreground bayrağını temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefAppInForeground, false);
      
      await windowManager.destroy();
      return;
    }

    // Uyarı mesajını belirle
    String message;
    if (isTranslating && hasUnsavedEditor) {
      message = trans['window_close_both_warning'] ??
          'Çeviri devam ediyor ve editörde kaydedilmemiş değişiklikler var. Çıkmak istediğinize emin misiniz?';
    } else if (isTranslating) {
      message = trans['window_close_translation_warning'] ??
          'Çeviri devam ediyor. Çıkmak istediğinize emin misiniz?';
    } else {
      message = trans['window_close_unsaved_warning'] ??
          'Editörde kaydedilmemiş değişiklikler var. Çıkmak istediğinize emin misiniz?';
    }

    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(trans['window_close_title'] ?? 'Uygulamadan Çık'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(trans['btn_cancel'] ?? 'İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onErrorContainer,
                backgroundColor: colorScheme.errorContainer,
              ),
              child: Text(trans['window_close_confirm'] ?? 'Çık'),
            ),
          ],
        );
      },
    );

    if (shouldClose == true) {
      _isShuttingDown = true;
      _isQuitRequested = true;
      
      // Uygulama normal şekilde kapatıldığında foreground bayrağını temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefAppInForeground, false);
      
      await windowManager.destroy();
    }
  }

  Future<bool> _initSystemTray() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return false;
    }
    if (_isShuttingDown || !mounted) {
      return false;
    }

    final settings = context.read<AppSettings>();
    final trayIconCandidates = _trayIconCandidates();
    if (trayIconCandidates.isEmpty) {
      _trayReady = false;
      return false;
    }

    var iconSet = false;
    for (final iconPath in trayIconCandidates) {
      if (!File(iconPath).existsSync()) continue;
      try {
        await trayManager.setIcon(File(iconPath).absolute.path);
        iconSet = true;
        break;
      } catch (_) {
        continue;
      }
    }

    if (!iconSet) {
      _trayReady = false;
      return false;
    }
    if (_isShuttingDown || !mounted) {
      _trayReady = false;
      return false;
    }
    _trayReady = true;
    await _syncTrayProgress(settings);
    return true;
  }

  String _joinPath(String base, String relative) {
    final separator = Platform.pathSeparator;
    final normalizedBase = base.endsWith(separator)
        ? base.substring(0, base.length - 1)
        : base;
    return '$normalizedBase$separator${relative.replaceAll('/', separator)}';
  }

  List<String> _trayIconCandidates() {
    final candidates = <String>[];
    void addCandidate(String value) {
      if (value.trim().isEmpty) return;
      if (!candidates.contains(value)) candidates.add(value);
    }

    final cwd = Directory.current.path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final exeParent = Directory(exeDir).parent.path;

    if (Platform.isWindows) {
      addCandidate('app_icon.ico');
      addCandidate('tray_icon.ico');
      addCandidate('windows/runner/resources/app_icon.ico');
      addCandidate('assets/icon/app_icon.png');
      addCandidate(_joinPath(cwd, 'app_icon.ico'));
      addCandidate(_joinPath(cwd, 'tray_icon.ico'));
      addCandidate(_joinPath(cwd, 'windows/runner/resources/app_icon.ico'));
      addCandidate(_joinPath(cwd, 'assets/icon/app_icon.png'));
      addCandidate(_joinPath(exeDir, 'app_icon.ico'));
      addCandidate(_joinPath(exeDir, 'tray_icon.ico'));
      addCandidate(_joinPath(exeDir, 'resources/app_icon.ico'));
      addCandidate(_joinPath(exeDir, 'data/flutter_assets/assets/icon/app_icon.png'));
      addCandidate(_joinPath(exeParent, 'app_icon.ico'));
      addCandidate(_joinPath(exeParent, 'tray_icon.ico'));
      addCandidate(_joinPath(exeParent, 'resources/app_icon.ico'));
      addCandidate(_joinPath(exeParent, 'data/flutter_assets/assets/icon/app_icon.png'));
      addCandidate('windows/runner/resources/tray_icon.ico');
      addCandidate(_joinPath(cwd, 'windows/runner/resources/tray_icon.ico'));
      addCandidate(_joinPath(exeDir, 'resources/tray_icon.ico'));
      addCandidate(_joinPath(exeParent, 'resources/tray_icon.ico'));
    } else {
      addCandidate('assets/icon/app_icon.png');
      addCandidate(_joinPath(cwd, 'assets/icon/app_icon.png'));
      addCandidate(_joinPath(exeDir, 'data/flutter_assets/assets/icon/app_icon.png'));
      addCandidate(_joinPath(exeParent, 'data/flutter_assets/assets/icon/app_icon.png'));
    }

    return candidates;
  }

  Future<bool> _minimizeToTray() async {
    if (_isShuttingDown || !mounted) return false;
    if (!_trayReady) {
      final initialized = await _initSystemTray();
      if (!initialized) return false;
    }
    if (!_trayReady) return false;
    await windowManager.hide();
    return true;
  }

  Future<void> _restoreFromTray() async {
    if (_isShuttingDown || !mounted) return;
    _userHiddenToTray = false;
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _ensureDesktopWindowVisibleOnStartup() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    if (_userHiddenToTray) {
      _deactivateStartupVisibilityGuard();
      return;
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted || _isShuttingDown) return;
      if (_userHiddenToTray) {
        _deactivateStartupVisibilityGuard();
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
      if (!mounted || _isShuttingDown) return;

      try {
        final isVisible = await windowManager.isVisible();
        final isMinimized = await windowManager.isMinimized();

        if (!isVisible || isMinimized) {
          await _restoreFromTray();
          continue;
        }

        if (attempt >= 2) {
          await windowManager.focus();
        }
        _deactivateStartupVisibilityGuard();
        return;
      } catch (_) {
        continue;
      }
    }

    _deactivateStartupVisibilityGuard();
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_restoreFromTray());
  }

  @override
  void onTrayIconRightMouseDown() {
    if (_isShuttingDown || !_trayReady) return;
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'progress':
        return;
      case 'restore':
        unawaited(_restoreFromTray());
        return;
      case 'exit':
        _isShuttingDown = true;
        _isQuitRequested = true;
        
        // Uygulama normal şekilde kapatıldığında foreground bayrağını temizle
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_kPrefAppInForeground, false);
        });
        
        unawaited(windowManager.destroy());
        return;
    }
  }

  void _saveState() {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = await windowManager.isMaximized();
      await prefs.setBool('window_maximized', isMaximized);

      if (!isMaximized) {
        final size = await windowManager.getSize();
        final pos = await windowManager.getPosition();
        await prefs.setDouble('window_width', size.width);
        await prefs.setDouble('window_height', size.height);
        await prefs.setDouble('window_x', pos.dx);
        await prefs.setDouble('window_y', pos.dy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = context.watch<ThemeManager>();
    final controller = context.watch<TranslationController>();
    final appTitle = Translations.resolveAppName(
      theme.language,
      trans: theme.trans,
    );
    final windowTitle = _resolveWindowTitle(
      appTitle: appTitle,
      settings: settings,
      controller: controller,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDesktopWindowTitle(windowTitle);
    });

    if (!settings.prefsLoaded || _forceStartupSplash) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupSplash(),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: windowTitle,
      themeMode: theme.themeMode,
      theme: AppTheme.light(),
      darkTheme: theme.oledMode ? AppTheme.oled() : AppTheme.dark(),
      builder: (context, child) {
        final scale = theme.uiScale;
        if (child == null || scale == 1.0) {
          return child ?? const SizedBox.shrink();
        }

        final media = MediaQuery.of(context);

        EdgeInsets scaleInsets(EdgeInsets value) {
          return EdgeInsets.fromLTRB(
            value.left / scale,
            value.top / scale,
            value.right / scale,
            value.bottom / scale,
          );
        }

        final dpr = media.devicePixelRatio;
        final scaledWidth =
            ((media.size.width * dpr / scale).floorToDouble()) / dpr;
        final scaledHeight =
            ((media.size.height * dpr / scale).floorToDouble()) / dpr;

        final scaledMedia = media.copyWith(
          size: Size(scaledWidth, scaledHeight),
          padding: scaleInsets(media.padding),
          viewPadding: scaleInsets(media.viewPadding),
          viewInsets: scaleInsets(media.viewInsets),
          systemGestureInsets: scaleInsets(media.systemGestureInsets),
        );

        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: scaledWidth,
            height: scaledHeight,
            child: MediaQuery(
              data: scaledMedia,
              child: child,
            ),
          ),
        );
      },
      home: const MainScreen(),
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/icon/splash_bg.png'),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  static const _tabChannel = MethodChannel('com.deepnode.altyaziceviri/tab');
  TabController? _tabController;

  Widget _buildUiScaleMenu(ThemeManager theme, ColorScheme colorScheme) {
    final current = theme.uiScale;
    final label = '${(current * 100).round()}%';
    final textStyle = TextStyle(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    return PopupMenuButton<double>(
      tooltip: theme.trans['ui_scale_tooltip'] ?? 'Scale',
      initialValue: current,
      onSelected: (value) async {
        final oldScale = theme.uiScale;
        if (value == oldScale) return;

        // Resize & adjust minimum window size for the new scale.
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final isMax = await windowManager.isMaximized();
          final newMinW = (_kDesktopMinWidth * value).roundToDouble();
          final newMinH = (_kDesktopMinHeight * value).roundToDouble();

          if (!isMax) {
            final currentSize = await windowManager.getSize();
            // Derive 100%-base size and compute new target.
            final baseW = currentSize.width / oldScale;
            final baseH = currentSize.height / oldScale;
            var newW = (baseW * value).roundToDouble();
            var newH = (baseH * value).roundToDouble();
            // Clamp to screen bounds so window never goes off-screen.
            final screen = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
            final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
            final screenW = screen.width / dpr;
            final screenH = screen.height / dpr;
            if (newW > screenW) newW = screenW;
            if (newH > screenH - 48) newH = screenH - 48; // taskbar
            // Ensure not smaller than minimum.
            if (newW < newMinW) newW = newMinW;
            if (newH < newMinH) newH = newMinH;

            await windowManager.setMinimumSize(Size(newMinW, newMinH));
            await windowManager.setSize(Size(newW, newH));
          } else {
            await windowManager.setMinimumSize(Size(newMinW, newMinH));
          }
        }

        // Wait a frame for window resize to settle, then update scale.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        theme.setUiScale(value);
      },
      itemBuilder: (_) => const [
        PopupMenuItem<double>(value: 0.75, child: Text('75%')),
        PopupMenuItem<double>(value: 0.90, child: Text('90%')),
        PopupMenuItem<double>(value: 1.00, child: Text('100%')),
        PopupMenuItem<double>(value: 1.25, child: Text('125%')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.zoom_in, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: textStyle),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _handleTabIndexChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController?.addListener(_handleTabIndexChanged);

    _tabChannel.setMethodCallHandler((call) async {
      if (call.method == 'switchTab') {
        final int tabIndex = call.arguments as int;
        if (tabIndex >= 0 && tabIndex < 2 && mounted) {
          _tabController?.animateTo(tabIndex);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettings>();
      settings.promptCrashReportIfAvailable(context);

      // Check for partial translations after a short delay
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        final project =
            await settings.promptPartialTranslationIfAvailable(context);

        if (project != null && mounted) {
          final controller = context.read<TranslationController>();
          // Ensure UI settings match the project's resume parameters.
          settings.setTranslationConfig(lang: project.targetLanguage);
          // Çeviri sekmesine geç
          _tabController?.animateTo(0);

          // Controller üzerinden çeviriyi devam ettir
          await controller.prepareResumeFromBlocks(
            file: File(project.filePath),
            alreadyTranslatedBlocks: project.processedBlocks,
            clearSdh: settings.sdhClear,
            targetLanguage: project.targetLanguage,
          );

          if (!mounted) return;

          // Ensure we enqueue + start using the permanent path picked by the controller.
          final permanentPath =
              controller.selectedFile?.path ?? project.filePath;

          // Make the resumed item visible in the AI Panel list and keep it on top.
          await settings.addFileToBatchTranslation(
            project.fileName,
            permanentPath,
            insertAtTop: true,
          );

          // Start immediately (resume from blocks) so user doesn't need to press start again.
          unawaited(
            controller.startBatchTranslationQueue(
              files: [
                BatchFile(
                  name: project.fileName,
                  path: permanentPath,
                ),
              ],
              clearSdh: settings.sdhClear,
              targetLanguage: project.targetLanguage,
              playCompletionSound: true,
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabIndexChanged);
    _tabController?.dispose();
    super.dispose();
  }

  /// Dinamik TabBar - dil değişikliğinde otomatik güncellenir
  PreferredSize _buildDynamicTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Consumer<ThemeManager>(
        builder: (context, theme, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final total = constraints.maxWidth;
              final w2 = total / 2;
              final trans = theme.trans;

              return TabBar(
                controller: _tabController,
                labelStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 15),
                labelPadding: EdgeInsets.zero,
                tabs: [
                  Tab(
                    child: SizedBox(
                      width: w2,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(trans["tab_translation"] ?? ""),
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    child: SizedBox(
                      width: w2,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(trans["tab_editor"] ?? ""),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = context.watch<ThemeManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final railBackgroundColor = colorScheme.surfaceContainerLow;

    final pendingTab = settings.pendingTabIndex;
    if (pendingTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (pendingTab >= 0 && pendingTab < 2) {
          _tabController?.animateTo(pendingTab);
        }
        context.read<AppSettings>().consumeTabSwitchRequest();
      });
    }

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          top: false,
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: ColoredBox(
                  color: railBackgroundColor,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 88,
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      Expanded(
                        child: NavigationRail(
                        selectedIndex: _tabController?.index ?? 0,
                        backgroundColor: railBackgroundColor,
                        selectedIconTheme: IconThemeData(
                          size: 24,
                          color: colorScheme.primary,
                        ),
                        unselectedIconTheme: IconThemeData(
                          size: 24,
                          color: colorScheme.primary,
                        ),
                        selectedLabelTextStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.1,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.1,
                        ),
                        onDestinationSelected: (index) {
                          _tabController?.animateTo(index);
                          setState(() {});
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.auto_awesome_outlined),
                            selectedIcon: const Icon(Icons.auto_awesome),
                            label: AdaptiveText(
                              theme.trans["tab_translation"] ?? "",
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              minFontSize: 9,
                              wrapWords: false,
                            ),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.edit_outlined),
                            selectedIcon: const Icon(Icons.edit),
                            label: AdaptiveText(
                              theme.trans["tab_editor"] ?? "",
                              maxLines: 1,
                              minFontSize: 8,
                            ),
                          ),
                        ],
                        trailing: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SettingsButton(showLabel: true),
                              SizedBox(height: 10),
                              FeaturesButton(),
                            ],
                          ),
                        ),
                        ),
                      ),
                    ],
                    ),
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              Translations.resolveAppName(
                                theme.language,
                                trans: theme.trans,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildUiScaleMenu(theme, colorScheme),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: const [
                                TranslationTab(),
                                EditorTab(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        title: Row(
          children: [
            Icon(Icons.translate, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Translations.resolveAppName(
                    theme.language,
                    trans: theme.trans,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottom: _buildDynamicTabBar(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildUiScaleMenu(theme, colorScheme),
          ),
          const FeaturesButton(),
          const SettingsButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TranslationTab(),
          EditorTab(),
        ],
      ),
    );
  }
}
