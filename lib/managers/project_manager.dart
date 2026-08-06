import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subtitle_block.dart';
import '../repositories/translation_repository.dart';
import '../services/subtitle_parser.dart';

/// Çeviri projelerinin yerel ve Firebase'e kaydedilmesini yönetir
class ProjectManager extends ChangeNotifier {
  final TranslationRepository _repository = TranslationRepository();
  final List<TranslationProject> _projects = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;

  bool _localPrefsLoaded = false;
  bool _firestoreInitialSyncDone = false;
  QuerySnapshot<Map<String, dynamic>>? _pendingInitialSnapshot;

  /// Eşzamanlı _handleFirestoreChanges çağrılarını seri hale getirmek için kilit.
  Completer<void>? _syncLock;

  List<TranslationProject> get projects => _projects;

  /// Kullanıcı çıkış yaptığında, sadece buluttan gelmiş (yerel dosya yolu olmayan)
  /// çeviri geçmişi kayıtlarını listeden kaldır.
  ///
  /// Böylece başka bir hesabın geçmişi / cloud-only kayıtlar logout sonrası
  /// ekranda kalmaz; yerel projeler korunur.
  Future<void> clearCloudOnlyProjects() async {
    final countBefore = _projects.length;
    _projects.removeWhere((p) => p.filePath.isEmpty);
    if (_projects.length == countBefore) return;

    await _saveProjectsToPrefs();
    notifyListeners();
  }

  /// Logout durumunda çeviri geçmişini UI'dan temizler.
  ///
  /// ÖNEMLİ: Bu metod dosya/cache silmez ve Firebase'deki geçmişi de silmez;
  /// sadece uygulama içi liste ve SharedPreferences kaydını boşaltır.
  Future<void> clearProjectsForLogout() async {
    if (_projects.isEmpty) return;
    _projects.clear();
    await _saveProjectsToPrefs();
    notifyListeners();
  }

  ({int translated, int total}) _deriveProgressFromResumeState(
    Map<String, dynamic>? resumeStateJson, {
    required int translatedFallback,
    required int totalFallback,
  }) {
    var translated = translatedFallback;
    var total = totalFallback;

    if (resumeStateJson == null) return (translated: translated, total: total);

    if (translated <= 0) {
      final blocksRaw = resumeStateJson['translatedBlocks'];
      if (blocksRaw is List) {
        translated = blocksRaw.length;
      }
    }

    if (total <= 0) {
      final totalBlocksRaw = resumeStateJson['totalBlocks'];
      if (totalBlocksRaw is num) {
        total = totalBlocksRaw.toInt();
      }
    }

    if (total <= 0) {
      final sourceContent = (resumeStateJson['sourceContent'] as String?) ?? '';
      if (sourceContent.trim().isNotEmpty) {
        total = SubtitleParser.parseSrt(sourceContent).length;
      }
    }

    // Legacy fallback only: older resume payloads stored newline count in
    // `totalLines`, which is not the same thing as subtitle block count.
    if (total <= 0) {
      final totalRaw = resumeStateJson['totalLines'];
      if (totalRaw is num) {
        total = totalRaw.toInt();
      }
    }

    return (translated: translated, total: total);
  }

  Map<String, dynamic>? _normalizeResumeStateJson(
    Map<String, dynamic> data, {
    Map<String, dynamic>? fallback,
  }) {
    final resumeStateRaw = data['resumeState'];
    final resumeStateJson = resumeStateRaw is Map
        ? Map<String, dynamic>.from(resumeStateRaw)
        : (fallback != null ? Map<String, dynamic>.from(fallback) : null);
    final chargeKey = (data['chargeKey'] as String?)?.trim() ?? '';

    if (chargeKey.isEmpty) {
      return resumeStateJson;
    }

    final normalized = resumeStateJson ?? <String, dynamic>{};
    final existingChargeKey =
        (normalized['chargeKey'] as String?)?.trim() ?? '';
    if (existingChargeKey.isEmpty) {
      normalized['chargeKey'] = chargeKey;
    }
    return normalized;
  }

