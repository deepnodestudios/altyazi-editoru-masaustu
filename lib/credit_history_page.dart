import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'controllers/translation_controller.dart';
import 'managers/theme_manager.dart';
import 'models/credit_history_entry.dart';
import 'repositories/credit_history_repository.dart';
import 'services/token_wallet_math.dart';
import 'widgets/adaptive_text.dart';

class CreditHistoryPage extends StatelessWidget {
  const CreditHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final trans = context.watch<ThemeManager>().trans;
    final tokenUi = context.watch<TranslationController>().showTokenWalletUi;
    final title = tokenUi
        ? (trans['credit_history_title_tokens'] ??
            trans['credit_history_title'] ??
            'Token Geçmişi')
        : (trans['credit_history_title'] ?? 'Kredi Geçmişi');

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: trans['back'] ?? 'Geri',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: AdaptiveText(title, maxLines: 1),
      ),
      body: const CreditHistoryBody(),
    );
  }
}

class CreditHistoryBody extends StatelessWidget {
  const CreditHistoryBody({super.key});

  Map<String, String> _trans(BuildContext context) =>
      context.read<ThemeManager>().trans;

  String _formatTimestamp(BuildContext context, DateTime? ts) {
    if (ts == null) return '';
    final local = ts.toLocal();
    final day = _two(local.day);
    final month = _two(local.month);
    final year = local.year.toString();
    final hour = _two(local.hour);
    final minute = _two(local.minute);
    return '$day.$month.$year $hour:$minute';
  }

  String _two(int value) {
    return value < 10 ? '0$value' : '$value';
  }

  String _formatAmount(BuildContext context, CreditHistoryEntry entry) {
    final sign = entry.isAdd ? '+' : '-';
    final abs = entry.displayAmount;
    if (entry.isTokenLedger) {
      return '$sign${formatTokenCount(abs, grouping: '.')}';
    }
    return '$sign$abs';
  }

  bool _isSubscriptionRenewalForfeit(CreditHistoryEntry entry) {
    final reason = entry.reason?.trim().toLowerCase();
    return reason == 'subscription_renewal_forfeit';
  }

  bool _isSubscriptionRenewalGrant(CreditHistoryEntry entry) {
    final reason = entry.reason?.trim().toLowerCase();
    return reason == 'subscription_renewal';
  }

  bool _isAdReward(CreditHistoryEntry entry) {
    final source = entry.source?.trim().toLowerCase();
    final reason = entry.reason?.trim().toLowerCase();
    return source == 'ad_reward' || reason == 'ad_reward';
  }

  bool _isMonthlyBonus(CreditHistoryEntry entry) {
    final reason = entry.reason?.trim().toLowerCase();
    return reason == 'monthly_google_bonus';
  }

  bool _isPurchaseBonus(CreditHistoryEntry entry) {
    final source = entry.source?.trim().toLowerCase();
    final reason = entry.reason?.trim().toLowerCase();
    return source == 'purchase_bonus' || reason == 'purchase_bonus';
  }

  bool _isBonusExpired(CreditHistoryEntry entry) {
    final source = entry.source?.trim().toLowerCase();
    final reason = entry.reason?.trim().toLowerCase();
    return source == 'bonus_expired' ||
        reason == 'bonus_expired' ||
        reason == 'bonus_expiry';
  }

  String? _productLabelFor(BuildContext context, String? rawProductId) {
    final trans = _trans(context);
    final productId = rawProductId?.trim().toLowerCase();
    if (productId == null || productId.isEmpty) {
      return null;
    }

    switch (productId) {
      case 'sub_20_credits_monthly':
      case 'hobi_paket_monthly':
        return trans['subscription_hobby_title'] ?? 'Hobby Pack';
      case 'sub_30_credits_monthly':
      case 'sinema_paketi_monthly':
        return trans['subscription_cinema_title'] ?? 'Cinema Pack';
      case 'tokens_1m':
        return trans['package_tokens_1m'] ??
            '${trans['package_starter'] ?? 'Starter Pack'} (1M ${trans['wallet_token_label'] ?? trans['purchase_tokens_unit'] ?? 'Tokens'})';
      case '2048626':
      case '1456186':
        return '${trans['package_starter'] ?? 'Starter Pack'} (1.1M ${trans['wallet_token_label'] ?? trans['purchase_tokens_unit'] ?? 'Tokens'})';
      case 'tokens_5m':
        return trans['package_tokens_5m'] ??
            '${trans['package_pro'] ?? 'Pro Pack'} (5M ${trans['wallet_token_label'] ?? trans['purchase_tokens_unit'] ?? 'Tokens'})';
      case '2048645':
      case '1456188':
        return '${trans['package_pro'] ?? 'Pro Pack'} (5.5M ${trans['wallet_token_label'] ?? trans['purchase_tokens_unit'] ?? 'Tokens'})';
      case 'tokens_10m':
        return trans['package_tokens_10m'] ??
            '${trans['package_expert'] ?? 'Expert Pack'} (10M ${trans['wallet_token_label'] ?? trans['purchase_tokens_unit'] ?? 'Tokens'})';
      case '2048653':
      case '1456194':
        return '${trans['package_expert'] ?? 'Expert Pack'} (11M ${trans['wallet_token_label'] ?? trans['purchase_tokens_unit'] ?? 'Tokens'})';
      default:
        if (productId.startsWith('credits_')) {
          return trans['credits_pack_generic'] ?? 'Credit Pack';
        }
        if (productId.startsWith('tokens_') || productId.contains('token')) {
          return trans['tokens_pack_generic'] ?? 'Token Pack';
        }
        return rawProductId?.trim();
    }
  }

