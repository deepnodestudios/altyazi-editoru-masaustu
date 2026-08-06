import 'package:flutter/material.dart';

class DesktopUpdateProgressDialog extends StatelessWidget {
  final String title;
  final String message;
  final double? progress;

  const DesktopUpdateProgressDialog({
    super.key,
    required this.title,
    required this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final value = progress;
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          const SizedBox(height: 16),
          if (value == null)
            const Center(child: CircularProgressIndicator())
          else
            LinearProgressIndicator(value: value.clamp(0.0, 1.0)),
        ],
      ),
    );
  }
}
