import 'package:flutter/material.dart';

import 'layout_constants.dart';

class AiPanelEnglishSourceTipBanner extends StatelessWidget {
  final String text;
  final bool fillHeight;
  final double? fontSize;

  const AiPanelEnglishSourceTipBanner({
    super.key,
    required this.text,
    this.fillHeight = false,
    this.fontSize,
  });

  double _resolveAdaptiveFontSize({
    required BuildContext context,
    required BoxConstraints constraints,
    required TextStyle baseStyle,
    required double maxFontSize,
    required double minFontSize,
  }) {
    if (constraints.maxWidth <= 0) {
      return maxFontSize;
    }

    if (!constraints.maxHeight.isFinite || constraints.maxHeight <= 0) {
      return maxFontSize;
    }

    final textDirection = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    bool fits(double size) {
      final span = TextSpan(
        text: text,
        style: baseStyle.copyWith(fontSize: size),
      );
      final painter = TextPainter(
        text: span,
        textDirection: textDirection,
        textScaler: scaler,
      )..layout(maxWidth: constraints.maxWidth);

      return painter.height <= constraints.maxHeight;
    }

    var low = minFontSize;
    var high = maxFontSize;
    var best = minFontSize;

    for (var i = 0; i < 14; i++) {
      final mid = (low + high) / 2;
      if (fits(mid)) {
        best = mid;
        low = mid;
      } else {
        high = mid;
      }
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double preferredFontSize =
        fontSize ?? (fillHeight ? 16.0 : 13.0);
    final double minimumFontSize = fillHeight ? 10.0 : 11.0;
    final baseStyle = TextStyle(
      color: colorScheme.onSurface,
      height: 1.35,
    );

    return Container(
      padding: EdgeInsets.all(fillHeight ? kAiPanelSectionGap + 2 : kAiPanelSectionGap),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.primary,
            size: fillHeight ? 24 : 20,
          ),
          const SizedBox(width: kAiPanelInlineGap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final adaptiveFontSize = _resolveAdaptiveFontSize(
                  context: context,
                  constraints: constraints,
                  baseStyle: baseStyle,
                  maxFontSize: preferredFontSize,
                  minFontSize: minimumFontSize,
                );

                return Text(
                  text,
                  style: baseStyle.copyWith(fontSize: adaptiveFontSize),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
