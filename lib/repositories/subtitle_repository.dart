import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:charset/charset.dart' as cs;
import 'package:enough_convert/enough_convert.dart' as ec;
import '../models/subtitle_block.dart';
import '../utils/background_runner.dart';

/// Altyazı dosyası işlemlerini yöneten repository
/// Parse etme, okuma, yazma ve encoding işlemleri
class SubtitleRepository {
  Function(String key, [String? param])? onLog;

  /// Dosyayı encoding tespiti ile oku
  Future<({String content, String encoding})> readFileWithEncoding(String path, {int? limit}) async {
    final file = File(path);
    List<int> bytes;
    
    if (limit != null) {
      final stream = file.openRead(0, limit);
      final BytesBuilder builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } else {
      bytes = await file.readAsBytes();
    }

    // Arka planda (isolate) çözümleme yap
    final result = await runInBackground(_decodeFileContent, bytes);
    return (content: result['content']!, encoding: result['encoding']!);
  }

  /// Dosyadan belirli bir aralıktaki byte'ları oku
  Future<List<int>> readFileBytesRange(
    String path, {
    required int start,
    required int length,
  }) async {
    if (start < 0) start = 0;
    if (length <= 0) return <int>[];

    final file = File(path);
    final int totalBytes = await file.length();
    if (start >= totalBytes) return <int>[];

    final int endExclusive = (start + length) > totalBytes ? totalBytes : (start + length);

    final stream = file.openRead(start, endExclusive);
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Bilinen encoding ile dosyadan chunk oku
  Future<String> readFileChunkWithKnownEncoding(
    String path, {
    required int start,
    required int length,
    required String encoding,
  }) async {
    final bytes = await readFileBytesRange(path, start: start, length: length);
    if (bytes.isEmpty) return '';
    return runInBackground(_decodeChunkWithKnownEncoding, {
      'bytes': bytes,
      'encoding': encoding,
    });
  }

  /// Önizleme için dosyayı encoding tespiti ile oku
  Future<({String content, String encoding, bool truncated, int totalBytes})> readFilePreviewWithEncoding(
    String path, {
    int limitBytes = 256 * 1024,
  }) async {
    final file = File(path);
    final int totalBytes = await file.length();
    final bool truncated = totalBytes > limitBytes;

    final result = await readFileWithEncoding(
      path,
      limit: truncated ? limitBytes : null,
    );

    return (
      content: result.content,
      encoding: result.encoding,
      truncated: truncated,
      totalBytes: totalBytes,
    );
  }

  /// Altyazı dosyasını parse et
  List<SubtitleBlock> parseSubtitle(String content) {
    List<SubtitleBlock> blocks = [];
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    List<String> lines = content.split('\n');

    String currentIdx = "";
    String currentTime = "";
    String currentText = "";

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.isEmpty) {
        if (currentTime.isNotEmpty && currentText.isNotEmpty) {
          final int idx = currentIdx.isEmpty
              ? blocks.length + 1
              : int.tryParse(currentIdx) ?? blocks.length + 1;
          blocks.add(SubtitleBlock(
            index: idx,
            timecode: currentTime,
            text: currentText.trim(),
          ));
          currentIdx = "";
          currentTime = "";
          currentText = "";
        }
        continue;
      }

      if (line.contains('-->')) {
        // Yeni bir zaman damgası bulundu
        if (currentTime.isNotEmpty && currentText.isNotEmpty) {
          final int idx = currentIdx.isEmpty
              ? blocks.length + 1
              : int.tryParse(currentIdx) ?? blocks.length + 1;
          blocks.add(SubtitleBlock(
            index: idx,
            timecode: currentTime,
            text: currentText.trim(),
          ));
          currentIdx = "";
          currentTime = "";
          currentText = "";
        }

        currentTime = line;

        // Bir önceki satır sayı ise, onu indeks olarak al (SRT formatı)
        if (i > 0) {
          String prev = lines[i - 1].trim();
          if (prev.isNotEmpty && int.tryParse(prev) != null) {
            currentIdx = prev;
          }
        }
        continue;
      }

      // Zaman damgası varsa, bu satır metindir
      if (currentTime.isNotEmpty) {
        currentText += "$line\n";
      }
    }

