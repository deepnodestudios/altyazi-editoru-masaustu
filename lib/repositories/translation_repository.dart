import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TranslationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Firestore document size is limited (~1MiB). Full resumeState JSON can be
  /// very large (chunks + translatedText duplicate data), so we compact it.
  ///
  /// The resume loader reconstructs missing fields (chunks/translatedText)
  /// from `sourceContent` + `translatedBlocks`.
  Map<String, dynamic> _compactResumeStateForCloud(Map<String, dynamic> raw) {
    // Keep only the minimum needed to resume on another device.
    final out = <String, dynamic>{
      'v': 2,
    };

    void keep(String key) {
      if (raw.containsKey(key) && raw[key] != null) {
        out[key] = raw[key];
      }
    }

    keep('hash');
    keep('targetLanguage');
    keep('clearSdh');
    keep('sourceContent');
    keep('sourceEncoding');
    keep('nextChunkIndex');
    keep('translatedBlocks');
    keep('processedLines');
    keep('totalLines');
    keep('totalBlocks');
    keep('chargeKey');

    return out;
  }

  /// Generate global cache key: sourceHash + targetLanguage
  String _generateGlobalCacheKey(String sourceHash, String targetLanguage) {
    return '${sourceHash}_${targetLanguage.toLowerCase()}';
  }

  /// Check if translation exists in global cache (shared across all users)
  Future<Map<String, dynamic>?> checkGlobalCache({
    required String sourceHash,
    required String targetLanguage,
  }) async {
    final cacheKey = _generateGlobalCacheKey(sourceHash, targetLanguage);
    final docRef = _firestore.collection('global_translations').doc(cacheKey);

    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      return docSnapshot.data();
    }
    return null;
  }

  /// Save translation to global cache (shared for all users)
  Future<void> saveToGlobalCache({
    required String sourceHash,
    required String sourceContent,
    required String translatedContent,
    required String originalName,
    required String targetLanguage,
    String? encodingDetected,
  }) async {
    if (encodingDetected != null && !_isModernEncoding(encodingDetected)) {
      return;
    }
    final cacheKey = _generateGlobalCacheKey(sourceHash, targetLanguage);
    
    final docRef = _firestore.collection('global_translations').doc(cacheKey);
    final docSnapshot = await docRef.get();
    
    if (docSnapshot.exists) {
      // Increment usage count if already exists
      await docRef.update({
        'usageCount': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new global translation
      await docRef.set({
        'sourceContent': sourceContent,
        'translatedContent': translatedContent,
        'originalName': originalName,
        'targetLanguage': targetLanguage,
        'sourceHash': sourceHash,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
        'usageCount': 1,
      });
    }
  }

  /// Add translation reference to user's history.
  /// Uses a stable doc ID `{sourceHash}_{targetLanguage}` with merge semantics
  /// so that the same translation from any device always points to one doc.
  Future<String> addToUserHistory({
    required String sourceHash,
    required String fileName,
    required String targetLanguage,
    bool isPartial = false,
    String? encodingDetected,
    Map<String, dynamic>? resumeState,
    int? translatedLines,
    int? totalLines,
    bool? isActive,
    bool? clearSdh,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return '';

    // Stable doc ID — same hash+language always produces the same key.
    final historyDocId = '${sourceHash}_${targetLanguage.toLowerCase()}';
    final cacheKey = _generateGlobalCacheKey(sourceHash, targetLanguage);

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('translation_history')
        .doc(historyDocId)
        .set({
          'globalTranslationRef': cacheKey,
          'fileName': fileName,
          'targetLanguage': targetLanguage,
          'sourceHash': sourceHash,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isPartial': isPartial,
          if (isActive != null) 'isActive': isActive,
          // Çevirinin yapıldığı platformı kaydet (android, ios, windows, macos, linux)
          'completedPlatform': Platform.operatingSystem,
          if (translatedLines != null) 'translatedLines': translatedLines,
          if (totalLines != null) 'totalLines': totalLines,
          if (isPartial && resumeState != null) ...{
            'resumeState': _compactResumeStateForCloud(resumeState),
            'resumeUpdatedAt': FieldValue.serverTimestamp(),
          },
          if (!isPartial) ...{
            // Completed items should not keep stale resume payloads.
            'resumeState': FieldValue.delete(),
            'resumeUpdatedAt': FieldValue.delete(),
          },
          if (!isPartial) 'completedAt': FieldValue.serverTimestamp(),
          if (encodingDetected != null) 'encodingDetected': encodingDetected,
          if (clearSdh != null) 'clearSdh': clearSdh,
        }, SetOptions(merge: true));

    return historyDocId;
  }

  /// Mark a user's history entry as active/inactive.
  ///
  /// Used to temporarily hide an entry from History while it is being resumed.
  Future<void> setUserHistoryActive({
    required String sourceHash,
    required String targetLanguage,
    required bool isActive,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final historyDocId = '${sourceHash}_${targetLanguage.toLowerCase()}';

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('translation_history')
        .doc(historyDocId)
        .set({
          'isActive': isActive,
          'activeUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Delete from user's history (global cache stays)
  Future<void> deleteFromUserHistory({
    required String historyDocId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('translation_history')
        .doc(historyDocId)
        .delete();
  }

  /// Get user's translation history
  Future<List<Map<String, dynamic>>> getUserTranslationHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('translation_history')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['historyDocId'] = doc.id;
      return data;
    }).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserTranslationHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('translation_history')
        .orderBy('createdAt', descending: true)
          .snapshots();
  }

  Future<void> clearAllUserHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('translation_history')
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Get translated content from global cache by reference
  Future<Map<String, dynamic>?> getTranslationByRef(String globalRef) async {
    final docSnapshot = await _firestore
        .collection('global_translations')
        .doc(globalRef)
        .get();

    if (docSnapshot.exists) {
      return docSnapshot.data();
    }
    return null;
  }

  bool _isModernEncoding(String encoding) {
    final normalized = encoding.toUpperCase();
    if (normalized.contains('UTF-8')) return true;
    if (normalized.contains('UTF-16')) return true;
    return false;
  }
}

