import 'package:flutter/material.dart';

class MaintenanceModeScreen extends StatelessWidget {
  final String title;
  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;
  final bool isRetrying;
  /// When true, renders as a blocking overlay layer (no Scaffold).
  final bool asOverlay;

  const MaintenanceModeScreen({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.isRetrying = false,
    this.asOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_rounded,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: asOverlay ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: asOverlay
                      ? Colors.white.withValues(alpha: 0.78)
                      : colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: isRetrying ? null : () => onRetry(),
                icon: isRetrying
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
          ),
        ),
      ),
    );

    if (asOverlay) {
      // Covers translation UI underneath via Stack hit-testing; retry stays tappable.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEB080A12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      body: SafeArea(child: content),
    );
  }
}