    // Son bloğu ekle
    if (currentTime.isNotEmpty && currentText.isNotEmpty) {
      final int idx = currentIdx.isEmpty
          ? blocks.length + 1
          : int.tryParse(currentIdx) ?? blocks.length + 1;
      blocks.add(SubtitleBlock(
        index: idx,
        timecode: currentTime,
        text: currentText.trim(),
      ));
    }

    return blocks;
  }

  /// Altyazı bloklarından SRT formatında string oluştur
  String buildSrtContent(List<SubtitleBlock> blocks) {
    final StringBuffer sb = StringBuffer();
    for (var block in blocks) {
      sb.writeln("${block.index}");
      sb.writeln(block.timecode);
      sb.writeln(block.text);
      sb.writeln();
    }
    return sb.toString();
  }

  /// Dosyayı kaydet
  Future<void> saveSubtitleFile(String path, List<SubtitleBlock> blocks) async {
    final content = buildSrtContent(blocks);
    final bytes = Uint8List.fromList(utf8.encode(content));
    await File(path).writeAsBytes(bytes, flush: true);
    onLog?.call('log_saved', path);
  }

  /// Dil son eki kaldır (dosya adından)
  String stripLanguageSuffix(String fileName) {
    // Örn: "movie_en.srt" -> "movie.srt"
    final commonSuffixes = ['_en', '_tr', '_es', '_fr', '_de', '_it', '_pt', '_ru', '_ar'];
    for (final suffix in commonSuffixes) {
      if (fileName.toLowerCase().contains(suffix)) {
        fileName = fileName.replaceAll(RegExp(suffix, caseSensitive: false), '');
      }
    }
    return fileName;
  }

  /// Zaman damgasını kaydır (ms cinsinden)
  String shiftTimecode(String timecode, int offsetMs) {
    try {
      // Format: 00:00:00,000 veya 00:00:00.000
      String clean = timecode.replaceAll(',', '.');
      List<String> parts = clean.split(':');
      if (parts.length == 3) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        List<String> sParts = parts[2].split('.');
        int s = int.parse(sParts[0]);
        int ms = 0;
        if (sParts.length > 1) {
          ms = int.parse(sParts[1]);
        }

        int total = h * 3600000 + m * 60000 + s * 1000 + ms;
        total += offsetMs;
        if (total < 0) total = 0;

        int newH = total ~/ 3600000;
        total %= 3600000;
        int newM = total ~/ 60000;
        total %= 60000;
        int newS = total ~/ 1000;
        int newMs = total % 1000;

        return "${newH.toString().padLeft(2, '0')}:"
            "${newM.toString().padLeft(2, '0')}:"
            "${newS.toString().padLeft(2, '0')},"
            "${newMs.toString().padLeft(3, '0')}";
      }
    } catch (_) {}
    return timecode;
  }

  /// Tüm blokların zaman damgasını kaydır
  void shiftAllTimecodes(List<SubtitleBlock> blocks, int offsetMs) {
    if (offsetMs == 0) return;

    for (var block in blocks) {
      List<String> parts = block.timecode.split('-->');
      if (parts.length == 2) {
        String start = shiftTimecode(parts[0].trim(), offsetMs);
        String end = shiftTimecode(parts[1].trim(), offsetMs);
        block.timecode = "$start --> $end";
      }
    }
  }

  /// Blokları yeniden numaralandır
  void renumberBlocks(List<SubtitleBlock> blocks) {
    for (int i = 0; i < blocks.length; i++) {
      blocks[i].index = i + 1;
    }
  }
}

// ============ TOP-LEVEL FUNCTIONS (for compute/isolate) ============

Map<String, String> _decodeFileContent(List<int> bytes) {
  // BOM detection
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return {'content': utf8.decode(bytes.sublist(3), allowMalformed: true), 'encoding': 'UTF-8 (BOM)'};
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return {'content': _decodeUtf16(bytes.sublist(2), true), 'encoding': 'UTF-16LE'};
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return {'content': _decodeUtf16(bytes.sublist(2), false), 'encoding': 'UTF-16BE'};
  }

  // Heuristic UTF-16 (no BOM)
  final utf16Guess = _guessUtf16(bytes);
  if (utf16Guess != null) {
    return {'content': _decodeUtf16(bytes, utf16Guess), 'encoding': utf16Guess ? 'UTF-16LE' : 'UTF-16BE'};
  }

  try {
    return {'content': utf8.decode(bytes), 'encoding': 'UTF-8'};
  } catch (_) {
    return _decodeWithGlobalCharsetDetection(bytes);
  }
}

