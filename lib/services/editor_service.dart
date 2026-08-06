import '../models/subtitle_block.dart';
import 'subtitle_parser.dart';

class EditorSearchRange {
  final int start;
  final int end;

  const EditorSearchRange(this.start, this.end);
}

class EditorReplaceResult {
  final String text;
  final int count;

  const EditorReplaceResult({required this.text, required this.count});
}

class _NormalizedSearchMap {
  final String source;
  final String normalizedText;
  final List<int> sourceIndices;

  const _NormalizedSearchMap({
    required this.source,
    required this.normalizedText,
    required this.sourceIndices,
  });
}

class EditorService {
  static final RegExp _wordCharacterPattern = RegExp(
    r'[\p{L}\p{N}\p{M}]',
    unicode: true,
  );

  List<SubtitleBlock> filterBlocks(
    List<SubtitleBlock> blocks,
    String searchQuery,
    bool isRegexSearch,
    bool isCaseSensitive,
  ) {
    if (searchQuery.isEmpty) {
      return blocks;
    }

    return blocks.where((block) {
      if (isRegexSearch) {
        try {
          final regex = RegExp(
            searchQuery,
            caseSensitive: isCaseSensitive,
            multiLine: true,
          );
          return regex.hasMatch(block.text);
        } catch (_) {
          return false;
        }
      }
      return findPlainTextMatchRanges(
        block.text,
        searchQuery,
        isCaseSensitive,
      ).isNotEmpty;
    }).toList();
  }

  List<int> findSearchResultIndices(
    List<SubtitleBlock> blocks,
    String searchQuery,
    bool isRegexSearch,
    bool isCaseSensitive,
  ) {
    List<int> indices = [];
    if (searchQuery.isEmpty) return indices;

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      bool matches = false;

      if (isRegexSearch) {
        try {
          final regex = RegExp(
            searchQuery,
            caseSensitive: isCaseSensitive,
            multiLine: true,
          );
          matches = regex.hasMatch(block.text);
        } catch (_) {
          matches = false;
        }
      } else {
        matches = findPlainTextMatchRanges(
          block.text,
          searchQuery,
          isCaseSensitive,
        ).isNotEmpty;
      }

      if (matches) {
        indices.add(i);
      }
    }
    return indices;
  }

  static List<EditorSearchRange> findPlainTextMatchRanges(
    String text,
    String searchQuery,
    bool isCaseSensitive,
  ) {
    final normalizedQuery = _normalizeSearchText(searchQuery);
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final map = _buildNormalizedSearchMap(text);
    final haystack = isCaseSensitive
        ? map.normalizedText
        : map.normalizedText.toLowerCase();
    final needle = isCaseSensitive
        ? normalizedQuery
        : normalizedQuery.toLowerCase();
    final ranges = <EditorSearchRange>[];

    int searchFrom = 0;
    while (searchFrom <= haystack.length - needle.length) {
      final matchIndex = haystack.indexOf(needle, searchFrom);
      if (matchIndex == -1) {
        break;
      }

      if (_hasWholeWordBoundaries(haystack, needle, matchIndex)) {
        final sourceStart = map.sourceIndices[matchIndex];
        final sourceEnd = map.sourceIndices[matchIndex + needle.length - 1] + 1;
        ranges.add(EditorSearchRange(sourceStart, sourceEnd));
      }

      searchFrom = matchIndex + needle.length;
    }

    return ranges;
  }

  static EditorReplaceResult replaceFirstPlainTextMatch(
    String text,
    String searchQuery,
    String replacement,
    bool isCaseSensitive,
  ) {
    final ranges = findPlainTextMatchRanges(text, searchQuery, isCaseSensitive);
    if (ranges.isEmpty) {
      return EditorReplaceResult(text: text, count: 0);
    }

    final range = ranges.first;
    return EditorReplaceResult(
      text: text.replaceRange(range.start, range.end, replacement),
      count: 1,
    );
  }

  static EditorReplaceResult replaceAllPlainTextMatches(
    String text,
    String searchQuery,
    String replacement,
    bool isCaseSensitive,
  ) {
    final ranges = findPlainTextMatchRanges(text, searchQuery, isCaseSensitive);
    if (ranges.isEmpty) {
      return EditorReplaceResult(text: text, count: 0);
    }

    final buffer = StringBuffer();
    int cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        buffer.write(text.substring(cursor, range.start));
      }
      buffer.write(replacement);
      cursor = range.end;
    }
    if (cursor < text.length) {
      buffer.write(text.substring(cursor));
    }

    return EditorReplaceResult(text: buffer.toString(), count: ranges.length);
  }

  static String _normalizeSearchText(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', ' ');
  }

  static _NormalizedSearchMap _buildNormalizedSearchMap(String text) {
    final source = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final normalizedChars = <String>[];
    final sourceIndices = <int>[];

    for (int index = 0; index < source.length; index++) {
      normalizedChars.add(source[index] == '\n' ? ' ' : source[index]);
      sourceIndices.add(index);
    }

    return _NormalizedSearchMap(
      source: source,
      normalizedText: normalizedChars.join(),
      sourceIndices: sourceIndices,
    );
  }

  static bool _hasWholeWordBoundaries(
    String haystack,
    String needle,
    int matchIndex,
  ) {
    if (needle.isEmpty) {
      return false;
    }

    final endIndex = matchIndex + needle.length;
    final needsLeftBoundary = _isWordCharacter(needle.substring(0, 1));
    final needsRightBoundary = _isWordCharacter(
      needle.substring(needle.length - 1),
    );
    final previousChar = matchIndex > 0
        ? haystack.substring(matchIndex - 1, matchIndex)
        : '';
    final nextChar = endIndex < haystack.length
        ? haystack.substring(endIndex, endIndex + 1)
        : '';

    if (needsLeftBoundary && _isWordCharacter(previousChar)) {
      return false;
    }
    if (needsRightBoundary && _isWordCharacter(nextChar)) {
      return false;
    }
    return true;
  }

  static bool _isWordCharacter(String char) {
    return char.isNotEmpty && _wordCharacterPattern.hasMatch(char);
  }

  List<SubtitleBlock> cleanSdhFromBlocks(List<SubtitleBlock> original) {
    List<SubtitleBlock> cleaned = [];
    int newIndex = 1;
    for (var b in original) {
      final cleanText = SubtitleParser.normalizeSdhCleanedText(b.text);

      if (SubtitleParser.hasMeaningfulDialogueText(cleanText)) {
        cleaned.add(
          SubtitleBlock(index: newIndex, timecode: b.timecode, text: cleanText),
        );
        newIndex++;
      }
    }
    return cleaned;
  }

  List<SubtitleBlock> deepCopyBlocks(List<SubtitleBlock> blocks) {
    return blocks
        .map(
          (b) =>
              SubtitleBlock(index: b.index, timecode: b.timecode, text: b.text),
        )
        .toList();
  }
}
