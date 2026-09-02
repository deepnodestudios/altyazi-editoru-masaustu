import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/purchase_dialog.dart';
import 'billing_service.dart';
import 'gemini_service.dart';
import 'token_wallet_math.dart';

enum TokenEstimateDecision { proceed, cancelled, openedShop }

/// Start-Translate gate for the server-authoritative exact quote.
///
/// Sufficient balance proceeds without a second confirmation dialog — the Start
/// button already shows the exact token amount. Insufficient balance still opens
/// the shop prompt.
class TokenEstimateGateService {
  TokenEstimateGateService._();
  static final TokenEstimateGateService instance = TokenEstimateGateService._();

  int paidTokenBalance(BillingService billing) {
    if (billing.offerTokenPacks) {
      return billing.displayPaidTokenBalance;
    }
    return (billing.tokenBalance - billing.tokenGrantBalance)
        .clamp(0, billing.tokenBalance);
  }

  int grantTokenBalance(BillingService billing) {
    if (billing.isDesktopClient) return 0;
    if (billing.offerTokenPacks) return billing.displayBonusTokenBalance;
    return billing.tokenGrantBalance;
  }

  int spendableTokens(BillingService billing) {
    if (billing.isDesktopClient) {
      return paidTokenBalance(billing);
    }
    return billing.displayTokenBalance;
  }

  Future<TokenEstimateDecision> confirmIfNeeded({
    required BillingService billing,
    required Map<String, String> trans,
    required TranslationQuote quote,
  }) async {
    if (!billing.usesTokenWallet && !billing.offerTokenPacks) {
      return TokenEstimateDecision.proceed;
    }
    if (!quote.chargesTokens) {
      return TokenEstimateDecision.proceed;
    }
    if (quote.sufficient) {
      return TokenEstimateDecision.proceed;
    }

    final estimated = quote.quotedAppTokens;
    final remaining = quote.spendableTokens;
    final context = globalNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return TokenEstimateDecision.cancelled;
    }

    final openShop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final title = trans['token_insufficient_title'] ?? 'Not enough tokens';
        final body = (trans['token_insufficient_body'] ??
                'This file needs {needed} tokens. You have {balance}.')
            .replaceAll('{needed}', formatTokenCount(estimated))
            .replaceAll('{balance}', formatTokenCount(remaining));
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
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                trans['token_insufficient_shop'] ??
                    trans['add_tokens'] ??
                    'Add tokens',
              ),
            ),
          ],
        );
      },
    );

    if (openShop != true) {
      return TokenEstimateDecision.cancelled;
    }
    if (!context.mounted) {
      return TokenEstimateDecision.cancelled;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => const PurchaseDialog(source: 'token_estimate'),
    );
    return TokenEstimateDecision.openedShop;
  }
}
