import 'dart:convert';

/// Dosya içeriğini byte listesinden string'e dönüştürür.
/// UTF-8, UTF-16 ve çeşitli ANSI/Windows kodlamalarını tanır (CP1254 vb.).
Map<String, String> decodeFileContent(List<int> bytes) {
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
    // Strict decode dene, hata verirse ANSI'ye düş
    return {'content': utf8.decode(bytes), 'encoding': 'UTF-8'};
  } catch (_) {
    return _decodeAnsi(bytes);
  }
}

/// Compute isolate içinde koşturmak için wrapper
/// args: {'bytes': List of int, 'encoding': String}
String decodeChunkWithKnownEncoding(Map<String, dynamic> args) {
  final List<int> bytes = (args['bytes'] as List).cast<int>();
  final String encoding = (args['encoding'] as String?) ?? 'UTF-8';

  if (encoding.toUpperCase().startsWith('UTF-8')) {
    return utf8.decode(bytes, allowMalformed: true);
  }
  if (encoding.toUpperCase().startsWith('ASCII')) {
    return String.fromCharCodes(bytes);
  }
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

  // Fallback: best-effort
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return String.fromCharCodes(bytes);
  }
}

Map<String, String> _decodeAnsi(List<int> bytes) {
  int highByteCount = 0;
  Map<int, int> freq = {};
  for (int b in bytes) {
    if (b >= 0x80) {
      highByteCount++;
      freq[b] = (freq[b] ?? 0) + 1;
    }
  }

  if (highByteCount == 0) {
    return {'content': String.fromCharCodes(bytes), 'encoding': 'ASCII'};
  }

  // Rusça (CP1251) Skoru
  int ruScore = 0;
  for (int i = 0xE0; i <= 0xEF; i++) {
    ruScore += (freq[i] ?? 0);
  }

  // Arapça (CP1256) Kontrolü
  if ((freq[0xC7] ?? 0) > highByteCount * 0.05) {
    return {
      'content': _decodeTable(bytes, _cp1256Map),
      'encoding': 'Windows-1256 (Arabic)'
    };
  }

  // Rusça Kontrolü
  if (ruScore > (freq[0xE7] ?? 0) * 2 + 10) {
    return {
      'content': _decodeTable(bytes, _cp1251Map),
      'encoding': 'Windows-1251 (Cyrillic)'
    };
  }

  // Yunanca (CP1253) Kontrolü
  final greekDecoded = _decodeTable(bytes, _cp1253Map);
  final greekScore = _countGreekLetters(greekDecoded);
  if (greekScore > (highByteCount * 0.15).round()) {
    return {
      'content': greekDecoded,
      'encoding': 'Windows-1253 (Greek)'
    };
  }

  // Varsayılan Türkçe (CP1254)
  return {
    'content': _decodeCp1254(bytes),
    'encoding': 'Windows-1254 (Turkish)'
  };
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
        // ... Diğer karakterler ...
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
          sb.write('‘');
          break;
        case 0x92:
          sb.write('’');
          break;
        case 0x93:
          sb.write('“');
          break;
        case 0x94:
          sb.write('”');
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

int _countGreekLetters(String text) {
  int count = 0;
  for (final rune in text.runes) {
    if ((rune >= 0x0370 && rune <= 0x03FF) || (rune >= 0x1F00 && rune <= 0x1FFF)) {
      count++;
    }
  }
  return count;
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

// CP1251 (Cyrillic)
const String _cp1251Map =
    "ЂЃ‚ѓ„…†‡€‰Љ‹ЊЌЋЏђ‘’“”•–—™љ›њќћџ ЎўЈ¤Ґ¦§Ё©Є«¬­®Ї°±Ііґµ¶·ё№є»јЅѕїАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя";

// CP1256 (Arabic) - Bazı karakterler eksik/bozuk olabilir, örnek map
const String _cp1256Map =
    "€پ‚ƒ„…†‡ˆ‰ٹ‹Œچژڈگ‘’“”•–—ک™š›œ‌žŸ ،¢£¤¥¦§¨©ھ«¬­®¯°±²³´µ¶·¸¹؛»¼½¾؟ہءآأؤإئابةتثجحخدذرزسشصضطظعغـفقكàلâمنهوçèéêëىíîïðñòóôõö÷øùúûüýþÿ";

// CP1253 (Greek)
const String _cp1253Map =
  "€‚ƒ„…†‡ˆ‰Š‹Œ‘’“”•–—˜™š›œ ΅Ά£¤¥¦§¨©ª«¬­®¯°±²³΄µ¶·¸¹º»¼½¾¿ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩΪΫάέήίΰαβγδεζηθικλμνξοπρςστυφχψωΐϋόύώ";


/// Dropbox Api Arg header'ı için özel encode (ASCII-only header gerekliliği)
String encodeDropboxApiArg(Map<String, dynamic> arg) {
  final jsonString = jsonEncode(arg);
  final buffer = StringBuffer();
  for (final rune in jsonString.runes) {
    if (rune >= 0x20 && rune <= 0x7E) {
      buffer.writeCharCode(rune);
    } else if (rune <= 0xFFFF) {
      buffer.write('\\u');
      buffer.write(rune.toRadixString(16).padLeft(4, '0'));
    } else {
      final surrogate = rune - 0x10000;
      final high = 0xD800 + (surrogate >> 10);
      final low = 0xDC00 + (surrogate & 0x3FF);
      buffer.write('\\u');
      buffer.write(high.toRadixString(16).padLeft(4, '0'));
      buffer.write('\\u');
      buffer.write(low.toRadixString(16).padLeft(4, '0'));
    }
  }
  return buffer.toString();
}
