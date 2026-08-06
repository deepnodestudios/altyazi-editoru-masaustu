// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'dart:io';

/// Adds new translation keys to all per-language translation files.
void main() {
  // New keys to add to EVERY language file.
  // Values are provided per-language where available; EN fallback otherwise.
    final Map<String, Map<String, String>> newKeys = {
        'batch_cloud_processing_text': {
      'TR': 'Çeviri sunucuda devam ediyor...',
      'EN': 'Translation continues on server...',
      'FR': 'La traduction continue sur le serveur...',
      'DE': 'Die Übersetzung wird auf dem Server fortgesetzt...',
      'IT': 'La traduzione continua sul server...',
      'ES': 'La traducción continúa en el servidor...',
      'PT': 'A tradução continua no servidor...',
      'RU': 'Перевод продолжается на сервере...',
      'EL': 'Η μετάφραση συνεχίζεται στον διακομιστή...',
      'AR': 'يستمر الترجمة على الخادم...',
      'IN': 'अनुवाद 계속 हो रहा है सर्वर पर...',
      'ID': 'Terjemahan berlanjut di peladen...',
      'CN': '翻译在服务器上继续...',
      'JA': 'サーバーで翻訳が続いています...',
      'KO': '서버에서 번역이 계속됩니다...',
      'PL': 'Traducerea żyje pe serwerze...',
      'RO': 'Traducerea continuă pe server...',
      'HU': 'Fordítás folytatódik a szerveren...',
      'DA': 'Oversættelsen fortsætter på serveren...'
    },
    'batch_starting_snackbar': {
      'TR': '{count} dosya için Toplu Çeviri başlatılıyor...',
      'EN': 'Batch Translation started for {count} files...',
      'FR': 'Traduction par lots lancée pour {count} fichiers...',
      'ES': 'Traducción por lotes iniciada para {count} archivos...',
      'DE': 'Stapelübersetzung für {count} Dateien gestartet...',
      'IT': 'Traduzione in blocco avviata per {count} file...',
      'PT': 'Tradução em lote iniciata para {count} arquivos...',
      'RU': 'Пакетный перевод запущен для {count} файлов...',
      'ZH': '已为 {count} 个文件启动批量翻译...',
      'JA': '{count} ファイルのバッチ翻訳が開始されました...',
      'AR': 'تم بدء الترجمة الجماعية لـ {count} ملفات...',
      'HI': '{count} फ़ाइलों के लिए बैच अनुवाद शुरू हुआ...',
    },
  };


  final allLangs = [
    'EN', 'FR', 'DE', 'IT', 'ES', 'PT', 'RU', 'EL',
    'AR', 'IN', 'ID', 'CN', 'JA', 'KO', 'TR',
    'NL', 'SV', 'PL', 'HE', 'FA', 'TH', 'VI',
    'TA', 'TE', 'ML', 'KN', 'PA', 'GU', 'MR',
    'CS', 'DA', 'RO', 'UK',
  ];

  for (final lang in allLangs) {
    final lc = lang.toLowerCase();
    final file = File('lib/translations/translations_$lc.dart');
    if (!file.existsSync()) {
      print('SKIP: ${file.path} not found');
      continue;
    }

    var content = file.readAsStringSync();

    // Find the last entry line (before the closing '};')
    final closingIndex = content.lastIndexOf('};');
    if (closingIndex == -1) {
      print('SKIP: ${file.path} — closing }; not found');
      continue;
    }

    final newEntries = StringBuffer();
    for (final entry in newKeys.entries) {
      final key = entry.key;
      // Skip if key already exists
      if (content.contains("'$key':")) continue;

      final value = (entry.value[lang] ?? entry.value['EN'] ?? '')
          .replaceAll('\\', '\\\\')
          .replaceAll('\$', '\\\$')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');
      newEntries.writeln("  '$key': '$value',");
    }

    if (newEntries.isEmpty) {
      print('SKIP: $lang — all keys already exist');
      continue;
    }

    content = content.substring(0, closingIndex) +
        newEntries.toString() +
        content.substring(closingIndex);
    file.writeAsStringSync(content);
    print('Updated: translations_$lc.dart');
  }

  print('\nDone adding new keys.');
}
