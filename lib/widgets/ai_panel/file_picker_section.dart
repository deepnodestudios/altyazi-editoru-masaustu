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
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddFiles,
                icon: const Icon(Icons.file_upload, size: 22),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(settings.trans['add_file'] ?? 'DOSYA EKLE'),
                    const SizedBox(height: 2),
                    const Text(
                      'SRT - VTT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: disabledBg,
                  disabledForegroundColor: disabledFg,
                  elevation: 3,
                  shadowColor: colorScheme.shadow.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: kAiPanelSectionGap),
      ],
    );
  }
}
