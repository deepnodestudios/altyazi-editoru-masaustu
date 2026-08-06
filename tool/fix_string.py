with open("lib/utils/string_utils.dart", "r", encoding="utf-8") as f:
    text = f.read()

methods = """
  static final RegExp _hex32 = RegExp(r'^[a-fA-F0-9]{32}$');

  static String hideHashAndMarkersInFileName(String fileName) {
    if (fileName.trim().isEmpty) return fileName;

    final extMatch = RegExp(r'(\.[^.]+)$').firstMatch(fileName);
    final ext = extMatch?.group(1) ?? '';
    var base = ext.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - ext.length);

    // Remove generated leading timestamp if present.
    base = base.replaceFirst(RegExp(r'^\d{10,}_'), '');

    final parts = base.split('_').where((p) => p.isNotEmpty).toList();
    while (parts.isNotEmpty) {
      final last = parts.last;
      final lower = last.toLowerCase();
      if (lower == 'cloud' || _hex32.hasMatch(last)) {
        parts.removeLast();
        continue;
      }
      break;
    }

    final cleanedBase = parts.isEmpty ? base : parts.join('_');
    return '$cleanedBase$ext';
  }

  static String buildTranslatedSubtitleFileName({
    required String fileName,
    required String targetLanguage,
  }) {
    final extMatch = RegExp(r'(\.[^.]+)$').firstMatch(fileName);
    final ext = extMatch?.group(1) ?? '';
    final base = ext.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - ext.length);

    final noGenerated = stripGeneratedPrefixAndHash(base);
    final stripped = stripLanguageSuffix(noGenerated);

    final safeExt = ext.isNotEmpty ? ext : '.srt';
    return '${stripped}_$targetLanguage$safeExt';
  }
"""

if "hideHashAndMarkersInFileName" not in text:
    last_brace = text.rfind("}")
    new_text = text[:last_brace] + methods + "\n" + text[last_brace:]
    with open("lib/utils/string_utils.dart", "w", encoding="utf-8") as f:
        f.write(new_text)
