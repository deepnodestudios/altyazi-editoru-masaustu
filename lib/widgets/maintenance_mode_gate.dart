import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../managers/theme_manager.dart';
import '../services/maintenance_mode_service.dart';
import 'maintenance_mode_screen.dart';

class MaintenanceModeGate extends StatefulWidget {
  final Widget child;

  const MaintenanceModeGate({
    super.key,
    required this.child,
  });

  @override
  State<MaintenanceModeGate> createState() => _MaintenanceModeGateState();
}

class _MaintenanceModeGateState extends State<MaintenanceModeGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _maintenanceActive = false;
  bool _retrying = false;
  final List<Timer> _retryTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshMaintenanceState(isInitial: true);
    // RC can race with Firebase startup on desktop; retry a few times.
    for (final delay in const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 6),
      Duration(seconds: 15),
    ]) {
      _retryTimers.add(Timer(delay, () {
        if (!mounted || _maintenanceActive) return;
        _refreshMaintenanceState();
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
      _refreshMaintenanceState();
    }
  }

  Future<void> _refreshMaintenanceState({bool isInitial = false}) async {
    final active = await MaintenanceModeService.refreshAndIsActive();
    if (!mounted) return;
    setState(() {
      _maintenanceActive = active;
      if (isInitial || _checking) {
        _checking = false;
      }
      _retrying = false;
    });
  }

  Future<void> _handleRetry() async {
    setState(() => _retrying = true);
    await _refreshMaintenanceState();
  }

  Widget _wrapWithApp(Widget home) {
    final themeManager = context.watch<ThemeManager>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeManager.themeMode,
      theme: AppTheme.light(),
      darkTheme: themeManager.oledMode ? AppTheme.oled() : AppTheme.dark(),
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return _wrapWithApp(
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_maintenanceActive) {
      final themeManager = context.watch<ThemeManager>();
      final trans = themeManager.trans;
      return _wrapWithApp(
        MaintenanceModeScreen(
          title: trans['maintenance_title'] ?? 'Under Maintenance',
          message: trans['maintenance_message'] ??
              'We are currently performing maintenance. Please try again later.',
          retryLabel: trans['maintenance_retry_btn'] ?? 'Try Again',
          onRetry: _handleRetry,
          isRetrying: _retrying,
        ),
      );
    }

    return widget.child;
  }
}
