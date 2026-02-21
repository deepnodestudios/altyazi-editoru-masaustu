import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../translations.dart';

typedef NotificationLogFn = dynamic Function(String, String?);

class NotificationManager {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Completer<void> _notificationsCompleter = Completer<void>();
  static const MethodChannel _foregroundChannel =
      MethodChannel('com.deepnode.altyaziceviri/foreground');
  NotificationLogFn? _addLog;
  bool _notificationsReady = false;
  bool _isReinitializing = false;

  // Reusing the same notification id on Windows often updates the existing
  // toast without showing a new popup. Use a rolling id for desktop completion.
  int _desktopCompletionNotificationId = 900;

  Future<void> initNotifications(
      {required NotificationLogFn addLog}) async {
    _addLog = addLog;
    await _initializeNotifications(addLog: addLog);
  }

  Future<bool> _initializeNotifications(
      {required NotificationLogFn addLog}) async {
    var initialized = false;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();

      String? windowsIconPath;
      if (Platform.isWindows) {
        try {
          final iconFile = File('windows/runner/resources/app_icon.ico');
          if (iconFile.existsSync()) {
            windowsIconPath = iconFile.absolute.path;
          }
        } catch (_) {
          // Ignore icon resolution failures.
        }
      }

      const primaryAumid = 'com.deepnode.altyaziceviri';
      const fallbackAumid = 'Deepnode.AltyaziEditoru';

      WindowsInitializationSettings buildWindowsSettings(String aumid) {
        return WindowsInitializationSettings(
          appName: 'Altyazi Editoru',
          appUserModelId: aumid,
          guid: '6a3155c7-71dd-4e90-a116-0d8fce2f7f58',
          iconPath: windowsIconPath,
        );
      }

      Future<bool?> initializeForWindowsAumid(String aumid) {
        final InitializationSettings initializationSettings =
            InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
          windows: buildWindowsSettings(aumid),
        );

        final timeout = Platform.isWindows
            ? const Duration(seconds: 6)
            : const Duration(seconds: 2);

        // Timeout ekleyerek sonsuz beklemeyi önlüyoruz
        return _notificationsPlugin
            .initialize(settings: initializationSettings)
            .timeout(timeout);
      }

