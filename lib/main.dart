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

import 'utils/single_instance_win.dart' as single_instance;
import 'app_settings.dart';
import 'managers/theme_manager.dart';
import 'app_theme.dart';
import 'controllers/translation_controller.dart';
import 'tabs/translation_tab.dart';
import 'tabs/editor_tab.dart';
import 'settings.dart';
import 'widgets/adaptive_text.dart';
import 'widgets/shared_system_log.dart';
import 'translations.dart';
import 'services/update_service.dart';
import 'services/desktop_install_tracker.dart';
import 'services/maintenance_mode_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

const String _kPrefAppInForeground = 'app_in_foreground';
const String _kPrefCrashForcePrompt = 'crash_report_force_prompt';
const String _kPrefWindowAlwaysOnTop = 'window_always_on_top';

const double _kDesktopMinWidth = 1120;
const double _kDesktopMinHeight = 720;

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

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
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: Özel localhost web sunucusu ile PKCE akışı kullandığımız için
      // eklenti tabanlı signInSilently her zaman `null` döndürür veya çalışmaz.
      // Bu adımda bir şey yapmıyoruz, `app_settings` yüklenince `restoreGoogleSession`
      // üzerinden token/refresh_token kontrolüyle otomatik oturum açılıyor.
      return false;
    }

    // Mobil için mevcut eklenti akışına devam:
    final googleSignIn = GoogleSignIn(
      scopes: const ['openid', 'email', 'profile'],
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

/// Remote Config ve Firebase Auth oturum geri yükleme işlemlerini
/// arka planda çalıştırır. main()'de runApp()'ı bloklamadan başlatılır.
Future<void> _deferredStartupWork(FirebaseAuth auth) async {
  // Remote Config (tüm platformlar)
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await MaintenanceModeService.ensureDefaults(remoteConfig);
    final minFetchInterval = (!kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
        ? const Duration(seconds: 10)
        : const Duration(hours: 1);
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 30),
      minimumFetchInterval: minFetchInterval,
    ));
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    debugPrint("Remote Config failed: $e");
  }

  // Firebase Auth oturum geri yükleme
  try {
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
      final restoredGoogle = await _tryRestoreGoogleFirebaseSession(auth);
      restoredUser = auth.currentUser;

      if (restoredUser == null && !restoredGoogle) {
        await auth.signInAnonymously();
        restoredUser = auth.currentUser;
      }
    }

    if (restoredUser != null) {
      try {
        await auth.currentUser?.reload();
      } on FirebaseAuthException catch (e) {
        const invalidCodes = <String>{
          'user-disabled',
          'user-not-found',
          'invalid-user-token',
          'user-token-expired',
          'invalid-credential',
        };

        if (invalidCodes.contains(e.code)) {
          debugPrint("⚠️ Oturum geçersiz (${e.code}), temizleniyor: $e");
          await auth.signOut();
          await auth.signInAnonymously();
        } else {
          debugPrint('⚠️ Oturum yenileme başarısız (${e.code}); oturum korunuyor: $e');
        }
      } catch (e) {
        debugPrint('⚠️ Oturum yenileme beklenmeyen hata; oturum korunuyor: $e');
      }

      try {
        final currentUid = auth.currentUser?.uid ?? restoredUser.uid;
        await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
          'lastAppOpen': FieldValue.serverTimestamp(),
          'platforms': FieldValue.arrayUnion([Platform.operatingSystem]),
          'lastPlatform': Platform.operatingSystem,
        }, SetOptions(merge: true));
      } catch (_) {}

      unawaited(DesktopInstallTracker.recordAppOpen());
    }
  } catch (e) {
    debugPrint("Firebase Auth failed: $e");
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
  final mainStopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('⏱️ [${mainStopwatch.elapsedMilliseconds}ms] WidgetsFlutterBinding.ensureInitialized');

  // Windows: tek örnek kontrolü.
  // Not: Debug/profile modlarında hot-restart ve geliştirme akışını bozabildiği
  // için yalnızca release build'de aktif.
  if (Platform.isWindows && kReleaseMode) {
    if (!single_instance.ensureSingleInstance()) {
      exit(0);
    }
  }

  // ── Bağımsız başlatma işlemlerini paralel çalıştır ──
  // Firebase, SharedPreferences ve WindowManager birbirinden
  // bağımsız olduğu için hepsini aynı anda başlatarak toplam bekleme süresini
  // en yavaş olan tek işlem kadar düşürüyoruz.
  final bool isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  late final SharedPreferences prefs;
  await Future.wait<void>([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance().then((p) => prefs = p),
    if (isDesktop) windowManager.ensureInitialized(),
  ]);
  debugPrint(
      '⏱️ [${mainStopwatch.elapsedMilliseconds}ms] Parallel init (Firebase+Prefs+Window)');

  // App Check (yalnızca mobil — masaüstünde atlanır)
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

  final auth = FirebaseAuth.instanceFor(app: Firebase.app());

  // Firebase Auth session'ını kontrol et (app restart sonrasında restore ediliyor mu?)
  final currentUser = auth.currentUser;
  if (currentUser != null) {
    debugPrint(
        '✅ Firebase Auth session restored: ${currentUser.uid} (${currentUser.email})');
  } else {
    debugPrint('⚠️ Firebase Auth session not found - anonymous or new user');
  }

  // Remote Config ve Firebase Auth oturum geri yükleme işlemlerini
  // runApp()'ı bloklamadan arka planda başlat.
  // AppSettings zaten authStateChanges dinliyor; auth hazır olduğunda
  // otomatik olarak senkronize olacaktır.
  unawaited(_deferredStartupWork(auth));

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
    // SharedPreferences önbelleği anında güncellenir; disk yazımı arka planda.
    unawaited(prefs.setBool(_kPrefCrashForcePrompt, true));
    unawaited(prefs.remove('crash_report_prompted_size'));
    unawaited(appendFlutterError(
      'Previous run ended unexpectedly',
      'Detected app_in_foreground=true at startup (likely native crash/kill).',
    ));
  }

  // Reset startup state and install lifecycle observer.
  unawaited(prefs.setBool(_kPrefAppInForeground, false));
  WidgetsBinding.instance.addObserver(_ForegroundFlagObserver(prefs));

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    unawaited(
      appendFlutterError(
          'FlutterError.onError', details.exceptionAsString(), details.stack),
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(appendFlutterError('PlatformDispatcher.onError', error, stack));
    // Returning true prevents the error from being treated as unhandled,
    // which can terminate the app in release builds on desktop.
    return true;
  };

    final double savedScale = (prefs.getDouble('ui_scale') ?? 1.0).clamp(0.75, 1.25);
    // Minimum boyut ölçeğe göre orantılı.
    final double scaledMinW = (_kDesktopMinWidth * savedScale).roundToDouble();
    final double scaledMinH = (_kDesktopMinHeight * savedScale).roundToDouble();

    final double width =
      (prefs.getDouble('window_width') ?? (1280 * savedScale)).clamp(scaledMinW, double.infinity);
    final double height =
      (prefs.getDouble('window_height') ?? (720 * savedScale)).clamp(scaledMinH, double.infinity);
  final double? x = prefs.getDouble('window_x');
  final double? y = prefs.getDouble('window_y');
  final bool isAlwaysOnTop = prefs.getBool(_kPrefWindowAlwaysOnTop) ?? false;
  final String startupAppTitle = _resolveStartupAppTitle(prefs);

  debugPrint('⏱️ [${mainStopwatch.elapsedMilliseconds}ms] Pre-windowManager setup');
  if (isDesktop) {
    // windowManager.ensureInitialized() paralel fazda tamamlandı.
    WindowOptions windowOptions = WindowOptions(
      size: Size(width, height),
      center: x == null,
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
      // Daima kaydedilen boyut/pozisyonda aç — maximize yapma.
      // Kullanıcı isterse manuel maximize edebilir.
      {
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

  debugPrint('⏱️ [${mainStopwatch.elapsedMilliseconds}ms] Pre-runApp');
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
  GlobalKey<NavigatorState> get _navigatorKey => globalNavigatorKey;
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
    
    // Test ortamında güncellemeleri kontrol etme
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _isShuttingDown || _desktopUpdatePromptShown) return;

    final update = await settings.checkDesktopUpdateFromGoogleDrive(
      minimumCheckInterval: Duration.zero,
    );
    if (update == null || !mounted || _isShuttingDown) {
      // Fallback to our direct website check
      _desktopUpdatePromptShown = true;
      if (_navigatorKey.currentContext != null) {
        await UpdateService.checkForUpdates(_navigatorKey.currentContext!);
      }
      return;
    }

    _desktopUpdatePromptShown = true;
    if (!context.mounted || _navigatorKey.currentContext == null) return;

    await UpdateService.promptAndApplyUpdate(
      _navigatorKey.currentContext!,
      update: update,
      trans: settings.trans,
    );
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
    final bool hasUnsavedEditor = settings.isEditorDirty;

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

    if (!context.mounted || _navigatorKey.currentContext == null) {
      _isShuttingDown = true;
      _isQuitRequested = true;
      
      // Uygulama normal şekilde kapatıldığında foreground bayrağını temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefAppInForeground, false);
      
      await windowManager.destroy();
      return;
    }

    // Uyarı mesajını belirle
    final translationWarning = trans['window_close_translation_warning'] ??
        'Ceviri devam ediyor. Uygulamadan cikabilirsiniz; tamamlandiginda bildirim alacaksiniz.';
    final unsavedWarning = trans['window_close_unsaved_warning'] ??
        'Editorde kaydedilmemis degisiklikler var. Uygulamayi kapatmak istediginize emin misiniz?';

    String message;
    if (isTranslating && hasUnsavedEditor) {
      message = '$translationWarning\n\n$unsavedWarning';
    } else if (isTranslating) {
      message = translationWarning;
    } else {
      message = unsavedWarning;
    }

    final shouldClose = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(trans['window_close_title'] ?? 'Uygulamayi Kapat'),
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
              child: Text(trans['window_close_confirm'] ?? 'Kapat'),
            ),
          ],
        );
      },
    );

    if (shouldClose == true) {
      if (isTranslating) {
        // Canlı çeviri varsa önce durdur (bu işlem partial sonucu geçmişe ekler)
        await controller.stopTranslation(
          clearSdh: settings.sdhClear,
          targetLanguage: settings.targetLanguage,
        );
      }

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
        if (mounted && _navigatorKey.currentContext != null) {
          final settings = _navigatorKey.currentContext!.read<AppSettings>();
          final controller = _navigatorKey.currentContext!.read<TranslationController>();
          
          final bool isTranslating = controller.status == TranslationStatus.running ||
              controller.status == TranslationStatus.paused;

          if (isTranslating) {
            // Canlı çeviri varsa geçmişe kaydedilmesini sağlamak için önce durduruyoruz
            unawaited(controller.stopTranslation(
              clearSdh: settings.sdhClear,
              targetLanguage: settings.targetLanguage,
            ).then((_) {
              _isShuttingDown = true;
              _isQuitRequested = true;
              SharedPreferences.getInstance().then((prefs) {
                prefs.setBool(_kPrefAppInForeground, false);
              });
              unawaited(windowManager.destroy());
            }));
            return;
          }
        }

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
      // Maximize durumunu kaydetme — daima normal boyutta açılsın.
      // Maximize iken boyut/pozisyon güncelleme (orijinal değerler korunsun).
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

    return !settings.prefsLoaded || _forceStartupSplash
        ? const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _StartupSplash(),
          )
        : MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: windowTitle,
      themeMode: theme.themeMode,
      theme: AppTheme.light(),
      darkTheme: theme.oledMode ? AppTheme.oled() : AppTheme.dark(),
      builder: (context, child) {
      if (child == null) return const SizedBox.shrink();

      final media = MediaQuery.of(context);
      if (media.size.width == 0 || media.size.height == 0) {
        return const SizedBox.shrink();
      }

      final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      final double scale = theme.uiScale;

      Widget content = child;

      if (isDesktop) {
        // Native title bar kullanıyor, sadece FittedBox ile ölçekleme yap.
        if ((scale - 1.0).abs() >= 0.001) {
          final physicalWidth = media.size.width;
          final physicalHeight = media.size.height;
          final logicalWidth = physicalWidth / scale;
          final logicalHeight = physicalHeight / scale;
          return FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: logicalWidth,
              height: logicalHeight,
              child: MediaQuery(
                data: media.copyWith(size: Size(logicalWidth, logicalHeight)),
                child: child,
              ),
            ),
          );
        }
        return child;
      }

      // Mobil/Web için eski mantık
      if ((scale - 1.0).abs() >= 0.001) {
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

        content = FittedBox(
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
      }

      return content;
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
      body: Center(
        child: CircularProgressIndicator(),
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
    with TickerProviderStateMixin {
  static const _tabChannel = MethodChannel('com.deepnode.altyaziceviri/tab');
  TabController? _tabController;

  // Pencere boyutu animasyonu için controller
  late final AnimationController _sizeAnimController;
  Animation<Size>? _sizeAnimation;

  void _animateWindowSize(Size from, Size to, {VoidCallback? onComplete}) {
    _sizeAnimation = Tween<Size>(begin: from, end: to).animate(
      CurvedAnimation(parent: _sizeAnimController, curve: Curves.easeOut),
    );
    _sizeAnimController.forward(from: 0.0).whenComplete(() {
      onComplete?.call();
    });
  }

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

        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final isMax = await windowManager.isMaximized();
          final newMinW = (_kDesktopMinWidth * value).roundToDouble();
          final newMinH = (_kDesktopMinHeight * value).roundToDouble();

          if (!isMax) {
            final currentSize = await windowManager.getSize();
            final baseW = currentSize.width / oldScale;
            final baseH = currentSize.height / oldScale;
            var newW = (baseW * value).roundToDouble();
            var newH = (baseH * value).roundToDouble();
            if (newW < newMinW) newW = newMinW;
            if (newH < newMinH) newH = newMinH;

            // Küçülme: önce min boyutu güncelle, küçülme başlasın
            if (value < oldScale) {
              await windowManager.setMinimumSize(Size(newMinW, newMinH));
            }

            // Ölçeği hemen uygula (FittedBox içerik oranını günceller)
            await theme.setUiScale(value);

            // AnimationController ile OS penceresini kare kare boyutlandır
            _animateWindowSize(currentSize, Size(newW, newH), onComplete: () async {
              if (value > oldScale) {
                await windowManager.setMinimumSize(Size(newMinW, newMinH));
              }
            });
          } else {
            // Maximize: boyut değişmez, yalnızca ölçek
            await windowManager.setMinimumSize(Size(newMinW, newMinH));
            await theme.setUiScale(value);
          }
        } else {
          await theme.setUiScale(value);
        }
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

    // Pencere boyutu animasyon denetleyicisi
    _sizeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sizeAnimController.addListener(() {
      final anim = _sizeAnimation;
      if (anim != null) {
        windowManager.setSize(anim.value);
      }
    });

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

      // Partial translations check removed
    });
  }

  @override
  void dispose() {
    _sizeAnimController.dispose();
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
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                labelPadding: EdgeInsets.zero,
                indicatorWeight: 3,
                splashBorderRadius: BorderRadius.circular(8),
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

  Widget _buildNavRailItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return SideRailHoverButton(
      onTap: onTap,
      isSelected: selected,
      verticalPadding: 8.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? selectedIcon : icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 4),
          AdaptiveText(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            minFontSize: 8,
            wrapWords: false,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
              height: 1.1,
            ),
          ),
        ],
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
                width: 82,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: railBackgroundColor,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildNavRailItem(
                              context: context,
                              icon: Icons.auto_awesome_outlined,
                              selectedIcon: Icons.auto_awesome,
                              label: theme.trans["tab_translation"] ?? "",
                              selected: (_tabController?.index ?? 0) == 0,
                              onTap: () {
                                _tabController?.animateTo(0);
                                setState(() {});
                              },
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 4),
                            _buildNavRailItem(
                              context: context,
                              icon: Icons.subtitles_outlined,
                              selectedIcon: Icons.subtitles,
                              label: theme.trans["tab_editor"] ?? "",
                              selected: (_tabController?.index ?? 0) == 1,
                              onTap: () {
                                _tabController?.animateTo(1);
                                setState(() {});
                              },
                              colorScheme: colorScheme,
                            ),
                            const Spacer(),
                            Padding(
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                                    letterSpacing: -0.3,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildUiScaleMenu(theme, colorScheme),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _tabController!,
                          builder: (context, _) {
                            final controller = _tabController!;
                            final index = controller.index;
                            return IndexedStack(
                              index: index,
                              children: [
                                TickerMode(
                                  enabled: index == 0,
                                  child: const TranslationTab(),
                                ),
                                TickerMode(
                                  enabled: index == 1,
                                  child: EditorTab(),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SharedSystemLog(),
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
        titleSpacing: 32,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
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
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController!,
              builder: (context, _) {
                final controller = _tabController!;
                final index = controller.index;
                return IndexedStack(
                  index: index,
                  children: [
                    TickerMode(
                      enabled: index == 0,
                      child: TranslationTab(),
                    ),
                    TickerMode(
                      enabled: index == 1,
                      child: EditorTab(),
                    ),
                  ],
                );
              },
            ),
          ),
          const SharedSystemLog(),
        ],
      ),
    );
  }
}
