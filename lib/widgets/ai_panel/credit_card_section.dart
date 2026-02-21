import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../controllers/translation_controller.dart';

class _WordSafeTwoLineText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _WordSafeTwoLineText({
    required this.text,
    required this.style,
  });

  bool _fitsOneLine(
    String candidate,
    TextDirection textDirection,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    );
    painter.layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  String _buildWordSafeTwoLineLabel(
    String raw,
    TextDirection textDirection,
    double maxWidth,
  ) {
    final input = raw.trim();
    if (input.isEmpty) return input;

    final words = input.split(RegExp(r'\s+'));
    if (words.length <= 1) {
      // No clear word boundaries; let Flutter handle line breaks.
      return input;
    }

    var firstLine = '';
    var splitIndex = 0;

    for (var i = 0; i < words.length; i++) {
      final candidate = firstLine.isEmpty ? words[i] : '$firstLine ${words[i]}';
      if (_fitsOneLine(candidate, textDirection, maxWidth)) {
        firstLine = candidate;
        splitIndex = i + 1;
        continue;
      }

      if (firstLine.isEmpty) {
        // First word itself doesn't fit in one line; bail out.
        return input;
      }
      break;
    }

    if (splitIndex >= words.length) {
      return firstLine;
    }

    var secondLine = words.sublist(splitIndex).join(' ');
    if (_fitsOneLine(secondLine, textDirection, maxWidth)) {
      return '$firstLine\n$secondLine';
    }

    // Trim words from the end until the 2nd line + ellipsis fits.
    final secondWords = words.sublist(splitIndex);
    for (var end = secondWords.length; end > 0; end--) {
      final candidateBase = secondWords.sublist(0, end).join(' ');
      final candidate = '$candidateBase…';
      if (_fitsOneLine(candidate, textDirection, maxWidth)) {
        return '$firstLine\n$candidate';
      }
    }

    // Fallback: show first line + ellipsis.
    return '$firstLine\n…';
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final safeLabel = _buildWordSafeTwoLineLabel(text, textDirection, maxWidth);
        return Text(
          safeLabel,
          style: style,
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

class AiPanelCreditCardSection extends StatelessWidget {
  final AppSettings settings;
  final TranslationController controller;
  final VoidCallback onAddCredits;

  const AiPanelCreditCardSection({
    super.key,
    required this.settings,
    required this.controller,
    required this.onAddCredits,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLowCredits = controller.userCredits > 0 && controller.userCredits < 3;
    final creditAccent = isLowCredits ? colorScheme.error : colorScheme.primary;
    final creditContainer =
        isLowCredits ? colorScheme.errorContainer : colorScheme.primaryContainer;

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 4,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                creditContainer.withValues(alpha: 0.35),
                colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: creditAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: creditAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLowCredits
                    ? Icons.warning_amber_rounded
                    : Icons.auto_awesome,
                color: creditAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      settings.trans['remaining_credits'] ?? 'KALAN HAK:',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${controller.userCredits} ${settings.trans['translations'] ?? 'ÇEVİRİ'}',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      settings.trans['credit_explanation'] ??
                          '1 Credit = 1 Full Translation',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: ElevatedButton(
                onPressed: onAddCredits,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade800,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: _WordSafeTwoLineText(
                    text: settings.trans['add_credits'] ?? 'EKLE',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
