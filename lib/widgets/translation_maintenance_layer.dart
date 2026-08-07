import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../managers/theme_manager.dart';
import '../services/maintenance_mode_service.dart';
import 'maintenance_mode_screen.dart';

/// Wraps only the translation UI. Editor and the rest of the app stay usable.
class TranslationMaintenanceLayer extends StatefulWidget {
  final Widget child;

  const TranslationMaintenanceLayer({
    super.key,
    required this.child,
  });

  @override
  State<TranslationMaintenanceLayer> createState() =>
      _TranslationMaintenanceLayerState();
}

class _TranslationMaintenanceLayerState
    extends State<TranslationMaintenanceLayer> with WidgetsBindingObserver {
  bool _active = false;
  bool _retrying = false;
  final List<Timer> _retryTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    for (final delay in const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 6),
      Duration(seconds: 15),
    ]) {
      _retryTimers.add(Timer(delay, () {
        if (!mounted || _active) return;
        _refresh();
      }));
    }
  }

  @override
  void dispose() {
    for (final timer in _retryTimers) {
      timer.cancel();
    }
    _retryTimers.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final active = await MaintenanceModeService.refreshAndIsActive();
    if (!mounted) return;
    setState(() {
      _active = active;
      _retrying = false;
    });
  }

  Future<void> _handleRetry() async {
    setState(() => _retrying = true);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    final trans = themeManager.trans;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_active)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: MaintenanceModeScreen(
                asOverlay: true,
                title: trans['maintenance_title'] ?? 'Under Maintenance',
                message: trans['maintenance_message'] ??
                    'We are currently performing maintenance. Please try again later.',
                retryLabel: trans['maintenance_retry_btn'] ?? 'Try Again',
                onRetry: _handleRetry,
                isRetrying: _retrying,
              ),
            ),
          ),
      ],
    );
  }
}
