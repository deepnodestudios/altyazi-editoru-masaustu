import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../controllers/translation_controller.dart';
import '../../services/token_wallet_math.dart';
import 'layout_constants.dart';

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

  void _openWalletInfoDialog(BuildContext context, {required bool tokenUi}) {
    final title = tokenUi
        ? (settings.trans['wallet_token_label'] ?? 'Token')
        : (settings.trans['remaining_credits'] ?? 'KALAN HAK:');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(_walletInfoBody(tokenUi: tokenUi)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(settings.trans['ok'] ?? 'Tamam'),
          ),
        ],
      ),
    );
  }

  String _walletInfoBody({required bool tokenUi}) {
    if (!tokenUi) {
      return settings.trans['credit_explanation'] ??
          '1 Credit = 1 Full Translation';
    }
    return settings.trans['credit_explanation_tokens'] ??
        settings.trans['token_usage_info'] ??
        'Tokens scale with file length.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokenUi = controller.showTokenWalletUi;
    final paidCredits = controller.displayFileCredits;
    final isLowCredits =
        controller.userCredits > 0 && controller.userCredits < 3;
    final creditAccent = isLowCredits ? colorScheme.error : colorScheme.primary;
    final creditContainer =
        isLowCredits ? colorScheme.errorContainer : colorScheme.primaryContainer;

    final double minHeight =
        kAiPanelPrimaryButtonHeight * 2 + kAiPanelSectionGap;
    final addLabel = tokenUi
        ? (settings.trans['add_tokens'] ??
            settings.trans['add_credits'] ??
            'Token Ekle')
        : (settings.trans['add_credits'] ?? 'EKLE');

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 4,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
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
              const SizedBox(width: kAiPanelInlineGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            settings.trans['remaining_credits'] ?? 'KALAN HAK:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (!settings.hideInfoButtons)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _openWalletInfoDialog(
                              context,
                              tokenUi: tokenUi,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.info,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tokenUi
                            ? '${formatTokenCount(controller.displayTokenBalance, grouping: '.')} ${settings.trans['wallet_token_label'] ?? 'TOKEN'}'
                            : '${controller.userCredits} ${settings.trans['translations'] ?? 'ÇEVİRİ'}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (tokenUi && paidCredits > 0)
                          _WalletChip(
                            label:
                                '${settings.trans['credit'] ?? 'Kredi'}: $paidCredits',
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.12),
                            foregroundColor: colorScheme.primary,
                          ),
                        if (tokenUi && controller.displayPaidTokenBalance > 0)
                          _WalletChip(
                            label:
                                '${settings.trans['wallet_paid_token_label'] ?? settings.trans['wallet_paid_label'] ?? 'Paid Token'}: ${formatTokenCount(controller.displayPaidTokenBalance, grouping: '.')}',
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.12),
                            foregroundColor: colorScheme.primary,
                          ),
                        if (!tokenUi)
                          _WalletChip(
                            label:
                                '${settings.trans['wallet_paid_label'] ?? 'Paid'}: $paidCredits',
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.12),
                            foregroundColor: colorScheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kAiPanelInlineGap),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 128, maxWidth: 170),
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
                      borderRadius: BorderRadius.circular(kAiPanelBorderRadius),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: _WordSafeTwoLineText(
                      text: addLabel,
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

class _WalletChip extends StatelessWidget {
  const _WalletChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
