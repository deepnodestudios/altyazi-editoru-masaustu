import 'dart:convert';

import '../constants/ai_language_options.dart';

/// Detects obvious off-target language in a translated SRT/dialogue chunk.
///
/// Primary known failure mode: model drifts into Turkish because system prompts
/// used to be Turkish. Keep checks conservative to avoid false retries.
bool translationLooksOffTarget(String srtOrText, String targetLanguage) {
  final code = normalizeAiPanelLanguageCode(targetLanguage);
  final dialogue = extractSubtitleDialogueText(srtOrText);
  if (dialogue.trim().length < 60) return false;

  // Known bleed: Turkish output when the user asked for another language.
  if (code != 'TR' && _looksStronglyTurkish(dialogue)) {
    return true;
  }
  return false;
}

String extractSubtitleDialogueText(String srtOrText) {
  final lines = const LineSplitter().convert(srtOrText);
  final buffer = StringBuffer();
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (RegExp(r'^\d+$').hasMatch(line)) continue;
    if (line.contains('-->')) continue;
    buffer.writeln(line);
  }
  return buffer.toString();
}

String wrongLanguageRetryHint({
  required String? existingContextHint,
  required String targetLanguage,
}) {
  final fullName = aiPanelLanguagePromptNameForCode(targetLanguage);
  final targetLabel =
      fullName.isNotEmpty ? fullName : targetLanguage.trim();
  final reminder =
      'CRITICAL RETRY: The previous output used the wrong language. '
      'Translate EVERY subtitle line into $targetLabel only. '
      'Do not write Turkish (or any other language) unless $targetLabel is that language.';
  final existing = (existingContextHint ?? '').trim();
  if (existing.isEmpty) return reminder;
  return '$existing\n$reminder';
}

bool _looksStronglyTurkish(String text) {
  final specificChars = RegExp(r'[ğĞşŞıİ]').allMatches(text).length;
  final letters = RegExp(r'[A-Za-zÀ-öø-ÿĀ-ſĞğİıŞş]').allMatches(text).length;
  if (letters < 40) return false;

  // Distinctive Turkish words / forms unlikely in Hungarian and most Latin targets.
  const distinctive = <String>[
    'için',
    'değil',
    'lütfen',
    'tamam',
    'tamamdır',
    'hayır',
    'neden',
    'benim',
    'senin',
    'olarak',
    'şimdi',
    'bırak',
    'lanet',
    'anladın',
    'yukarı',
    'defol',
    'hiçbir',
    'çünkü',
    'söylüyorsun',
    'olası',
    'gururunu',
    'koğuş',
    'uslu',
    'şunu',
    'bunu',
    'şey',
    'değilim',
    'misin',
    'musun',
    'mısın',
    'müsün',
  ];

  final lower = text.toLowerCase();
  var wordHits = 0;
  for (final word in distinctive) {
    if (RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lower)) {
      wordHits++;
    }
  }

  if (specificChars >= 8 && specificChars / letters >= 0.012) return true;
  if (specificChars >= 3 && wordHits >= 4) return true;
  if (wordHits >= 6) return true;
  return false;
}
