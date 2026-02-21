import 'package:flutter/services.dart';

class StringUtils {
  static String fillTemplate(String template, Map<String, String> params) {
    var out = template;
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }

  static String stripLanguageSuffix(String filename) {
    const languages = [
      "English", "Turkish", "German", "French", "Spanish", "Italian",
      "Russian", "Portuguese", "Dutch", "Polish", "Czech", "Swedish",
      "Danish", "Finnish", "Norwegian", "Hungarian", "Greek", "Romanian",
      "Bulgarian", "Croatian", "Serbian", "Ukrainian", "Slovak", "Slovenian",
      "Hebrew", "Arabic", "Hindi", "Thai", "Korean", "Japanese", "Chinese",
      "Vietnamese", "Indonesian", "Malay", "Farsi", "Persian",
      "EN", "TR", "DE", "FR", "ES", "IT", "RU", "PT", "NL", "PL", "CZ",
      "SV", "DA", "FI", "NO", "HU", "EL", "RO", "BG", "HR", "SR", "UK", "SK", "SL",
      "HE", "AR", "HI", "IN", "TH", "KO", "JA", "ZH", "CN", "VI", "ID", "MS", "FA",
    ];

    var result = filename;
    for (var lang in languages) {
      final patterns = [
        '.$lang.',
        '.$lang',
        '[$lang]',
        '($lang)',
        ' $lang ',
        ' $lang.',
        '.$lang ',
        '_$lang.',
        '_$lang',
        '-$lang.',
        '-$lang',
      ];
      for (var p in patterns) {
        final lowerResult = result.toLowerCase();
        final lowerPattern = p.toLowerCase();
        int idx = lowerResult.indexOf(lowerPattern);
        if (idx != -1) {
          final endIdx = idx + p.length;
          // Guard: if the character right after the match is a letter,
          // this is a partial word match (e.g. ".TH" matching ".The")
          // — skip it to avoid corrupting the filename.
          if (endIdx < result.length &&
              RegExp(r'[a-zA-Z]').hasMatch(result[endIdx])) {
            continue;
          }
          result = result.substring(0, idx) +
              result.substring(endIdx);
        }
      }
    }

    return result.trim();
  }

  static String stripGeneratedPrefixAndHash(String nameWithoutExtension) {
    // UI/file history may include generated prefixes/suffixes.
    // Example:
    //   1712345678_movie_en_0123abcd... -> movie_en
    final withoutTimestamp = nameWithoutExtension.replaceFirst(
      RegExp(r'^\d{10,}_'),
      '',
    );
    return withoutTimestamp.replaceFirst(
      RegExp(r'_[a-f0-9]{32}$', caseSensitive: false),
      '',
    );
  }

  /// Normalizes a potentially-generated filename for display.
  ///
  /// Removes common generated hash suffixes like:
  /// - `_0123abcd...` (md5/sha1 style)
  /// - `_localcache_0123abcd...`
  ///
  /// Keeps the original extension (if any).
  static String normalizeDisplayFileName(String rawName) {
    final leaf = rawName.split(RegExp(r'[\\/]')).last.trim();
    if (leaf.isEmpty) return rawName;

    final dot = leaf.lastIndexOf('.');
    final hasExt = dot > 0 && dot < leaf.length - 1;
    final ext = hasExt ? leaf.substring(dot) : '';
    final nameWithoutExt = hasExt ? leaf.substring(0, dot) : leaf;

    var base = stripGeneratedPrefixAndHash(nameWithoutExt);
    // Remove our generated local-cache suffix.
    base = base.replaceFirst(
      RegExp(r'_(?:localcache|cloudcache|resume)_[a-f0-9]{24,64}$',
          caseSensitive: false),
      '',
    );
    // Generic long-hex suffix (avoid stripping short numeric suffixes like years).
    base = base.replaceFirst(
      RegExp(r'_[a-f0-9]{24,64}$', caseSensitive: false),
      '',
    );

    final outBase = base.trim().isEmpty ? nameWithoutExt.trim() : base.trim();
    return '$outBase$ext';
  }

  static String formatGoogleSignInError(Object e) {
    if (e is PlatformException) {
      final code = e.code;
      final message = e.message ?? '';
      final details = e.details;

      final msgLower = message.toLowerCase();
      final isDeveloperError = msgLower.contains('apiexception: 10') ||
          msgLower.contains('developer_error');

      final hint = isDeveloperError
          ? ' (Android OAuth Hatası: 1. SHA-1 imzasını Firebase konsoluna ekleyin. 2. google-services.json dosyasını güncelleyip clean yapın. 3. Firebase Proje Ayarlarında "Destek e-postası" seçili olmalı.)'
          : '';

      return 'PlatformException($code): ${message.isEmpty ? '(no message)' : message}'
          '${details == null ? '' : ' details=$details'}$hint';
    }
    return e.toString();
  }

  static String getFullLanguageName(String code) {
    const map = {
      "TR": "Turkish",
      "EN": "English",
      "DE": "German",
      "FR": "French",
      "ES": "Spanish",
      "IT": "Italian",
      "PT": "Portuguese",
      "RU": "Russian",
      "EL": "Greek",
      "AR": "Arabic",
      "IN": "Hindi",
      "ID": "Indonesian",
      "CN": "Chinese",
      "JA": "Japanese",
      "KO": "Korean",
      "NL": "Dutch",
      "SV": "Swedish",
      "PL": "Polish",
      "TH": "Thai",
      "VI": "Vietnamese",
      "HE": "Hebrew",
      "FA": "Persian",
      "TA": "Tamil",
      "TE": "Telugu",
      "ML": "Malayalam",
      "KN": "Kannada",
      "PA": "Punjabi",
      "GU": "Gujarati",
      "MR": "Marathi",
    };
    return map[code] ?? code;
  }

  static bool isSubtitleFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.srt') || lower.endsWith('.vtt');
  }
}