String _decodeChunkWithKnownEncoding(Map<String, dynamic> args) {
  final List<int> bytes = (args['bytes'] as List).cast<int>();
  final String encoding = (args['encoding'] as String?) ?? 'UTF-8';

  final normalized = encoding.trim().toLowerCase();

  if (encoding.toUpperCase().startsWith('UTF-8')) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  if (encoding.toUpperCase().startsWith('ASCII')) {
    return String.fromCharCodes(bytes);
  }

  // Big5
  if (normalized.contains('big5')) {
    try {
      return ec.big5.decode(bytes);
    } catch (_) {
      // ignore
    }
  }

  // Use robust codec registry (Shift-JIS / EUC-JP / EUC-KR / GBK / ISO-8859-x / Windows-125x / etc)
  try {
    final codec = cs.Charset.getByName(normalized) ?? Encoding.getByName(encoding);
    if (codec != null) {
      // Many non-UTF codecs are strict; best-effort decode is fine for preview/chunks.
      return codec.decode(bytes);
    }
  } catch (_) {
    // ignore
  }

  // Legacy fallback to our small built-in tables (kept for safety/backward compatibility)
  if (encoding.contains('1256')) {
    return _decodeTable(bytes, _cp1256Map);
  }
  if (encoding.contains('1251')) {
    return _decodeTable(bytes, _cp1251Map);
  }
  if (encoding.contains('1253') || encoding.contains('8859-7')) {
    return _decodeTable(bytes, _cp1253Map);
  }
  if (encoding.contains('1254')) {
    return _decodeCp1254(bytes);
  }

  // Fallback
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return String.fromCharCodes(bytes);
  }
}

// NOTE: Previous narrow ANSI heuristics were replaced by
// `_decodeWithGlobalCharsetDetection` to support global encodings.

Map<String, String> _decodeWithGlobalCharsetDetection(List<int> bytes) {
  int highByteCount = 0;
  for (final b in bytes) {
    if (b >= 0x80) highByteCount++;
  }

  if (highByteCount == 0) {
    return {'content': String.fromCharCodes(bytes), 'encoding': 'ASCII'};
  }

  // Score only a sample for speed.
  final sample = bytes.length > (256 * 1024) ? bytes.sublist(0, 256 * 1024) : bytes;

  final candidates = <({String label, String Function() decode})>[
    // Multi-byte East Asian encodings
    (
      label: 'Shift-JIS',
      decode: () => cs.shiftJis.decode(sample),
    ),
    (
      label: 'EUC-JP',
      decode: () => cs.eucJp.decode(sample),
    ),
    (
      label: 'EUC-KR',
      decode: () => cs.eucKr.decode(sample),
    ),
    (
      label: 'GBK',
      decode: () => cs.gbk.decode(sample),
    ),
    (
      label: 'Big5',
      decode: () => ec.big5.decode(sample),
    ),

    // Windows code pages (common for subtitles)
    (
      label: 'Windows-1252',
      decode: () => cs.windows1252.decode(sample),
    ),
    (
      label: 'Windows-1251',
      decode: () => cs.windows1251.decode(sample),
    ),
    (
      label: 'Windows-1253',
      decode: () => cs.windows1253.decode(sample),
    ),
    (
      label: 'Windows-1254',
      decode: () => cs.windows1254.decode(sample),
    ),
    (
      label: 'Windows-1256',
      decode: () => cs.windows1256.decode(sample),
    ),
    (
      label: 'Windows-1250',
      decode: () => cs.windows1250.decode(sample),
    ),
    (
      label: 'Windows-1255',
      decode: () => cs.windows1255.decode(sample),
    ),
    (
      label: 'Windows-1257',
      decode: () => cs.windows1257.decode(sample),
    ),
    (
      label: 'Windows-1258',
      decode: () => cs.windows1258.decode(sample),
    ),
    (
      label: 'Windows-874',
      decode: () => cs.windows874.decode(sample),
    ),

    // ISO-8859 family (common legacy)
    (
      label: 'ISO-8859-1',
      decode: () => latin1.decode(sample),
    ),
    (
      label: 'ISO-8859-2',
      decode: () => cs.latin2.decode(sample),
    ),
    (
      label: 'ISO-8859-5',
      decode: () => cs.latinCyrillic.decode(sample),
    ),
    (
      label: 'ISO-8859-6',
      decode: () => cs.latinArabic.decode(sample),
    ),
    (
      label: 'ISO-8859-7',
      decode: () => cs.latinGreek.decode(sample),
    ),
    (
      label: 'ISO-8859-8',
      decode: () => cs.latinHebrew.decode(sample),
    ),
    (
      label: 'ISO-8859-9',
      decode: () => cs.latin5.decode(sample),
    ),
    (
      label: 'ISO-8859-15',
      decode: () => cs.latin9.decode(sample),
    ),
  ];

  String bestText = '';
  String bestLabel = 'Windows-1252';
  double bestScore = double.negativeInfinity;

  for (final candidate in candidates) {
    try {
      final text = candidate.decode();
      final score = _scoreDecodedText(text);
      if (score > bestScore) {
        bestScore = score;
        bestText = text;
        bestLabel = candidate.label;
      }
    } catch (_) {
      // ignore
    }
  }

  if (bestText.isEmpty) {
    // Absolute last resort
    return {'content': String.fromCharCodes(bytes), 'encoding': 'Binary'};
  }
  return {'content': bestText, 'encoding': bestLabel};
}

