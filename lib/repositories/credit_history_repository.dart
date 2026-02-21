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
      await txSub?.cancel();
      txSub = null;
      await stopLegacySubs();
    }

    void emitEmpty() {
      controller.add(const <CreditHistoryEntry>[]);
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
        final merged = <CreditHistoryEntry>[...latestPurchases!, ...latestUsages!];
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
      final txQuery = _firestore
          .collection('users')
          .doc(uid)
          .collection('credit_transactions')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (!includeLegacyFallback) {
        txSub = txQuery.snapshots().listen(
          (snapshot) {
            final txEntries = snapshot.docs
                .map(CreditHistoryEntry.fromCreditTransactionsDoc)
                .toList();
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
          final txEntries = snapshot.docs
              .map(CreditHistoryEntry.fromCreditTransactionsDoc)
              .toList();

          _debug('unified snapshot: ${txEntries.length} entries');

          if (txEntries.isNotEmpty) {
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
