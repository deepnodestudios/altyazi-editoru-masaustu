import 'package:flutter/material.dart';

import '../../models/subtitle_block.dart';
import '../../tabs/live_subtitle_viewer.dart';

class AiPanelLiveSubtitleSection extends StatelessWidget {
  final List<SubtitleBlock> source;
  final List<SubtitleBlock> target;
  final bool followEnabled;
  final bool fillHeight;

  final bool showStartingSoonOverlay;
  final String startingSoonText;
  final ColorScheme colorScheme;

  const AiPanelLiveSubtitleSection({
    super.key,
    required this.source,
    required this.target,
    required this.followEnabled,
    this.fillHeight = false,
    required this.showStartingSoonOverlay,
    required this.startingSoonText,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        LiveSubtitleViewer(
          source: source,
          target: target,
          followEnabled: followEnabled,
          isFullScreen: fillHeight,
        ),
        if (showStartingSoonOverlay)
          Positioned.fill(
            child: Center(
              child: Text(
                startingSoonText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withAlpha(180),
                ),
              ),
            ),
          ),
      ],
    );

    if (fillHeight) {
      return SizedBox.expand(child: content);
    }

    return Column(children: [content]);
  }
}
