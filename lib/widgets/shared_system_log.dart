import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_settings.dart';
import 'adaptive_text.dart';

/// Uygulama genelinde tek bir ortak "Sistem Günlüğü" paneli.
///
/// Hem Çeviri hem de Editör sekmesinin dışında, ana layout'ta kullanılır.
/// Kendi açılıp kapanma durumunu kendi içinde yönetir.
class SharedSystemLog extends StatefulWidget {
  const SharedSystemLog({super.key});

  @override
  State<SharedSystemLog> createState() => _SharedSystemLogState();
}

class _SharedSystemLogState extends State<SharedSystemLog> {
  bool _isLogExpanded = false;
  final ScrollController _logScrollController = ScrollController();
  bool _shouldAutoScrollLogs = true;

  void _handleLogScrollChanged() {
    if (!_logScrollController.hasClients) return;
    final position = _logScrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    const threshold = 24.0;
    _shouldAutoScrollLogs = distanceToBottom <= threshold;
  }

  void _scrollToBottomIfNeeded() {
    if (!_shouldAutoScrollLogs) return;
    if (!_logScrollController.hasClients) return;
    final maxScroll = _logScrollController.position.maxScrollExtent;
    if ((_logScrollController.offset - maxScroll).abs() < 1) return;
    _logScrollController.jumpTo(maxScroll);
  }

  @override
  void initState() {
    super.initState();
    _logScrollController.addListener(_handleLogScrollChanged);
  }

  @override
  void didUpdateWidget(covariant SharedSystemLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isLogExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottomIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _logScrollController.removeListener(_handleLogScrollChanged);
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final trans = settings.trans;

    // Auto-scroll when new logs arrive while expanded.
    if (_isLogExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottomIfNeeded();
      });
    }

    void copyAllLogsToClipboard() {
      if (settings.logs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trans['system_log_empty'] ??
                  'Sistem günlüğünde kopyalanacak kayıt yok.',
            ),
          ),
        );
        return;
      }

      final allLogs = settings.logs
          .reversed
          .map((log) => settings.formatLogLine(log))
          .join('\n');

      Clipboard.setData(ClipboardData(text: allLogs));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trans['system_log_copied'] ?? 'Sistem günlüğü panoya kopyalandı.',
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height:
          _isLogExpanded ? MediaQuery.of(context).size.height * 0.33 : 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).dividerColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 5,
            color: Theme.of(context)
                .colorScheme
                .shadow
                .withValues(alpha: 0.12),
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isLogExpanded = !_isLogExpanded;
                });
              },
              child: Container(
                height: 49,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            _isLogExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          AdaptiveText(
                            trans['system_log'] ?? 'Sistem Günlüğü',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            minFontSize: 10,
                          ),
                        ],
                      ),
                    ),
                    if (!_isLogExpanded && settings.logs.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: AdaptiveText(
                            settings.formatLogLine(
                              settings.logs.first,
                              includeTime: false,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            minFontSize: 8,
                          ),
                        ),
                      ),
                    if (_isLogExpanded)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_all),
                            tooltip: trans['copy'] ?? 'Kopyala',
                            onPressed: copyAllLogsToClipboard,
                          ),
                          IconButton(
                            icon: const Icon(Icons.save_alt),
                            tooltip: trans['save_log'],
                            onPressed: () => settings.saveLogsToFile(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLogExpanded)
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                width: double.infinity,
                child: SelectionArea(
                  child: SingleChildScrollView(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      settings.logs
                          .reversed
                          .map((log) => settings.formatLogLine(log))
                          .join('\n'),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier',
                        color: Theme.of(context).colorScheme.primary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
