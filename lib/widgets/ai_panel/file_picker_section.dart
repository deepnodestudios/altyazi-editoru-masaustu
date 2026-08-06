import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../app_settings.dart';
import 'layout_constants.dart';

class AiPanelFilePickerSection extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onAddFiles;

  const AiPanelFilePickerSection({
    super.key,
    required this.settings,
    required this.onAddFiles,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabledBg = colorScheme.surfaceContainerHighest;
    final disabledFg = colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: kAiPanelPrimaryButtonHeight,
          child: ElevatedButton.icon(
            onPressed: onAddFiles,
            icon: const Icon(Icons.file_upload, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: AutoSizeText(
                '${settings.trans['add_file'] ?? 'DOSYA EKLE'} (SRT - VTT)',
                maxLines: 1,
                minFontSize: 10,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: disabledBg,
              disabledForegroundColor: disabledFg,
              elevation: 3,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: kAiPanelSectionGap),
      ],
    );
  }
}
