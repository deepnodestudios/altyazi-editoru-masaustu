import 'package:flutter/material.dart';

import '../adaptive_text.dart';
import 'layout_constants.dart';

class AiPanelLanguageSelectorSection extends StatelessWidget {
  final String displayText;
  final VoidCallback onTap;
  final Key? selectorTapKey;
  final bool balancedTopBand;

  const AiPanelLanguageSelectorSection({
    super.key,
    required this.displayText,
    required this.onTap,
    this.selectorTapKey,
    this.balancedTopBand = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    
    final safeDisplayText = displayText.trim().isEmpty ? 'Language' : displayText;
    final containerPadding = balancedTopBand
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
      : const EdgeInsets.symmetric(horizontal: 12, vertical: 1);
    final selectorVerticalPadding = balancedTopBand ? 7.0 : 5.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 420.0;
        final compactScale = width < 380
            ? 0.84
            : (width < 430 ? 0.9 : (width < 520 ? 0.96 : 1.0));
        final labelFontSize = (balancedTopBand ? 15.0 : 13.0) * compactScale;
        final languageIconSize = (balancedTopBand ? 22.0 : 20.0) * compactScale;
        final expandIconSize = (balancedTopBand ? 22.0 : 20.0) * compactScale;

        return Container(
          key: selectorTapKey,
          padding: containerPadding,
          decoration: BoxDecoration(
            color: isDarkMode 
                ? colorScheme.surfaceContainerHighest.withAlpha(80)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
            border: Border.all(
              color: isDarkMode
                  ? colorScheme.outline.withAlpha(60)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.language,
                color: colorScheme.primary,
                size: languageIconSize,
              ),
              const SizedBox(width: kAiPanelInlineGap),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: selectorVerticalPadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: AdaptiveText(
                            safeDisplayText,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            minFontSize: 10,
                            wrapWords: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.expand_more,
                          color: colorScheme.onSurfaceVariant,
                          size: expandIconSize,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
