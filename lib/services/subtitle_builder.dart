import '../models/subtitle_block.dart';

class SubtitleBuilder {
  /// Builds a standard SRT format string from a list of SubtitleBlock objects.
  static String buildSrt(List<SubtitleBlock> blocks, {bool resequence = true}) {
    final buffer = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final index = resequence ? (i + 1) : (block.index > 0 ? block.index : (i + 1));
      buffer.writeln(index);
      buffer.writeln(block.timecode.replaceAll('.', ','));
      buffer.writeln(block.text);
      buffer.writeln(''); // Always add a blank line after each block, including the last one
    }
    return buffer.toString();
  }
}
