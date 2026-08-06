import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'managers/theme_manager.dart';
import 'models/credit_history_entry.dart';
import 'repositories/credit_history_repository.dart';
import 'widgets/adaptive_text.dart';

class CreditHistoryPage extends StatelessWidget {
  const CreditHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final trans = context.watch<ThemeManager>().trans;
    final title = trans['credit_history_title'] ?? 'Kredi Geçmişi';

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
    final sign = entry.type == CreditHistoryEntryType.add ? '+' : '-';
    return '$sign${entry.amount.abs()}';
  }

  String? _addSourceLabel(BuildContext context, CreditHistoryEntry entry) {
    final trans = context.read<ThemeManager>().trans;
    final source = entry.source?.trim().toLowerCase();

    if (entry.reason?.trim().toLowerCase() == 'monthly_google_bonus') {
      return trans['credit_source_monthly_bonus'] ?? 'Monthly Bonus';
    }
    if (source == 'login_bonus') {
      return trans['credit_source_login_bonus'] ?? 'Google Login Bonus';
    }
    if (source == 'purchase_history' || (source?.contains('purchase') ?? false)) {
      return trans['credit_source_purchase'] ?? 'Purchase';
    }
    if (source?.contains('website') ?? false) {
      return trans['credit_source_website'] ?? 'Website';
    }

    return source;
  }

  String _titleFor(BuildContext context, CreditHistoryEntry entry) {
    final trans = context.read<ThemeManager>().trans;

    if (entry.type == CreditHistoryEntryType.add) {
      return trans['credit_history_add'] ?? trans['credit_history_added'] ?? 'Credit added';
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
        final trans = context.read<ThemeManager>().trans;
        detailParts.add(trans['credit_history_cache'] ?? trans['credit_history_cache_hit'] ?? 'Cache');
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
    final trans = context.read<ThemeManager>().trans;

    final dateText = _formatTimestamp(context, entry.timestamp);
    if (dateText.isNotEmpty) {
      subtitleParts.add(dateText);
    }

    if (entry.type == CreditHistoryEntryType.spend) {
      final spendDetails = _buildSpendDetail(context, entry);
      if (spendDetails.isNotEmpty) {
        subtitleParts.add(spendDetails);
      }
    } else {
      final sourceLabel = _addSourceLabel(context, entry);
      if (sourceLabel != null && sourceLabel.isNotEmpty) {
        subtitleParts.add(sourceLabel);
      }

      var productId = entry.productId?.trim().toLowerCase();
      if (productId != null && productId.isNotEmpty) {
        if (productId.startsWith('credits_')) {
          subtitleParts.add(trans['credits_pack_generic'] ?? 'Credit Pack');
        } else {
          subtitleParts.add(productId);
        }
      }
    }

    if (subtitleParts.isEmpty) return null;
    return subtitleParts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final trans = context.watch<ThemeManager>().trans;

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
                trans['credit_history_empty'] ?? 'No transactions yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final repo = CreditHistoryRepository();

        return StreamBuilder<List<CreditHistoryEntry>>(
          stream: repo.watchCreditHistory(limit: 200, includeLegacyFallback: true),
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
                    trans['credit_history_error'] ?? 'Could not load credit history.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final entries = snapshot.data ?? const <CreditHistoryEntry>[];
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AdaptiveText(
                    trans['credit_history_empty'] ?? 'No transactions yet.',
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
                final isAdd = entry.type == CreditHistoryEntryType.add;
                final amountColor = isAdd ? colorScheme.primary : colorScheme.error;

                return ListTile(
                  leading: Icon(
                    isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline,
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
