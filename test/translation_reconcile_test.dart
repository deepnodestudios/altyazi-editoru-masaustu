import 'package:flutter_test/flutter_test.dart';
import 'package:altyazi_editoru/models/subtitle_block.dart';
import 'package:altyazi_editoru/services/translation_engine.dart';

void main() {
  group('TranslationEngine.reconcileBlocksToExpectedCount', () {
    test('exact block count match retains original timecodes and text', () {
      final source = [
        SubtitleBlock(index: 1, timecode: '00:01:00,000 --> 00:01:02,000', text: 'Hello'),
        SubtitleBlock(index: 2, timecode: '00:01:02,500 --> 00:01:05,000', text: 'World'),
      ];
      final translated = [
        SubtitleBlock(index: 1, timecode: '00:00:00,000 --> 00:00:00,000', text: 'Merhaba'),
        SubtitleBlock(index: 2, timecode: '00:00:00,000 --> 00:00:00,000', text: 'Dünya'),
      ];

      final result = TranslationEngine.reconcileBlocksToExpectedCount(
        sourceBlocks: source,
        translatedBlocks: translated,
      );

      expect(result.length, equals(2));
      expect(result[0].timecode, equals('00:01:00,000 --> 00:01:02,000'));
      expect(result[0].text, equals('Merhaba'));
      expect(result[1].timecode, equals('00:01:02,500 --> 00:01:05,000'));
      expect(result[1].text, equals('Dünya'));
    });

    test('model split sentence into extra block: merges fragment back into partner', () {
      // 2 source blocks expected, but model produced 3 blocks because it split block 1
      final source = [
        SubtitleBlock(index: 1, timecode: '00:01:00,000 --> 00:01:04,000', text: 'I prefer the skater, he is much cooler.'),
        SubtitleBlock(index: 2, timecode: '00:01:04,500 --> 00:01:06,000', text: 'So much cooler.'),
      ];
      final translated = [
        SubtitleBlock(index: 1, timecode: '00:01:00,000 --> 00:01:02,000', text: 'A gördeszkást szeretem, ő sokkal,'),
        SubtitleBlock(index: 2, timecode: '00:01:02,000 --> 00:01:04,000', text: 'menőbb.'),
        SubtitleBlock(index: 3, timecode: '00:01:04,500 --> 00:01:06,000', text: 'Sokkal menőbb.'),
      ];

      final result = TranslationEngine.reconcileBlocksToExpectedCount(
        sourceBlocks: source,
        translatedBlocks: translated,
      );

      expect(result.length, equals(2));
      // First block should have merged the fragment
      expect(result[0].timecode, equals('00:01:00,000 --> 00:01:04,000'));
      expect(result[0].text, contains('menőbb'));
      // Second block must remain aligned to source block 2
      expect(result[1].timecode, equals('00:01:04,500 --> 00:01:06,000'));
      expect(result[1].text, equals('Sokkal menőbb.'));
    });

    test('model dropped a block: pads with source block to preserve count', () {
      final source = [
        SubtitleBlock(index: 1, timecode: '00:01:00,000 --> 00:01:02,000', text: 'Line 1'),
        SubtitleBlock(index: 2, timecode: '00:01:02,500 --> 00:01:04,000', text: 'Line 2'),
        SubtitleBlock(index: 3, timecode: '00:01:04,500 --> 00:01:06,000', text: 'Line 3'),
      ];
      final translated = [
        SubtitleBlock(index: 1, timecode: '00:00:00,000 --> 00:00:00,000', text: 'Satır 1'),
        SubtitleBlock(index: 2, timecode: '00:00:00,000 --> 00:00:00,000', text: 'Satır 2'),
      ];

      final result = TranslationEngine.reconcileBlocksToExpectedCount(
        sourceBlocks: source,
        translatedBlocks: translated,
      );

      expect(result.length, equals(3));
      expect(result[0].timecode, equals('00:01:00,000 --> 00:01:02,000'));
      expect(result[0].text, equals('Satır 1'));
      expect(result[1].timecode, equals('00:01:02,500 --> 00:01:04,000'));
      expect(result[1].text, equals('Satır 2'));
      expect(result[2].timecode, equals('00:01:04,500 --> 00:01:06,000'));
      expect(result[2].text, equals('Line 3'));
    });
  });
}