  String? _addSourceLabel(BuildContext context, CreditHistoryEntry entry) {
    final trans = _trans(context);

    if (_isPurchaseBonus(entry)) {
      return trans['credit_source_purchase_bonus'] ?? 'Purchase Bonus';
    }
    if (_isSubscriptionRenewalGrant(entry)) {
      return trans['credit_source_subscription_renewal'] ??
          trans['credit_source_subscription'] ??
          'Subscription Renewal';
    }
    if (_isBonusExpired(entry)) {
      return trans['credit_source_bonus_expired'] ?? 'Bonus Expired';
    }
    if (entry.source?.trim().toLowerCase() == 'legacy_bonus_conversion' ||
        entry.reason?.trim().toLowerCase() == 'legacy_bonus_conversion') {
      return trans['credit_source_legacy_bonus_conversion'] ??
          'Bonus krediler tokena dönüştürüldü';
    }
    if (_isMonthlyBonus(entry)) {
      return trans['credit_source_monthly_bonus'] ?? 'Monthly Bonus';
    }
    if (entry.source == 'login_bonus') {
      return trans['credit_source_login_bonus'] ?? 'Google Login Bonus';
    }
    if (_isAdReward(entry)) {
      return trans['credit_source_ad_reward'] ?? 'Ad Reward Credit';
    }

    final source = entry.source?.trim().toLowerCase();
    if (source == null || source.isEmpty) {
      return null;
    }

    if (source == 'purchase_history' || source.contains('purchase')) {
      return trans['credit_source_purchase'] ?? 'Purchase';
    }
    if (source == 'subscription' || source.contains('subscription')) {
      return trans['credit_source_subscription'] ?? 'Subscription';
    }
    if (source.contains('website')) {
      return trans['credit_source_website'] ?? 'Website';
    }
    if (source.contains('referral')) {
      return trans['credit_source_referral'] ??
          trans['referral_dialog_title'] ??
          'Referral reward';
    }

    return source;
  }

  String _titleFor(BuildContext context, CreditHistoryEntry entry) {
    final trans = _trans(context);

    if (entry.isAdd) {
      if (entry.isTokenLedger) {
        return trans['credit_history_add_tokens'] ??
            trans['credit_history_add'] ??
            trans['credit_history_added'] ??
            'Token added';
      }
      return trans['credit_history_add'] ??
          trans['credit_history_added'] ??
          'Credit added';
    }

    if (_isSubscriptionRenewalForfeit(entry)) {
      if (entry.isTokenLedger) {
        return trans['credit_history_subscription_forfeit_tokens'] ??
            trans['credit_history_subscription_forfeit'] ??
            'Unused subscription tokens reset';
      }
      return trans['credit_history_subscription_forfeit'] ??
          'Unused subscription credits reset';
    }

    if (entry.isTokenLedger) {
      return trans['credit_history_spend_tokens'] ??
          trans['credit_history_spend'] ??
          'Token spent';
    }

    return trans['credit_history_spend'] ?? 'Credit spent';
  }