double _scoreDecodedText(String text) {
  final runes = text.runes;
  final total = runes.length;
  if (total == 0) return double.negativeInfinity;

  int replacement = 0;
  int controls = 0;
  int nonAscii = 0;
  int greek = 0;
  int cyrillic = 0;
  int arabic = 0;
  int hebrew = 0;
  int devanagari = 0;
  int thai = 0;
  int hangul = 0;
  int hiragana = 0;
  int katakana = 0;
  int cjk = 0;
  int latinExt = 0;

  for (final r in runes) {
    if (r == 0xFFFD) {
      replacement++;
      continue;
    }
    if (r > 0x7F) nonAscii++;

    if (r < 0x20 && r != 0x0A && r != 0x0D && r != 0x09) {
      controls++;
      continue;
    }
    if (r == 0x7F) {
      controls++;
      continue;
    }

    if ((r >= 0x0370 && r <= 0x03FF) || (r >= 0x1F00 && r <= 0x1FFF)) greek++;
    if ((r >= 0x0400 && r <= 0x04FF) || (r >= 0x0500 && r <= 0x052F)) cyrillic++;
    if ((r >= 0x0590 && r <= 0x05FF)) hebrew++;
    if ((r >= 0x0600 && r <= 0x06FF) || (r >= 0x0750 && r <= 0x077F) || (r >= 0x08A0 && r <= 0x08FF)) arabic++;
    if ((r >= 0x0900 && r <= 0x097F)) devanagari++;
    if ((r >= 0x0E00 && r <= 0x0E7F)) thai++;
    if ((r >= 0x1100 && r <= 0x11FF) || (r >= 0xAC00 && r <= 0xD7AF)) hangul++;
    if ((r >= 0x3040 && r <= 0x309F)) hiragana++;
    if ((r >= 0x30A0 && r <= 0x30FF) || (r >= 0x31F0 && r <= 0x31FF)) katakana++;
    if ((r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF)) cjk++;
    if ((r >= 0x00C0 && r <= 0x024F)) latinExt++;
  }

  final scriptBonus =
      (cjk + hangul + hiragana + katakana) * 3 +
      (arabic + hebrew + greek + cyrillic + devanagari + thai) * 2 +
      latinExt;

  // Heavy penalties for obviously broken decodes.
  final replacementRatio = replacement / total;
  final controlRatio = controls / total;

  double score = 0;
  score += scriptBonus.toDouble();
  score += (nonAscii * 0.2);
  score -= replacement * 25.0;
  score -= controls * 10.0;

  if (replacementRatio > 0.02) score -= 500.0;
  if (controlRatio > 0.01) score -= 250.0;

  return score;
}

String _decodeTable(List<int> bytes, String map) {
  StringBuffer sb = StringBuffer();
  for (int b in bytes) {
    if (b < 128) {
      sb.writeCharCode(b);
    } else {
      int index = b - 128;
      if (index >= 0 && index < map.length) {
        sb.write(map[index]);
      } else {
        sb.writeCharCode(b);
      }
    }
  }
  return sb.toString();
}

