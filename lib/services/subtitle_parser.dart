import 'dart:convert';
import '../models/subtitle_block.dart';

class SubtitleParser {
  static final RegExp _sdhRegex = RegExp(r'\(.*?\)|\[.*?\]');
  static final RegExp _multiNewLineRegex = RegExp(r'\n+');
  static final RegExp _hasMeaningfulTextRegex = RegExp(
    r'[\p{L}\p{N}]',
    unicode: true,
  );

  static String normalizeSdhCleanedText(String text) {
    final cleaned = text.replaceAll(_sdhRegex, '').trim();
    return cleaned.replaceAll(_multiNewLineRegex, '\n').trim();
  }

  static bool hasMeaningfulDialogueText(String text) {
    return _hasMeaningfulTextRegex.hasMatch(text);
  }

  static int? parseTimestampToMs(String value) {
    // Supports SRT/VTT-like timestamps:
    // - HH:MM:SS,mmm
    // - HH:MM:SS.mmm
    // - HH:MM:SS (no millis)
    // Also tolerates extra cue settings after the timestamp (VTT).
    final token = value.trim().split(RegExp(r'\s+')).first;
    final m = RegExp(r'^(\d{1,3}):(\d{2}):(\d{2})(?:[\.,](\d{1,3}))?$')
        .firstMatch(token);
    if (m == null) return null;

    final h = int.tryParse(m.group(1) ?? '');
    final min = int.tryParse(m.group(2) ?? '');
    final sec = int.tryParse(m.group(3) ?? '');
    if (h == null || min == null || sec == null) return null;

    final msRaw = m.group(4);
    int ms = 0;
    if (msRaw != null && msRaw.isNotEmpty) {
      final parsed = int.tryParse(msRaw);
      if (parsed == null) return null;
      // Normalize to milliseconds precision (right-pad).
      if (msRaw.length == 1) {
        ms = parsed * 100;
      } else if (msRaw.length == 2) {
        ms = parsed * 10;
      } else {
        ms = parsed;
      }
    }

    return h * 3600000 + min * 60000 + sec * 1000 + ms;
  }

  static int maxTimecodeMsFromBlocks(List<SubtitleBlock> blocks) {
    var maxMs = -1;
    for (final block in blocks) {
      final parts = block.timecode.split('-->');
      if (parts.length != 2) continue;

      final startMs = parseTimestampToMs(parts[0]);
      final endMs = parseTimestampToMs(parts[1]);
      if (startMs != null && startMs > maxMs) maxMs = startMs;
      if (endMs != null && endMs > maxMs) maxMs = endMs;
    }
    return maxMs;
  }
  
