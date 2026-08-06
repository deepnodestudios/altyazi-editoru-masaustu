import 'package:flutter/material.dart';

import 'layout_constants.dart';

class AiPanelHeaderSection extends StatelessWidget {
  final bool sdhClear;
  final ValueChanged<bool> onSdhClearChanged;
  final String sdhClearLabel;

  final bool hideInfoButtons;
  final VoidCallback onInfoTap;

  final String historyLabel;
  final VoidCallback onOpenHistory;
  final Key? historyButtonKey;
  final Widget? sourceIndicator;

  final ColorScheme colorScheme;
  final bool balancedTopBand;

  const AiPanelHeaderSection({
    super.key,
    required this.sdhClear,
    required this.onSdhClearChanged,
    required this.sdhClearLabel,
    required this.hideInfoButtons,
    required this.onInfoTap,
    required this.historyLabel,
    required this.onOpenHistory,
    this.historyButtonKey,
    this.sourceIndicator,
    required this.colorScheme,
    this.balancedTopBand = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabledBg = colorScheme.surfaceContainerHighest;
    final disabledFg = colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    final labelFontSize = balancedTopBand ? 18.0 : null;
    final historyVerticalPadding = balancedTopBand ? 10.0 : 8.0;
    final historyHorizontalPadding = balancedTopBand ? 16.0 : 14.0;
    final historyIconSize = balancedTopBand ? 22.0 : 20.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: balancedTopBand ? 36 : 32,
                child: FittedBox(
                  child: Switch(
                    value: sdhClear,
                    onChanged: onSdhClearChanged,
                    activeThumbColor: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: kAiPanelInlineGap),
              Flexible(
                child: Text(
                  sdhClearLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: labelFontSize,
                  ),
                ),
              ),
              if (!hideInfoButtons) ...[
                const SizedBox(width: kAiPanelInlineGap),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onInfoTap,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.info,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sourceIndicator != null) ...[
              sourceIndicator!,
              const SizedBox(width: kAiPanelInlineGap),
            ],
            ElevatedButton.icon(
              key: historyButtonKey,
              onPressed: onOpenHistory,
              icon: Icon(Icons.history, size: historyIconSize),
              label: Text(historyLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: disabledBg,
                disabledForegroundColor: disabledFg,
                padding: EdgeInsets.symmetric(
                  horizontal: historyHorizontalPadding,
                  vertical: historyVerticalPadding,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
