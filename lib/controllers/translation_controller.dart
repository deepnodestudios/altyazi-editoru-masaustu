import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/ai_language_options.dart';
import '../utils/string_utils.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';
import '../services/billing_service.dart';
import '../services/token_estimate_gate_service.dart';
import '../services/token_wallet_math.dart';
import '../services/subtitle_parser.dart';
import '../services/translation_engine.dart';
import '../services/subtitle_builder.dart';
import '../services/cloud_retry_queue.dart';
import '../repositories/translation_repository.dart';
import '../repositories/subtitle_repository.dart';
import '../models/subtitle_block.dart';
import '../app_settings.dart';
import '../managers/project_manager.dart';

enum TranslationStatus { idle, running, paused, completed, error }

/// Çeviri işi için veri modeli
class TranslationJob {
  final File file;
  final String targetLanguage;
  final bool clearSdh;
  final String? displayFileName;

  TranslationJob({
    required this.file,
    required this.targetLanguage,
    required this.clearSdh,
    this.displayFileName,
  });

  String get fileName => path.basename(file.path);
  String get effectiveFileName => displayFileName ?? fileName;
}

class BatchFile {
  final String name;
  final String path;

  const BatchFile({required this.name, required this.path});
}

class BatchError {
  final String fileName;
  final String message;

  const BatchError({required this.fileName, required this.message});
}

class BatchSummary {
  final int successCount;
  final List<BatchError> errors;
  final List<String> completedPaths;
  final bool stopped;
  final bool outOfCredits;

  const BatchSummary({
    required this.successCount,
    required this.errors,
    required this.completedPaths,
    required this.stopped,
    required this.outOfCredits,
  });
}

class TranslationController extends ChangeNotifier {
  static const int _maxAllowedTimecodeMs = 5 * 60 * 60 * 1000;

  // Services
  final FileService _fileService = FileService();
  final BillingService billingService = BillingService();
  final TranslationRepository _repository = TranslationRepository();
  late final CloudRetryQueue _cloudRetryQueue = CloudRetryQueue(_repository);
  final SubtitleRepository _subtitleRepository = SubtitleRepository();
  late final TranslationEngine _engine;
  late final GeminiService _geminiService;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  // --- UI State ---
  File? _selectedFile;
  File? get selectedFile => _selectedFile;

  String? currentFileName;
  String? generatedFilePath;

  List<SubtitleBlock> sourceBlocks = [];
  List<SubtitleBlock> translatedBlocks = [];

  TranslationStatus status = TranslationStatus.idle;
  bool get isLoading =>
      status == TranslationStatus.running || status == TranslationStatus.paused;

  bool _stopRequested = false;
  bool get isStopped => _stopRequested;

  // Desktop/batch UX: On manual stop, only remove the current file from the
  // batch translation list if the first-chunk credit was actually consumed
  // for this run (or we're resuming a previously-paid job).
  bool _stopShouldRemoveFromBatchList = false;

  bool isTranslationComplete = false;
  bool isCached = false;

  // Progress
  double progress = 0.0;
  String elapsedTime = "00:00";
  String remainingTime = "00:00";
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _progressTimer;

  // Resume State
  TranslationResumeState? _resumeState;
  bool get hasResumeState => _resumeState != null;

  Timer? _resumeCloudSyncTimer;
  DateTime? _lastResumeCloudSyncAt;
  static const Duration _resumeCloudSyncDebounce = Duration(seconds: 8);
  static const Duration _resumeCloudSyncMinInterval = Duration(seconds: 20);

  String? _lastTargetLanguage;
  String? _activeTranslationChargeKey;

  // Optional bridge to AppSettings (for keeping local history in sync)
  AppSettings? _settings;

  // --- Queue / Batch State ---
  final List<TranslationJob> _jobQueue = [];
  TranslationJob? _currentJob;

  // Batch Results
  final Map<String, String> batchResults = {};
  final List<String> activeBatchFilePaths = [];
  final List<BatchError> _batchErrors = [];
  final List<String> _batchCompletedPaths = [];

  // Best-effort cached source content for the currently running job.
  // Prevents completion from failing if the source copy is missing later.
  String? _currentJobSourceContent;

