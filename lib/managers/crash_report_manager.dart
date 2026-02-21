import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../translations.dart';

class CrashReportManager {
  static const String _crashLogFileName = 'crash_log.txt';
  static const String _crashReportEmail = 'deepnodestudios@gmail.com';

  Future<File> getCrashLogFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$_crashLogFileName');
  }

  Future<bool> hasCrashLog() async {
    try {
      final file = await getCrashLogFile();
      if (!await file.exists()) return false;
      return await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearCrashLog() async {
    try {
      final file = await getCrashLogFile();
      if (await file.exists()) {
        await file.delete();
      }
      // Clear the prompted flag when crash log is deleted
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('crash_report_prompted_size');
      await prefs.remove('crash_report_force_prompt');
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  Future<void> saveCrashLogToFile(File file, {required Function(String, String?) addLog, required String language}) async {
    final t = Translations.getWithGlobalFallback(language);
    final bytes = await file.readAsBytes();
    final fileName = "crash_log_${DateTime.now().millisecondsSinceEpoch}.txt";
    final isAndroidIos = Platform.isAndroid || Platform.isIOS;
    String? f = await FilePicker.platform.saveFile(
      dialogTitle:
          t["crash_report_download_title"] ?? (t["save_log"] ?? 'Save Log'),
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['txt'],
      bytes: isAndroidIos ? bytes : null,
    );
    if (f != null) {
      if (!isAndroidIos) {
        await File(f).writeAsBytes(bytes, flush: true);
      }
      addLog("log_saved", isAndroidIos ? fileName : f);
    }
  }

  Future<bool> shareCrashLog(BuildContext context, File file, {required String language}) async {
    String logText = '';
    try {
      logText = await file.readAsString();
    } catch (e) {
      debugPrint('[crash_report] read crash log failed: $e');
    }

    String? langFromLog;
    try {
      final m = RegExp(r'app_language=([A-Za-z]{2})').firstMatch(logText);
      final g = m?.group(1);
      if (g != null && g.isNotEmpty) {
        langFromLog = g.toUpperCase();
      }
    } catch (_) {
      // Ignore parse failures.
    }

    final t = Translations.getWithGlobalFallback(langFromLog ?? language);
    final subject = t["crash_report_subject"] ?? 'Crash Log';
    final baseBody = t["crash_report_body"] ?? 'Crash log below.';

    // Avoid extremely large email bodies (some clients may choke).
    const maxBodyChars = 120000;
    var clippedLogText = logText;
    var clipped = false;
    if (clippedLogText.length > maxBodyChars) {
      clippedLogText = clippedLogText.substring(0, maxBodyChars);
      clipped = true;
    }

    final bodyWithLog = StringBuffer()
      ..writeln(baseBody)
      ..writeln()
      ..writeln('--- crash_log.txt ---')
      ..writeln(clippedLogText)
      ..writeln();

    if (clipped) {
      bodyWithLog.writeln(
        t["crash_report_body_truncated"] ??
            '[truncated] Use Download to send the full log.',
      );
    }

    // Android: use native intent with a MIME type set (Gmail is more reliable).
    if (Platform.isAndroid) {
      try {
        final ok = await const MethodChannel(
          'com.deepnode.altyaziceviri/email',
        ).invokeMethod<bool>('sendEmailWithAttachment', {
          'recipients': <String>[_crashReportEmail],
          'subject': subject,
          'body': bodyWithLog.toString(),
          // Attachment is intentionally omitted; some Android mail clients show it as empty.
          'attachmentPath': null,
        });
        if (ok == true) return true;
      } catch (e) {
        debugPrint('[crash_report] native sendEmailWithAttachment failed: $e');
      }
    }

    // iOS fallback via plugin (Android plugin fallback may show non-email apps).
    if (Platform.isIOS) {
      try {
        final email = Email(
          subject: subject,
          body: bodyWithLog.toString(),
          recipients: [_crashReportEmail],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
        return true;
      } catch (e) {
        debugPrint('[crash_report] FlutterEmailSender.send failed: $e');
      }
    }

    // Last resort: mailto (no attachments).
    // Keep this short; mailto URLs have practical length limits.
    final mailtoBody = () {
      const maxMailtoChars = 2000;
      final b = bodyWithLog.toString();
      if (b.length <= maxMailtoChars) return b;
      return '${b.substring(0, maxMailtoChars)}\n\n... (truncated, use Download for full log)';
    }();
    final uri = Uri(
      scheme: 'mailto',
      path: _crashReportEmail,
      queryParameters: {
        'subject': subject,
        'body': mailtoBody,
      },
    );
    final launched = await launchUrl(
      uri,
      mode: (Platform.isAndroid || Platform.isIOS)
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );

    return launched;
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
}
