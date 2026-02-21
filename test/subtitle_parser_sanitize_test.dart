import 'package:flutter_test/flutter_test.dart';

import 'package:altyazi_editoru/services/subtitle_parser.dart';
import 'package:altyazi_editoru/services/subtitle_builder.dart';

void main() {
  test('parseSrt drops stray duplicate cue index lines inside a cue', () {
    const srt = '''
69
00:00:01,000 --> 00:00:02,000
Elimden geldiğince
hızlıyım!
70

70
00:00:03,000 --> 00:00:04,000
Doğu tünelini açın!
''';

    final blocks = SubtitleParser.parseSrt(srt);
    expect(blocks.length, 2);
    expect(blocks.first.text, isNot(contains('\n70')));

    final rebuilt = SubtitleBuilder.buildSrt(blocks);
    expect(rebuilt, isNot(contains('hızlıyım!\n70')));
  });

  test('parseSrt treats numeric-only line before a timecode as next cue index', () {
    const srt = '''
1
00:00:01,000 --> 00:00:02,000
Hi
2
00:00:03,000 --> 00:00:04,000
There
''';

    final blocks = SubtitleParser.parseSrt(srt);
    expect(blocks.length, 2);
    expect(blocks[0].text.trim(), 'Hi');
    expect(blocks[1].text.trim(), 'There');
  });

  test('parseSrt strips next cue index appended to end-of-line', () {
    const srt = '''
69
00:00:01,000 --> 00:00:02,000
Elimden geldiğince
hızlıyım! 70
00:00:03,000 --> 00:00:04,000
Doğu tünelini açın!
''';

    final blocks = SubtitleParser.parseSrt(srt);
    expect(blocks.length, 2);
    expect(blocks.first.text, isNot(contains(' 70')));

    final rebuilt = SubtitleBuilder.buildSrt(blocks);
    expect(rebuilt, isNot(contains('hızlıyım! 70')));
  });
}
