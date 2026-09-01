import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/translation_repository.dart';

/// Best-effort retry queue for Firestore writes.
///
/// Motivation: translation completion should not fail just because Firestore is
/// temporarily unavailable. We enqueue failed writes and retry with backoff.
class CloudRetryQueue {
  static const _prefsKey = 'cloud_retry_queue_v1';

  final TranslationRepository _repo;
  final Future<SharedPreferences> Function() _prefsFactory;

  Timer? _timer;
  bool _isPumping = false;
  bool _isInitialized = false;

  void Function(String key, [String? param])? onLog;

  // In-memory queue: list of maps for flexible forward compatibility.
  final List<Map<String, dynamic>> _queue = [];

  CloudRetryQueue(
    this._repo, {
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _prefsFactory = (prefsFactory ?? SharedPreferences.getInstance);

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await _prefsFactory();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            _queue.add(item.cast<String, dynamic>());
          }
        }
      }
    } catch (e) {
      // Best-effort; keep queue empty on parse errors.
      onLog?.call('cloud_error_with_details', jsonEncode({'error': e.toString()}));
      _queue.clear();
    }
  }

  void start() {
    // Idempotent.
    _timer ??= Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(pump());
    });
    unawaited(init().then((_) => pump()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> enqueueSaveToGlobalCache({
    required String sourceHash,
    required String sourceContent,
    required String translatedContent,
    required String originalName,
    required String targetLanguage,
    String? encodingDetected,
    String? deviceId,
    bool isBatch = false,
    Map<String, dynamic>? cost,
    int chargedTokens = 0,
    String? appVersion,
  }) async {
    await init();
    _queue.add({
      'type': 'saveToGlobalCache',
      'payload': {
        'sourceHash': sourceHash,
        'sourceContent': sourceContent,
        'translatedContent': translatedContent,
        'originalName': originalName,
        'targetLanguage': targetLanguage,
        if (encodingDetected != null) 'encodingDetected': encodingDetected,
        if (deviceId != null) 'deviceId': deviceId,
        'isBatch': isBatch,
        if (cost != null && cost.isNotEmpty) 'cost': cost,
        'chargedTokens': chargedTokens < 0 ? 0 : chargedTokens,
        if (appVersion != null && appVersion.trim().isNotEmpty)
          'appVersion': appVersion.trim(),
      },
      'attempt': 0,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'nextAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _persist();
    unawaited(pump());
  }

  Future<void> enqueueAddToUserHistory({
    required String sourceHash,
    required String fileName,
    required String targetLanguage,
    required bool isPartial,
    String? encodingDetected,
    Map<String, dynamic>? resumeState,
    int? translatedLines,
    int? totalLines,
    bool? isActive,
    bool? clearSdh,
    String? partialTranslatedContent,
    String? sourceContentForResume,
  }) async {
    await init();
    _queue.add({
      'type': 'addToUserHistory',
      'payload': {
        'sourceHash': sourceHash,
        'fileName': fileName,
        'targetLanguage': targetLanguage,
        'isPartial': isPartial,
        if (encodingDetected != null) 'encodingDetected': encodingDetected,
        if (resumeState != null) 'resumeState': resumeState,
        if (translatedLines != null) 'translatedLines': translatedLines,
        if (totalLines != null) 'totalLines': totalLines,
        if (isActive != null) 'isActive': isActive,
        if (clearSdh != null) 'clearSdh': clearSdh,
      if (partialTranslatedContent != null) 'partialTranslatedContent': partialTranslatedContent,
      if (sourceContentForResume != null) 'sourceContentForResume': sourceContentForResume,
      },
      'attempt': 0,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'nextAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _persist();
    unawaited(pump());
  }

  Future<void> enqueueSetUserHistoryActive({
    required String sourceHash,
    required String targetLanguage,
    required bool isActive,
  }) async {
    await init();
    _queue.add({
      'type': 'setUserHistoryActive',
      'payload': {
        'sourceHash': sourceHash,
        'targetLanguage': targetLanguage,
        'isActive': isActive,
      },
      'attempt': 0,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'nextAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _persist();
    unawaited(pump());
  }

  Future<void> pump() async {
    if (_isPumping) return;
    _isPumping = true;
    try {
      await init();
      if (_queue.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;

      // Process at most a few items per pump to avoid long stalls.
      var processed = 0;
      for (var i = 0; i < _queue.length; i++) {
        if (processed >= 3) break;

        final item = _queue[i];
        final nextAt = (item['nextAtMs'] as int?) ?? 0;
        if (nextAt > now) continue;

        final type = item['type'] as String?;
        final payload = (item['payload'] as Map?)?.cast<String, dynamic>();
        if (type == null || payload == null) {
          // Malformed; drop.
          _queue.removeAt(i);
          i--;
          processed++;
          continue;
        }

        try {
          if (type == 'saveToGlobalCache') {
            final chargedRaw = payload['chargedTokens'];
            final chargedTokens = chargedRaw is int
                ? chargedRaw
                : (chargedRaw is num ? chargedRaw.floor() : 0);
            await _repo.saveToGlobalCache(
              sourceHash: payload['sourceHash'] as String,
              sourceContent: payload['sourceContent'] as String,
              translatedContent: payload['translatedContent'] as String,
              originalName: payload['originalName'] as String,
              targetLanguage: payload['targetLanguage'] as String,
              encodingDetected: payload['encodingDetected'] as String?,
              deviceId: payload['deviceId'] as String?,
              isBatch: payload['isBatch'] as bool? ?? false,
              cost: (payload['cost'] as Map?)?.cast<String, dynamic>(),
              chargedTokens: chargedTokens < 0 ? 0 : chargedTokens,
              appVersion: payload['appVersion'] as String?,
            );
          } else if (type == 'addToUserHistory') {
            final translatedLinesRaw = payload['translatedLines'];
            final totalLinesRaw = payload['totalLines'];
            await _repo.addToUserHistory(
              sourceHash: payload['sourceHash'] as String,
              fileName: payload['fileName'] as String,
              targetLanguage: payload['targetLanguage'] as String,
              isPartial: payload['isPartial'] as bool? ?? false,
              encodingDetected: payload['encodingDetected'] as String?,
              resumeState: (payload['resumeState'] as Map?)?.cast<String, dynamic>(),
              translatedLines: translatedLinesRaw is num ? translatedLinesRaw.toInt() : null,
              totalLines: totalLinesRaw is num ? totalLinesRaw.toInt() : null,
              isActive: payload['isActive'] as bool? ?? false,
              clearSdh: payload['clearSdh'] as bool?,
              partialTranslatedContent: payload['partialTranslatedContent'] as String?,
              sourceContentForResume: payload['sourceContentForResume'] as String?,
            );
          } else if (type == 'setUserHistoryActive') {
            await _repo.setUserHistoryActive(
              historyDocId: '_',
              isActive: payload['isActive'] as bool? ?? false,
            );
          }

          // Success: remove.
          _queue.removeAt(i);
          i--;
          processed++;
        } catch (e) {
          // Failure: schedule retry with backoff.
          final attempt = (item['attempt'] as int?) ?? 0;
          final nextAttempt = attempt + 1;

          // Cap attempts; after that drop to avoid infinite growth.
          if (nextAttempt >= 10) {
            onLog?.call('cloud_error_with_details', jsonEncode({'error': e.toString()}));
            _queue.removeAt(i);
            i--;
            processed++;
            continue;
          }

          final delaySeconds = _computeBackoffSeconds(nextAttempt);
          item['attempt'] = nextAttempt;
          item['nextAtMs'] = DateTime.now().millisecondsSinceEpoch + (delaySeconds * 1000);

          // Keep item in queue.
          processed++;
        }
      }

      await _persist();
    } finally {
      _isPumping = false;
    }
  }

  int _computeBackoffSeconds(int attempt) {
    // 5s, 10s, 20s, 40s, ... capped.
    final seconds = 5 * (1 << (attempt - 1));
    if (seconds > 5 * 60) return 5 * 60;
    return seconds;
  }

  Future<void> _persist() async {
    try {
      final prefs = await _prefsFactory();
      await prefs.setString(_prefsKey, jsonEncode(_queue));
    } catch (e) {
      // Best-effort.
      onLog?.call('cloud_error_with_details', jsonEncode({'error': e.toString()}));
    }
  }
}
