import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final safeDisplayText = displayText.trim().isEmpty ? 'Language' : displayText;
    final containerPadding = balancedTopBand
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    final selectorVerticalPadding = balancedTopBand ? 14.0 : 12.0;
    final labelFontSize = balancedTopBand ? 18.0 : 16.0;
    final languageIconSize = balancedTopBand ? 26.0 : 24.0;
    final expandIconSize = balancedTopBand ? 26.0 : 24.0;

    return Container(
      key: selectorTapKey,
      padding: containerPadding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.language,
            color: colorScheme.primary,
            size: languageIconSize,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: selectorVerticalPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        safeDisplayText,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
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
  }
}
