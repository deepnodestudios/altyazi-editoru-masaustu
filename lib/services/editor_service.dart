import '../models/subtitle_block.dart';
import 'subtitle_parser.dart';

class EditorService {
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
          final regex = RegExp(searchQuery,
              caseSensitive: isCaseSensitive, multiLine: true);
          return regex.hasMatch(block.text);
        } catch (_) {
          return false;
        }
      }
      String text = block.text.replaceAll('\n', ' ');
      String query = searchQuery.replaceAll('\n', ' ');
      if (!isCaseSensitive) {
        text = text.toLowerCase();
        query = query.toLowerCase();
      }
      return text.contains(query);
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
          final regex = RegExp(searchQuery,
              caseSensitive: isCaseSensitive, multiLine: true);
          matches = regex.hasMatch(block.text);
        } catch (_) {
          matches = false;
        }
      } else {
        String text = block.text.replaceAll('\n', ' ');
        String query = searchQuery.replaceAll('\n', ' ');
        if (!isCaseSensitive) {
          text = text.toLowerCase();
          query = query.toLowerCase();
        }
        matches = text.contains(query);
      }

      if (matches) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<SubtitleBlock> cleanSdhFromBlocks(List<SubtitleBlock> original) {
    List<SubtitleBlock> cleaned = [];
    int newIndex = 1;
    for (var b in original) {
      final cleanText = SubtitleParser.normalizeSdhCleanedText(b.text);
      
      if (SubtitleParser.hasMeaningfulDialogueText(cleanText)) {
        cleaned.add(SubtitleBlock(
            index: newIndex, timecode: b.timecode, text: cleanText));
        newIndex++;
      }
    }
    return cleaned;
  }

  List<SubtitleBlock> deepCopyBlocks(List<SubtitleBlock> blocks) {
    return blocks
        .map((b) => SubtitleBlock(
              index: b.index,
              timecode: b.timecode,
              text: b.text,
            ))
        .toList();
  }
}
