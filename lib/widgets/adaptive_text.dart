import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/widgets.dart';

/// A drop-in alternative to [Text] that automatically reduces font size
/// to avoid overflows in tight layouts.
///
/// Use this mainly in constrained horizontal UI (Row, AppBar titles,
/// buttons, tab labels). For long paragraphs where wrapping is fine,
/// normal [Text] is usually better.
class AdaptiveText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final double minFontSize;
  final double stepGranularity;
  final bool wrapWords;
  final StrutStyle? strutStyle;

  const AdaptiveText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
    this.minFontSize = 10,
    this.stepGranularity = 1,
    this.wrapWords = true,
    this.strutStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      data,
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      minFontSize: minFontSize,
      stepGranularity: stepGranularity,
      wrapWords: wrapWords,
      strutStyle: strutStyle,
    );
  }
}
