import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/purchase_dialog.dart';
import 'billing_service.dart';
import 'token_wallet_math.dart';

enum TokenEstimateDecision { proceed, cancelled, openedShop }

/// Start-Translate confirm: local `ceil(chars * 1.30)` before any server upload.
class TokenEstimateGateService {
  TokenEstimateGateService._();
  static final TokenEstimateGateService instance = TokenEstimateGateService._();

  int paidTokenBalance(BillingService billing) {
    return (billing.tokenBalance - billing.tokenGrantBalance)
        .clamp(0, billing.tokenBalance);
  }

  int spendableTokens(BillingService billing) {
    if (billing.isDesktopClient) {
      return paidTokenBalance(billing);
    }
    return billing.tokenBalance;
  }

  bool willChargeFileCredit({
    required BillingService billing,
    required int estimatedTokens,
  }) {
    if (!billing.usesTokenWallet) return false;
    final desktop = billing.isDesktopClient;
    final paidFiles = billing.legacyFlatRateRemaining;
    final bonusFiles = desktop ? 0 : billing.freeCredits;
    final paidTokens = paidTokenBalance(billing);
    final grantTokens = desktop ? 0 : billing.tokenGrantBalance;

    if (desktop) {
      return paidFiles > 0;
    }
    if (billing.preferFreeCreditsFirst) {
      if (bonusFiles > 0) return true;
      if (estimatedTokens > 0 && grantTokens >= estimatedTokens) return false;
      return paidFiles > 0;
    }
    if (paidFiles > 0) return true;
    if (estimatedTokens > 0 && paidTokens >= estimatedTokens) return false;
    return bonusFiles > 0;
  }

  Future<TokenEstimateDecision> confirmIfNeeded({
    required BillingService billing,
    required Map<String, String> trans,
    required int charCount,
  }) async {
    if (!billing.usesTokenWallet) {
      return TokenEstimateDecision.proceed;
    }
    final estimated = estimateTokensFromCharCount(charCount);
    if (willChargeFileCredit(billing: billing, estimatedTokens: estimated)) {
      return TokenEstimateDecision.proceed;
    }

    final remaining = spendableTokens(billing);
    final insufficient = estimated <= 0 || remaining < estimated;
    final context = globalNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return insufficient
          ? TokenEstimateDecision.cancelled
          : TokenEstimateDecision.proceed;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final title = insufficient
            ? (trans['token_insufficient_title'] ?? 'Not enough tokens')
            : (trans['token_estimate_title'] ?? 'Estimated token use');
        final body = insufficient
            ? (trans['token_insufficient_body'] ??
                    'This file needs {needed} tokens. You have {balance}.')
                .replaceAll('{needed}', formatTokenCount(estimated))
                .replaceAll('{balance}', formatTokenCount(remaining))
            : (trans['token_estimate_body'] ??
                    'This file will use about {tokens} tokens. Remaining after: {remaining}.')
                .replaceAll('{tokens}', formatTokenCount(estimated))
                .replaceAll(
                  '{remaining}',
                  formatTokenCount(remaining - estimated),
                );
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                trans['token_estimate_cancel'] ??
                    trans['btn_cancel'] ??
                    'Cancel',
              ),
            ),
            if (insufficient)
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  trans['token_insufficient_shop'] ??
                      trans['add_tokens'] ??
                      'Add tokens',
                ),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(trans['token_estimate_confirm'] ?? 'Start'),
              ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return TokenEstimateDecision.cancelled;
    }
    if (insufficient) {
      if (!context.mounted) {
        return TokenEstimateDecision.cancelled;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => const PurchaseDialog(source: 'token_estimate'),
      );
      return TokenEstimateDecision.openedShop;
    }
    return TokenEstimateDecision.proceed;
  }
}
