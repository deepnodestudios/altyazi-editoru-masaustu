import 'package:flutter/material.dart';

import 'layout_constants.dart';

class AiPanelBatchProcessingBanner extends StatelessWidget {
  final String message;
  final ColorScheme colorScheme;

  const AiPanelBatchProcessingBanner({
    super.key,
    required this.message,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withAlpha(120)),
          ),
          child: Row(
            children: [
              Icon(Icons.queue, color: colorScheme.primary, size: 20),
              const SizedBox(width: kAiPanelInlineGap),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: kAiPanelSectionGap),
      ],
    );
  }
}