  static bool isSubtitleFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.srt') || lower.endsWith('.vtt');
  }

  static String generateOutputFilePath(String path, String langCode) {
    String suffix = "_$langCode";
    if (path.toLowerCase().endsWith('.srt')) {
      return "${path.substring(0, path.length - 4)}$suffix.srt";
    }
    if (path.toLowerCase().endsWith('.vtt')) {
      return "${path.substring(0, path.length - 4)}$suffix.vtt";
    }
    return "$path$suffix.srt";
  }

  static List<SubtitleBlock> parseSrt(String content) {
    final List<SubtitleBlock> blocks = [];
    // Normalize line endings to improve lookahead logic.
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = const LineSplitter().convert(normalized);
    String? currentTime;
    StringBuffer currentText = StringBuffer();
    int index = 1;
    int? lastExplicitCueIndex;

    int? nextNonEmptyLineIndex(int start) {
      for (var i = start; i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) return i;
      }
      return null;
    }

    void flushBlockIfAny() {
      if (currentTime != null && currentText.isNotEmpty) {
        blocks.add(
          SubtitleBlock(
            index: index++,
            timecode: currentTime!,
            text: currentText.toString().trim(),
          ),
        );
      }
      currentTime = null;
      currentText.clear();
    }

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      var line = lines[lineIndex].trim();
      if (line.isEmpty) {
        flushBlockIfAny();
        continue;
      }

      // Model/bad-SRT artifact: next cue index appended to the end of the last
      // subtitle text line, without a separating newline.
      // Example:
      //   69
      //   00:.. --> ..
      //   hızlıyım! 70
      //   00:.. --> ..
      // Only strip when we have seen a prior explicit cue index and the
      // appended number matches (lastIndex + 1), to avoid removing legitimate
      // trailing numbers (years, counts, etc.).
      if (currentTime != null && lastExplicitCueIndex != null) {
        final m = RegExp(r'^(.*?)(?:[\.!\?…])\s+(\d{1,6})$').firstMatch(line);
        if (m != null) {
          final trailing = int.tryParse(m.group(2) ?? '');
          if (trailing != null && trailing == lastExplicitCueIndex + 1) {
            final nextIdx = nextNonEmptyLineIndex(lineIndex + 1);
            final next = nextIdx == null ? '' : lines[nextIdx].trim();
            if (next.contains('-->')) {
              line = (m.group(1) ?? '').trimRight();
              lastExplicitCueIndex = trailing;
            }
          }
        }
      }

      if (line.contains('-->')) {
        // If we were in the middle of a block and another timecode appears,
        // best-effort flush what we have.
        if (currentTime != null) {
          flushBlockIfAny();
        }
        currentTime = line;
        continue;
      }

      final asInt = int.tryParse(line);
      if (asInt != null) {
        if (currentTime == null) {
          // Normal cue index line.
          lastExplicitCueIndex = asInt;
          continue;
        }

        // We are inside a cue but got a numeric-only line.
        // This often happens in model output where the next cue index is accidentally
        // included at the end of the previous cue's text.
        final nextIdx = nextNonEmptyLineIndex(lineIndex + 1);
        final next = nextIdx == null ? '' : lines[nextIdx].trim();

        // Case A: index line appears without a separating blank line.
        // Example:
        //   Hello
        //   70
        //   00:.. --> ..
        // Treat '70' as a cue index, not as subtitle text.
        if (next.contains('-->')) {
          // Treat this as the next cue index, even though it appeared inside a cue.
          lastExplicitCueIndex = asInt;
          flushBlockIfAny();
          // Skip the numeric line; the next iteration will read the timecode.
          continue;
        }

        // Case B: stray duplicate index line appears just before the real index.
        // Example:
        //   Hello
        //   70
        //
        //   70
        //   00:.. --> ..
        final nextAsInt = int.tryParse(next);
        if (nextAsInt != null && nextAsInt == asInt) {
          final next2Idx = nextIdx == null ? null : nextNonEmptyLineIndex(nextIdx + 1);
          final next2 = next2Idx == null ? '' : lines[next2Idx].trim();
          if (next2.contains('-->')) {
            // Drop the stray numeric line from the current cue text.
            continue;
          }
        }
        // Otherwise: keep it as actual subtitle text (rare but possible: countdown etc.).
      }

      if (currentTime != null) currentText.writeln(line);
    }
    flushBlockIfAny();
    return blocks;
  }

  static List<String> buildSrtChunks(String content) {
    final lines = const LineSplitter().convert(content);
    final chunks = <String>[];
    final buffer = <String>[];

    for (final line in lines) {
      buffer.add(line);
      // 150 satır ≈ 37-38 blok
      if (buffer.length >= 150 && line.trim().isEmpty) {
        chunks.add(buffer.join('\n'));
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.join('\n'));
    }

    return chunks;
  }

  /// Builds chunks for SRT translation.
  ///
  /// For small subtitle files, sending a single request improves consistency
  /// (no cross-chunk drift, no per-chunk style variance). For larger files,
  /// we fall back to chunking to keep requests bounded and resumable.
  static List<String> buildSrtChunksAdaptive(
    String content, {
    // Strongly prefer single-request translation for quality/consistency.
    // Still keep a safety ceiling to avoid hitting model/context limits.
    int maxChars = 60000,
    int maxBlocks = 600,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [content];

    // If it looks like a valid SRT and is small enough, keep it as one chunk.
    final blockCount = parseSrt(content).length;
    final isSmallEnough = content.length <= maxChars && blockCount > 0 && blockCount <= maxBlocks;
    if (isSmallEnough) {
      return [content];
    }

    return buildSrtChunks(content);
  }

  /// Desktop-safe chunking preset.
  ///
  /// On desktop, a single large request is more likely to exceed timeouts or
  /// stall due to network/proxy issues. Keeping chunks smaller improves
  /// reliability without changing the core chunking algorithm.
  static List<String> buildSrtChunksAdaptiveDesktop(String content) {
    return buildSrtChunksAdaptive(
      content,
      maxChars: 20000,
      maxBlocks: 220,
    );
  }
  
  static String clearSdh(String content) {
    // SDH temizleme sadece parantez/köşeli parantez içi açıklamaları kaldırır: (...) ve [...]
    // Not: Müzik notaları (♪ ... ♪) korunur.

    // İçeriği satır satır işle ve blokları yeniden oluştur
    final lines = const LineSplitter().convert(content);
    StringBuffer output = StringBuffer();
    int newIndex = 1;
    
    String? currentTime;
    StringBuffer currentText = StringBuffer();

    void writeCurrentBlockIfMeaningful() {
      if (currentTime == null || currentText.isEmpty) return;
      final cleaned = normalizeSdhCleanedText(currentText.toString());
      if (!hasMeaningfulDialogueText(cleaned)) return;
      output.writeln("$newIndex");
      output.writeln(currentTime);
      output.writeln(cleaned);
      output.writeln("");
      newIndex++;
    }
    
    for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();
        
        // Boş satır: Blok sonu
        if (line.isEmpty) {
        writeCurrentBlockIfMeaningful();
        currentTime = null;
        currentText.clear();
        continue;
        }
        
        // Zaman kodu satırı
        if (line.contains('-->')) {
        // Eğer önceki blok kapanmadıysa (boş satır eksikse) kapat
        writeCurrentBlockIfMeaningful();
        currentText.clear();
        currentTime = line;
        continue;
        }
        
        // İndeks satırını atla (Biz kendimiz üretiyoruz)
        if (currentTime == null && int.tryParse(line) != null) {
        continue;
        }
        
        // Metin satırı
        if (currentTime != null) {
        currentText.writeln(line);
        }
    }
    
    // Son bloğu işle
    writeCurrentBlockIfMeaningful();
    
    return output.toString();
  }
}