  String _buildSpendDetail(BuildContext context, CreditHistoryEntry entry) {
    final detailParts = <String>[];

    final displayFileName = entry.displayFileName;
    if (displayFileName != null && displayFileName.isNotEmpty) {
      detailParts.add(displayFileName);
    } else {
      final reason = entry.reason?.trim();
      if (reason == 'cache_hit') {
        final trans = _trans(context);
        detailParts.add(trans['credit_history_cache'] ??
            trans['credit_history_cache_hit'] ??
            'Cache');
      } else if (_isSubscriptionRenewalForfeit(entry)) {
        final trans = _trans(context);
        detailParts.add(
          trans['credit_source_subscription_renewal_forfeit'] ??
              trans['credit_source_subscription'] ??
              'Monthly subscription renewal',
        );
        final productLabel = _productLabelFor(context, entry.productId);
        if (productLabel != null && productLabel.isNotEmpty) {
          detailParts.add(productLabel);
        }
      } else if (reason != null && reason.isNotEmpty) {
        const hiddenReasons = {'first_chunk', 'usage', 'unknown'};
        if (!hiddenReasons.contains(reason)) {
          detailParts.add(reason);
        }
      }
    }

    final platform = entry.platform?.trim();
    if (platform != null && platform.isNotEmpty) {
      detailParts.add(platform);
    }

    var targetLanguage = entry.targetLanguage?.trim();
    if (targetLanguage == null || targetLanguage.isEmpty) {
      targetLanguage = _inferTargetLanguageFromChargeKey(entry.chargeKey);
    }
    if (targetLanguage != null && targetLanguage.isNotEmpty) {
      detailParts.add(targetLanguage.length <= 3
          ? targetLanguage.toUpperCase()
          : targetLanguage);
    }

    return detailParts.join(' • ');
  }

  String? _inferTargetLanguageFromChargeKey(String? chargeKey) {
    final key = chargeKey?.trim();
    if (key == null || key.isEmpty) return null;
    final m = RegExp(r'^run_\d+_[a-fA-F0-9]{32}_(.+)$').firstMatch(key);
    if (m == null) return null;
    final value = (m.group(1) ?? '').trim();
    if (value.isEmpty) return null;
    return value;
  }

  String? _subtitleFor(BuildContext context, CreditHistoryEntry entry) {
    final subtitleParts = <String>[];

    final dateText = _formatTimestamp(context, entry.timestamp);
    if (dateText.isNotEmpty) {
      subtitleParts.add(dateText);
    }

    if (entry.isSpend) {
      final spendDetails = _buildSpendDetail(context, entry);
      if (spendDetails.isNotEmpty) {
        subtitleParts.add(spendDetails);
      }
    } else {
      final sourceLabel = _addSourceLabel(context, entry);
      if (sourceLabel != null && sourceLabel.isNotEmpty) {
        subtitleParts.add(sourceLabel);
      }

      final productLabel = _productLabelFor(context, entry.productId);
      if (productLabel != null && productLabel.isNotEmpty) {
        subtitleParts.add(productLabel);
      }
    }

    if (subtitleParts.isEmpty) return null;
    return subtitleParts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final trans = context.watch<ThemeManager>().trans;
    final tokenUi = context.watch<TranslationController>().showTokenWalletUi;
    final emptyLabel = trans['credit_history_empty'] ?? 'No transactions yet.';
    final errorLabel = tokenUi
        ? (trans['credit_history_error_tokens'] ??
            trans['credit_history_error'] ??
            'Could not load token history.')
        : (trans['credit_history_error'] ?? 'Could not load credit history.');

    final auth = FirebaseAuth.instance;

    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      initialData: auth.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null || user.isAnonymous) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AdaptiveText(
                emptyLabel,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final repo = CreditHistoryRepository();

        return StreamBuilder<List<CreditHistoryEntry>>(
          stream: repo.watchCreditHistory(
            limit: 200,
            includeLegacyFallback: true,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              assert(() {
                debugPrint('[CreditHistory] Stream error: ${snapshot.error}');
                return true;
              }());
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AdaptiveText(
                    errorLabel,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final entries = (snapshot.data ?? const <CreditHistoryEntry>[])
                .where((entry) => !entry.isHiddenLemonExtraRow)
                .toList();
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AdaptiveText(
                    emptyLabel,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final colorScheme = Theme.of(context).colorScheme;

            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isAdd = entry.isAdd;
                final amountColor =
                    isAdd ? colorScheme.primary : colorScheme.error;

                return ListTile(
                  leading: Icon(
                    isAdd
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    color: amountColor,
                  ),
                  title: Text(
                    _titleFor(context, entry),
                  ),
                  subtitle: () {
                    final subtitle = _subtitleFor(context, entry);
                    if (subtitle == null || subtitle.isEmpty) return null;
                    return Text(subtitle);
                  }(),
                  trailing: Text(
                    _formatAmount(context, entry),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
