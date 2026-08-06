import 'dart:math';

import 'package:flutter/material.dart';

class SubtitlePreviewRowData {
  final int index;
  final String timecode;
  final String text;

  const SubtitlePreviewRowData({
    required this.index,
    required this.timecode,
    required this.text,
  });
}

/// Shared subtitle preview/compare list UI.
///
/// - Single mode: shows only [primaryRowAt].
/// - Compare mode (no side-by-side): shows source and translation stacked
///   vertically per row when [secondaryCount] > 0.
class SubtitlePreviewList extends StatelessWidget {
  final ScrollController controller;
  final int primaryCount;
  final SubtitlePreviewRowData? Function(int index) primaryRowAt;

  final int secondaryCount;
  final SubtitlePreviewRowData? Function(int index)? secondaryRowAt;
  final String? primaryLabel;
  final String? secondaryLabel;

  final EdgeInsetsGeometry padding;

  const SubtitlePreviewList({
    super.key,
    required this.controller,
    required this.primaryCount,
    required this.primaryRowAt,
    this.secondaryCount = 0,
    this.secondaryRowAt,
    this.primaryLabel,
    this.secondaryLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  bool get _isCompareMode => secondaryCount > 0 && secondaryRowAt != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rowCount = max(primaryCount, secondaryCount);

    final dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.45);
    final cardBorderColor = colorScheme.outlineVariant.withValues(alpha: 0.4);
    final cardDecoration = BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cardBorderColor),
    );
    final indexChipDecoration = BoxDecoration(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(6),
    );
    final indexChipTextStyle = TextStyle(
      fontSize: 12,
      color: colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.w700,
    );
    final timecodeTextStyle = TextStyle(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
      fontFamily: 'Courier',
      fontWeight: FontWeight.w600,
    );
    final bodyTextStyle = TextStyle(
      fontSize: 13,
      color: colorScheme.onSurface,
      height: 1.3,
    );
    final labelTextStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: colorScheme.primary,
    );

    if (rowCount <= 0) {
      return Center(
        child: Text(
          '—',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Scrollbar(
      controller: controller,
      interactive: true,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(3),
      child: ListView.builder(
        controller: controller,
        padding: padding,
        itemCount: rowCount,
        addAutomaticKeepAlives: false,
        addSemanticIndexes: false,
        itemBuilder: (context, i) {
          final primary = i < primaryCount ? primaryRowAt(i) : null;
          final secondary =
              _isCompareMode && i < secondaryCount ? secondaryRowAt!(i) : null;

          final rowTimecode = primary?.timecode ?? secondary?.timecode ?? '-';
          final rowIndex = primary?.index ?? secondary?.index ?? (i + 1);

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: indexChipDecoration,
                      child: Text(
                        '$rowIndex',
                        style: indexChipTextStyle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rowTimecode,
                        style: timecodeTextStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (!_isCompareMode)
                  _buildTextCard(
                    decoration: cardDecoration,
                    textStyle: bodyTextStyle,
                    text: primary?.text,
                  )
                else
                  _buildCompareStack(
                    primaryText: primary?.text,
                    secondaryText: secondary?.text,
                    labelTextStyle: labelTextStyle,
                    cardDecoration: cardDecoration,
                    bodyTextStyle: bodyTextStyle,
                  ),
                if (i < rowCount - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: dividerColor,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextCard({
    required BoxDecoration decoration,
    required TextStyle textStyle,
    required String? text,
  }) {
    final value = (text ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: decoration,
      child: Text(
        value.isNotEmpty ? value : '—',
        style: textStyle,
      ),
    );
  }

  Widget _buildCompareStack({
    required String? primaryText,
    required String? secondaryText,
    required TextStyle labelTextStyle,
    required BoxDecoration cardDecoration,
    required TextStyle bodyTextStyle,
  }) {
    final pLabel = primaryLabel;
    final sLabel = secondaryLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pLabel != null && pLabel.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              pLabel,
              style: labelTextStyle,
            ),
          ),
        _buildTextCard(
          decoration: cardDecoration,
          textStyle: bodyTextStyle,
          text: primaryText,
        ),
        const SizedBox(height: 10),
        if (sLabel != null && sLabel.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              sLabel,
              style: labelTextStyle,
            ),
          ),
        _buildTextCard(
          decoration: cardDecoration,
          textStyle: bodyTextStyle,
          text: secondaryText,
        ),
      ],
    );
  }
}
