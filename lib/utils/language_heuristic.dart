import 'dart:io';

class LanguageHeuristic {
  static const Map<String, List<String>> _stopWords = {
    'TR': [
      've',
      'bir',
      'bu',
      'da',
      'de',
      'için',
      'ile',
      'çok',
      'olarak',
      'gibi',
      'en',
      'daha',
      'olan',
      'ama',
      'ben',
      'sen',
      'var',
      'yok',
      'ne'
    ],
    'EN': [
      'the',
      'and',
      'to',
      'of',
      'in',
      'is',
      'that',
      'it',
      'for',
      'you',
      'on',
      'with',
      'as',
      'are',
      'be',
      'this',
      'was',
      'have',
      'but'
    ],
    'ES': [
      'el',
      'la',
      'de',
      'que',
      'en',
      'un',
      'se',
      'los',
      'no',
      'por',
      'con',
      'su',
      'para',
      'una',
      'es',
      'como',
      'más',
      'pero'
    ],
    'FR': [
      'de',
      'la',
      'le',
      'et',
      'les',
      'des',
      'en',
      'un',
      'du',
      'une',
      'est',
      'pour',
      'que',
      'dans',
      'il',
      'au',
      'ne',
      'pas'
    ],
    'DE': [
      'der',
      'die',
      'und',
      'in',
      'den',
      'von',
      'zu',
      'das',
      'mit',
      'sich',
      'auf',
      'für',
      'ist',
      'nicht',
      'ein',
      'im',
      'dem',
      'dass'
    ],
    'IT': [
      'di',
      'e',
      'il',
      'la',
      'che',
      'in',
      'un',
      'a',
      'non',
      'per',
      'una',
      'è',
      'con',
      'le',
      'lo',
      'come',
      'ma',
      'si'
    ],
    'RU': [
      'и',
      'в',
      'не',
      'на',
      'я',
      'быть',
      'с',
      'он',
      'что',
      'а',
      'по',
      'это',
      'она',
      'этот',
      'к',
      'но',
      'они',
      'мы',
      'как'
    ],
    'AR': [
      'في',
      'من',
      'على',
      'الى',
      'لا',
      'ان',
      'ما',
      'عن',
      'ولا',
      'قد',
      'أو',
      'كان',
      'هذا',
      'لم',
      'مع',
      'كل',
      'هو',
      'انا'
    ],
  };

  static Future<bool> isLikelyTargetLanguage(
      List<File> files, String targetLang) async {
    if (files.isEmpty) return false;

    final code = targetLang.toUpperCase();
    final lowerCode = code.toLowerCase();

    // Check filename first for common patterns
    for (var f in files) {
      final name = f.path.toLowerCase();
      if (name.endsWith('.$lowerCode.srt') ||
          name.endsWith('_$lowerCode.srt') ||
          name.endsWith('-$lowerCode.srt')) {
        return true;
      }
    }

    final words = _stopWords[code];
    if (words == null) return false;

    try {
      final text = await files.first.readAsString();
      final cleanText = text.toLowerCase();

      int matchCount = 0;
      for (final w in words) {
        final pattern = RegExp('\\b$w\\b');
        matchCount += pattern.allMatches(cleanText).length;
      }

      double threshold = (cleanText.length / 400).clamp(3.0, 100.0);
      return matchCount > threshold;
    } catch (e) {
      return false;
    }
  }
}
