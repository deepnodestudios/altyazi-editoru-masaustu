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
      body: const _CreditHistoryBody(),
    );
  }
}

class _CreditHistoryBody extends StatelessWidget {
  const _CreditHistoryBody();

  String _formatTimestamp(BuildContext context, DateTime? ts) {
    if (ts == null) return '';
    final local = ts.toLocal();
    final loc = MaterialLocalizations.of(context);
    final date = loc.formatFullDate(local);
    final time = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return '$date • $time';
  }

  String _formatAmount(BuildContext context, CreditHistoryEntry entry) {
    final sign = entry.type == CreditHistoryEntryType.add ? '+' : '-';
    return '$sign${entry.amount}';
  }

  String _titleFor(BuildContext context, CreditHistoryEntry entry) {
    final trans = context.read<ThemeManager>().trans;

    if (entry.type == CreditHistoryEntryType.add) {
      final base = trans['credit_history_added'] ?? 'Kredi eklendi';
      return base;
    }

    final base = trans['credit_history_spent'] ?? 'Kredi harcandı';
    return base;
  }

  String? _subtitleFor(BuildContext context, CreditHistoryEntry entry) {
    final pieces = <String>[];

    final ts = _formatTimestamp(context, entry.timestamp);
    if (ts.isNotEmpty) pieces.add(ts);

    if (entry.type == CreditHistoryEntryType.spend) {
      final file = entry.displayFileName;
      if (file != null && file.isNotEmpty) {
        pieces.add(file);
      }

      final platform = entry.platform;
      if (platform != null && platform.isNotEmpty) {
        pieces.add(platform);
      }

      final lang = entry.targetLanguage;
      if (lang != null && lang.isNotEmpty) {
        pieces.add(lang);
      }

      final reason = entry.reason;
      final hasFile = file != null && file.isNotEmpty;
      if (!hasFile && reason != null && reason.isNotEmpty) {
        if (reason.trim().toLowerCase() == 'cache_hit') {
          final trans = context.read<ThemeManager>().trans;
          pieces.add(trans['credit_history_cache_hit'] ?? 'Önbellek');
        } else {
          pieces.add(reason);
        }
      }
    } else {
      final source = entry.source;
      if (source != null && source.isNotEmpty) {
        pieces.add(source);
      }
      final productId = entry.productId;
      if (productId != null && productId.isNotEmpty) {
        pieces.add(productId);
      }
    }

    if (pieces.isEmpty) return null;
    return pieces.join(' • ');
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
                  title: Row(
                    children: [
                      Expanded(
                        child: AdaptiveText(
                          _titleFor(context, entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatAmount(context, entry),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                  subtitle: () {
                    final subtitle = _subtitleFor(context, entry);
                    if (subtitle == null || subtitle.isEmpty) return null;
                    return AdaptiveText(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      minFontSize: 10,
                    );
                  }(),
                );
              },
            );
          },
        );
      },
    );
  }
}
