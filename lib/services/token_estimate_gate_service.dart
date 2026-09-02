import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/purchase_dialog.dart';
import 'billing_service.dart';
import 'gemini_service.dart';
import 'token_wallet_math.dart';

enum TokenEstimateDecision { proceed, cancelled, openedShop }

/// Start-Translate confirm for the server-authoritative exact quote.
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
    final estimated = quote.quotedAppTokens;
    if (!quote.chargesTokens) {
      return TokenEstimateDecision.proceed;
    }

    final remaining = quote.spendableTokens;
    final insufficient = !quote.sufficient;
    final allocation = TokenChargeAllocation(
      fromPaidTokens: quote.fromPaidTokens,
      fromGrantTokens: quote.fromGrantTokens,
    );
    final mixedPayment = !insufficient && allocation.isMixed;
    final paidFirstMix = mixedPayment && !billing.preferFreeCreditsFirst;
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
        final String title;
        final String body;
        if (insufficient) {
          title = trans['token_insufficient_title'] ?? 'Not enough tokens';
          body = (trans['token_insufficient_body'] ??
                  'This file needs {needed} tokens. You have {balance}.')
              .replaceAll('{needed}', formatTokenCount(estimated))
              .replaceAll('{balance}', formatTokenCount(remaining));
        } else if (mixedPayment) {
          title = paidFirstMix
              ? (trans['token_mix_bonus_title'] ?? 'Paid tokens are not enough')
              : (trans['token_mix_paid_title'] ??
                  'Bonus tokens are not enough');
          final allocationBody = (trans['token_mix_paid_body'] ??
                  'This file needs exactly {needed} tokens: {bonus} from bonus tokens, {paid} from paid tokens.')
              .replaceAll('{needed}', formatTokenCount(estimated))
              .replaceAll(
                '{bonus}',
                formatTokenCount(allocation.fromGrantTokens),
              )
              .replaceAll(
                '{paid}',
                formatTokenCount(allocation.fromPaidTokens),
              );
          final adNotice = trans['token_mix_rewarded_ad_notice'] ??
              'Because bonus tokens will be used, a rewarded ad will be shown before processing.';
          body = '$allocationBody\n\n$adNotice';
        } else {
          title = trans['token_estimate_title'] ?? 'Exact token use';
          body = (trans['token_estimate_body'] ??
                  'This file will use exactly {tokens} tokens. Remaining after: {remaining}.')
              .replaceAll('{tokens}', formatTokenCount(estimated))
              .replaceAll(
                '{remaining}',
                formatTokenCount(remaining - estimated),
              );
        }
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
                child: Text(
                  mixedPayment
                      ? (trans['token_mix_paid_confirm'] ??
                          trans['token_estimate_confirm'] ??
                          'Continue')
                      : (trans['token_estimate_confirm'] ?? 'Start'),
                ),
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