      final initOk = await initializeForWindowsAumid(primaryAumid);
      if (Platform.isWindows && initOk != true) {
        final fallbackOk = await initializeForWindowsAumid(fallbackAumid);
        if (fallbackOk != true) {
          addLog(
            'log_notification_error',
            'Windows notification init failed (primary+fallback).',
          );
          initialized = false;
        } else {
          initialized = true;
        }
      } else {
        initialized = initOk == true;
      }
    } catch (e) {
      initialized = false;
      if (e is! TimeoutException) {
        addLog("log_notification_error", e.toString());
      }
    } finally {
      _notificationsReady = initialized;
      if (!_notificationsCompleter.isCompleted) {
        _notificationsCompleter.complete();
      }
    }
    return initialized;
  }

  Future<void> requestNotificationPermission() async {
    await _notificationsCompleter.future;
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> showProgressNotification(
    int current,
    int total, {
    bool isComplete = false,
    String? fileName,
    required String language,
    required bool translationForegroundActive,
    required Function(bool) setTranslationForegroundActive,
  }) async {
    if (total == 0) return;

    final bool isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    // Desktop'ta ilerleme bildirimleri yerine yalnızca tamamlanma bildirimi göster.
    // Böylece Notification Center spam'lenmez ve item 19 beklentisi (tamamlandı bildirimi)
    // net şekilde karşılanır.
    if (isDesktop && !isComplete) {
      return;
    }

    // Android: Use a Foreground Service notification while translating so the OS
    // keeps the process alive and translation continues in background.
    // Keep the existing completion notification (sound/high importance) by stopping
    // the service on completion and then using flutter_local_notifications.
    if (Platform.isAndroid && !isComplete) {
      final int progress = ((current / total) * 100).clamp(0, 100).toInt();
      final t = Translations.getWithGlobalFallback(language);
      String fill(String template, Map<String, String> params) {
        var out = template;
        params.forEach((k, v) {
          out = out.replaceAll('{$k}', v);
        });
        return out;
      }

      final String baseTitle =
          (t["notification_translation_in_progress_title"] ??
              "AI translation in progress");
      final String fileDisplay = fileName != null ? " • $fileName" : "";
      final String title = '$baseTitle$fileDisplay • $progress%';
      final String body = fill(
        t["notification_translation_progress_body"] ??
            "{progress}% completed ({current}/{total})",
        {
          'progress': progress.toString(),
          'current': current.toString(),
          'total': total.toString(),
        },
      );

      try {
        await _foregroundChannel.invokeMethod('translationForegroundUpdate', {
          'title': title,
          'body': body,
          'current': current,
          'total': total,
          'isComplete': false,
        });
        setTranslationForegroundActive(true);
        return;
      } catch (_) {
        // If foreground service fails, fallback to normal notification below.
      }
    }

    if (Platform.isAndroid && isComplete && translationForegroundActive) {
      try {
        await _foregroundChannel.invokeMethod('translationForegroundStop');
      } catch (_) {
        // Ignore.
      }
      setTranslationForegroundActive(false);
    }

    await _notificationsCompleter.future;

    if (isDesktop && isComplete && !_notificationsReady && !_isReinitializing) {
      _isReinitializing = true;
      try {
        final NotificationLogFn logger =
            _addLog ?? ((String _, String? __) {});
        await _initializeNotifications(addLog: logger);
      } finally {
        _isReinitializing = false;
      }
    }

    final int progress = ((current / total) * 100).toInt();

    final t = Translations.getWithGlobalFallback(language);
    String fill(String template, Map<String, String> params) {
      var out = template;
      params.forEach((k, v) {
        out = out.replaceAll('{$k}', v);
      });
      return out;
    }

    final String title = isComplete
        ? (t["notification_translation_completed_title"] ?? "İşlem Tamamlandı")
        : (t["notification_translation_in_progress_title"] ??
            "AI Çeviri Yapılıyor");

    final String body = isComplete
        ? (t["notification_translation_completed_body"] ??
            "Çeviri başarıyla bitirildi.")
        : fill(
            t["notification_translation_progress_body"] ??
                "{progress}% completed ({current}/{total})",
            {
              'progress': progress.toString(),
              'current': current.toString(),
              'total': total.toString(),
            },
          );

    NotificationDetails platformChannelSpecifics;

    if (Platform.isAndroid) {
      // Tamamlandığında sesli ve yüksek öncelikli, devam ederken sessiz
      final String channelId =
        isComplete ? 'translation_completed' : 'translation_progress';
      final String channelName = isComplete
        ? (t["notification_channel_completed"] ?? title)
        : (t["notification_channel_progress"] ?? "Çeviri Durumu");
      final Importance importance =
        isComplete ? Importance.high : Importance.low;
      final Priority priority = isComplete ? Priority.high : Priority.low;

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channelId, channelName,
          importance: importance,
          priority: priority,
          ongoing: !isComplete,
          showProgress: !isComplete,
          maxProgress: total,
          progress: current,
          playSound: isComplete,
          onlyAlertOnce: !isComplete);
      platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    } else {
      // Windows/macOS/Linux: Provide explicit Windows details. Some Windows
      // configurations require a WindowsNotificationDetails payload for toasts
      // to be emitted reliably.
      final windowsDetails = Platform.isWindows
          ? (isComplete
              ? WindowsNotificationDetails(
                  duration: WindowsNotificationDuration.long,
                  scenario: WindowsNotificationScenario.urgent,
                  audio: WindowsNotificationAudio.preset(
                    sound: WindowsNotificationSound.defaultSound,
                  ),
                )
              : const WindowsNotificationDetails(
                  duration: WindowsNotificationDuration.short,
                ))
          : null;
      platformChannelSpecifics = NotificationDetails(windows: windowsDetails);
    }
    try {
      final notificationId = (isDesktop && isComplete)
          ? (_desktopCompletionNotificationId++)
          : 777;

      // Keep the id bounded.
      if (_desktopCompletionNotificationId > 50000) {
        _desktopCompletionNotificationId = 900;
      }

      await _notificationsPlugin.show(
          id: notificationId,
          title: title,
          body: body,
          notificationDetails: platformChannelSpecifics);
    } catch (e) {
      // Bildirim gösterilemezse işlemi durdurma, devam et
      if (isDesktop && isComplete) {
        _addLog?.call('log_notification_error',
            'Desktop completion notification failed: ${e.toString()}');
        // This helps diagnose Windows toast delivery problems.
        try {
          final t = Translations.getWithGlobalFallback(language);
          final msg = t['log_notification_error'] ?? 'Notification error';
          debugPrint('$msg: ${e.toString()}');
        } catch (_) {
          debugPrint('Notification error: ${e.toString()}');
        }
      }
    }
  }

  Future<void> cancelNotification(
      {required bool translationForegroundActive,
      required Function(bool) setTranslationForegroundActive}) async {
    if (Platform.isAndroid && translationForegroundActive) {
      try {
        await _foregroundChannel.invokeMethod('translationForegroundStop');
      } catch (_) {
        // Ignore.
      }
      setTranslationForegroundActive(false);
    }

    await _notificationsCompleter.future;
    try {
      await _notificationsPlugin.cancel(id: 777);
    } catch (_) {
      // Hata yut
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final dynamic res = await _foregroundChannel
          .invokeMethod('isIgnoringBatteryOptimizations');
      return res == true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return false;
    try {
      final dynamic res = await _foregroundChannel
          .invokeMethod('requestIgnoreBatteryOptimizations');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final dynamic res = await _foregroundChannel
          .invokeMethod('openBatteryOptimizationSettings');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppDetailsSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final dynamic res =
          await _foregroundChannel.invokeMethod('openAppDetailsSettings');
      return res == true;
    } catch (_) {
      return false;
    }
  }
}