  void startFirestoreSync() {
    // Zaten çalışıyorsa yeniden başlatma — Windows'ta 2 sn. polling timer
    // her çağrıda bu metodu tetikler; state sıfırlanmamalı.
    if (_firestoreSubscription != null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    // Sadece gerçekten yeni başlatırken state'i sıfırla.
    _firestoreInitialSyncDone = false;
    _pendingInitialSnapshot = null;
    debugPrint('Firestore sync starting for uid=${user.uid}');
    _firestoreSubscription = _repository.getUserTranslationHistoryStream().listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        debugPrint(
          'Firestore snapshot: docs=${snapshot.docs.length} changes=${snapshot.docChanges.length} fromCache=${snapshot.metadata.isFromCache}',
        );
        _handleFirestoreChanges(snapshot);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Firestore sync error: $e');
        // If the stream errors out (auth/network/permission), the subscription can
        // end up "stuck" but still non-null. Clear it so periodic polling can restart.
        stopFirestoreSync();
      },
      onDone: () {
        debugPrint('Firestore sync done.');
        // Allow restart.
        stopFirestoreSync();
      },
      cancelOnError: true,
    );
    debugPrint('Firestore sync started.');
  }

  void stopFirestoreSync() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    // _localPrefsLoaded sıfırlanmaz — prefs çıkış sonrasında da yüklü kalır.
    // Kullanıcı tekrar giriş yaptığında loadProjectsFromPrefs çalışmaz ama
    // Firestore snapshot'ı doğrudan _handleFirestoreChanges'e gidebilir.
    _firestoreInitialSyncDone = false;
    _pendingInitialSnapshot = null;
    debugPrint('Firestore sync stopped.');
  }

  Future<void> _handleFirestoreChanges(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    // Önceki çağrı bitene kadar bekle — eşzamanlı mutasyonları önle.
    while (_syncLock != null) {
      await _syncLock!.future;
    }
    _syncLock = Completer<void>();
    try {
      await _handleFirestoreChangesInner(snapshot);
    } finally {
      final lock = _syncLock;
      _syncLock = null;
      lock?.complete();
    }
  }

  Future<void> _handleFirestoreChangesInner(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (!_localPrefsLoaded) {
      _pendingInitialSnapshot = snapshot;
      return;
    }
    if (!_firestoreInitialSyncDone) {
      await _reconcileWithFullSnapshot(snapshot);
      _firestoreInitialSyncDone = true;
      return;
    }
    bool changed = false;
    for (final DocumentChange<Map<String, dynamic>> change
        in snapshot.docChanges) {
      final docId = change.doc.id;
      switch (change.type) {
        case DocumentChangeType.removed:
          final countBefore = _projects.length;
          _projects.removeWhere((p) => _matchesDocId(p, docId));
          if (_projects.length < countBefore) changed = true;
          break;
        case DocumentChangeType.added:
          final data = change.doc.data();
          if (data == null) break;
          final existingIdx = _projects.indexWhere(
            (p) => _matchesDocId(p, docId),
          );
          if (existingIdx >= 0) {
            if (_projects[existingIdx].id != docId) {
              _projects[existingIdx] = _projects[existingIdx].copyWith(
                id: docId,
              );
              changed = true;
            }
            break;
          }
          final project = _buildProjectMetadataFromFirestoreDoc(docId, data);
          if (project != null) {
            // Sadece henüz listede değilse ekle (legacy migration zaten in-place günceller)
            if (!_projects.any((p) => identical(p, project))) {
              _projects.add(project);
            }
            changed = true;
          }
          break;
        case DocumentChangeType.modified:
          final data = change.doc.data();
          if (data == null) break;
          final idx = _projects.indexWhere((p) => _matchesDocId(p, docId));
          if (idx < 0) break;

          final isPartial = data['isPartial'] as bool? ?? false;
          final isActive = data['isActive'] as bool? ?? false;
          final translatedLinesRaw = data['translatedLines'];
          final totalLinesRaw = data['totalLines'];
          final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
          final resumeStateJson = _normalizeResumeStateJson(
            data,
            fallback: _projects[idx].resumeStateJson,
          );

          final clearSdh =
              data['clearSdh'] as bool? ??
              (resumeStateJson != null
                  ? resumeStateJson['clearSdh'] as bool?
                  : null) ??
              _projects[idx].clearSdh;
          final completedPlatform =
              data['completedPlatform'] as String? ??
              _projects[idx].completedPlatform;

          _projects[idx] = _projects[idx].copyWith(
            id: docId,
            isCompleted: !isPartial,
            isPartial: isPartial,
            isActive: isActive,
            clearSdh: clearSdh,
            completedPlatform: completedPlatform,
          );
          if (translatedLinesRaw is num) {
            _projects[idx] = _projects[idx].copyWith(
              translatedLines: translatedLinesRaw.toInt(),
            );
          }
          if (totalLinesRaw is num) {
            _projects[idx] = _projects[idx].copyWith(
              totalLines: totalLinesRaw.toInt(),
            );
          }

          // If Firestore doesn't include explicit progress fields, derive them
          // from resumeState to avoid showing %0 on other devices.
          if (translatedLinesRaw is! num || totalLinesRaw is! num) {
            final baseTranslated = _projects[idx].translatedLines;
            final baseTotal = _projects[idx].totalLines;
            final derived = _deriveProgressFromResumeState(
              resumeStateJson,
              translatedFallback: baseTranslated,
              totalFallback: baseTotal,
            );
            if (derived.translated != baseTranslated ||
                derived.total != baseTotal) {
              _projects[idx] = _projects[idx].copyWith(
                translatedLines: derived.translated,
                totalLines: derived.total,
              );
            }
          }
          if (updatedAt != null) {
            _projects[idx] = _projects[idx].copyWith(
              lastUpdated: updatedAt.toIso8601String(),
            );
          }
          _projects[idx] = _projects[idx].copyWith(
            resumeStateJson: isPartial ? resumeStateJson : null,
          );
          changed = true;
          break;
      }
    }
    if (changed) {
      _projects.sort(
        (a, b) => _safeParseTime(
          b.lastUpdated,
        ).compareTo(_safeParseTime(a.lastUpdated)),
      );
      await _saveProjectsToPrefs();
      notifyListeners();
    }
  }

  bool _matchesDocId(TranslationProject p, String docId) {
    if (p.id == docId) return true;
    if (p.sourceHash != null && p.sourceHash!.isNotEmpty) {
      return '${p.sourceHash}_${p.targetLanguage.toLowerCase()}' == docId;
    }
    return false;
  }

  Future<void> _reconcileWithFullSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final newProjects = <TranslationProject>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingIdx = _projects.indexWhere((p) => _matchesDocId(p, doc.id));
      if (existingIdx >= 0) {
        final isPartial = data['isPartial'] as bool? ?? false;
        final isActive = data['isActive'] as bool? ?? false;
        final translatedLinesRaw = data['translatedLines'];
        final totalLinesRaw = data['totalLines'];
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
        final resumeStateJson = _normalizeResumeStateJson(
          data,
          fallback: _projects[existingIdx].resumeStateJson,
        );

        final clearSdh =
            data['clearSdh'] as bool? ??
            (resumeStateJson != null
                ? resumeStateJson['clearSdh'] as bool?
                : null) ??
            _projects[existingIdx].clearSdh;
        final completedPlatform =
            data['completedPlatform'] as String? ??
            _projects[existingIdx].completedPlatform;

        newProjects.add(
          _projects[existingIdx].copyWith(
            id: doc.id,
            isCompleted: !isPartial,
            isPartial: isPartial,
            isActive: isActive,
            clearSdh: clearSdh,
            completedPlatform: completedPlatform,
            translatedLines: translatedLinesRaw is num
                ? translatedLinesRaw.toInt()
                : _projects[existingIdx].translatedLines,
            totalLines: totalLinesRaw is num
                ? totalLinesRaw.toInt()
                : _projects[existingIdx].totalLines,
            lastUpdated:
                (updatedAt ??
                        _safeParseTime(_projects[existingIdx].lastUpdated))
                    .toIso8601String(),
            resumeStateJson: isPartial ? resumeStateJson : null,
          ),
        );
      } else {
        final project = _buildProjectMetadataFromFirestoreDoc(doc.id, data);
        if (project != null) newProjects.add(project);
      }
    }
    newProjects.sort(
      (a, b) => _safeParseTime(
        b.lastUpdated,
      ).compareTo(_safeParseTime(a.lastUpdated)),
    );
    bool changed = _projects.length != newProjects.length;
    if (!changed) {
      final oldById = <String, TranslationProject>{
        for (final p in _projects) p.id: p,
      };
      for (final p in newProjects) {
        final old = oldById[p.id];
        if (old == null ||
            old.isActive != p.isActive ||
            old.isPartial != p.isPartial ||
            old.isCompleted != p.isCompleted ||
            old.translatedLines != p.translatedLines ||
            old.totalLines != p.totalLines ||
            old.lastUpdated != p.lastUpdated) {
          changed = true;
          break;
        }
      }
    }
    _projects
      ..clear()
      ..addAll(newProjects);
    if (changed) {
      await _saveProjectsToPrefs();
      notifyListeners();
    }
  }

  /// Firestore dokümanından anında (ağ beklenmeden) metadata oluştur.
  /// Bloklar (içerik) kullanıcı tıkladığında [loadBlocksIfNeeded] ile lazy yüklenir.
  TranslationProject? _buildProjectMetadataFromFirestoreDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    try {
      final globalRef = data['globalTranslationRef'] as String?;
      if (globalRef == null || globalRef.isEmpty) return null;

      final fileName = data['fileName'] as String? ?? 'unknown.srt';
      final targetLanguage = data['targetLanguage'] as String? ?? '';
      final isPartial = data['isPartial'] as bool? ?? false;
      final isActive = data['isActive'] as bool? ?? false;
      final sourceHash = data['sourceHash'] as String? ?? '';
      final createdAt =
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      final translatedLinesRaw = data['translatedLines'];
      final totalLinesRaw = data['totalLines'];
      final translatedLinesBase = translatedLinesRaw is num
          ? translatedLinesRaw.toInt()
          : 0;
      final totalLinesBase = totalLinesRaw is num ? totalLinesRaw.toInt() : 0;

      final resumeStateJson = _normalizeResumeStateJson(data);

      final clearSdh =
          data['clearSdh'] as bool? ??
          (resumeStateJson != null
              ? resumeStateJson['clearSdh'] as bool?
              : null) ??
          false;
      final completedPlatform = data['completedPlatform'] as String?;

      final derived = _deriveProgressFromResumeState(
        resumeStateJson,
        translatedFallback: translatedLinesBase,
        totalFallback: totalLinesBase,
      );

      // Zaten doğru ID ile varsa ekleme (idempotent)
      if (_projects.any((p) => p.id == docId)) return null;

      // Eski format geçiş: aynı sourceHash+lang ile kaydedilmiş ama ID'si
      // dosya yolu olan (file.path) yerel proje varsa, ID'sini stable format'a
      // yükselt — böylece Firestore'dan gelen removed/reconcile olayları onu bulabilir.
      int legacyIdx = -1;
      if (sourceHash.isNotEmpty) {
        // Önce sourceHash ile eşleşmeye çalış (Phase-5 sonrası projeler)
        legacyIdx = _projects.indexWhere(
          (p) =>
              p.id != docId &&
              (p.sourceHash == sourceHash || p.id.contains(sourceHash)) &&
              p.targetLanguage.toLowerCase() == targetLanguage.toLowerCase(),
        );
      }
      if (legacyIdx < 0) {
        // sourceHash yoksa dosya adı + dil ile eşleş (Phase-5 öncesi eski projeler)
        legacyIdx = _projects.indexWhere(
          (p) =>
              p.id != docId &&
              p
                  .filePath
                  .isNotEmpty && // yerel dosyası olan proje (Firestore kaynağı değil)
              p.sourceHash == null && // henüz migrate edilmemiş
              p.fileName == fileName &&
              p.targetLanguage.toLowerCase() == targetLanguage.toLowerCase(),
        );
      }
      if (legacyIdx >= 0) {
        _projects[legacyIdx] = _projects[legacyIdx].copyWith(
          id: docId,
          sourceHash: sourceHash.isNotEmpty ? sourceHash : null,
          globalRef: globalRef,
        );
        debugPrint(
          '[Migrate] Proje ID\'si güncellendi: ${_projects[legacyIdx].filePath} → $docId',
        );
        return _projects[legacyIdx];
      }

      final project = TranslationProject(
        id: docId,
        fileName: fileName,
        filePath: '', // Uzak kaynaklı projede yerel dosya yolu yoktur
        targetLanguage: targetLanguage,
        isCompleted: !isPartial,
        isPartial: isPartial,
        isActive: isActive,
        clearSdh: clearSdh,
        totalLines: derived.total,
        translatedLines: derived.translated,
        lastUpdated: (updatedAt ?? createdAt).toIso8601String(),
        sourceBlocks: const [], // henüz yüklenmedi
        processedBlocks: const [], // henüz yüklenmedi
        sourceHash: sourceHash,
        globalRef: globalRef,
        resumeStateJson: isPartial ? resumeStateJson : null,
        completedPlatform: completedPlatform,
      );

      // NOT: _projects'e ekleme yapılmaz — çağıran taraf (added handler veya
      // reconcile) bunu kendi üstüne alır.
      debugPrint(
        'Firestore\'tan metadata oluşturuldu (bloklar lazy): $docId ($fileName)',
      );
      return project;
    } catch (e) {
      debugPrint('Firestore metadata oluşturulurken hata: $e');
      return null;
    }
  }

  /// Bloklara ihtiyaç duyulduğunda (kullanıcı tıkladığında) yükle.
  ///
  /// Partial kayıtlar için önce resume payload okunur; böylece farklı cihazda
  /// yarım kalan çeviri de önizleme ve karşılaştırma için açılabilir.
  Future<bool> loadBlocksIfNeeded(
    String projectId, {
    bool forceCloudRefresh = false,
  }) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx < 0) return false;
    var project = _projects[idx];

    if (!forceCloudRefresh) {
      if (project.isPartial) {
        if (project.sourceBlocks.isNotEmpty &&
            project.processedBlocks.isNotEmpty) {
          return true;
        }
      } else if (project.sourceBlocks.isNotEmpty &&
          project.processedBlocks.isNotEmpty) {
        return true;
      }
    }

    try {
      final historyDocId =
          (project.sourceHash != null && project.sourceHash!.isNotEmpty)
          ? '${project.sourceHash}_${project.targetLanguage.toLowerCase()}'
          : project.id;
      final payload = await _repository.getResumePayload(
        historyDocId: historyDocId,
      );

      if (payload != null) {
        final payloadClearSdh = payload['clearSdh'] == 'true';
        if (payloadClearSdh && !project.clearSdh) {
          project = project.copyWith(clearSdh: true);
          _projects[idx] = project;
        }

        var sourceContent = payload['source'] ?? '';
        final partialContent = payload['partial'] ?? '';

        if (project.clearSdh && sourceContent.trim().isNotEmpty) {
          sourceContent = SubtitleParser.clearSdh(sourceContent);
        }

        final sourceBlocks = sourceContent.isNotEmpty
            ? SubtitleParser.parseSrt(sourceContent)
            : <SubtitleBlock>[];
        final processedBlocks = partialContent.isNotEmpty
            ? SubtitleParser.parseSrt(partialContent)
            : <SubtitleBlock>[];

        if (sourceBlocks.isNotEmpty) {
          final useCloud =
              !forceCloudRefresh ||
              processedBlocks.length >= project.processedBlocks.length;

          _projects[idx] = project.copyWith(
            sourceBlocks: sourceBlocks,
            processedBlocks: useCloud
                ? processedBlocks
                : project.processedBlocks,
            totalLines: sourceBlocks.length,
            translatedLines: useCloud
                ? processedBlocks.length
                : project.processedBlocks.length,
          );

          await _saveProjectsToPrefs();
          notifyListeners();
          debugPrint(
            'Resume payload lazy yüklendi: $projectId (${processedBlocks.length} blok)',
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('Resume payload lazy yükleme hatası ($projectId): $e');
    }

    final ref = project.globalRef;
    if (ref == null || ref.isEmpty) return false;

    try {
      final translationData = await _repository.getTranslationByRef(ref);
      if (translationData == null) return false;

      final translatedContent =
          translationData['translatedContent'] as String? ?? '';
      var sourceContent = translationData['sourceContent'] as String? ?? '';

      if (project.clearSdh && sourceContent.trim().isNotEmpty) {
        sourceContent = SubtitleParser.clearSdh(sourceContent);
      }

      final processedBlocks = translatedContent.isNotEmpty
          ? SubtitleParser.parseSrt(translatedContent)
          : <SubtitleBlock>[];
      final sourceBlocks = sourceContent.isNotEmpty
          ? SubtitleParser.parseSrt(sourceContent)
          : <SubtitleBlock>[];

      _projects[idx] = project.copyWith(
        processedBlocks: processedBlocks,
        sourceBlocks: sourceBlocks,
        totalLines: sourceBlocks.isNotEmpty
            ? sourceBlocks.length
            : processedBlocks.length,
        translatedLines: processedBlocks.length,
      );

      await _saveProjectsToPrefs();
      notifyListeners();
      debugPrint(
        'Bloklar lazy yüklendi: $projectId (${processedBlocks.length} blok)',
      );
      return sourceBlocks.isNotEmpty || processedBlocks.isNotEmpty;
    } catch (e) {
      debugPrint('Blok lazy yükleme hatası ($projectId): $e');
      return false;
    }
  }

  /// Projeler listesini SharedPreferences'tan yükle
  Future<void> loadProjectsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? jsonList = prefs.getStringList('saved_projects');
      if (jsonList != null) {
        _projects.clear();
        _projects.addAll(
          jsonList
              .map((json) => TranslationProject.fromJson(jsonDecode(json)))
              .toList(),
        );

        // Tekilleştirme: aynı dosya + aynı dil için en güncel kaydı tut.
        // (Eski batch kopyalamada timestamp_ ön eki ve _<md5> soneki sebebiyle
        // aynı dosya birden fazla entry üretebiliyordu.)
        final Map<String, TranslationProject> deduped = {};
        for (final p in _projects) {
          final keyName = _normalizeFileNameForDedupe(p.fileName);
          final key = '$keyName|${p.targetLanguage}';
          final existing = deduped[key];
          if (existing == null) {
            deduped[key] = p;
            continue;
          }

          final aTime = _safeParseTime(existing.lastUpdated);
          final bTime = _safeParseTime(p.lastUpdated);
          final isNewer = bTime.isAfter(aTime);
          final isSameTime = bTime.isAtSameMomentAs(aTime);
          final preferP =
              isNewer || (isSameTime && p.isCompleted && !existing.isCompleted);
          if (preferP) {
            deduped[key] = p;
          }
        }

        _projects
          ..clear()
          ..addAll(deduped.values);

        _projects.sort(
          (a, b) => _safeParseTime(
            b.lastUpdated,
          ).compareTo(_safeParseTime(a.lastUpdated)),
        );

        // Temizlenmiş listeyi geri yaz (kalıcı olarak duplicate'leri kaldırır)
        await _saveProjectsToPrefs();
      }
      _localPrefsLoaded = true;
      notifyListeners();
      if (_pendingInitialSnapshot != null) {
        final pending = _pendingInitialSnapshot!;
        _pendingInitialSnapshot = null;
        await _reconcileWithFullSnapshot(pending);
        _firestoreInitialSyncDone = true;
      }
    } catch (e) {
      debugPrint('Error loading projects from prefs: $e');
      _localPrefsLoaded = true;
    }
  }

  String _normalizeFileNameForDedupe(String name) {
    // timestamp_foo.srt -> foo.srt
    var n = name.replaceFirst(RegExp(r'^\d{10,}_'), '');
    // foo_<md5>.srt -> foo.srt
    n = n.replaceFirst(
      RegExp(r'_[a-f0-9]{32}(?=\.[^.]+$)', caseSensitive: false),
      '',
    );
    return n.trim().toLowerCase();
  }

  DateTime _safeParseTime(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Projeler listesini SharedPreferences'e kaydet
  /// Ağır verileri (bloklar, resumeStateJson) hariç tutar — bunlar Firestore'dan
  /// lazy yüklenir (ancak sadece Firestore globalRef'i olan projeler için).
  /// Yerel projelerde veri kaybı olmaması için globalRef yoksa (veya boşsa) bloklar da kaydedilir.
  Future<void> _saveProjectsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _projects
          .map(
            (p) => jsonEncode(
              p.toJson(
                includeHeavyData: p.globalRef == null || p.globalRef!.isEmpty,
              ),
            ),
          )
          .toList();
      await prefs.setStringList('saved_projects', jsonList);
    } catch (e) {
      debugPrint('Error saving projects to prefs: $e');
    }
  }

  /// Yeni projeyi ekle veya mevcut olanı güncelle
  Future<void> addOrUpdateProject(TranslationProject project) async {
    final existingIndex = _projects.indexWhere((p) => p.id == project.id);
    if (existingIndex >= 0) {
      _projects[existingIndex] = project;
    } else {
      _projects.insert(0, project);
    }
    _projects.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    await _saveProjectsToPrefs();
    notifyListeners();
  }

  /// Projeyi güncelle (bilinen proje için)
  Future<void> updateProject(TranslationProject project) async {
    final existingIndex = _projects.indexWhere((p) => p.id == project.id);
    if (existingIndex >= 0) {
      _projects[existingIndex] = project;
    } else {
      _projects.insert(0, project);
    }
    _projects.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    await _saveProjectsToPrefs();
    notifyListeners();
  }

  /// Projeyi sil (yerel ve Firebase)
  void deleteProject(String id) {
    final projectIndex = _projects.indexWhere((p) => p.id == id);
    if (projectIndex != -1) {
      final project = _projects[projectIndex];
      _projects.removeAt(projectIndex);
      _saveProjectsToPrefs();

      // Kalıcı dosyayı sil
      final stillUsesFilePath = _projects.any(
        (p) => p.filePath == project.filePath,
      );
      if (!stillUsesFilePath) {
        _deletePermanentFile(project.filePath);
      }

      final srcCachePath = project.translationSourceCachePath;
      if (srcCachePath != null && srcCachePath.isNotEmpty) {
        final stillUsesCache = _projects.any(
          (p) => p.translationSourceCachePath == srcCachePath,
        );
        if (!stillUsesCache) {
          _deletePermanentFile(srcCachePath);
        }
      }

      // Sync deletion to Firebase
      _deleteProjectFromFirebase(project);
    } else {
      _projects.removeWhere((p) => p.id == id);
      _saveProjectsToPrefs();
    }

    notifyListeners();
  }

  /// Kalıcı dosyayı sil
  Future<void> _deletePermanentFile(String filePath) async {
    try {
      if (filePath.isEmpty) return;
      final appDir = await getApplicationDocumentsDirectory();
      final subtitlesDir = Directory(path.join(appDir.path, 'subtitles'));

      // Yolları normalize et
      final context = path.Context(
        style: Platform.isWindows ? path.Style.windows : path.Style.posix,
      );
      final root = context.canonicalize(subtitlesDir.path);
      final target = context.canonicalize(filePath);

      if (context.isWithin(root, target) ||
          context.equals(context.dirname(target), root)) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Kalıcı dosya silindi: $filePath');
        }
      }
    } catch (e) {
      debugPrint('Kalıcı dosya silinirken hata: $e');
    }
  }

  /// Firebase'ten projeyi sil.
  /// Firestore doc ID her zaman canonical format: {sourceHash}_{lang}.
  /// project.id eski/legacy format (file path) olabilir; önce canonical
  /// ID'yi hesapla ki yanlış döküman silinmesin.
  Future<void> _deleteProjectFromFirebase(TranslationProject project) async {
    try {
      final candidateIds = <String>{};
      final sourceHash = project.sourceHash;
      if (sourceHash != null && sourceHash.isNotEmpty) {
        candidateIds.add(
          '${sourceHash}_${project.targetLanguage.toLowerCase()}',
        );
      }
      if (project.id.isNotEmpty) candidateIds.add(project.id);

      for (final docId in candidateIds) {
        try {
          await _repository.deleteFromUserHistory(historyDocId: docId);
          debugPrint('Firestore delete attempted: $docId');
        } catch (e) {
          debugPrint('Firestore delete failed for $docId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error deleting project from Firebase: $e');
    }
  }

  /// Projeyi geri ekle (undo için)
  void restoreProject(TranslationProject project) {
    _projects.add(project);
    _projects.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    _saveProjectsToPrefs();
    notifyListeners();
  }

  /// Tüm projeleri temizle
  void clearAllProjects() {
    // Tüm kalıcı dosyaları sil
    final uniquePaths = <String>{};
    for (final project in _projects) {
      if (project.filePath.isNotEmpty) uniquePaths.add(project.filePath);
      final cache = project.translationSourceCachePath;
      if (cache != null && cache.isNotEmpty) uniquePaths.add(cache);
    }
    for (final p in uniquePaths) {
      _deletePermanentFile(p);
    }

    _projects.clear();
    _saveProjectsToPrefs();

    // Sync clearing to Firebase
    _clearAllProjectsFromFirebase();

    notifyListeners();
  }

  /// Firebase'ten tüm projeleri temizle
  Future<void> _clearAllProjectsFromFirebase() async {
    try {
      final repository = TranslationRepository();
      await repository.clearAllUserHistory();
    } catch (e) {
      debugPrint('Error clearing projects from Firebase: $e');
    }
  }

  /// Partial (yarım) projeleri al
  List<TranslationProject> getPartialProjects() {
    return _projects.where((p) => p.isPartial).toList();
  }

  /// En son projeyi al
  TranslationProject? getLatestProject() {
    if (_projects.isEmpty) return null;
    return _projects.first;
  }
}

/// Çeviri projesi modeli
class TranslationProject {
  static const Object _noChange = Object();

  String id;
  String fileName;
  String filePath;
  String? translationSourceCachePath;
  String targetLanguage;
  bool isCompleted;
  bool isPartial;
  bool isActive;
  bool clearSdh;
  int totalLines;
  int translatedLines;
  String lastUpdated;
  List<SubtitleBlock> sourceBlocks;
  List<SubtitleBlock> processedBlocks;
  String? usedModel;
  String? sourceHash;

  /// Firestore'daki `global_translations` doküman referansı (lazy yükleme için)
  String? globalRef;

  /// Firestore'dan gelen (varsa) çeviri devam ettirme state'i.
  /// Yalnızca `isPartial == true` iken dolu olur.
  Map<String, dynamic>? resumeStateJson;

  /// Çevirinin tamamlandığı platform (ör. "android", "windows", "ios", "macos", "linux").
  String? completedPlatform;

  /// Blokların lazy yüklenip yüklenmediğini gösterir
  bool get blocksLoaded => processedBlocks.isNotEmpty;

  TranslationProject({
    required this.id,
    required this.fileName,
    required this.filePath,
    this.translationSourceCachePath,
    required this.targetLanguage,
    required this.isCompleted,
    this.isPartial = false,
    this.isActive = false,
    this.clearSdh = false,
    required this.totalLines,
    required this.translatedLines,
    required this.lastUpdated,
    required this.sourceBlocks,
    required this.processedBlocks,
    this.usedModel,
    this.sourceHash,
    this.globalRef,
    this.resumeStateJson,
    this.completedPlatform,
  });

  /// Belirli alanları değiştirerek yeni bir kopya döndürür (Firestore güncellemeleri için)
  TranslationProject copyWith({
    String? id,
    String? fileName,
    String? filePath,
    String? translationSourceCachePath,
    String? targetLanguage,
    bool? isCompleted,
    bool? isPartial,
    bool? isActive,
    bool? clearSdh,
    int? totalLines,
    int? translatedLines,
    String? lastUpdated,
    List<SubtitleBlock>? sourceBlocks,
    List<SubtitleBlock>? processedBlocks,
    String? usedModel,
    String? sourceHash,
    String? globalRef,
    Object? resumeStateJson = _noChange,
    String? completedPlatform,
  }) {
    return TranslationProject(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      translationSourceCachePath:
          translationSourceCachePath ?? this.translationSourceCachePath,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      isCompleted: isCompleted ?? this.isCompleted,
      isPartial: isPartial ?? this.isPartial,
      isActive: isActive ?? this.isActive,
      clearSdh: clearSdh ?? this.clearSdh,
      totalLines: totalLines ?? this.totalLines,
      translatedLines: translatedLines ?? this.translatedLines,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sourceBlocks: sourceBlocks ?? this.sourceBlocks,
      processedBlocks: processedBlocks ?? this.processedBlocks,
      usedModel: usedModel ?? this.usedModel,
      sourceHash: sourceHash ?? this.sourceHash,
      globalRef: globalRef ?? this.globalRef,
      resumeStateJson: resumeStateJson == _noChange
          ? this.resumeStateJson
          : resumeStateJson as Map<String, dynamic>?,
      completedPlatform: completedPlatform ?? this.completedPlatform,
    );
  }

  Map<String, dynamic> toJson({bool includeHeavyData = true}) => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'translationSourceCachePath': translationSourceCachePath,
    'targetLanguage': targetLanguage,
    'isCompleted': isCompleted,
    'isPartial': isPartial,
    'isActive': isActive,
    'clearSdh': clearSdh,
    'totalLines': totalLines,
    'translatedLines': translatedLines,
    'lastUpdated': lastUpdated,
    // Bloklar ve resumeStateJson ağır veri — SharedPreferences'a yazılmaz,
    // Firestore'dan lazy yüklenir.
    if (includeHeavyData)
      'sourceBlocks': sourceBlocks.map((b) => b.toJson()).toList(),
    if (includeHeavyData)
      'processedBlocks': processedBlocks.map((b) => b.toJson()).toList(),
    if (includeHeavyData) 'resumeStateJson': resumeStateJson,
    'usedModel': usedModel,
    'sourceHash': sourceHash,
    'globalRef': globalRef,
    'completedPlatform': completedPlatform,
  };

  factory TranslationProject.fromJson(Map<String, dynamic> json) {
    return TranslationProject(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      translationSourceCachePath: json['translationSourceCachePath'],
      targetLanguage: json['targetLanguage'],
      isCompleted: json['isCompleted'] ?? false,
      isPartial: json['isPartial'] ?? false,
      isActive: json['isActive'] ?? false,
      clearSdh: json['clearSdh'] ?? false,
      totalLines: json['totalLines'],
      translatedLines: json['translatedLines'],
      lastUpdated: json['lastUpdated'],
      sourceBlocks:
          (json['sourceBlocks'] as List?)
              ?.map((i) => SubtitleBlock.fromJson(i))
              .toList() ??
          const [],
      processedBlocks:
          (json['processedBlocks'] as List?)
              ?.map((i) => SubtitleBlock.fromJson(i))
              .toList() ??
          const [],
      usedModel: json['usedModel'],
      sourceHash: json['sourceHash'] as String?,
      globalRef: json['globalRef'] as String?,
      resumeStateJson: (json['resumeStateJson'] as Map?)
          ?.cast<String, dynamic>(),
      completedPlatform: json['completedPlatform'] as String?,
    );
  }
}
