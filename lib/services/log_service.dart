import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/cloud_file_info.dart';

class LogService {
  String formatLogLine(
    LogEntry log,
    Map<String, String> translations,
    String language, {
    bool includeTime = true,
  }) {
    final logText = translations[log.key] ?? log.key;
    final timePrefix = includeTime ? '${log.time} - ' : '';
    var line = '$timePrefix$logText';

    if (log.param != null && log.param!.isNotEmpty) {
      final paramKey = log.param!;
      Map<String, dynamic>? paramMap;
      if (paramKey.startsWith('{') && paramKey.endsWith('}')) {
        try {
          final decoded = jsonDecode(paramKey);
          if (decoded is Map<String, dynamic>) {
            paramMap = decoded;
          }
        } catch (_) {
          paramMap = null;
        }
      }

      if (paramMap != null && logText.contains('{')) {
        var rendered = logText;
        paramMap.forEach((key, value) {
          rendered = rendered.replaceAll('{$key}', '$value');
        });
        line = '$timePrefix$rendered';
        return line;
      }

      final translatedParam = translations[paramKey];
      if (translatedParam != null) {
        line += ': $translatedParam';
      } else {
        line += ': $paramKey';
      }
    }

    return line;
  }

  String buildLogsContent(
    List<LogEntry> logs,
    Map<String, String> translations,
    String language,
  ) {
    StringBuffer sb = StringBuffer();
    sb.writeln("${translations['system_logs'] ?? 'System Logs'} - ${DateTime.now()}");
    sb.writeln("--------------------------------");
    for (var log in logs) {
      sb.writeln(formatLogLine(log, translations, language));
    }
    return sb.toString();
  }

  String buildLogsFileName() {
    return "system_log_${DateTime.now().millisecondsSinceEpoch}.txt";
  }

  Future<void> copyLogsToClipboard(
    List<LogEntry> logs, 
    Map<String, String> translations,
    String language,
    Function(String key, [String? param]) addLog,
  ) async {
    try {
      final content = buildLogsContent(logs, translations, language);
      await Clipboard.setData(ClipboardData(text: content));
      addLog("log_copied");
    } catch (e) {
      addLog("log_error", e.toString());
    }
  }

  Future<void> saveLogsToFile(
    List<LogEntry> logs,
    Map<String, String> translations,
    String language,
    Function(String key, [String? param]) addLog,
  ) async {
    final content = buildLogsContent(logs, translations, language);
    final fileName = buildLogsFileName();
    final bytes = Uint8List.fromList(utf8.encode(content));
    final isAndroidIos = Platform.isAndroid || Platform.isIOS;
    String? f = await FilePicker.platform.saveFile(
      dialogTitle: translations["save_log"] ?? 'Save Logs',
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

  Future<void> shareLogs(
    List<LogEntry> logs,
    Map<String, String> translations,
    String language,
    Function(String key, [String? param]) addLog,
  ) async {
    try {
      final content = buildLogsContent(logs, translations, language);
      final fileName = buildLogsFileName();
      final bytes = Uint8List.fromList(utf8.encode(content));
      final xfile = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'text/plain',
      );
      await SharePlus.instance.share(
        ShareParams(files: [xfile]),
      );
    } catch (e) {
      addLog("log_error", e.toString());
    }
  }
}
