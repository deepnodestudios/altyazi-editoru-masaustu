import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/credit_history_entry.dart';

class CreditHistoryRepository {
  CreditHistoryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  bool _isVisibleEntry(CreditHistoryEntry entry) {
    if (entry.type != CreditHistoryEntryType.add) {
      return true;
    }

    final source = (entry.source ?? '').trim().toLowerCase();
    final reason = (entry.reason ?? '').trim().toLowerCase();

    if (source == 'ad_reward' || reason == 'ad_reward') {
      return false;
    }

    if (reason == 'monthly_google_bonus') {
      return false;
    }

    return true;
  }

  List<CreditHistoryEntry> _filterVisibleEntries(List<CreditHistoryEntry> entries) {
    return entries.where(_isVisibleEntry).toList(growable: false);
  }

  void _debug(String message) {
    assert(() {
      debugPrint('[CreditHistory] $message');
      return true;
    }());
  }

  Stream<List<CreditHistoryEntry>> watchCreditHistory({
    int limit = 200,
    bool includeLegacyFallback = true,
  }) {
    // Build a stream that reacts to auth changes so data clears immediately on
    // logout (and switches user streams on re-login) even if the UI doesn't
    // rebuild or auth streams are flaky on desktop.
    late final StreamController<List<CreditHistoryEntry>> controller;

    StreamSubscription<User?>? authSub;
    Timer? authPollTimer;
    // Windows polling timers (replaces Firestore stream listeners on Windows)
    Timer? windowsPollTimer;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? txSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? purchaseSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? usageSub;

    String? activeUid;
    List<CreditHistoryEntry>? latestPurchases;
    List<CreditHistoryEntry>? latestUsages;

    Future<void> stopLegacySubs() async {
      await purchaseSub?.cancel();
      await usageSub?.cancel();
      purchaseSub = null;
      usageSub = null;
      latestPurchases = null;
      latestUsages = null;
    }

    Future<void> stopAllFirestoreSubs() async {
      windowsPollTimer?.cancel();
      windowsPollTimer = null;
      await txSub?.cancel();
      txSub = null;
      await stopLegacySubs();
    }

    void emitEmpty() {
      controller.add(const <CreditHistoryEntry>[]);
    }

    // Windows-only: one-time fetch of legacy collections (no stream listener).
    Future<void> fetchLegacyOnceForUid(String uid) async {
      _debug('windows polling: fetching legacy collections once');
      try {
        final purchaseSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('purchase_history')
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();
        final usageSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('credit_usage')
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();
        final purchases =
            purchaseSnap.docs.map(CreditHistoryEntry.fromPurchaseHistoryDoc).toList();
        final usages =
            usageSnap.docs.map(CreditHistoryEntry.fromCreditUsageDoc).toList();
        final merged = _filterVisibleEntries(<CreditHistoryEntry>[...purchases, ...usages]);
        merged.sort((a, b) {
          final at = a.timestamp;
          final bt = b.timestamp;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        _debug(
          'windows legacy fetched: purchases=${purchases.length}, usages=${usages.length}, total=${merged.length}',
        );
        if (!controller.isClosed) {
          controller.add(merged.length > limit ? merged.sublist(0, limit) : merged);
        }
      } catch (e) {
        _debug('windows legacy fetch error: $e');
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Windows-only: one-time fetch + polling via Timer (no stream listeners).
    void startWindowsPollingForUid(String uid) {
      windowsPollTimer?.cancel();
      windowsPollTimer = null;

      Future<void> poll() async {
        if (activeUid != uid) return;
        _debug('windows polling: fetching credit_transactions');
        try {
          final txSnap = await _firestore
              .collection('users')
              .doc(uid)
              .collection('credit_transactions')
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();
          if (activeUid != uid) return;
          if (txSnap.docs.isNotEmpty) {
            final txEntries = _filterVisibleEntries(txSnap.docs
                .map(CreditHistoryEntry.fromCreditTransactionsDoc)
                .toList());
            _debug('windows polling: unified ${txEntries.length} entries');
            if (!controller.isClosed) controller.add(txEntries);
          } else if (includeLegacyFallback) {
            await fetchLegacyOnceForUid(uid);
          } else {
            if (!controller.isClosed) {
              controller.add(const <CreditHistoryEntry>[]);
            }
          }
        } catch (e) {
          _debug('windows poll error: $e');
          if (!controller.isClosed) controller.addError(e);
        }
      }

      // Initial fetch immediately, then poll every 15 seconds.
      unawaited(poll());
      windowsPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(poll());
      });
    }

    void startLegacySubsForUid(String uid) {
      if (purchaseSub != null || usageSub != null) return;

      _debug('unified empty; subscribing to legacy collections');

      final purchaseQuery = _firestore
          .collection('users')
          .doc(uid)
          .collection('purchase_history')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      final usageQuery = _firestore
          .collection('users')
          .doc(uid)
          .collection('credit_usage')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      void emitLegacyIfReady() {
        if (latestPurchases == null || latestUsages == null) return;
        final merged = _filterVisibleEntries(
          <CreditHistoryEntry>[...latestPurchases!, ...latestUsages!],
        );
        merged.sort((a, b) {
          final at = a.timestamp;
          final bt = b.timestamp;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        _debug(
          'legacy merged: purchases=${latestPurchases!.length}, usages=${latestUsages!.length}, total=${merged.length}',
        );
        controller.add(merged.length > limit ? merged.sublist(0, limit) : merged);
      }

      purchaseSub = purchaseQuery.snapshots().listen(
        (snapshot) {
          latestPurchases =
              snapshot.docs.map(CreditHistoryEntry.fromPurchaseHistoryDoc).toList();
          emitLegacyIfReady();
        },
        onError: controller.addError,
      );

      usageSub = usageQuery.snapshots().listen(
        (snapshot) {
          latestUsages =
              snapshot.docs.map(CreditHistoryEntry.fromCreditUsageDoc).toList();
          emitLegacyIfReady();
        },
        onError: controller.addError,
      );
    }

    void startUnifiedSubsForUid(String uid) {
      // Windows'da Firestore stream callback'leri platform thread dışında
      // gelebiliyor (engine crash riski). Windows'da polling kullan.
      if (!kIsWeb && Platform.isWindows) {
        _debug('windows: using polling instead of stream listeners');
        startWindowsPollingForUid(uid);
        return;
      }

      final txQuery = _firestore
          .collection('users')
          .doc(uid)
          .collection('credit_transactions')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (!includeLegacyFallback) {
        txSub = txQuery.snapshots().listen(
          (snapshot) {
            final txEntries = _filterVisibleEntries(snapshot.docs
                .map(CreditHistoryEntry.fromCreditTransactionsDoc)
                .toList());
            controller.add(txEntries);
          },
          onError: controller.addError,
        );
        return;
      }

      // Prefer unified `credit_transactions`. If it's empty (older users), fall
      // back to legacy collections. If unified becomes non-empty later, switch.
      txSub = txQuery.snapshots().listen(
        (snapshot) async {
          final rawTxEntries = snapshot.docs
              .map(CreditHistoryEntry.fromCreditTransactionsDoc)
              .toList();
          final txEntries = _filterVisibleEntries(rawTxEntries);

          _debug('unified snapshot: visible=${txEntries.length}, raw=${rawTxEntries.length}');

          if (rawTxEntries.isNotEmpty) {
            _debug('using unified credit_transactions');
            await stopLegacySubs();
            controller.add(txEntries);
            return;
          }

          startLegacySubsForUid(uid);
        },
        onError: (Object error, StackTrace stack) {
          _debug('unified stream error; falling back to legacy: $error');
          startLegacySubsForUid(uid);
        },
      );
    }

    String signatureFor(User? user) {
      if (user == null) return 'null';
      return '${user.uid}|${user.isAnonymous}';
    }

    Future<void> handleUser(User? user) async {
      final uid = user?.uid;
      if (user == null || uid == null || user.isAnonymous) {
        if (activeUid != null) {
          _debug('auth changed: logged out/anonymous; clearing history');
        }
        activeUid = null;
        await stopAllFirestoreSubs();
        emitEmpty();
        return;
      }

      if (activeUid == uid) return;
      _debug('auth changed: uid=$uid; switching credit history stream');
      activeUid = uid;
      await stopAllFirestoreSubs();
      startUnifiedSubsForUid(uid);
    }

    controller = StreamController<List<CreditHistoryEntry>>(
      onListen: () {
        // On Windows desktop, authStateChanges can be unreliable. Poll current
        // user signature so logout always clears the stream.
        if (!kIsWeb && Platform.isWindows) {
          var lastSig = signatureFor(_auth.currentUser);
          unawaited(handleUser(_auth.currentUser));
          authPollTimer = Timer.periodic(
            const Duration(milliseconds: 750),
            (_) {
              final sig = signatureFor(_auth.currentUser);
              if (sig == lastSig) return;
              lastSig = sig;
              unawaited(handleUser(_auth.currentUser));
            },
          );
          return;
        }

        authSub = _auth.authStateChanges().listen(
          (user) {
            unawaited(handleUser(user));
          },
          onError: controller.addError,
        );

        // Seed with current state.
        unawaited(handleUser(_auth.currentUser));
      },
    );

    controller.onCancel = () async {
      await authSub?.cancel();
      authSub = null;
      authPollTimer?.cancel();
      authPollTimer = null;
      await stopAllFirestoreSubs();
    };

    return controller.stream;
  }
}
