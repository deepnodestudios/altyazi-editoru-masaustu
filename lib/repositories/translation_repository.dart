import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subtitle_block.dart';
import '../services/subtitle_builder.dart';

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

  String _gunzipFromB64(String b64) {
    final gz = base64Decode(b64);
    final bytes = GZipDecoder().decodeBytes(gz);
    return utf8.decode(bytes);
  }

  int _countSrtBlocks(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed
        .split(RegExp(r'\n\s*\n'))
        .where((block) => block.trim().isNotEmpty)
        .length;
  }

  Future<String?> _readChunked(
    DocumentReference<Map<String, dynamic>> docRef, {
    required String keyPrefix,
  }) async {
    final snap = await docRef.collection('resume_payload').get();
    if (snap.docs.isEmpty) return null;

    final keyed = snap.docs
        .where((d) => d.id.startsWith('${keyPrefix}_'))
        .map((d) => d.data())
        .where((m) => m['data'] is String && m['i'] is int)
        .toList();

    if (keyed.isEmpty) return null;
    keyed.sort((a, b) => (a['i'] as int).compareTo(b['i'] as int));

    final expectedN = keyed.first['n'] is int ? keyed.first['n'] as int : null;
    if (expectedN == null || expectedN <= 0) {
      return keyed.map((m) => m['data'] as String).join();
    }

    final byIndex = <int, String>{
      for (final m in keyed) (m['i'] as int): (m['data'] as String),
    };
    final buffer = StringBuffer();
    for (var i = 0; i < expectedN; i++) {
      final part = byIndex[i];
      if (part == null) return null;
      buffer.write(part);
    }
    return buffer.toString();
  }

  Future<Map<String, String>?> getResumePayload({
    required String historyDocId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || historyDocId.trim().isEmpty) return null;

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('translation_history')
        .doc(historyDocId);

    final snap = await docRef.get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    Map<String, String>? mobilePayload;
    if (data['resumeChunked'] == true) {
      final sourceB64 = await _readChunked(docRef, keyPrefix: 'source');
      if (sourceB64 != null && sourceB64.isNotEmpty) {
        final partialB64 = await _readChunked(docRef, keyPrefix: 'partial') ?? '';
        mobilePayload = {
          'source': _gunzipFromB64(sourceB64),
          'partial': partialB64.isNotEmpty ? _gunzipFromB64(partialB64) : '',
        };
      }
    }

    if (mobilePayload == null) {
      final sourceGz = data['resumeSourceGzipB64'] as String?;
      if (sourceGz != null && sourceGz.isNotEmpty) {
        final partialGz = data['resumePartialGzipB64'] as String? ?? '';
        mobilePayload = {
          'source': _gunzipFromB64(sourceGz),
          'partial': partialGz.isNotEmpty ? _gunzipFromB64(partialGz) : '',
        };
      }
    }

    if (mobilePayload == null) {
      final sourceRaw = data['sourceContentForResume'] as String?;
      if (sourceRaw != null && sourceRaw.isNotEmpty) {
        mobilePayload = {
          'source': sourceRaw,
          'partial': (data['partialTranslatedContent'] as String?) ?? '',
        };
      }
    }

    Map<String, String>? desktopPayload;
    final resumeStateRaw = data['resumeState'];
    if (resumeStateRaw is Map) {
      final resumeMap = Map<String, dynamic>.from(resumeStateRaw);
      final srcContent = resumeMap['sourceContent'] as String? ?? '';
      if (srcContent.trim().isNotEmpty) {
        String partialSrt = '';
        final rawBlocks = resumeMap['translatedBlocks'];
        if (rawBlocks is List && rawBlocks.isNotEmpty) {
          try {
            final blocks = rawBlocks
                .whereType<Map>()
                .map((b) => SubtitleBlock.fromJson(Map<String, dynamic>.from(b)))
                .toList();
            if (blocks.isNotEmpty) {
              partialSrt = SubtitleBuilder.buildSrt(blocks, resequence: false);
            }
          } catch (_) {
            partialSrt = '';
          }
        }
        desktopPayload = {
          'source': srcContent,
          'partial': partialSrt,
        };
      }
    }

    final docClearSdh = (data['clearSdh'] == true) ||
        (resumeStateRaw is Map && resumeStateRaw['clearSdh'] == true);

    if (mobilePayload != null && docClearSdh) {
      mobilePayload['clearSdh'] = 'true';
    }
    if (desktopPayload != null && docClearSdh) {
      desktopPayload['clearSdh'] = 'true';
    }

    if (mobilePayload != null && desktopPayload != null) {
      return _countSrtBlocks(desktopPayload['partial'] ?? '') >=
              _countSrtBlocks(mobilePayload['partial'] ?? '')
          ? desktopPayload
          : mobilePayload;
    }

    return mobilePayload ?? desktopPayload;
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
    String? deviceId,
    bool isBatch = false,
    Map<String, dynamic>? cost,
  }) async {
    if (encodingDetected != null && !_isModernEncoding(encodingDetected)) {
      return;
    }
    final cacheKey = _generateGlobalCacheKey(sourceHash, targetLanguage);
    final currentEmail = _auth.currentUser?.email?.trim().toLowerCase();

    final docRef = _firestore.collection('global_translations').doc(cacheKey);
    final docSnapshot = await docRef.get();
    final existing = docSnapshot.data() ?? const <String, dynamic>{};

    if (docSnapshot.exists) {
      // Increment usage count if already exists
      final updateData = <String, dynamic>{
        'usageCount': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
        'platforms': FieldValue.arrayUnion([Platform.operatingSystem]),
      };
      if (existing['sourceContent'] == null) {
        updateData['sourceContent'] = sourceContent;
      }
      if (existing['translatedContent'] == null) {
        updateData['translatedContent'] = translatedContent;
      }
      if (existing['originalName'] == null) {
        updateData['originalName'] = originalName;
      }
      if (existing['targetLanguage'] == null) {
        updateData['targetLanguage'] = targetLanguage;
      }
      if (existing['sourceHash'] == null) {
        updateData['sourceHash'] = sourceHash;
      }
      if (existing['completedPlatform'] == null) {
        updateData['completedPlatform'] = Platform.operatingSystem;
      }
      if (existing['isBatch'] == null) {
        updateData['isBatch'] = isBatch;
      }
      if (deviceId != null && deviceId.isNotEmpty) {
        updateData['deviceIds'] = FieldValue.arrayUnion([deviceId]);
        updateData['lastDeviceId'] = deviceId;
        if (existing['creatorDeviceId'] == null) {
          updateData['creatorDeviceId'] = deviceId;
        }
      }
      if (currentEmail != null && currentEmail.isNotEmpty) {
        updateData['lastUserEmail'] = currentEmail;
      }
      await docRef.update(updateData);
    } else {
      // Create new global translation
      final setData = <String, dynamic>{
        'sourceContent': sourceContent,
        'translatedContent': translatedContent,
        'originalName': originalName,
        'targetLanguage': targetLanguage,
        'sourceHash': sourceHash,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
        'completedPlatform': Platform.operatingSystem,
        'platforms': FieldValue.arrayUnion([Platform.operatingSystem]),
        'isBatch': isBatch,
        'usageCount': 1,
        if (cost != null && cost.isNotEmpty) 'cost': cost,
      };
      if (deviceId != null && deviceId.isNotEmpty) {
        setData['deviceIds'] = FieldValue.arrayUnion([deviceId]);
        setData['lastDeviceId'] = deviceId;
        setData['creatorDeviceId'] = deviceId;
      }
      if (currentEmail != null && currentEmail.isNotEmpty) {
        setData['creatorEmail'] = currentEmail;
        setData['lastUserEmail'] = currentEmail;
      }
      await docRef.set(setData);
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