String _decodeCp1254(List<int> bytes) {
  StringBuffer sb = StringBuffer();
  for (int b in bytes) {
    if (b < 128) {
      sb.writeCharCode(b);
    } else {
      switch (b) {
        case 0xD0:
          sb.write('Ğ');
          break;
        case 0xDD:
          sb.write('İ');
          break;
        case 0xDE:
          sb.write('Ş');
          break;
        case 0xF0:
          sb.write('ğ');
          break;
        case 0xFD:
          sb.write('ı');
          break;
        case 0xFE:
          sb.write('ş');
          break;
        case 0x80:
          sb.write('€');
          break;
        case 0x82:
          sb.write('‚');
          break;
        case 0x83:
          sb.write('ƒ');
          break;
        case 0x84:
          sb.write('„');
          break;
        case 0x85:
          sb.write('…');
          break;
        case 0x86:
          sb.write('†');
          break;
        case 0x87:
          sb.write('‡');
          break;
        case 0x88:
          sb.write('ˆ');
          break;
        case 0x89:
          sb.write('‰');
          break;
        case 0x8A:
          sb.write('Š');
          break;
        case 0x8B:
          sb.write('‹');
          break;
        case 0x8C:
          sb.write('Œ');
          break;
        case 0x91:
          sb.write(''');
          break;
        case 0x92:
          sb.write(''');
          break;
        case 0x93:
          sb.write('"');
          break;
        case 0x94:
          sb.write('"');
          break;
        case 0x95:
          sb.write('•');
          break;
        case 0x96:
          sb.write('–');
          break;
        case 0x97:
          sb.write('—');
          break;
        case 0x98:
          sb.write('˜');
          break;
        case 0x99:
          sb.write('™');
          break;
        case 0x9A:
          sb.write('š');
          break;
        case 0x9B:
          sb.write('›');
          break;
        case 0x9C:
          sb.write('œ');
          break;
        case 0x9F:
          sb.write('Ÿ');
          break;
        default:
          sb.writeCharCode(b);
      }
    }
  }
  return sb.toString();
}

bool? _guessUtf16(List<int> bytes) {
  if (bytes.length < 4) return null;
  int evenZero = 0;
  int oddZero = 0;
  int sample = 0;
  for (int i = 0; i < bytes.length && i < 2000; i++) {
    if (bytes[i] == 0) {
      if (i.isEven) {
        evenZero++;
      } else {
        oddZero++;
      }
    }
    sample++;
  }
  if (sample == 0) return null;
  final evenRatio = evenZero / sample;
  final oddRatio = oddZero / sample;
  if (evenRatio > 0.2 && oddRatio < 0.05) return true; // LE
  if (oddRatio > 0.2 && evenRatio < 0.05) return false; // BE
  return null;
}

String _decodeUtf16(List<int> bytes, bool littleEndian) {
  final codeUnits = <int>[];
  for (int i = 0; i + 1 < bytes.length; i += 2) {
    final int unit = littleEndian
        ? (bytes[i] | (bytes[i + 1] << 8))
        : ((bytes[i] << 8) | bytes[i + 1]);
    codeUnits.add(unit);
  }
  return String.fromCharCodes(codeUnits);
}

const String _cp1251Map =
    "ЂЃ‚ѓ„…†‡€‰Љ‹ЊЌЋЏђ''""•–—™љ›њќћџ ЎўЈ¤Ґ¦§Ё©Є«¬­®Ї°±Ііґµ¶·ё№є»јЅѕїАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя";
const String _cp1256Map =
    "€پ‚ƒ„…†‡ˆ‰ٹ‹Œچژڈگ''""•–—ک™š›œ‌žŸ ،¢£¤¥¦§¨©ھ«¬­®¯°±²³´µ¶·¸¹؛»¼½¾؟ہءآأؤإئابةتثجحخدذرزسشصضطظعغـفقكàلâمنهوçèéêëىíîïðñòóôõö÷øùúûüýþÿ";
const String _cp1253Map =
  "€�‚ƒ„…†‡ˆ‰Š‹Œ���‘’“”•–—˜™š›œ��� ΅Ά£¤¥¦§¨©ª«¬­®¯°±²³΄µ¶·¸¹º»¼½¾¿ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡ�ΣΤΥΦΧΨΩΪΫάέήίΰαβγδεζηθικλμνξοπρςστυφχψωΐϋόύώ��";
