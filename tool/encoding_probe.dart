import 'dart:io';

import 'package:altyazi_editoru/repositories/subtitle_repository.dart';

int _countGreek(String s) {
  var count = 0;
  for (final rune in s.runes) {
    // Greek and Coptic: U+0370..U+03FF
    // Greek Extended:  U+1F00..U+1FFF
    if ((rune >= 0x0370 && rune <= 0x03FF) || (rune >= 0x1F00 && rune <= 0x1FFF)) {
      count++;
    }
  }
  return count;
}

int _countReplacement(String s) {
  var count = 0;
  for (final rune in s.runes) {
    if (rune == 0xFFFD) count++;
  }
  return count;
}

int _countCyrillic(String s) {
  var count = 0;
  for (final rune in s.runes) {
    // Cyrillic: U+0400..U+04FF
    // Cyrillic Supplement: U+0500..U+052F
    if ((rune >= 0x0400 && rune <= 0x04FF) || (rune >= 0x0500 && rune <= 0x052F)) {
      count++;
    }
  }
  return count;
}

int _countArabic(String s) {
  var count = 0;
  for (final rune in s.runes) {
    // Arabic: U+0600..U+06FF
    // Arabic Supplement: U+0750..U+077F
    // Arabic Extended-A: U+08A0..U+08FF
    if ((rune >= 0x0600 && rune <= 0x06FF) || (rune >= 0x0750 && rune <= 0x077F) || (rune >= 0x08A0 && rune <= 0x08FF)) {
      count++;
    }
  }
  return count;
}

void _printSample(String label, String encoding, String content) {
  final greek = _countGreek(content);
  final cyr = _countCyrillic(content);
  final arabic = _countArabic(content);
  final repl = _countReplacement(content);
  final total = content.runes.length;
  final preview = content.substring(0, content.length < 160 ? content.length : 160);

  final greekWordScore = _countGreekStopwords(content);
  final russianWordScore = _countRussianStopwords(content);

  stdout.writeln('[$label] $encoding');
  stdout.writeln(
    '  Chars: $total | Greek: $greek | Cyrillic: $cyr | Arabic: $arabic | Replacement(\uFFFD): $repl | GreekWords: $greekWordScore | RuWords: $russianWordScore',
  );
  stdout.writeln('  Preview: ${preview.replaceAll('\n', '↵')}');
}

int _countGreekStopwords(String s) {
  final text = s.toLowerCase();
  // Very common Greek words (rough heuristic).
  const words = <String>[
    'και',
    'να',
    'το',
    'την',
    'που',
    'με',
    'σε',
    'για',
    'δεν',
    'ειναι',
    'είναι',
  ];
  var score = 0;
  for (final w in words) {
    score += _countOccurrences(text, w);
  }
  return score;
}

int _countRussianStopwords(String s) {
  final text = s.toLowerCase();
  // Common Russian words (avoid single-letter tokens).
  const words = <String>[
    'что',
    'это',
    'как',
    'мне',
    'тебя',
    'нет',
    'да',
    'не',
    'она',
    'он',
  ];
  var score = 0;
  for (final w in words) {
    score += _countOccurrences(text, w);
  }
  return score;
}

int _countOccurrences(String text, String needle) {
  var count = 0;
  var start = 0;
  while (true) {
    final idx = text.indexOf(needle, start);
    if (idx == -1) break;
    count++;
    start = idx + needle.length;
  }
  return count;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/encoding_probe.dart <path-to-srt>');
    exitCode = 64;
    return;
  }

  final path = args.join(' ');
  final repo = SubtitleRepository();

  final detected = await repo.readFileWithEncoding(path, limit: 256 * 1024);
  stdout.writeln('Path: $path');
  stdout.writeln('Detected encoding: ${detected.encoding}');
  _printSample('Detected', detected.encoding, detected.content);

  // Compare a few likely candidates for debugging.
  final sampleUtf8 = await repo.readFileChunkWithKnownEncoding(
    path,
    start: 0,
    length: 64 * 1024,
    encoding: 'UTF-8',
  );
  final sample1253 = await repo.readFileChunkWithKnownEncoding(
    path,
    start: 0,
    length: 64 * 1024,
    encoding: 'Windows-1253',
  );
  final sample1251 = await repo.readFileChunkWithKnownEncoding(
    path,
    start: 0,
    length: 64 * 1024,
    encoding: 'Windows-1251',
  );
  final sample1254 = await repo.readFileChunkWithKnownEncoding(
    path,
    start: 0,
    length: 64 * 1024,
    encoding: 'Windows-1254',
  );
  final sample1256 = await repo.readFileChunkWithKnownEncoding(
    path,
    start: 0,
    length: 64 * 1024,
    encoding: 'Windows-1256',
  );

  stdout.writeln('--- Candidate comparison (first 64KB) ---');
  _printSample('UTF8', 'UTF-8', sampleUtf8);
  _printSample('1253', 'Windows-1253', sample1253);
  _printSample('1251', 'Windows-1251', sample1251);
  _printSample('1254', 'Windows-1254', sample1254);
  _printSample('1256', 'Windows-1256', sample1256);
}