  static String _canonicalizeSubtitleContentForHash(String content) {
    var s = content;
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
      s = s.substring(1);
    }
    s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.trimRight();
    return s;
  }

  String _stableSubtitleHash(String content) {
    return _fileService.calculateMd5FromString(
      _canonicalizeSubtitleContentForHash(content),
    );
  }

  TranslationResumeState _rebuildResumeWith({
    required TranslationResumeState resume,
    required String hash,
    required String filePath,
  }) {
    return TranslationResumeState(
      hash: hash,
      filePath: filePath,
      targetLanguage: resume.targetLanguage,
      clearSdh: resume.clearSdh,
      sourceContent: resume.sourceContent,
      sourceEncoding: resume.sourceEncoding,
      chunks: resume.chunks,
      nextChunkIndex: resume.nextChunkIndex,
      translatedText: resume.translatedText,
      translatedBlocks: resume.translatedBlocks,
      processedLines: resume.processedLines,
      totalLines: resume.totalLines,
      totalBlocks: resume.totalBlocks,
      chargeKey: resume.chargeKey,
    );
  }

  bool _isBatchMode = false;
  bool _isCloudBatchMode = false;
  bool get isCloudBatchMode => _isCloudBatchMode;
  bool get isBatchProcessing => _isBatchMode || _isCloudBatchMode;

  int _batchSuccessCount = 0;
  int get batchSuccessCount => _batchSuccessCount;
  int get batchErrorCount => _batchErrors.length;
  int _totalBatchJobs = 0;
  int get batchQueueLength => _totalBatchJobs;
  List<BatchError> get batchErrors => List.unmodifiable(_batchErrors);
  List<String> get batchCompletedPaths =>
      List.unmodifiable(_batchCompletedPaths);

  final _batchCompleteController =
      StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get batchCompleteStream =>
      _batchCompleteController.stream;

  static String _normalizePathForCompare(String pathStr) {
    final normalized = pathStr.replaceAll('/', Platform.pathSeparator);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  void attachSettings(AppSettings settings) {
    _settings = settings;

    // Bind Google Sign In Success to grant login bonus
    _settings?.onGoogleSignInSuccess = (String uid) async {
      await billingService.checkAndGiveStarterCredits(silent: false);
    };

    // Keep background progress notifications working even when the AI panel UI
    // isn't mounted (e.g., user backgrounds the app or is on another tab).
    onProgress ??= settings.showProgressNotification;

    // Allow the cloud retry queue to surface errors into system logs.
    _cloudRetryQueue.onLog = (key, [param]) => settings.addLog(key, param);
  }

  /// Dosyayı uygulama kalıcı depolama alanına kopyalar ve yeni yolu döndürür
  Future<String> _copyFileToAppStorage(File sourceFile, String hash) async {
    final appDir = await getApplicationDocumentsDirectory();
    final subtitlesDir = Directory(path.join(appDir.path, 'subtitles'));
    if (!await subtitlesDir.exists()) {
      await subtitlesDir.create(recursive: true);
    }

    // If the file is already in our app storage, reuse it as-is to avoid
    // creating a double-hash filename (which breaks resume path matching).
    if (path.isWithin(subtitlesDir.path, sourceFile.path) ||
        path.equals(subtitlesDir.path, path.dirname(sourceFile.path))) {
      return sourceFile.path;
    }

    final fileName = path.basename(sourceFile.path);
    var extension = path.extension(fileName);
    if (extension.isEmpty) extension = '.srt';

    // Short + stable filename to avoid overly long names (resume_*, etc.).
    // Still matches orphan-cleanup pattern: _<md5>.(srt|vtt)
    final permanentFileName = 'src_$hash$extension';
    final permanentFile = File(path.join(subtitlesDir.path, permanentFileName));

    // Dosya zaten varsa kopyalamaya gerek yok
    if (await permanentFile.exists()) {
      return permanentFile.path;
    }

    // Dosyayı kopyala
    await sourceFile.copy(permanentFile.path);
    debugPrint('Dosya kalıcı depolamaya kopyalandı: ${permanentFile.path}');
    return permanentFile.path;
  }

  void _logResumeDebug(String message) {
    _onLog?.call('log_resume_debug', jsonEncode({'message': message}));
  }

  bool _isLikelyEnglishSubtitleContent(String subtitleContent) {
    // Parse blocks to avoid timestamps/indices affecting detection.
    final blocks = SubtitleParser.parseSrt(subtitleContent);
    if (blocks.isEmpty) return false;

    final buffer = StringBuffer();
    for (final block in blocks) {
      final text = block.text.trim();
      if (text.isEmpty) continue;
      buffer.writeln(text);
      if (buffer.length >= 8000) break; // enough sample
    }

    final sample = buffer.toString().toLowerCase();
    final words = sample
        .replaceAll(RegExp(r"[^a-z\u00C0-\u024F'\s]"), ' ')
        .split(RegExp(r"\s+"))
        .where((w) => w.length > 1)
        .toList();

    if (words.length < 10) {
      // Too little text to be confident; default to NOT storing in Firebase.
      return false;
    }

    // Quick Turkish-character heuristic (very strong signal for TR source).
    final turkishCharHits = RegExp(r"[ğüşöçıİĞÜŞÖÇ]").allMatches(sample).length;
    if (turkishCharHits >= 2) return false;

    const stopwords = <String>{
      'the',
      'and',
      'to',
      'of',
      'in',
      'is',
      'it',
      'you',
      'i',
      'that',
      'for',
      'on',
      'with',
      'as',
      'this',
      'be',
      'are',
      'was',
      'were',
      'have',
      'has',
      'had',
      'not',
      'at',
      'but',
      'we',
      'they',
      'he',
      'she',
      'my',
      'your',
      'me',
      'do',
      'does',
      'did',
      'so',
      'if',
      'what',
      'there',
      'their',
      'them',
      'can',
      'will',
      'just',
      'one',
      'all',
      'no',
      'yes',
      'okay',
      'yeah',
    };

    var stopHits = 0;
    var letters = 0;
    var asciiLetters = 0;
    for (final word in words) {
      if (stopwords.contains(word)) stopHits++;
      for (final codeUnit in word.codeUnits) {
        final isAsciiLower = codeUnit >= 97 && codeUnit <= 122; // a-z
        final isLatinExtended = (codeUnit >= 192 && codeUnit <= 591);
        if (isAsciiLower || isLatinExtended) {
          letters++;
          if (isAsciiLower) asciiLetters++;
        }
      }
    }

    if (letters == 0) return false;

    final stopRatio = stopHits / words.length;
    final asciiRatio = asciiLetters / letters;

    // Conservative thresholds: only store when we're fairly confident it's English.
    // Lowered for short subtitles: stopRatio >= 0.02 and asciiRatio >= 0.80
    return stopRatio >= 0.02 && asciiRatio >= 0.80;
  }

  Future<bool> _shouldUseFirebaseForFile(File file) async {
    try {
      final readResult =
          await _subtitleRepository.readFileWithEncoding(file.path);
      var content = readResult.content;
      final clearSdh = _settings?.sdhClear ?? false;
      if (clearSdh) {
        content = SubtitleParser.clearSdh(content);
      }
      return _isLikelyEnglishSubtitleContent(content);
    } catch (_) {
      return false;
    }
  }

  // Callbacks
  Function(String key, [String? param])? _onLog;
  set onLog(Function? callback) {
    if (callback == null) {
      _onLog = null;
      billingService.onLog = null;
      return;
    }

    _onLog = (String key, [String? param]) {
      try {
        Function.apply(callback, [key, param]);
      } catch (_) {
        // Fallback for legacy callbacks that accept only one argument.
        Function.apply(callback, [key]);
      }
    };
    billingService.onLog = _onLog;
  }

  Function(int current, int total, {bool isComplete, String? fileName})?
      onProgress;
  Function(String title, String message)? onError;
  Function(bool enabled)? onWakelock;

  // Proxy getters for UI (Delegation pattern)
  int get userCredits => billingService.userCredits;
  int get tokenBalance => billingService.tokenBalance;
  bool get usesTokenWallet => billingService.usesTokenWallet;
  bool get offerTokenPacks => billingService.offerTokenPacks;
  int get displayFileCredits => billingService.displayFileCredits;
  int get displayTokenBalance => billingService.displayTokenBalance;
  int get displayPaidTokenBalance => billingService.displayPaidTokenBalance;
  int get displayBonusTokenBalance => billingService.displayBonusTokenBalance;
  bool get showTokenWalletUi => billingService.showTokenWalletUi;
  bool get hasSpendableBalance => billingService.hasSpendableBalance;
  List<CreditPackage> get packages => billingService.packages;
  Stream<void> get purchaseSuccessStream =>
      billingService.purchaseSuccessStream;

  bool get isPurchasing => billingService.isPurchasing;
  bool get isStoreLoading => billingService.isStoreLoading;
  String? get storeError => billingService.storeError;

  TranslationController() {
    _geminiService = GeminiService();
    _engine = TranslationEngine(_geminiService);

    // Engine Logging & Listeners
    _engine.onLog = (key, [param]) => _onLog?.call(key, param);
    _engine.onProgress = _updateProgress;
    _engine.onTranslatedBlocksUpdate = _updateTranslatedBlocks;

    // Billing Listeners
    billingService.addListener(_onBillingUpdate);
    // Avoid spamming the system log on app startup; user-initiated actions
    // (opening purchase dialog / retry) still log as before.
    billingService.checkAndGiveStarterCredits(silent: true);
    billingService.fetchPackages(silent: true);

    // Cache'den resume state'i yükle
    _loadResumeStateFromCache();

    // Best-effort Firestore retry queue.
    _cloudRetryQueue.start();
  }

  /// Mark a history entry active/inactive in Firestore.
  ///
  /// Used by History -> Devam Et to hide the entry while it's being processed.
  Future<void> setUserHistoryActive({
    required String sourceHash,
    required String targetLanguage,
    required bool isActive,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;
    if (sourceHash.trim().isEmpty) return;
    if (targetLanguage.trim().isEmpty) return;

    try {
      await _repository.setUserHistoryActive(
        sourceHash: sourceHash.trim(),
        targetLanguage: targetLanguage.trim(),
        isActive: isActive,
      );
    } catch (_) {
      unawaited(
        _cloudRetryQueue.enqueueSetUserHistoryActive(
          sourceHash: sourceHash.trim(),
          targetLanguage: targetLanguage.trim(),
          isActive: isActive,
        ),
      );
    }
  }

  void _onBillingUpdate() {
    notifyListeners();
  }

  // Proxy Methods
  Future<void> fetchPackages() => billingService.fetchPackages();
  Future<void> buyCredit(CreditPackage p) => billingService.buyCredit(p);

  /// Çoklu çeviri işlemini başlatır
  Future<BatchSummary> startBatchTranslationQueue({
    required List<BatchFile> files,
    required bool clearSdh,
    required String targetLanguage,
    bool playCompletionSound = true,
  }) async {
    if (_isBatchMode) {
      // If we got stuck in batch mode due to an unexpected exception, don't
      // silently ignore new starts.
      // Important: having a non-empty queue while status is idle is NOT a sign
      // of a healthy running state; it usually indicates we got stuck.
      final isActuallyRunning = status == TranslationStatus.running ||
          status == TranslationStatus.paused ||
          _currentJob != null;

      if (!isActuallyRunning) {
        _onLog?.call('log_batch_reset');
        _isBatchMode = false;
        _stopRequested = false;
        _jobQueue.clear();
        _currentJob = null;
      } else {
        // Zaten çalışıyorsa mevcut durumu döndür
        return BatchSummary(
          successCount: _batchSuccessCount,
          errors: List.unmodifiable(_batchErrors),
          completedPaths:
              List.unmodifiable(_batchCompletedPaths), // completedPaths
          stopped: false,
          outOfCredits: false,
        );
      }
    }

    // Kuyruğu hazırla
    _jobQueue.clear();
    for (var f in files) {
      _jobQueue.add(TranslationJob(
        file: File(f.path),
        targetLanguage: targetLanguage,
        clearSdh: clearSdh,
        displayFileName: f.name,
      ));
    }
    _totalBatchJobs = _jobQueue.length;

    _batchErrors.clear();
    _batchCompletedPaths.clear();
    batchResults.clear();
    _batchSuccessCount = 0;

    _stopRequested = false;
    _isBatchMode = true;
    _isCloudBatchMode = false;

    // If a previous run left the controller in paused state, starting a new queue
    // would hang in the pause loop before the first job.
    if (status == TranslationStatus.paused) {
      status = TranslationStatus.idle;
    }
    notifyListeners();

    try {
      // İşlem döngüsünü başlat
      await _processQueue(playCompletionSound: playCompletionSound);
    } catch (e, stackTrace) {
      // Unexpected error: don't leave batch mode stuck.
      status = TranslationStatus.error;
      _onLog?.call(
        'log_batch_start_error',
        jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
      );
    } finally {
      _isBatchMode = false;
      _currentJob = null;
      notifyListeners();
    }

    return BatchSummary(
      successCount: _batchSuccessCount,
      errors: List.unmodifiable(_batchErrors),
      completedPaths: List.unmodifiable(_batchCompletedPaths), // completedPaths
      stopped: _stopRequested,
      outOfCredits: !hasSpendableBalance && _jobQueue.isNotEmpty,
    );
  }

  /// Adds files to the currently running queue.
  ///
  /// If a batch/single translation is already in progress, newly enqueued jobs
  /// will be processed right after the current job finishes.
  int enqueueBatchFiles({
    required List<BatchFile> files,
    required bool clearSdh,
    required String targetLanguage,
  }) {
    if (files.isEmpty) return 0;

    // De-duplicate by path across current + queued.
    final existing = <String>{};
    if (_currentJob != null) {
      existing.add(_normalizePathForCompare(_currentJob!.file.path));
    }
    for (final j in _jobQueue) {
      existing.add(_normalizePathForCompare(j.file.path));
    }

    var added = 0;
    for (final f in files) {
      final p = f.path;
      if (p.isEmpty) continue;
      final norm = _normalizePathForCompare(p);
      if (existing.contains(norm)) continue;

      _jobQueue.add(
        TranslationJob(
          file: File(p),
          targetLanguage: targetLanguage,
          clearSdh: clearSdh,
          displayFileName: f.name,
        ),
      );
      existing.add(norm);
      added++;
    }

    if (added > 0) {
      // Keep total count accurate while batch is running.
      if (_isBatchMode) {
        _totalBatchJobs += added;
      }
      notifyListeners();
    }

    return added;
  }

  /// Tekli çeviri işlemini başlatır
  Future<void> startTranslation({
    bool clearSdh = false,
    String targetLanguage = 'Turkish',
    bool playCompletionSound = true,
    String? displayFileName,
  }) async {
    if (_selectedFile == null) return;

    // Tekli işlem için kuyruğu hazırla
    _jobQueue.clear();
    _jobQueue.add(TranslationJob(
      file: _selectedFile!,
      targetLanguage: targetLanguage,
      clearSdh: clearSdh,
      displayFileName: displayFileName ?? currentFileName,
    ));

    _stopRequested = false;
    _isBatchMode = false; // Tekli mod
    _isCloudBatchMode = false;

    await _processQueue(playCompletionSound: playCompletionSound);
  }

  /// Kuyruktaki işleri sırayla işleyen ana döngü
  Future<void> _processQueue({bool playCompletionSound = true}) async {
    while (_jobQueue.isNotEmpty) {
      if (_stopRequested) break;

      // Pause kontrolü
      while (status == TranslationStatus.paused) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_stopRequested) break;
      }
      if (_stopRequested) break;

      _currentJob = _jobQueue.removeAt(0);
      final job = _currentJob!;

      // Guard: batch list can contain paths that no longer exist (OS cleanup/user deleted).
      // Don't crash/stall; surface an error and move on.
      if (!job.file.existsSync()) {
        if (_isBatchMode) {
          _batchErrors.add(BatchError(
              fileName: job.effectiveFileName, message: job.file.path));
          _batchCompletedPaths.add(job.file.path);

          final settings = _settings;
          if (settings != null) {
            unawaited(
                settings.removeFilesFromBatchTranslation([job.file.path]));
          }
          _onLog?.call(
            'log_batch_error',
            jsonEncode({'file': job.effectiveFileName, 'error': job.file.path}),
          );
          // Continue with the next job.
          continue;
        } else {
          status = TranslationStatus.error;
          _onLog?.call('log_file_missing', jsonEncode({'path': job.file.path}));
          onError?.call('Hata', 'Dosya bulunamadı: ${job.file.path}');
          break;
        }
      }

      // Kredi kontrolü
      // Resume durumunda kredi düşülmeyeceği için burada katı kontrol yapmıyoruz,
      // _processJob içinde kontrol edilecek.

      try {
        await _processJob(job);

        // Başarılı işlem sonrası
        if (status == TranslationStatus.completed) {
          if (_isBatchMode) {
            _batchSuccessCount++;
            _batchCompletedPaths.add(job.file.path);

            // Keep persisted AI Panel list in sync even if the batch was started
            // from outside the AI panel (e.g. History resume).
            final settings = _settings;
            if (settings != null) {
              unawaited(
                  settings.removeFilesFromBatchTranslation([job.file.path]));
            }

            // Batch sonuçlarını topla
            if (generatedFilePath != null) {
              try {
                final content = await File(generatedFilePath!).readAsString();
                batchResults[job.effectiveFileName] = content;
              } catch (e) {
                _batchErrors.add(
                  BatchError(
                    fileName: job.effectiveFileName,
                    message: 'OUTPUT_READ_FAILED: ${e.toString()}',
                  ),
                );
                _onLog?.call(
                  'log_batch_error',
                  jsonEncode(
                      {'file': job.effectiveFileName, 'error': e.toString()}),
                );
              }
            }
          }
        }
      } catch (e) {
        if (_isBatchMode) {
          _batchErrors.add(BatchError(
              fileName: job.effectiveFileName, message: e.toString()));
          status = TranslationStatus.error;
          _onLog?.call(
            'log_batch_error',
            jsonEncode({'file': job.effectiveFileName, 'error': e.toString()}),
          );
          notifyListeners();
          // Kredi hatası ise döngüyü kır
          if (e.toString().contains('Yetersiz Bakiye')) {
            _stopRequested = true;
            break;
          }
        } else {
          // Tekli modda hatayı UI'a yansıt
          status = TranslationStatus.error;
          _onLog?.call(
              'log_error_generic', jsonEncode({'error': e.toString()}));
          onError?.call("Hata", "$e");
        }
      }
    }

    // Tüm işlemler bittiğinde
    if (_batchSuccessCount > 0 && _isBatchMode) {
      _batchCompleteController.add(batchResults);
      if (playCompletionSound) SystemSound.play(SystemSoundType.alert);
    }

    _currentJob = null;
  }

  /// Tek bir işi işleyen metod
  Future<void> _processJob(TranslationJob job) async {
    _setupJobUI(job);

    // If we are offline, wait instead of failing the job. This makes "resume"
    // seamless: translation continues from where it stopped as soon as the
    // connection comes back.
    while (true) {
      if (_stopRequested) return;
      try {
        await _ensurePrerequisites();
        break;
      } catch (e) {
        if (_stopRequested) return;
        if (_isOfflineException(e)) {
          await _waitUntilOnlineOrStop();
          continue;
        }
        rethrow;
      }
    }

    _startTranslationTimer();

    try {
      // 1. Dosya Hazırlığı ve Hash
      final prep = await _prepareFileAndHash(job);
      final workingFile = prep.file;
      final initialHash = prep.hash;

      // Resume Kontrolü + Hash Double-check (Single + Batch)
      final resolved = await _resolveResumeAndHash(
        file: workingFile,
        hash: initialHash,
        targetLanguage: job.targetLanguage,
      );
      final hash = resolved.hash;
      final resume = resolved.resume;
        final resumedChargeKey = resume?.chargeKey?.trim();
        final cachedChargeKey = (_activeTranslationChargeKey ?? '').trim();
        final creditChargeKey =
          (resumedChargeKey != null && resumedChargeKey.isNotEmpty)
            ? resumedChargeKey
            : (cachedChargeKey.isNotEmpty
              ? cachedChargeKey
              : _buildCreditChargeKey(
                filePath: workingFile.path,
                targetLanguage: job.targetLanguage,
              ));
      _activeTranslationChargeKey = creditChargeKey;
      _geminiService.setDeviceId(billingService.deviceId);
      final isResuming = resume != null;
      final hasTranslatedProgressOnResume =
          isResuming && resume.translatedBlocks.isNotEmpty;

      // Per-job stop behavior.
      // - New run: keep in batch list until credit is successfully consumed.
      // - Resume with progress: credit was already consumed earlier.
      _stopShouldRemoveFromBatchList = hasTranslatedProgressOnResume;

      // Blokları Hazırla
      await _prepareBlocksForUI(workingFile, job.clearSdh, isResuming, resume);

      generatedFilePath = SubtitleParser.generateOutputFilePath(
          workingFile.path, job.targetLanguage);
      final allowGlobalCache = await _shouldUseFirebaseForFile(workingFile);
      final u = _auth.currentUser;
      final allowUserHistory = u != null && !u.isAnonymous;

      // 2. Kredi kontrolü
      // - Yeni çeviri: kredi yoksa başlamasın.
      // - Resume + hiç ilerleme yoksa: ilk başarılı chunk için kredi gerekir.
      // - Resume + en az 1 çevrilmiş blok varsa: kredi tekrar sorgulanmasın.
      final needsCreditForThisRun = !hasTranslatedProgressOnResume;
      if (needsCreditForThisRun && !hasSpendableBalance) {
        throw Exception("Yetersiz Bakiye");
      }

      if (needsCreditForThisRun) {
        final charCount = (_currentJobSourceContent ?? '').length;
        final estimateDecision =
            await TokenEstimateGateService.instance.confirmIfNeeded(
          billing: billingService,
          trans: _settings?.trans ?? const {},
          charCount: charCount,
        );
        if (estimateDecision != TokenEstimateDecision.proceed) {
          _stopRequested = true;
          status = TranslationStatus.idle;
          notifyListeners();
          return;
        }

        await _geminiService.prepareTranslationAccess(
          chargeKey: creditChargeKey,
          fileName: job.fileName,
          targetLanguage: job.targetLanguage,
          platform: Platform.operatingSystem,
          charCount: charCount,
          estimatedTokens: estimateTokensFromCharCount(charCount),
        );
      } else {
        _geminiService.setTranslationChargeContext(
          chargeKey: creditChargeKey,
          approveCharge: false,
        );
      }

      // 3. Cache Kontrolü (Resume değilse)
      if (!isResuming && allowGlobalCache) {
        final cacheHit = await _tryLoadFromGlobalCache(
          hash,
          job,
          workingFile,
          chargeKey: creditChargeKey,
        );
        if (cacheHit) return;
      }

      // Resume'da kredi sadece daha önce en az bir başarılı chunk varsa
      // düşülmüş kabul edilir. (İlk chunk'tan önce hata aldıysa tekrar denemede
      // kredi ilk başarılı chunk'ta düşmelidir.)
      // Yeni çeviride kredi, ilk chunk başarıyla geldikten sonra bir kez düşülür.
      var creditConsumedForRun = hasTranslatedProgressOnResume;

      final effectiveClearSdhForRun =
          isResuming ? resume.clearSdh : job.clearSdh;

      // Update deviceId for server-side verification
      _geminiService.setDeviceId(billingService.deviceId);

      // 4. Çeviri Motorunu Çalıştır
      _engine.onBeforeChunk = (chunkIndex, totalChunks) async {
        if (_stopRequested) return;
        if (!creditConsumedForRun && !hasSpendableBalance) {
          throw Exception("Yetersiz Bakiye");
        }
      };

      _engine.onAfterChunkSuccess = (chunkIndex, totalChunks) async {
        if (_stopRequested) return;
        if (!creditConsumedForRun) {
          creditConsumedForRun = true;
          _stopShouldRemoveFromBatchList = true;
        }
      };

      final outFile = File(generatedFilePath!);

      // Auto-resume loop: if the engine returns a resumable state due to
      // transient/network errors, keep waiting/retrying with backoff.
      TranslationResumeState? resumeForRun = isResuming ? resume : null;
      var autoAttempt = 0;
      const maxAutoResumeRetries = 8;

      while (!_stopRequested) {
        final errorState = await _engine.runTranslation(
          file: workingFile,
          hash: hash,
          targetLanguage: job.targetLanguage,
          clearSdh: effectiveClearSdhForRun,
          outputFile: outFile,
          resumeState: resumeForRun,
          chargeKey: creditChargeKey,
        );

        if (errorState == null) {
          if (status != TranslationStatus.idle && !_stopRequested) {
            await _handleTranslationSuccess(
              outFile,
              workingFile,
              hash,
              job,
              allowGlobalCache,
              allowUserHistory,
            );
          }
          break;
        }

        // Persist partial state locally so it is always resumable.
        final errorDetail = await _handleTranslationError(
          errorState,
          workingFile,
          hash,
          job,
          allowUserHistory,
        );

        // Stop immediately on credit issues.
        if (errorDetail.toLowerCase().contains('yetersiz')) {
          throw Exception('Yetersiz Bakiye');
        }

        // If the issue looks non-transient, surface as an error.
        if (!_isAutoResumableError(errorDetail)) {
          // Translation is no longer continuing automatically; ensure the
          // History entry becomes visible again.
          unawaited(
            setUserHistoryActive(
              sourceHash: hash,
              targetLanguage: job.targetLanguage,
              isActive: false,
            ),
          );
          throw Exception('Çeviri kesintiye uğradı: $errorDetail');
        }

        // Wait and retry from the last resume state.
        autoAttempt++;
        if (autoAttempt > maxAutoResumeRetries) {
          _onLog?.call('log_max_retry_state_saving');
          throw Exception(
            'Maksimum yeniden deneme sayısı aşıldı ($maxAutoResumeRetries)',
          );
        }
        resumeForRun = errorState;

        // Pause the timer while waiting.
        _stopwatch.stop();
        status = TranslationStatus.paused;
        notifyListeners();

        final waitSeconds = _computeAutoResumeDelaySeconds(autoAttempt);
        _onLog?.call(
          'log_retrying_after_error',
          jsonEncode({
            'seconds': waitSeconds,
            'attempt': autoAttempt,
            'max': maxAutoResumeRetries,
          }),
        );

        // If we are offline, wait specifically for connectivity.
        if (_settings != null) {
          await _settings!.checkConnectivity();
          if (_settings!.isOffline) {
            await _waitUntilOnlineOrStop();
          } else {
            await Future.delayed(Duration(seconds: waitSeconds));
          }
        } else {
          await Future.delayed(Duration(seconds: waitSeconds));
        }

        // Resume timer.
        if (!_stopRequested) {
          status = TranslationStatus.running;
          _stopwatch.start();
          notifyListeners();
        }

        // Re-check prerequisites (auth/connectivity) before retrying.
        while (true) {
          if (_stopRequested) break;
          try {
            await _ensurePrerequisites();
            break;
          } catch (e) {
            if (_stopRequested) break;
            if (_isOfflineException(e)) {
              await _waitUntilOnlineOrStop();
              continue;
            }
            rethrow;
          }
        }
      }
    } finally {
      _activeTranslationChargeKey = null;
      _geminiService.clearTranslationChargeContext();
      _engine.onAfterChunkSuccess = null;
      _stopTranslationTimer();
    }
  }

  String _buildCreditChargeKey({
    required String filePath,
    required String targetLanguage,
  }) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final raw = '${_normalizePathForCompare(filePath)}|$targetLanguage|$now';
    final digest = _fileService.calculateMd5FromString(raw);
    return digest;
  }

  Future<String> _doubleCheckCanonicalHash({
    required File file,
    required bool clearSdh,
    required String expectedHash,
  }) async {
    try {
      // Small debounce to avoid reacting to transient/partial reads.
      await Future.delayed(const Duration(seconds: 1));

      final readResult =
          await _subtitleRepository.readFileWithEncoding(file.path);
      var content = readResult.content;
      if (clearSdh) {
        content = SubtitleParser.clearSdh(content);
      }
      final canonicalHash = _stableSubtitleHash(content);

      if (canonicalHash != expectedHash) {
        _logResumeDebug(
          'hash double-check mismatch expected=$expectedHash got=$canonicalHash file=${file.path}',
        );
      }
      return canonicalHash;
    } catch (e) {
      _logResumeDebug(
          'hash double-check failed error=${e.toString()} file=${file.path}');
      return '';
    }
  }

  Future<({TranslationResumeState? resume, String hash})>
      _resolveResumeAndHash({
    required File file,
    required String hash,
    required String targetLanguage,
  }) async {
    var resume = _resumeState;
    if (resume == null) return (resume: null, hash: hash);

    // If hash doesn't match, try to reconcile using a stable hash computed from
    // resume.sourceContent (cross-device: Windows vs Android line endings/BOM).
    if (resume.hash != hash) {
      final stableFromFile = await _doubleCheckCanonicalHash(
        file: file,
        clearSdh: resume.clearSdh,
        expectedHash: resume.hash,
      );

      final stableFromResume = resume.sourceContent.trim().isNotEmpty
          ? _stableSubtitleHash(resume.sourceContent)
          : '';

      final canReconcile = stableFromFile.isNotEmpty &&
          stableFromResume.isNotEmpty &&
          stableFromFile == stableFromResume;

      if (canReconcile) {
        _logResumeDebug('hash reconciled via stable hash; continuing resume');
        final rebuilt = _rebuildResumeWith(
          resume: resume,
          hash: stableFromFile,
          filePath: file.path,
        );
        _resumeState = rebuilt;
        unawaited(_saveResumeStateToCache());
        resume = rebuilt;
        if (aiPanelLanguageCodesEqual(resume.targetLanguage, targetLanguage)) {
          return (resume: resume, hash: stableFromFile);
        }
        return (resume: null, hash: stableFromFile);
      }

      if (stableFromFile == resume.hash) {
        _logResumeDebug(
            'hash double-check matched; continuing without restart');
        if (aiPanelLanguageCodesEqual(resume.targetLanguage, targetLanguage)) {
          return (resume: resume, hash: stableFromFile);
        }
        return (resume: null, hash: stableFromFile);
      }

      // Confirmed mismatch: clear resumable state.
      _onLog?.call('log_hash_changed_restart');
      _resumeState = null;
      unawaited(_saveResumeStateToCache());
      resume = null;
      return (resume: null, hash: hash);
    }

    if (aiPanelLanguageCodesEqual(resume.targetLanguage, targetLanguage)) {
      return (resume: resume, hash: hash);
    }

    return (resume: null, hash: hash);
  }

  bool _isOfflineException(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('internet') ||
        s.contains('offline') ||
        s.contains('bağlantı');
  }

  bool _isAutoResumableError(String errorDetail) {
    final s = errorDetail.toLowerCase();
    return s.contains('internet') ||
        s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('network') ||
        s.contains('socket') ||
        s.contains('handshake') ||
        s.contains('502') ||
        s.contains('503') ||
        s.contains('504') ||
        s.contains('unavailable');
  }

  int _computeAutoResumeDelaySeconds(int attempt) {
    // 5s, 10s, 15s ... capped to 60s.
    final s = 5 * attempt;
    if (s > 60) return 60;
    return s;
  }

  Future<void> _waitUntilOnlineOrStop() async {
    final settings = _settings;
    if (settings == null) {
      // No connectivity signal; wait a bit and let the retry loop re-check.
      await Future.delayed(const Duration(seconds: 8));
      return;
    }

    while (!_stopRequested) {
      await settings.checkConnectivity();
      if (!settings.isOffline) return;
      status = TranslationStatus.paused;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // --- Helper Methods for _processJob ---

  void _setupJobUI(TranslationJob job) {
    _lastTargetLanguage = job.targetLanguage;
    currentFileName = _resolveDisplayFileName(
      preferred: job.effectiveFileName,
      fallbackPath: job.file.path,
    );
    _selectedFile = job.file;
    _onLog?.call(
      'log_processing_file',
      jsonEncode({'file': currentFileName}),
    );
  }

  Future<void> _ensurePrerequisites() async {
    if (_auth.currentUser == null) {
      // Main() already attempts anonymous sign-in, but on some devices the first
      // translation start can race auth restoration. Ensure we have a session.
      try {
        await _auth.signInAnonymously();
        await _auth.currentUser?.reload();
      } catch (_) {
        // Ignore; we'll throw below if still missing.
      }
    }
    if (_auth.currentUser == null) throw Exception('Giriş gerekli.');
    if (Platform.isAndroid) {
      try {
        await _settings?.requestNotificationPermission();
      } catch (_) {}
    }
    if (_settings != null) {
      await _settings!.checkConnectivity();
      if (_settings!.isOffline) throw Exception('İnternet bağlantısı yok.');
    }
  }

  void _startTranslationTimer() {
    status = TranslationStatus.running;
    isTranslationComplete = false;
    notifyListeners();

    _engine.onProgress = _updateProgress;
    _engine.onTranslatedBlocksUpdate = _updateTranslatedBlocks;

    _stopwatch.reset();
    _stopwatch.start();
    onWakelock?.call(true);

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_stopwatch.isRunning) return;
      final elapsed = _stopwatch.elapsed;
      elapsedTime =
          '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      notifyListeners();
    });
  }

  void _stopTranslationTimer() {
    onWakelock?.call(false);
    _stopwatch.stop();
    _progressTimer?.cancel();
    notifyListeners();
  }

  Future<({File file, String hash})> _prepareFileAndHash(
      TranslationJob job) async {
    File workingFile = job.file;
    if (_isBatchMode) {
      final hashTemp = await _fileService.calculateMd5(job.file);
      final permPath = await _copyFileToAppStorage(job.file, hashTemp);
      workingFile = File(permPath);
    }

    final readResult =
        await _subtitleRepository.readFileWithEncoding(workingFile.path);
    var content = readResult.content;
    if (job.clearSdh) {
      content = SubtitleParser.clearSdh(content);
    }
    final hash = _stableSubtitleHash(content);
    return (file: workingFile, hash: hash);
  }

  // NOTE: Resume/hash validation is handled asynchronously in _resolveResumeAndHash
  // to allow double-checking against transient I/O/decoding issues.

  Future<void> _prepareBlocksForUI(File file, bool clearSdh, bool isResuming,
      TranslationResumeState? resume) async {
    if (!isResuming) {
      sourceBlocks = [];
      translatedBlocks = [];
      final readResult =
          await _subtitleRepository.readFileWithEncoding(file.path);
      var content = readResult.content;
      if (clearSdh) {
        content = SubtitleParser.clearSdh(content);
      }
      _currentJobSourceContent = content;
      sourceBlocks = SubtitleParser.parseSrt(content);
      _throwIfMultiPackDetected(sourceBlocks);
        _throwIfTimecodeLimitExceeded(sourceBlocks);
    } else {
      // Resume durumunda hem source hem translated blokları yükle
      // LiveSubtitleViewer sourceBlocks.isNotEmpty kontrolü yapıyor
      if (resume!.sourceContent.isNotEmpty) {
        _currentJobSourceContent = resume.sourceContent;
        sourceBlocks = SubtitleParser.parseSrt(resume.sourceContent);
        _throwIfMultiPackDetected(sourceBlocks);
        _throwIfTimecodeLimitExceeded(sourceBlocks);
      } else {
        final readResult =
            await _subtitleRepository.readFileWithEncoding(file.path);
        var content = readResult.content;
        if (clearSdh) {
          content = SubtitleParser.clearSdh(content);
        }
        _currentJobSourceContent = content;
        sourceBlocks = SubtitleParser.parseSrt(content);
        _throwIfMultiPackDetected(sourceBlocks);
        _throwIfTimecodeLimitExceeded(sourceBlocks);
      }
      translatedBlocks = List.from(resume.translatedBlocks);
    }
  }

  void _throwIfMultiPackDetected(List<SubtitleBlock> blocks) {
    int maxStartTime = 0;

    for (var i = 0; i < blocks.length; i++) {
      final timecodeStr = blocks[i].timecode;
      if (timecodeStr.isEmpty) continue;
      
      final parts = timecodeStr.split('-->');
      if (parts.isEmpty) continue;

      final startStr = parts[0].trim();
      final startMs = SubtitleParser.parseTimestampToMs(startStr) ?? 0;

      if (startMs > maxStartTime) {
        maxStartTime = startMs;
      }

      // Güvenlik mekanizması: Eğer zaman kodu içinde en az 1 dakika (60.000 ms)
      // ilerlemişsek ve aniden 30 saniyeden (30.000 ms) büyük bir geri dönüş/sıfırlanma 
      // yaşanıyorsa bu dosyanın birleştirilmiş (multi-pack) olduğunu anlarız.
      if (maxStartTime > 60000 && (maxStartTime - startMs) > 30000) {
        final message = _settings?.trans['error_multi_pack_detected'] ?? 'MULTI_PACK_DETECTED';
        _onLog?.call(
          'log_error',
          jsonEncode({
            'error': message,
            'maxMs': maxStartTime,
            'currentMs': startMs
          }),
        );
        throw Exception(message);
      }
    }
  }

  void _throwIfTimecodeLimitExceeded(List<SubtitleBlock> blocks) {
    final maxMs = SubtitleParser.maxTimecodeMsFromBlocks(blocks);
    if (maxMs <= _maxAllowedTimecodeMs) return;

    final limitHours = (_maxAllowedTimecodeMs ~/ 3600000);
    final settings = _settings;
    final message = settings?.trans['timecode_limit_exceeded'] ??
        'Zaman kodu $limitHours saati geçen altyazılar çevrilemiyor.';

    _onLog?.call(
      'log_error',
      jsonEncode(
          {'error': message, 'maxMs': maxMs, 'limitMs': _maxAllowedTimecodeMs}),
    );

    throw Exception(message);
  }

  String _cleanDisplayFileName(String name) {
    return StringUtils.normalizeDisplayFileName(name).trim();
  }

  String _resolveDisplayFileName({
    String? preferred,
    required String fallbackPath,
  }) {
    final fromPreferred = _cleanDisplayFileName(preferred ?? '');
    if (fromPreferred.isNotEmpty &&
        !_looksLikeInternalGeneratedFileName(fromPreferred)) {
      return fromPreferred;
    }
    final fromPath = _cleanDisplayFileName(path.basename(fallbackPath));
    if (fromPath.isNotEmpty && !_looksLikeInternalGeneratedFileName(fromPath)) {
      return fromPath;
    }
    if (fromPreferred.isNotEmpty) return fromPreferred;
    return fromPath;
  }

  bool _looksLikeInternalGeneratedFileName(String name) {
    final leaf = name.trim().split(RegExp(r'[\\/]')).last.trim();
    if (leaf.isEmpty) return false;
    final lower = leaf.toLowerCase();

    // Internal permanent storage name: src_<md5>.<ext>
    if (RegExp(r'^src_[a-f0-9]{32}(\.[^.]+)?$', caseSensitive: false)
        .hasMatch(lower)) {
      return true;
    }

    // Cross-device resume temp name: resume_<timestamp>_<name>.<ext>
    if (RegExp(r'^resume_\d{10,}_', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // Known fallback used by History when no name is available.
    if (lower == 'resume_source.srt' || lower == 'resume_source.vtt') {
      return true;
    }

    return false;
  }

  String? _findFriendlyProjectFileName({
    required String hash,
    required String targetLanguage,
  }) {
    final settings = _settings;
    if (settings == null) return null;

    final id = '${hash}_${targetLanguage.toLowerCase()}';
    for (final p in settings.projects) {
      if (p.id == id) return p.fileName;
    }

    for (final p in settings.projects) {
      if ((p.sourceHash ?? '') == hash && p.targetLanguage == targetLanguage) {
        return p.fileName;
      }
    }

    return null;
  }

  String _bestFriendlyDisplayNameForHash({
    required String hash,
    required String targetLanguage,
    String? fallbackName,
    String? fallbackPath,
  }) {
    String clean(String s) => StringUtils.normalizeDisplayFileName(s).trim();

    final candidates = <String?>[
      fallbackName,
      _findFriendlyProjectFileName(hash: hash, targetLanguage: targetLanguage),
      fallbackPath,
    ];

    for (final c in candidates) {
      final raw = (c ?? '').trim();
      if (raw.isEmpty) continue;
      if (_looksLikeInternalGeneratedFileName(raw)) continue;
      final cleaned = clean(raw);
      if (cleaned.isEmpty) continue;
      return cleaned;
    }

    // Worst-case fallback.
    final raw = (fallbackName ?? fallbackPath ?? 'subtitle.srt').trim();
    final cleaned = clean(raw);
    return cleaned.isNotEmpty ? cleaned : raw;
  }

  String _bestFriendlyDisplayNameForJob({
    required TranslationJob job,
    required String hash,
  }) {
    String clean(String s) => StringUtils.normalizeDisplayFileName(s).trim();

    final candidates = <String?>[
      job.displayFileName,
      _findFriendlyProjectFileName(
          hash: hash, targetLanguage: job.targetLanguage),
      job.effectiveFileName,
      job.fileName,
    ];

    for (final c in candidates) {
      final raw = (c ?? '').trim();
      if (raw.isEmpty) continue;
      if (_looksLikeInternalGeneratedFileName(raw)) continue;
      final cleaned = clean(raw);
      if (cleaned.isEmpty) continue;
      return cleaned;
    }

    final fallback = clean(job.effectiveFileName);
    return fallback.isEmpty ? job.effectiveFileName : fallback;
  }

  Future<bool> _tryLoadFromGlobalCache(
    String hash,
    TranslationJob job,
    File workingFile, {
    required String chargeKey,
  }) async {
    final cachedData = await _repository.checkGlobalCache(
      sourceHash: hash,
      targetLanguage: job.targetLanguage,
    );

    if (cachedData != null) {
      isCached = true;
      _resumeState = null;
      await _saveResumeStateToCache();

      final translatedContent = cachedData['translatedContent'];
      translatedBlocks = SubtitleParser.parseSrt(translatedContent);
      await File(generatedFilePath!).writeAsString(translatedContent);

      await billingService.consumeCredit(
        1,
        reason: 'cache_hit',
        chargeKey: chargeKey,
        fileName: _bestFriendlyDisplayNameForJob(job: job, hash: hash),
        targetLanguage: job.targetLanguage,
      );

      _syncProjectToSettings(
        file: workingFile,
        sourceHash: hash,
        targetLanguage: job.targetLanguage,
        isPartial: false,
        isCompleted: true,
        isActive: false,
      );

      // Best-effort cloud history: don't fail the translation if Firestore is
      // temporarily unavailable.
      try {
        final displayName =
            _bestFriendlyDisplayNameForJob(job: job, hash: hash);
        await _repository.addToUserHistory(
          sourceHash: hash,
          fileName: displayName,
          targetLanguage: job.targetLanguage,
          encodingDetected: _engine.lastDetectedEncoding,
          clearSdh: job.clearSdh,
        );
      } catch (e) {
        _onLog?.call(
            'cloud_error_with_details', jsonEncode({'error': e.toString()}));
        unawaited(
          _cloudRetryQueue.enqueueAddToUserHistory(
            sourceHash: hash,
            fileName: _bestFriendlyDisplayNameForJob(job: job, hash: hash),
            targetLanguage: job.targetLanguage,
            isPartial: false,
            encodingDetected: _engine.lastDetectedEncoding,
            clearSdh: job.clearSdh,
          ),
        );
      }

      _finishSuccess(false);
      _onLog?.call('log_translation_complete');
      _onLog?.call('log_saved', generatedFilePath);
      return true;
    }
    return false;
  }

  Future<String> _handleTranslationError(
      TranslationResumeState errorState,
      File workingFile,
      String hash,
      TranslationJob job,
      bool allowUserHistory) async {
    _resumeState = errorState;
    translatedBlocks = errorState.translatedBlocks;

    final translatedCount = errorState.translatedBlocks.length;
    final totalCount = sourceBlocks.isNotEmpty
        ? sourceBlocks.length
        : (errorState.sourceContent.isNotEmpty
            ? SubtitleParser.parseSrt(errorState.sourceContent).length
            : 0);

    // İlk başarılı çeviri bloğu henüz yoksa geçmişe "yarım" kayıt düşme.
    if (errorState.translatedBlocks.isEmpty) {
      final errorDetail = _engine.lastError ?? 'Bilinmeyen hata';
      return errorDetail;
    }

    _syncProjectToSettings(
      file: workingFile,
      sourceHash: hash,
      targetLanguage: job.targetLanguage,
      isPartial: true,
      isCompleted: false,
      isActive: true,
    );

    if (allowUserHistory) {
      try {
        final displayName =
            _bestFriendlyDisplayNameForJob(job: job, hash: hash);
        await _repository.addToUserHistory(
          sourceHash: hash,
          fileName: displayName,
          targetLanguage: job.targetLanguage,
          isPartial: true,
          encodingDetected: _engine.lastDetectedEncoding,
          resumeState: errorState.toJson(),
          translatedLines: translatedCount,
          totalLines: totalCount,
          isActive: true,
          clearSdh: job.clearSdh,
        );
      } catch (e) {
        _onLog?.call(
            'cloud_error_with_details', jsonEncode({'error': e.toString()}));
        unawaited(
          _cloudRetryQueue.enqueueAddToUserHistory(
            sourceHash: hash,
            fileName: _bestFriendlyDisplayNameForJob(job: job, hash: hash),
            targetLanguage: job.targetLanguage,
            isPartial: true,
            encodingDetected: _engine.lastDetectedEncoding,
            resumeState: errorState.toJson(),
            translatedLines: translatedCount,
            totalLines: totalCount,
            isActive: true,
            clearSdh: job.clearSdh,
          ),
        );
      }
    }

    final errorDetail = _engine.lastError ?? 'Bilinmeyen hata';
    return errorDetail;
  }

  Future<void> _handleTranslationSuccess(
      File outFile,
      File workingFile,
      String hash,
      TranslationJob job,
      bool allowGlobalCache,
      bool allowUserHistory) async {
    final finalContent = await outFile.readAsString();
    translatedBlocks = SubtitleParser.parseSrt(finalContent);

    final displayName = _bestFriendlyDisplayNameForJob(job: job, hash: hash);

    final originalNameForGlobalCache = StringUtils.ensureHashSuffixInFileName(
      fileName: displayName,
      hash: hash,
    );

    var sourceContent = (_currentJobSourceContent ?? '').trim();
    if (sourceContent.isEmpty) {
      try {
        final sourceReadResult =
            await _subtitleRepository.readFileWithEncoding(workingFile.path);
        sourceContent = sourceReadResult.content;
      } catch (e) {
        _onLog?.call(
          'log_source_read_failed',
          jsonEncode({'path': workingFile.path, 'error': e.toString()}),
        );
        sourceContent = '';
      }
    }

    if (allowGlobalCache && sourceContent.trim().isNotEmpty) {
      // Gerçek AI maliyeti: yalnızca bu çevrilen dosyaya, global_translations
      // dokümanının içine düz alan olarak yazılır (cache-hit'te AI çağrısı yoktur).
      final usage = _engine.usageSnapshot;
      final inputTokens = (usage['inputTokens'] as num?)?.toInt() ?? 0;
      final outputTokens = (usage['outputTokens'] as num?)?.toInt() ?? 0;
      final cost = <String, dynamic>{
        'inputTokens': usage['inputTokens'],
        'outputTokens': usage['outputTokens'],
        'calls': usage['apiCalls'],
        'retries': usage['apiRetries'],
        'resendRounds': usage['resendRounds'],
        'costUsd': formatUsd6(ledgerCostUsd(
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        )),
        'costUsdProvider': formatUsd6(providerCostUsd(
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        )),
        'model': (usage['model'] as String?)?.trim().isNotEmpty == true
            ? usage['model']
            : 'gemini-2.5-flash-lite',
        'at': DateTime.now().toUtc().toIso8601String(),
      };
      // Cloud writes are best-effort: translation should still be marked as
      // completed locally even if Firestore is temporarily unavailable.
      try {
        await _repository.saveToGlobalCache(
          sourceHash: hash,
          sourceContent: sourceContent,
          translatedContent: finalContent,
          originalName: originalNameForGlobalCache,
          targetLanguage: job.targetLanguage,
          encodingDetected: _engine.lastDetectedEncoding,
          deviceId: billingService.deviceId,
          isBatch: _isCloudBatchMode,
          cost: cost,
        );
      } catch (e) {
        _onLog?.call(
            'cloud_error_with_details', jsonEncode({'error': e.toString()}));
        unawaited(
          _cloudRetryQueue.enqueueSaveToGlobalCache(
            sourceHash: hash,
            sourceContent: sourceContent,
            translatedContent: finalContent,
            originalName: originalNameForGlobalCache,
            targetLanguage: job.targetLanguage,
            encodingDetected: _engine.lastDetectedEncoding,
            deviceId: billingService.deviceId,
            isBatch: _isCloudBatchMode,
            cost: cost,
          ),
        );
      }
    }

    if (allowUserHistory) {
      try {
        await _repository.addToUserHistory(
          sourceHash: hash,
          fileName: displayName,
          targetLanguage: job.targetLanguage,
          isPartial: false,
          encodingDetected: _engine.lastDetectedEncoding,
          isActive: false,
          clearSdh: job.clearSdh,
        );
      } catch (e) {
        _onLog?.call(
            'cloud_error_with_details', jsonEncode({'error': e.toString()}));
        unawaited(
          _cloudRetryQueue.enqueueAddToUserHistory(
            sourceHash: hash,
            fileName: displayName,
            targetLanguage: job.targetLanguage,
            isPartial: false,
            encodingDetected: _engine.lastDetectedEncoding,
            isActive: false,
            clearSdh: job.clearSdh,
          ),
        );
      }
    }

    _syncProjectToSettings(
      file: workingFile,
      sourceHash: hash,
      targetLanguage: job.targetLanguage,
      isPartial: false,
      isCompleted: true,
      isActive: false,
    );

    // Resume state ve cache'i temizle
    _resumeState = null;
    await _saveResumeStateToCache();

    _currentJobSourceContent = null;

    _finishSuccess(false);
    _onLog?.call('log_translation_complete');
    _onLog?.call('log_saved', generatedFilePath);
  }

  void shareTranslatedFile() {
    if (generatedFilePath == null) return;
    unawaited(_shareWithFriendlyName());
  }

  Future<void> _shareWithFriendlyName() async {
    final export = await getTranslatedFileExport();
    if (export == null) return;

    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, export.name);
    final tempFile = File(tempPath);
    await tempFile.writeAsString(export.content, flush: true);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(tempFile.path)]),
    );
  }

  String getTranslatedFileName() => _buildTranslatedFileName();

  Future<({String name, String content})?> getTranslatedFileExport() async {
    if (generatedFilePath == null) return null;
    final file = File(generatedFilePath!);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final name = _buildTranslatedFileName();
    return (name: name, content: content);
  }

  String _buildTranslatedFileName() {
    final fallbackName = generatedFilePath != null
        ? path.basename(generatedFilePath!)
        : 'output.srt';
    final baseName = currentFileName ?? fallbackName;
    final ext =
        path.extension(baseName).isNotEmpty ? path.extension(baseName) : '.srt';
    final nameWithoutExt = baseName.replaceAll(RegExp(r'\.[^.]*$'), '');
    final noHash = nameWithoutExt.replaceFirst(
        RegExp(r'_[a-f0-9]{32}$', caseSensitive: false), '');
    final stripped = StringUtils.stripLanguageSuffix(noHash);

    // Eğer çeviri yapılmamışsa (bloklar boşsa veya ilerleme yoksa) dil ekini ekleme
    if (translatedBlocks.isEmpty) {
      return '$stripped$ext';
    }

    final lang = _lastTargetLanguage ?? 'TR';
    return '$stripped' '_$lang$ext';
  }

  Future<void> saveTranslatedFile() async {
    if (generatedFilePath == null) return;
    final file = File(generatedFilePath!);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final isAndroidIos = Platform.isAndroid || Platform.isIOS;
    final defaultName = _buildTranslatedFileName();
    final dialogTitle = _settings?.trans["dialog_save"] ?? 'Kaydet';

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      bytes: isAndroidIos ? bytes : null,
    );

    if (savedPath != null && !isAndroidIos) {
      await File(savedPath).writeAsBytes(bytes, flush: true);
    }

    if (savedPath != null) {
      _onLog?.call('log_saved', isAndroidIos ? defaultName : savedPath);
    }
  }

  void _updateProgress(int current, int total, {bool isComplete = false}) {
    if (total > 0) {
      progress = (current / total).clamp(0.0, 0.99);
    }

    if (isComplete) {
      progress = 1.0;
    }

    // Calculate estimated time
    final elapsedSeconds = _stopwatch.elapsed.inSeconds;
    if (elapsedSeconds > 0 && current > 0) {
      final rate = current / elapsedSeconds;
      final remainingLines = total - current;
      if (remainingLines > 0) {
        final remSeconds = (remainingLines / rate).ceil();
        final remDuration = Duration(seconds: remSeconds);
        remainingTime =
            '-${remDuration.inMinutes.toString().padLeft(2, '0')}:${(remDuration.inSeconds % 60).toString().padLeft(2, '0')}';
      }
    }

    // Don't forward engine-level completion. Completion notifications should be
    // emitted only after post-processing succeeds and the controller is marked
    // completed (see _finishSuccess).
    onProgress?.call(current, total,
        isComplete: false, fileName: currentFileName);
    notifyListeners();
  }

  void _updateTranslatedBlocks(List<SubtitleBlock> blocks) {
    translatedBlocks = blocks;
    notifyListeners();
  }

  @override
  void dispose() {
    _batchCompleteController.close();
    _progressTimer?.cancel();
    _resumeCloudSyncTimer?.cancel();
    _cloudRetryQueue.stop();
    billingService.removeListener(_onBillingUpdate);
    billingService.dispose();
    super.dispose();
  }

  void pauseTranslation() {
    if (status == TranslationStatus.running) {
      status = TranslationStatus.paused;
      _stopwatch.stop();
      _engine.pause();
      notifyListeners();
    }
  }

  void resumeTranslation() {
    if (status == TranslationStatus.paused) {
      status = TranslationStatus.running;
      _stopwatch.start();
      _engine.resume();
      notifyListeners();
    }
  }

  Future<void> startBatchTranslationTest({
    required List<BatchFile> inputSrtFiles,
    required String targetLanguage,
    bool clearSdh = false,
    void Function(File)? onFileCompleted,
  }) async {
    if (inputSrtFiles.isEmpty) return;

    if (!hasSpendableBalance) {
      _onLog?.call(
          _settings?.trans['error_prefix'] ?? 'Hata',
          billingService.showTokenWalletUi
              ? (_settings?.trans['batch_no_token_log'] ??
                  _settings?.trans['batch_no_credit_log'] ??
                  'Yetersiz token. İşlemi başlatabilmek için bakiyeniz bulunmuyor.')
              : (_settings?.trans['batch_no_credit_log'] ??
                  'Kredi yetersiz. İşlemi başlatabilmek için bakiyeniz bulunmuyor.'));
      onError?.call(
          billingService.showTokenWalletUi
              ? (_settings?.trans['billing_no_token'] ??
                  _settings?.trans['token_insufficient_title'] ??
                  'Yetersiz token')
              : (_settings?.trans['billing_no_credit'] ?? 'Kredi Yetersiz'),
          billingService.showTokenWalletUi
              ? (_settings?.trans['billing_no_token_desc'] ??
                  _settings?.trans['billing_no_credit_desc'] ??
                  'Bu işlemi başlatmak için bakiyeniz bulunmuyor.')
              : (_settings?.trans['billing_no_credit_desc'] ??
                  'Bu işlemi başlatmak için bakiyeniz bulunmuyor.'));
      return;
    }

    List<BatchFile> filesToProcess = inputSrtFiles;
    if (!billingService.usesTokenWallet &&
        userCredits < inputSrtFiles.length) {
      filesToProcess = inputSrtFiles.sublist(0, userCredits);
      final partialDesc = (_settings?.trans['batch_credit_partial'] ??
              'Krediniz ({credits}), seçilen dosya sayısından ({total}) az...')
          .replaceAll('{credits}', userCredits.toString())
          .replaceAll('{total}', inputSrtFiles.length.toString());
      _onLog?.call(_settings?.trans['info'] ?? 'Bilgi', partialDesc);
    }

    _selectedFile = File(filesToProcess.first.path);

    // activeBatchFilePaths.clear(); // We shouldn't clear it so we can run concurrently!
    for (var f in filesToProcess) {
      if (!activeBatchFilePaths.contains(f.path)) {
        activeBatchFilePaths.add(f.path);
      }
    }

    _geminiService.setDeviceId(billingService.deviceId);

    // Eski ortak hash hesaplaması iptal edildi, artık her dosya için kendi içeriğinden hash üretilecek.

    if (!_isCloudBatchMode) {
      batchResults.clear();
    }
    _isCloudBatchMode = true;
    _startBatchTimer();
    status = TranslationStatus.running;
    progress = 1.0;
    isTranslationComplete = false;
    // _batchErrors.clear(); // Eğer error listesi class düzeyindeyse

    final triggeredDesc = (_settings?.trans['batch_api_triggered'] ??
            '{count} dosya için Batch API tetiklendi.')
        .replaceAll('{count}', filesToProcess.length.toString());
    _onLog?.call(
        _settings?.trans['batch_starting'] ?? 'Toplu Çeviri Başlatılıyor...',
        triggeredDesc);
    notifyListeners();

    String? fcmToken;
    // Desktop FCM disabled

    List<Map<String, dynamic>> activeJobs = [];
    try {
      for (final batchF in filesToProcess) {
        final file = File(batchF.path);
        var content = await file.readAsString();

        if (clearSdh) {
          content = SubtitleParser.clearSdh(content);
        }

        // Her dosya için kendi hash'i üzerinden chargeKey oluşturuyoruz
        final fileHash = content.hashCode.toString();
        final fileChargeKey = _buildSessionChargeKey(fileHash, targetLanguage);
        _activeTranslationChargeKey = fileChargeKey;
        _geminiService.setChargeKey(fileChargeKey);

        final blocks = SubtitleParser.parseSrt(content);

        if (file.path == _selectedFile?.path) {
          sourceBlocks = blocks;
        }

        List<Map<String, String>> requests = [];
        int chunkSize = 200;
        for (int i = 0; i < blocks.length; i += chunkSize) {
          final end =
              (i + chunkSize < blocks.length) ? i + chunkSize : blocks.length;
          final chunkBlocks = blocks.sublist(i, end);
          final chunkStr =
              SubtitleBuilder.buildSrt(chunkBlocks, resequence: false);
          requests.add({
            'id': 'chunk_$i',
            'text': chunkStr,
          });
        }

        final sourceHash = _stableSubtitleHash(content);
        final displayName = batchF.name;
        final originalNameForGlobalCache =
            StringUtils.ensureHashSuffixInFileName(
          fileName: displayName,
          hash: sourceHash,
        );

        final isMultiFile = filesToProcess.length > 1;

        final estimateDecision =
            await TokenEstimateGateService.instance.confirmIfNeeded(
          billing: billingService,
          trans: _settings?.trans ?? const {},
          charCount: content.length,
        );
        if (estimateDecision != TokenEstimateDecision.proceed) {
          _stopRequested = true;
          status = TranslationStatus.idle;
          notifyListeners();
          return;
        }

        await _geminiService.prepareTranslationAccess(
          chargeKey: fileChargeKey,
          fileName: displayName,
          targetLanguage: targetLanguage,
          platform: Platform.operatingSystem,
          charCount: content.length,
          estimatedTokens: estimateTokensFromCharCount(content.length),
        );

        if (isMultiFile && filesToProcess.indexOf(batchF) > 0) {
            await Future.delayed(const Duration(milliseconds: 3000));
          }
          final jobName = await _geminiService.startBatchTranslation(
          chunks: requests,
          targetLanguage: targetLanguage,
          fcmToken: fcmToken,
          sourceHash: sourceHash,
          sourceContent: content,
          originalNameForGlobalCache: originalNameForGlobalCache,
          fileNameForHistory: displayName,
          totalLines: blocks.length,
          canWriteUserHistory: true,
          completedPlatform: Platform.operatingSystem,
          isMultiFileBatch: isMultiFile,
        );

        activeJobs.add({
          'file': file,
          'jobName': jobName,
          'sourceHash': sourceHash,
          'sourceContent': content,
          'originalNameForGlobalCache': originalNameForGlobalCache,
          'displayName': displayName,
          'totalLines': blocks.length,
        });

        final sentDesc = (_settings?.trans['batch_file_sent'] ??
                '{filename} sunucuya gönderildi. Job: {job}')
            .replaceAll('{filename}', displayName)
            .replaceAll('{job}', jobName);
        _onLog?.call(_settings?.trans['batch_process_prefix'] ?? 'Batch İşlemi',
            sentDesc);
        notifyListeners();
      }

      while (activeJobs.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 15));
        if (status != TranslationStatus.running) {
          _onLog?.call(
              _settings?.trans['batch_process_prefix'] ?? 'Batch İşlemi',
              _settings?.trans['batch_process_canceled'] ??
                  'İşlem iptal edildi.');
          notifyListeners();
          return;
        }

        final ongoingDesc = (_settings?.trans['batch_process_ongoing'] ??
                'Devam ediyor (15sn aralıklarla kontrol ediliyor, kalan iş: {count})...')
            .replaceAll('{count}', activeJobs.length.toString());
        _onLog?.call(_settings?.trans['batch_process_prefix'] ?? 'Batch İşlemi',
            ongoingDesc);
        notifyListeners();

        List<Map<String, dynamic>> completedJobs = [];

        for (final job in activeJobs) {
          try {
            final result = await _geminiService.checkBatchTranslationStatus(
              jobName: job['jobName'],
              sourceHash: job['sourceHash'],
              sourceContent: job['sourceContent'],
              targetLanguage: targetLanguage,
              originalNameForGlobalCache: job['originalNameForGlobalCache'],
              fileNameForHistory: job['displayName'],
              totalLines: job['totalLines'],
              canWriteUserHistory: true,
              completedPlatform: Platform.operatingSystem,
            );

            final state = result['status'];
            if (state == 'SUCCEEDED') {
              final String sourceContent = job['sourceContent'] as String;
              final jobSourceBlocks = SubtitleParser.parseSrt(sourceContent);

              final List<dynamic> translationResults = result['results'];
              List<SubtitleBlock> alignedBlocks = [];
              int chunkSize = 200;

              for (int i = 0; i < translationResults.length; i++) {
                final startIdx = i * chunkSize;
                final endIdx = (startIdx + chunkSize < jobSourceBlocks.length)
                    ? startIdx + chunkSize
                    : jobSourceBlocks.length;
                if (startIdx >= jobSourceBlocks.length) break;

                final srcChunk = jobSourceBlocks.sublist(startIdx, endIdx);
                final transStr = "${translationResults[i]}\n\n";
                final transChunk = SubtitleParser.parseSrt(transStr);

                String normTc(String tc) {
                  final parts = tc.split('-->');
                  if (parts.isEmpty) return '';
                  return parts[0].replaceAll(RegExp(r'[^0-9]'), '');
                }

                int searchStartIdx = 0;

                for (int srcIdx = 0; srcIdx < srcChunk.length; srcIdx++) {
                  final src = srcChunk[srcIdx];
                  final srcStart = normTc(src.timecode);

                  SubtitleBlock? matchedDst;

                  int bestMatch = -1;
                  for (int look = searchStartIdx; look < searchStartIdx + 8 && look < transChunk.length; look++) {
                    if (normTc(transChunk[look].timecode) == srcStart) {
                      bestMatch = look;
                      break;
                    }
                  }

                  if (bestMatch != -1) {
                    matchedDst = transChunk[bestMatch];
                    searchStartIdx = bestMatch + 1;
                  } else if (srcChunk.length == transChunk.length && searchStartIdx < transChunk.length) {
                    // Fallback to strict index mapping ONLY if lengths match perfectly 
                    // and we couldn't find a timecode match (AI might have mangled timecode formatting).
                    matchedDst = transChunk[srcIdx];
                    searchStartIdx = srcIdx + 1;
                  }

                  if (matchedDst != null) {
                    final dst = SubtitleBlock(
                      index: src.index,
                      timecode: src.timecode,
                      text: matchedDst.text,
                    );

                    // Quotes logic
                    final srcTrim = src.text.trim();
                    final dstTrim = dst.text.trim();
                    final srcHasOuterQuotes =
                        (srcTrim.startsWith('"') && srcTrim.endsWith('"')) ||
                            (srcTrim.startsWith('“') && srcTrim.endsWith('”')) ||
                            (srcTrim.startsWith('«') && srcTrim.endsWith('»'));
                    final dstHasOuterQuotes =
                        (dstTrim.startsWith('"') && dstTrim.endsWith('"')) ||
                            (dstTrim.startsWith('“') && dstTrim.endsWith('”')) ||
                            (dstTrim.startsWith('«') && dstTrim.endsWith('»'));

                    if (!srcHasOuterQuotes && dstHasOuterQuotes) {
                      var cleaned = dstTrim;
                      cleaned = cleaned.replaceFirst(RegExp(r'^("|“|«)\s*'), '');
                      cleaned =
                          cleaned.replaceFirst(RegExp(r'\s*("|”|»)\s*$'), '');
                      dst.text = cleaned.trim();
                    }

                    // Line count logic
                    final srcLineCount = src.text
                        .split('\n')
                        .where((l) => l.trim().isNotEmpty)
                        .length;
                    if (srcLineCount <= 1) {
                      dst.text =
                          dst.text.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
                    } else {
                      final dstLines = dst.text
                          .split('\n')
                          .where((l) => l.trim().isNotEmpty)
                          .toList();
                      if (dstLines.length != srcLineCount) {
                        final flat = dst.text
                            .replaceAll('\n', ' ')
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim();
                        if (flat.isNotEmpty) {
                          final words = flat.split(' ');
                          final targetLines = <String>[];
                          final totalChars = flat.length;
                          final approxPerLine =
                              (totalChars / srcLineCount).ceil();

                          var current = StringBuffer();
                          for (final w in words) {
                            if (targetLines.length < srcLineCount - 1 &&
                                current.isNotEmpty &&
                                (current.length + 1 + w.length) > approxPerLine) {
                              targetLines.add(current.toString().trim());
                              current = StringBuffer();
                            }
                            if (current.isNotEmpty) current.write(' ');
                            current.write(w);
                          }
                          if (current.isNotEmpty) {
                            targetLines.add(current.toString().trim());
                          }
                          dst.text = targetLines.join('\n');
                        }
                      }
                    }
                    alignedBlocks.add(dst);
                  } else {
                    // AI dropped this block's translation, fallback to source text to prevent desync
                    alignedBlocks.add(SubtitleBlock(
                        index: src.index,
                        timecode: src.timecode,
                        text: src.text));
                  }
                }
              }
              final resBlocks = alignedBlocks;
              final String fullTransSrt =
                  SubtitleBuilder.buildSrt(alignedBlocks);

              final jobNorm =
                  job['file'].path.replaceAll('\\', '/').toLowerCase();
              final selNorm =
                  _selectedFile?.path.replaceAll('\\', '/').toLowerCase();
              if (jobNorm == selNorm) {
                translatedBlocks = resBlocks;
                generatedFilePath = SubtitleParser.generateOutputFilePath(
                    job['file'].path, targetLanguage);
                await File(generatedFilePath!).writeAsString(fullTransSrt);
              }

              _syncProjectToSettings(
                file: job['file'],
                targetLanguage: targetLanguage,
                isPartial: false,
                isCompleted: true,
                sourceHash: job['sourceHash'],
                customSourceBlocks: jobSourceBlocks,
                customTranslatedBlocks: resBlocks,
                customFileName: job['displayName'],
              );

              final finalName = job['displayName'] ??
                  StringUtils.hideHashAndMarkersInFileName(
                      job['file'].path.split(Platform.pathSeparator).last);
              batchResults[finalName] = fullTransSrt;

              completedJobs.add(job);
              _batchSuccessCount++;
              final succDesc = (_settings?.trans['batch_file_success'] ??
                      '{filename} çevirisi başarıyla tamamlandı.')
                  .replaceAll('{filename}', job['displayName'] ?? '');
              _onLog?.call(
                  _settings?.trans['batch_process_prefix'] ?? 'Batch İşlemi',
                  succDesc);

              // Her dosya tamamlandığında ayrı ayrı bildirim
              // Cloud Batch'te push bildirimi (FCM) geldiği için,
              // çift bildirim olmaması adına bu yerel bildirimi kapatıyoruz.
              // onProgress?.call(1, 1,
              //     isComplete: true, fileName: job['displayName']);

              onFileCompleted?.call(job['file']);
              // _checkAndShowRateUs();
            } else if (state == 'FAILED') {
              final errDesc = (_settings?.trans['batch_file_error'] ??
                      '{filename} sunucuda hata ile karşılaştı.')
                  .replaceAll('{filename}', job['displayName'] ?? '');
              _onLog?.call(
                  _settings?.trans['batch_process_prefix'] ?? 'Batch İşlemi',
                  errDesc);
              _batchErrors.add(BatchError(
                  fileName: job['displayName'] ?? 'Unknown',
                  message: 'Failed on server'));
              completedJobs.add(job);
            }
          } catch (e) {
            if (e.toString().contains('resource-exhausted') ||
                e.toString().contains('RESOURCE_EXHAUSTED')) {
              final limitDesc =
                  (_settings?.trans['batch_file_rate_limit'] ?? '')
                      .replaceAll('{filename}', job['displayName']);
              _onLog?.call(
                  _settings?.trans['error_prefix'] ?? 'Hata', limitDesc);
              continue; // bu job bir sonraki döngüde kontrol edilecek
            }
            // Beklenmeyen hata olursa şimdilik atla, belki db sorunu anlıktır. Çok sık olursa job'ı da the silmek gerekebilir.
          }
        }

        for (final done in completedJobs) {
          activeJobs.remove(done);
          activeBatchFilePaths.remove(done['file'].path);
        }
        progress = 1.0; // Toplu çeviride çubuğun grileşmemesi için 1.0'da tutuyoruz
        notifyListeners();
      }

      if (activeBatchFilePaths.isEmpty) {
        _finishSuccess(
          true,
        );
        _batchCompleteController.add(Map.from(batchResults));
        _onLog?.call(
            _settings?.trans['batch_process_prefix'] ?? 'Batch İşlemi',
            _settings?.trans['batch_all_completed'] ??
                'Tüm dosyaların çevirisi tamamlandı.');
      }
      notifyListeners();
    } catch (e) {
      status = TranslationStatus.error;
      _onLog?.call(
          _settings?.trans['batch_error_prefix'] ?? 'Batch Çeviri Hatası',
          e.toString());
      onError?.call(
          _settings?.trans['batch_error_prefix'] ?? 'Batch Çeviri Hatası',
          e.toString());
      notifyListeners();
    } finally {
      // Fonksiyona giren tüm dosyaları temizle. Tamamlananlar zaten silinmişti, hata alanlar veya yarım kalanlar burada silinir.
      for (final f in filesToProcess) {
        activeBatchFilePaths.remove(f.path);
      }

      // Eğer başka hiçbir batch işlemi aktif değilse temizliği yap.
      if (activeBatchFilePaths.isEmpty) {
        _stopTranslationTimer();
        Future.microtask(() {
          _isCloudBatchMode = false;
          notifyListeners();
        });
      }
      notifyListeners();
    }
  }

  void _startBatchTimer() {
    _stopwatch.reset();
    _stopwatch.start();
    onWakelock?.call(true);

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_stopwatch.isRunning) return;
      final elapsed = _stopwatch.elapsed;
      elapsedTime =
          '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      notifyListeners();
    });
  }

  String _buildSessionChargeKey(String sourceHash, String targetLanguage) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final canonicalTarget = normalizeAiPanelLanguageCode(targetLanguage);
    final normalizedTarget = canonicalTarget
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safeTarget = normalizedTarget.isEmpty ? 'unknown' : normalizedTarget;
    return 'run_${now}_${sourceHash}_$safeTarget';
  }

  Future<void> stopTranslation({
    required bool clearSdh,
    required String targetLanguage,
    bool isBulkProcessing = false,
  }) async {
    if (status == TranslationStatus.idle) return;

    _stopRequested = true;
    if (!isBulkProcessing) {
      _isBatchMode = false;
      _isCloudBatchMode = false;
    }

    // Prefer resume state's permanent path if available so we always persist to
    // stable app storage.
    final filePath =
        _resumeState?.filePath ?? _currentJob?.file.path ?? _selectedFile?.path;
    final file = (filePath == null || filePath.isEmpty) ? null : File(filePath);

    // Kullanıcı stop'a bastığında gördüğü ilerlemeyi koru. latestRealBlocks,
    // animasyonun henüz göstermediği bir sonraki chunk'ı içerebildiği için
    // önce UI'da görünen translatedBlocks'u esas al.
    final snapshot = translatedBlocks.isNotEmpty
      ? List<SubtitleBlock>.from(translatedBlocks)
      : (_engine.latestRealBlocks.isNotEmpty
        ? List<SubtitleBlock>.from(_engine.latestRealBlocks)
        : List<SubtitleBlock>.from(
          _resumeState?.translatedBlocks ?? const <SubtitleBlock>[]));

    // Stop any further work first.
    status = TranslationStatus.idle;
    _stopwatch.stop();
    _stopwatch.reset();
    _progressTimer?.cancel();
    _engine.cancel();
    _engine.onProgress = null; // Callback'leri devre dışı bırak
    onWakelock?.call(false);
    _jobQueue.clear(); // Kuyruğu temizle ki otomatik devam etmesin

    // Bildirim çubuğunu temizle
    await _settings?.cancelNotification();

    // İlerleme yüzdesini ve zamanları sıfırla
    progress = 0.0;
    elapsedTime = "00:00";
    remainingTime = "00:00";

    notifyListeners();

    var removeFromBatchList = false;

    // Preserve resumability if we have partial results.
    if (file != null && snapshot.isNotEmpty) {
      try {
        await prepareResumeFromBlocks(
          file: file,
          alreadyTranslatedBlocks: snapshot,
          clearSdh: clearSdh,
          targetLanguage: targetLanguage,
          updateUIBlocks: false, // Durdururken UI'yı güncellemiyoruz
        );

        // Ensure we save the *permanent* path (inside app storage) for resumability.
        final permanentPath =
            _resumeState?.filePath ?? _selectedFile?.path ?? file.path;
        final permanentFile = File(permanentPath);

        // History'ye kaydet - Hash'i resume state ile tutarlı olacak şekilde hesapla
        // prepareResumeFromBlocks içinde zaten hesaplanmış hash'i kullanalım
        final hash = _resumeState?.hash ?? '';
        final user = _auth.currentUser;
        final allowUserHistory = user != null && !user.isAnonymous;

        // Ensure we persist the blocks we actually have.
        if (translatedBlocks.isEmpty && snapshot.isNotEmpty) {
          translatedBlocks = List<SubtitleBlock>.from(snapshot);
        }

        // Await local save so the entry reliably shows up in History.
        await _syncProjectToSettingsAwait(
          file: permanentFile,
          sourceHash: hash,
          targetLanguage: targetLanguage,
          isPartial: true,
          isCompleted: false,
          isActive: false,
        );

        if (allowUserHistory) {
          try {
            final resume = _resumeState;
            final resumeJson = resume?.toJson();
            final translatedCount = snapshot.length;
            final totalCount = sourceBlocks.isNotEmpty
                ? sourceBlocks.length
                : (resume?.sourceContent.isNotEmpty == true
                    ? SubtitleParser.parseSrt(resume!.sourceContent).length
                    : null);

            final nameForHistory = _bestFriendlyDisplayNameForHash(
              hash: hash,
              targetLanguage: targetLanguage,
              fallbackName: currentFileName,
              fallbackPath: permanentPath,
            );
            await _repository.addToUserHistory(
              sourceHash: hash,
              fileName: nameForHistory,
              targetLanguage: targetLanguage,
              isPartial: true,
              encodingDetected: _engine.lastDetectedEncoding,
              resumeState: resumeJson,
              translatedLines: translatedCount,
              totalLines: totalCount,
              isActive: false,
              clearSdh: clearSdh,
            );
          } catch (e) {
            debugPrint('Failed to save partial translation to history: $e');
            final resume = _resumeState;
            final resumeJson = resume?.toJson();
            final nameForHistory = _bestFriendlyDisplayNameForHash(
              hash: hash,
              targetLanguage: targetLanguage,
              fallbackName: currentFileName,
              fallbackPath: permanentPath,
            );
            unawaited(
              _cloudRetryQueue.enqueueAddToUserHistory(
                sourceHash: hash,
                fileName: nameForHistory,
                targetLanguage: targetLanguage,
                isPartial: true,
                encodingDetected: _engine.lastDetectedEncoding,
                resumeState: resumeJson,
                translatedLines: snapshot.length,
                totalLines:
                    sourceBlocks.isNotEmpty ? sourceBlocks.length : null,
                isActive: false,
                clearSdh: clearSdh,
              ),
            );
          }
        }

        // Tek dosya çevirisinde: UI'yı tamamen temizle (yeni açılmış gibi)
        // Çoklu dosya çevirisinde: Sadece geçmişe kaydet, UI'yı temizleme
        if (!isBulkProcessing) {
          _selectedFile = null;
          currentFileName = null;
          sourceBlocks = [];
          translatedBlocks = [];
          generatedFilePath = null;
          isCached = false;

          // Editör ekranındaki listeleri de temizle
          _settings?.clearTranslationFile();

          _onLog?.call('log_translation_stopped_saved_history');
        } else {
          // Çoklu işlemde: dosya sadece kredi gerçekten kesildiyse listeden
          // çıkarılmalı. İlk chunk gelmiş olsa bile kredi kesilmediyse (örn.
          // ödeme hatası/askıda), listede kalsın.
          if (_stopShouldRemoveFromBatchList) {
            // Hem kalıcı storage path'ini hem de orijinal path'i ekle
            if (file.path.isNotEmpty) {
              _batchCompletedPaths.add(file.path);
            }
            // _selectedFile varsa onun path'ini de ekle
            if (_selectedFile != null && _selectedFile!.path.isNotEmpty) {
              _batchCompletedPaths.add(_selectedFile!.path);
            }
            removeFromBatchList = true;
            _onLog?.call('log_translation_saved_removed_list');
          } else {
            removeFromBatchList = false;
            _onLog?.call('log_translation_stopped_kept_in_list');
          }
        }

        notifyListeners();
        return;
      } catch (e, stackTrace) {
        _onLog?.call(
          'log_stop_resume_failed',
          jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
        );
      }
    }

    // İlk chunk gelmeden durdurulan çoklu çeviri listede kalmalı.
    // Bu nedenle completedPaths sadece partial ilerleme başarıyla
    // geçmişe kaydedildiğinde işaretlenir.
    if (isBulkProcessing && !removeFromBatchList) {
      _onLog?.call('log_translation_stopped_kept_in_list');
    }

    // If we couldn't preserve state, fall back to a clean reset.
    _resumeState = null;
    await _saveResumeStateToCache();
    reset();
    _onLog?.call('log_translation_stopped');
    notifyListeners();
  }

  /// Fully abandons the current translation progress and clears any resumable state.
  ///
  /// This is intended for a user-facing "Sıfırla/İptal" action when they want to
  /// start over from scratch (as opposed to stopping and resuming later).
  void abandonTranslation({bool keepSelectedFile = true}) {
    _stopRequested = true;
    _isBatchMode = false;
    _isCloudBatchMode = false;
    // Stop any ongoing work defensively.
    _progressTimer?.cancel();
    _engine.cancel();
    _engine.onProgress = null; // Callback'leri devre dışı bırak
    onWakelock?.call(false);

    _stopwatch.stop();
    _stopwatch.reset();

    _resumeState = null;
    unawaited(_saveResumeStateToCache());
    translatedBlocks = [];
    generatedFilePath = null;

    // Bildirim çubuğunu temizle
    unawaited(_settings?.cancelNotification());

    // Reset UI progress state.
    reset();

    if (!keepSelectedFile) {
      _selectedFile = null;
      currentFileName = null;
      sourceBlocks = [];
      isCached = false;
    }

    _onLog?.call('log_process_reset_ready');
    notifyListeners();
  }

  void reset() {
    progress = 0.0;
    elapsedTime = "00:00";
    remainingTime = "00:00";
    status = TranslationStatus.idle;
    isTranslationComplete = false;
  }

  /// Clears single-translation UI state and returns the controller to its
  /// initial "fresh launch" state.
  ///
  /// This is used by the AI panel after a successful translation, so the UI
  /// doesn't remain stuck at 100%.
  void clearAfterCompletion() {
    _stopRequested = false;
    _selectedFile = null;
    currentFileName = null;
    generatedFilePath = null;
    isCached = false;
    sourceBlocks = [];
    translatedBlocks = [];
    _settings?.clearTranslationFile();
    reset();
    notifyListeners();
  }

  Future<void> handlePickedFile(File file, {String? displayName}) async {
    try {
      if (!SubtitleParser.isSubtitleFileName(file.path)) {
        _onLog?.call('log_invalid_file_format');
        return;
      }

      // Yeni dosya seçildiğinde stop flag'ini reset et
      _stopRequested = false;

      final hash = await _fileService.calculateMd5(file);

      // Eğer resume state varsa, seçilen dosyanın *kanonik* (encoding çözülmüş ve
      // gerekiyorsa SDH temizlenmiş) içeriği ile resume hash'ini karşılaştır.
      // Not: resume hash'i raw-bytes md5 değildir; normal çeviri akışında içerikten
      // hesaplanır. Bu yüzden burada byte-hash ile karşılaştırmak resume'ı yanlışlıkla
      // silip "%0'dan başlama" hatasına yol açıyordu.
      if (_resumeState != null) {
        try {
          final resume = _resumeState!;
          final readResult =
              await _subtitleRepository.readFileWithEncoding(file.path);
          var content = readResult.content;
          if (resume.clearSdh) {
            content = SubtitleParser.clearSdh(content);
          }
          final canonicalHash = _stableSubtitleHash(content);
          if (resume.hash != canonicalHash) {
            final stableHash = await _doubleCheckCanonicalHash(
              file: file,
              clearSdh: resume.clearSdh,
              expectedHash: resume.hash,
            );
            if (stableHash != resume.hash) {
              _onLog?.call('log_resume_file_changed');
              _resumeState = null;
              unawaited(_saveResumeStateToCache());
            } else {
              _logResumeDebug(
                  'pickFile hash double-check matched; keeping resume');
            }
          }
        } catch (_) {
          // Hash karşılaştırması başarısız olursa resume state'i agresifçe silmeyelim;
          // asıl doğrulama çeviri başlarken yapılacak.
        }
      }

      // Dosyayı kalıcı depolamaya kopyala
      final permanentPath = await _copyFileToAppStorage(file, hash);
      final permFile = File(permanentPath);
      _selectedFile = permFile;

      currentFileName = _resolveDisplayFileName(
        preferred: displayName,
        fallbackPath: file.path,
      );
      generatedFilePath = null;

      _onLog?.call('log_subtitle_selected', currentFileName);

      // Non-English kaynaklar için Firebase cache/history kullanmıyoruz.
      final allowFirebase = await _shouldUseFirebaseForFile(file);
      if (allowFirebase) {
        final cachedData = await _repository.checkGlobalCache(
          sourceHash: hash,
          targetLanguage: 'Turkish',
        );
        isCached = cachedData != null;
      } else {
        isCached = false;
      }
    } catch (e, stackTrace) {
      _onLog?.call(
        'log_error_with_stack',
        jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
      );
      _selectedFile = null;
    }
    notifyListeners();
  }

  Future<void> pickFile() async {
    try {
      final file = await _fileService.pickSrtFile();
      if (file != null) {
        await handlePickedFile(file);
      }
    } catch (e) {
      _onLog?.call('log_error_generic', jsonEncode({'error': e.toString()}));
    }
  }

  void _finishSuccess(bool sound) {
    status = TranslationStatus.completed;
    isTranslationComplete = true;
    progress = 1.0;
    remainingTime = "-00:00";
    // Only announce completion once the controller is truly completed
    // (including post-processing like local persistence).
    onProgress?.call(1, 1, isComplete: true, fileName: currentFileName);
    if (sound) SystemSound.play(SystemSoundType.alert);
    notifyListeners();
  }

  void _syncProjectToSettings({
    required File file,
    required String targetLanguage,
    required bool isPartial,
    required bool isCompleted,
    String sourceHash = '',
    bool? isActive,
    List<SubtitleBlock>? customSourceBlocks,
    List<SubtitleBlock>? customTranslatedBlocks,
    String? customFileName,
  }) {
    final settings = _settings;
    if (settings == null) return;

    // Stable ID matching Firestore doc ID so cross-device delete works.
    // Falls back to file.path for projects without a hash (legacy).
    final stableId = sourceHash.isNotEmpty
        ? '${sourceHash}_${targetLanguage.toLowerCase()}'
        : file.path;

    final existingIndex = settings.projects
        .indexWhere((p) => p.id == stableId || p.id == file.path);
    final existing =
        existingIndex != -1 ? settings.projects[existingIndex] : null;

    final fileName = customFileName ??
        currentFileName ??
        existing?.fileName ??
        file.path.split(Platform.pathSeparator).last;
    final srcBlocks =
        customSourceBlocks != null && customSourceBlocks.isNotEmpty
            ? customSourceBlocks
            : (sourceBlocks.isNotEmpty
                ? sourceBlocks
                : (existing?.sourceBlocks ?? <SubtitleBlock>[]));
    final processed =
        List<SubtitleBlock>.from(customTranslatedBlocks ?? translatedBlocks);

    final project = TranslationProject(
      id: stableId,
      fileName: fileName,
      filePath: file.path,
      translationSourceCachePath:
          existing?.translationSourceCachePath ?? file.path,
      targetLanguage: targetLanguage,
      isCompleted: isCompleted,
      isPartial: isPartial,
      isActive: isActive ?? existing?.isActive ?? false,
      totalLines: srcBlocks.length,
      translatedLines: processed.length,
      lastUpdated: DateTime.now().toString(),
      sourceBlocks: List<SubtitleBlock>.from(srcBlocks),
      processedBlocks: processed,
      sourceHash: sourceHash.isNotEmpty ? sourceHash : null,
      globalRef: existing?.globalRef,
    );

    settings.addOrUpdateExternalProject(project);
  }

  Future<void> _syncProjectToSettingsAwait({
    List<SubtitleBlock>? customSourceBlocks,
    List<SubtitleBlock>? customTranslatedBlocks,
    String? customFileName,
    required File file,
    required String targetLanguage,
    required bool isPartial,
    required bool isCompleted,
    String sourceHash = '',
    bool? isActive,
  }) async {
    final settings = _settings;
    if (settings == null) return;

    final stableId = sourceHash.isNotEmpty
        ? '${sourceHash}_${targetLanguage.toLowerCase()}'
        : file.path;

    final existingIndex = settings.projects
        .indexWhere((p) => p.id == stableId || p.id == file.path);
    final existing =
        existingIndex != -1 ? settings.projects[existingIndex] : null;

    final fileName = customFileName ??
        currentFileName ??
        existing?.fileName ??
        file.path.split(Platform.pathSeparator).last;
    final srcBlocks =
        customSourceBlocks != null && customSourceBlocks.isNotEmpty
            ? customSourceBlocks
            : (sourceBlocks.isNotEmpty
                ? sourceBlocks
                : (existing?.sourceBlocks ?? <SubtitleBlock>[]));
    final processed =
        List<SubtitleBlock>.from(customTranslatedBlocks ?? translatedBlocks);

    final project = TranslationProject(
      id: stableId,
      fileName: fileName,
      filePath: file.path,
      translationSourceCachePath:
          existing?.translationSourceCachePath ?? file.path,
      targetLanguage: targetLanguage,
      isCompleted: isCompleted,
      isPartial: isPartial,
      isActive: isActive ?? existing?.isActive ?? false,
      totalLines: srcBlocks.length,
      translatedLines: processed.length,
      lastUpdated: DateTime.now().toString(),
      sourceBlocks: List<SubtitleBlock>.from(srcBlocks),
      processedBlocks: processed,
      sourceHash: sourceHash.isNotEmpty ? sourceHash : null,
      globalRef: existing?.globalRef,
    );

    await settings.addOrUpdateExternalProject(project);
  }

  void clearBatchResults() {
    batchResults.clear();
    notifyListeners();
  }

  /// Prepares an in-memory resume state based on already translated blocks.
  /// This enables "Devam Et" from History without restarting from 0.
  Future<void> prepareResumeFromBlocks({
    required File file,
    required List<SubtitleBlock> alreadyTranslatedBlocks,
    required bool clearSdh,
    required String targetLanguage,
    int? expectedSourceBlockCount,
    bool updateUIBlocks = true,
  }) async {
    if (!SubtitleParser.isSubtitleFileName(file.path)) return;

    // Ensure controller file state is up to date.
    await handlePickedFile(file);

    final readResult =
        await _subtitleRepository.readFileWithEncoding(file.path);
    final rawContent = readResult.content;
    final cleanedContent = SubtitleParser.clearSdh(rawContent);

    final rawBlocksCount = SubtitleParser.parseSrt(rawContent).length;
    final cleanedBlocksCount = SubtitleParser.parseSrt(cleanedContent).length;

    bool effectiveClearSdh = clearSdh;
    if (expectedSourceBlockCount != null && expectedSourceBlockCount > 0) {
      final rawDiff = (rawBlocksCount - expectedSourceBlockCount).abs();
      final cleanedDiff = (cleanedBlocksCount - expectedSourceBlockCount).abs();
      effectiveClearSdh = cleanedDiff < rawDiff;
    }

    final sourceContent = effectiveClearSdh ? cleanedContent : rawContent;

    // Hash'i temizlenmiş içerikten hesapla (resume consistency için kritik)
    final hash = _stableSubtitleHash(sourceContent);

    // Populate source blocks for UI using the correctly decoded content.
    sourceBlocks = SubtitleParser.parseSrt(sourceContent);

    final chunks = SubtitleParser.buildSrtChunksAdaptiveDesktop(sourceContent);

    // Determine next chunk index by matching cumulative *source* block counts.
    final alreadyCount = alreadyTranslatedBlocks.length;
    var cumulativeBlocks = 0;
    var nextChunkIndex = 0;
    for (var i = 0; i < chunks.length; i++) {
      final chunkBlocks = SubtitleParser.parseSrt(chunks[i]).length;
      if (cumulativeBlocks + chunkBlocks <= alreadyCount) {
        cumulativeBlocks += chunkBlocks;
        nextChunkIndex = i + 1;
      } else {
        break;
      }
    }

    _logResumeDebug(
      'prepareResume file=${file.path} hash=$hash encoding=${readResult.encoding} '
      'alreadyBlocks=$alreadyCount chunks=${chunks.length} nextChunkIndex=$nextChunkIndex cumulativeBlocks=$cumulativeBlocks clearSdh=$effectiveClearSdh rawBlocks=$rawBlocksCount cleanedBlocks=$cleanedBlocksCount expectedBlocks=${expectedSourceBlockCount ?? -1}',
    );

    // processedLines hesaplaması: İşlenmiş chunk'ların kaynak satır sayısını kullan
    // Bu, normal çeviri akışındaki hesaplama ile tutarlı olmalı
    var processedLines = 0;
    for (var i = 0; i < nextChunkIndex && i < chunks.length; i++) {
      processedLines += const LineSplitter().convert(chunks[i]).length;
    }

    final translatedText = SubtitleBuilder.buildSrt(alreadyTranslatedBlocks);
    final totalLines = sourceContent.split(RegExp(r'\r?\n')).length;
    final totalBlocks = sourceBlocks.length;

    _resumeState = TranslationResumeState(
      hash: hash,
      filePath: _selectedFile?.path ?? file.path,
      targetLanguage: targetLanguage,
      clearSdh: effectiveClearSdh,
      sourceContent: sourceContent,
      sourceEncoding: readResult.encoding,
      chunks: chunks,
      nextChunkIndex: nextChunkIndex,
      translatedText: translatedText,
      translatedBlocks: List<SubtitleBlock>.from(alreadyTranslatedBlocks),
      processedLines: processedLines,
      totalLines: totalLines,
      totalBlocks: totalBlocks,
      chargeKey: _activeTranslationChargeKey,
    );

    // Update UI immediately with what we already have.
    if (updateUIBlocks) {
      translatedBlocks = List<SubtitleBlock>.from(alreadyTranslatedBlocks);
    }

    // Detaylı log mesajı - kaç block çevrildi, kaç kaldı
    final remainingBlocks =
        sourceBlocks.length - alreadyTranslatedBlocks.length;
    _onLog?.call(
      'log_resume_progress',
      jsonEncode({
        'done': alreadyTranslatedBlocks.length,
        'total': sourceBlocks.length,
        'remaining': remainingBlocks,
        'chunkIndex': nextChunkIndex,
        'chunkTotal': chunks.length,
      }),
    );

    // Cache resume state kalıcı olarak sakla
    await _saveResumeStateToCache();

    if (updateUIBlocks) {
      notifyListeners();
    }
  }

  /// Restores a resumable translation state that was synced via Firestore.
  ///
  /// This enables "Devam Et" on a different platform even when the original
  /// subtitle file does not exist locally.
  Future<({bool ok, bool clearSdh})> prepareResumeFromCloudState({
    required TranslationProject project,
  }) async {
    try {
      final raw = project.resumeStateJson;
      if (raw == null || raw.isEmpty) return (ok: false, clearSdh: false);

      final historyDocId = (project.sourceHash != null && project.sourceHash!.isNotEmpty)
          ? '${project.sourceHash}_${project.targetLanguage.toLowerCase()}'
          : project.id;
      final payload = await _repository.getResumePayload(historyDocId: historyDocId);
      final payloadSourceContent = (payload?['source'] ?? '').trim();
      final payloadPartialContent = (payload?['partial'] ?? '').trim();
      final payloadClearSdh = payload?['clearSdh'] == 'true';

      // Support both full engine JSON and compact cloud JSON.
      final sourceContent = payloadSourceContent.isNotEmpty
          ? payloadSourceContent
          : ((raw['sourceContent'] as String?) ?? '');
      final clearSdh = payloadClearSdh || (raw['clearSdh'] as bool? ?? false);
      final targetLanguage =
          (raw['targetLanguage'] as String?) ?? project.targetLanguage;
      final hash = (raw['hash'] as String?) ?? project.sourceHash ?? '';
      final sourceEncoding = raw['sourceEncoding'] as String?;
      final chargeKey = (raw['chargeKey'] as String?)?.trim().isEmpty == true
          ? null
          : raw['chargeKey'] as String?;

      if (sourceContent.trim().isEmpty) {
        return (ok: false, clearSdh: clearSdh);
      }

      List<SubtitleBlock> translatedBlocksList;
      if (payloadPartialContent.isNotEmpty) {
        translatedBlocksList = SubtitleParser.parseSrt(payloadPartialContent);
      } else {
        final translatedBlocksRaw = raw['translatedBlocks'];
        translatedBlocksList = translatedBlocksRaw is List
            ? translatedBlocksRaw.map((b) => SubtitleBlock.fromJson(b)).toList()
            : <SubtitleBlock>[];
      }

      final chunksRaw = raw['chunks'];
      final chunks = chunksRaw is List
          ? chunksRaw.map((e) => e.toString()).toList()
          : SubtitleParser.buildSrtChunksAdaptiveDesktop(sourceContent);

      int nextChunkIndex = 0;
      final nciRaw = raw['nextChunkIndex'];
      final alreadyCount = translatedBlocksList.length;
      var cumulativeBlocks = 0;
      for (var i = 0; i < chunks.length; i++) {
        final chunkBlocks = SubtitleParser.parseSrt(chunks[i]).length;
        if (cumulativeBlocks + chunkBlocks <= alreadyCount) {
          cumulativeBlocks += chunkBlocks;
          nextChunkIndex = i + 1;
        } else {
          break;
        }
      }
      if (payloadPartialContent.isEmpty && nciRaw is num) {
        nextChunkIndex = nciRaw.toInt();
      }
      if (nextChunkIndex < 0) nextChunkIndex = 0;
      if (nextChunkIndex > chunks.length) nextChunkIndex = chunks.length;

      final translatedTextRaw = raw['translatedText'];
      final translatedText =
          (translatedTextRaw is String && translatedTextRaw.isNotEmpty)
              ? translatedTextRaw
              : SubtitleBuilder.buildSrt(translatedBlocksList);

      int processedLines = 0;
      final plRaw = raw['processedLines'];
      if (plRaw is num) {
        processedLines = plRaw.toInt();
      } else {
        for (var i = 0; i < nextChunkIndex && i < chunks.length; i++) {
          processedLines += const LineSplitter().convert(chunks[i]).length;
        }
      }

      final totalLinesRaw = raw['totalLines'];
      final totalLines = totalLinesRaw is num
          ? totalLinesRaw.toInt()
          : sourceContent.split(RegExp(r'\r?\n')).length;

      final totalBlocksRaw = raw['totalBlocks'];
      final totalBlocks = totalBlocksRaw is num
          ? totalBlocksRaw.toInt()
          : SubtitleParser.parseSrt(sourceContent).length;

      final appDir = await getApplicationDocumentsDirectory();
      final subtitlesDir = Directory(path.join(appDir.path, 'subtitles'));
      if (!await subtitlesDir.exists()) {
        await subtitlesDir.create(recursive: true);
      }

      final originalName = project.fileName.trim().isEmpty
          ? 'subtitle.srt'
          : project.fileName.trim();
      final ext = path.extension(originalName).isNotEmpty
          ? path.extension(originalName)
          : '.srt';
      final base = path.basenameWithoutExtension(originalName);

      final effectiveHash = hash.trim().isNotEmpty
          ? hash.trim()
          : _stableSubtitleHash(sourceContent);

      final generatedPath = path.join(
        subtitlesDir.path,
        '${base}_cloud_$effectiveHash$ext',
      );

      final generatedFile = File(generatedPath);
      if (!await generatedFile.exists()) {
        await generatedFile.writeAsString(sourceContent, flush: true);
      }

      _selectedFile = generatedFile;
      currentFileName = originalName;
      generatedFilePath = null;
      isCached = false;

      // Ensure UI has a consistent view immediately.
      sourceBlocks = SubtitleParser.parseSrt(sourceContent);
      translatedBlocks = List<SubtitleBlock>.from(translatedBlocksList);

      // Pin resume state's filePath to our local generated file so stop/resume
      // continues to work on this device.
      _resumeState = TranslationResumeState(
        hash: hash,
        filePath: generatedFile.path,
        targetLanguage: targetLanguage,
        clearSdh: clearSdh,
        sourceContent: sourceContent,
        sourceEncoding: sourceEncoding,
        chunks: List<String>.from(chunks),
        nextChunkIndex: nextChunkIndex,
        translatedText: translatedText,
        translatedBlocks: List<SubtitleBlock>.from(translatedBlocksList),
        processedLines: processedLines,
        totalLines: totalLines,
        totalBlocks: totalBlocks,
        chargeKey: chargeKey,
      );

      await _saveResumeStateToCache();
      notifyListeners();
      return (ok: true, clearSdh: clearSdh);
    } catch (e) {
      _onLog?.call(
          'log_resume_state_load_failed', jsonEncode({'error': e.toString()}));
      return (ok: false, clearSdh: false);
    }
  }

  /// Attempts to resume using the locally cached resume_state_cache.
  ///
  /// This is a fallback for cases where the original subtitle file was deleted
  /// (or OS cleaned app storage) and the History entry doesn't have enough
  /// blocks to regenerate the file.
  Future<({bool ok, bool clearSdh})> prepareResumeFromLocalCacheForProject({
    required TranslationProject project,
  }) async {
    var resume = _resumeState;
    if (resume == null) {
      await _loadResumeStateFromCache();
      resume = _resumeState;
    }
    if (resume == null) return (ok: false, clearSdh: false);

    // Determine expected hash from project.
    String expectedHash = (project.sourceHash ?? '').trim();
    if (expectedHash.isEmpty) {
      final id = project.id;
      final parts = id.split('_');
      if (parts.length >= 2) {
        expectedHash = parts.first.trim();
      }
    }

    final matches = expectedHash.isNotEmpty &&
        resume.hash.trim().isNotEmpty &&
        resume.hash.trim() == expectedHash &&
        resume.targetLanguage.toLowerCase() ==
            project.targetLanguage.toLowerCase();
    if (!matches) {
      return (ok: false, clearSdh: resume.clearSdh);
    }

    if (resume.sourceContent.trim().isEmpty) {
      return (ok: false, clearSdh: resume.clearSdh);
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final subtitlesDir = Directory(path.join(appDir.path, 'subtitles'));
      if (!await subtitlesDir.exists()) {
        await subtitlesDir.create(recursive: true);
      }

      final originalName = project.fileName.trim().isEmpty
          ? 'subtitle.srt'
          : project.fileName.trim();
      final ext = path.extension(originalName).isNotEmpty
          ? path.extension(originalName)
          : '.srt';
      final base = path.basenameWithoutExtension(originalName);
      final effectiveHash = resume.hash.trim().isNotEmpty
          ? resume.hash.trim()
          : _stableSubtitleHash(resume.sourceContent);

      final generatedPath = path.join(
        subtitlesDir.path,
        '${base}_localcache_$effectiveHash$ext',
      );

      final generatedFile = File(generatedPath);
      if (!await generatedFile.exists()) {
        await generatedFile.writeAsString(resume.sourceContent, flush: true);
      }

      _selectedFile = generatedFile;
      currentFileName = originalName;
      generatedFilePath = null;
      isCached = false;

      sourceBlocks = SubtitleParser.parseSrt(resume.sourceContent);
      translatedBlocks = List<SubtitleBlock>.from(resume.translatedBlocks);

      // Update resume state's filePath to point to the generated file.
      _resumeState = TranslationResumeState(
        hash: resume.hash,
        filePath: generatedFile.path,
        targetLanguage: resume.targetLanguage,
        clearSdh: resume.clearSdh,
        sourceContent: resume.sourceContent,
        sourceEncoding: resume.sourceEncoding,
        chunks: List<String>.from(resume.chunks),
        nextChunkIndex: resume.nextChunkIndex,
        translatedText: resume.translatedText,
        translatedBlocks: List<SubtitleBlock>.from(resume.translatedBlocks),
        processedLines: resume.processedLines,
        totalLines: resume.totalLines,
        totalBlocks: resume.totalBlocks,
        chargeKey: resume.chargeKey,
      );
      await _saveResumeStateToCache();
      notifyListeners();
      return (ok: true, clearSdh: resume.clearSdh);
    } catch (e) {
      _onLog?.call(
          'log_resume_state_load_failed', jsonEncode({'error': e.toString()}));
      return (ok: false, clearSdh: resume.clearSdh);
    }
  }

  // Resume state'i SharedPreferences'a kaydet
  Future<void> _saveResumeStateToCache() async {
    try {
      if (_resumeState == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('resume_state_cache');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final json = _resumeState!.toJson();
      final jsonStr = jsonEncode(json);
      await prefs.setString('resume_state_cache', jsonStr);

      // Best-effort: also persist resumable progress to Firestore periodically
      // so other platforms can continue without needing the local file.
      _scheduleResumeCloudSync();
    } catch (e) {
      _onLog?.call(
          'log_resume_cache_save_failed', jsonEncode({'error': e.toString()}));
    }
  }

  void _scheduleResumeCloudSync() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final resume = _resumeState;
    if (resume == null || resume.hash.trim().isEmpty) return;

    _resumeCloudSyncTimer?.cancel();

    final now = DateTime.now();
    final last = _lastResumeCloudSyncAt;
    final minWait = (last == null)
        ? Duration.zero
        : _resumeCloudSyncMinInterval - now.difference(last);
    final effectiveDelay =
        minWait > Duration.zero ? minWait : _resumeCloudSyncDebounce;

    _resumeCloudSyncTimer = Timer(effectiveDelay, () {
      unawaited(_syncResumeStateToFirestore());
    });
  }

  Future<void> _syncResumeStateToFirestore() async {
    final user = _auth.currentUser;
    final resume = _resumeState;
    if (user == null || user.isAnonymous) return;
    if (resume == null || resume.hash.trim().isEmpty) return;

    _lastResumeCloudSyncAt = DateTime.now();

    final name = _bestFriendlyDisplayNameForHash(
      hash: resume.hash,
      targetLanguage: resume.targetLanguage,
      fallbackName: currentFileName,
      fallbackPath: resume.filePath,
    );

    final translatedLines = resume.translatedBlocks.length;
    final totalBlocks = (sourceBlocks.isNotEmpty)
        ? sourceBlocks.length
        : (resume.totalBlocks > 0
            ? resume.totalBlocks
            : SubtitleParser.parseSrt(resume.sourceContent).length);

    try {
      await _repository.addToUserHistory(
        sourceHash: resume.hash,
        fileName: name,
        targetLanguage: resume.targetLanguage,
        isPartial: true,
        encodingDetected: resume.sourceEncoding,
        resumeState: resume.toJson(),
        translatedLines: translatedLines,
        totalLines: totalBlocks,
        clearSdh: resume.clearSdh,
      );
    } catch (e) {
      unawaited(
        _cloudRetryQueue.enqueueAddToUserHistory(
          sourceHash: resume.hash,
          fileName: name,
          targetLanguage: resume.targetLanguage,
          isPartial: true,
          encodingDetected: resume.sourceEncoding,
          resumeState: resume.toJson(),
          translatedLines: translatedLines,
          totalLines: totalBlocks,
          clearSdh: resume.clearSdh,
        ),
      );
    }
  }

  // SharedPreferences'dan resume state'i yükle
  Future<void> _loadResumeStateFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('resume_state_cache');

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _resumeState = TranslationResumeState.fromJson(json);
        _onLog?.call('log_resume_state_loaded');

        // Best-effort: also persist resumable progress to Firestore so another
        // platform can continue even without the local file.
        // This is intentionally non-blocking and safe to fail.
        final user = _auth.currentUser;
        final resume = _resumeState;
        if (user != null && resume != null && resume.hash.trim().isNotEmpty) {
          final fileName = _bestFriendlyDisplayNameForHash(
            hash: resume.hash,
            targetLanguage: resume.targetLanguage,
            fallbackName: currentFileName,
            fallbackPath: resume.filePath,
          );
          final totalBlocks =
              SubtitleParser.parseSrt(resume.sourceContent).length;
          unawaited(() async {
            try {
              await _repository.addToUserHistory(
                sourceHash: resume.hash,
                fileName: fileName,
                targetLanguage: resume.targetLanguage,
                isPartial: true,
                encodingDetected: resume.sourceEncoding,
                resumeState: resume.toJson(),
                translatedLines: resume.translatedBlocks.length,
                totalLines: totalBlocks,
                clearSdh: resume.clearSdh,
              );
            } catch (e) {
              unawaited(
                _cloudRetryQueue.enqueueAddToUserHistory(
                  sourceHash: resume.hash,
                  fileName: fileName,
                  targetLanguage: resume.targetLanguage,
                  isPartial: true,
                  encodingDetected: resume.sourceEncoding,
                  resumeState: resume.toJson(),
                  translatedLines: resume.translatedBlocks.length,
                  totalLines: totalBlocks,
                  clearSdh: resume.clearSdh,
                ),
              );
            }
          }());
        }
      }
    } catch (e) {
      _onLog?.call(
          'log_resume_state_load_failed', jsonEncode({'error': e.toString()}));
      _resumeState = null;
    }
  }

  // Resume state cache'ini temizle (geçmiş sekmesinden silme işlemi yapıldığında)
  Future<void> clearResumeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('resume_state_cache');
      _resumeState = null;
      _onLog?.call('log_resume_cache_cleared');
      notifyListeners();
    } catch (e) {
      _onLog?.call(
          'log_resume_cache_clear_failed', jsonEncode({'error': e.toString()}));
    }
  }
}
