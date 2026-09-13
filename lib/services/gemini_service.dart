import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/ai_language_options.dart';
import 'app_version_service.dart';

class TranslationQuote {
  const TranslationQuote({
    required this.quoteProtocolVersion,
    required this.quoteVersion,
    required this.quoteId,
    required this.contentHash,
    required this.quotedCharacterCount,
    required this.characterMultiplier,
    required this.quotedAppTokens,
    required this.sufficient,
    required this.chargeMode,
    required this.fromPaidTokens,
    required this.fromGrantTokens,
    required this.requiresRewardedAd,
    required this.translationCreditType,
    required this.spendableTokens,
    required this.sourceContent,
  });

  final int quoteProtocolVersion;
  final String quoteVersion;
  final String quoteId;
  final String contentHash;
  final int quotedCharacterCount;
  final double characterMultiplier;
  final int quotedAppTokens;
  final bool sufficient;
  final String chargeMode;
  final int fromPaidTokens;
  final int fromGrantTokens;
  final bool requiresRewardedAd;
  final String? translationCreditType;
  final int spendableTokens;
  final String sourceContent;

  bool get chargesTokens => chargeMode == 'tokens';

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.floor();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory TranslationQuote.fromCallable(
    dynamic raw, {
    required String sourceContent,
  }) {
    if (raw is! Map) {
      throw const FormatException('Invalid translation quote response.');
    }
    final creditType = raw['translationCreditType']?.toString().trim();
    final quote = TranslationQuote(
      quoteProtocolVersion: _intValue(raw['quoteProtocolVersion']),
      quoteVersion: raw['quoteVersion']?.toString() ?? '',
      quoteId: raw['quoteId']?.toString() ?? '',
      contentHash: raw['contentHash']?.toString() ?? '',
      quotedCharacterCount: _intValue(raw['quotedCharacterCount']),
      characterMultiplier:
          (raw['characterMultiplier'] as num?)?.toDouble() ?? 0,
      quotedAppTokens: _intValue(raw['quotedAppTokens']),
      sufficient: raw['sufficient'] == true,
      chargeMode: raw['chargeMode']?.toString() ?? 'tokens',
      fromPaidTokens: _intValue(raw['fromPaidTokens']),
      fromGrantTokens: _intValue(raw['fromGrantTokens']),
      requiresRewardedAd: raw['requiresRewardedAd'] == true,
      translationCreditType:
          creditType == 'paid' || creditType == 'free' ? creditType : null,
      spendableTokens: _intValue(raw['spendableTokens']),
      sourceContent: sourceContent,
    );
    if (quote.quoteProtocolVersion != 1 ||
        quote.quoteId.isEmpty ||
        quote.contentHash.isEmpty ||
        quote.quotedCharacterCount <= 0 ||
        quote.quotedAppTokens <= 0) {
      throw const FormatException('Incomplete translation quote response.');
    }
    return quote;
  }
}

class GeminiService {
  final FirebaseApp _app;
  late final FirebaseAuth _auth;
  late final FirebaseFunctions _functions;

  String? _deviceId;
  void setDeviceId(String? id) => _deviceId = id;

  String? _chargeKey;
  void setChargeKey(String? key) => _chargeKey = key;

  bool _approveChargeOnNextCall = false;
  int? _pendingCharCount;
  int? _pendingEstimatedTokens;
  String? _lastChargeMode;
  int _lastPlannedEstimatedTokens = 0;
  TranslationQuote? _pendingQuote;
  Map<String, dynamic>? _lastChargeReceipt;

  /// Last `checkTranslationAccess` charge mode (`tokens`, `paid_file`, …).
  String? get lastChargeMode => _lastChargeMode;

  /// Planned app-token amount from last access check (0 when not token mode).
  int get lastPlannedEstimatedTokens => _lastPlannedEstimatedTokens;
  TranslationQuote? get pendingQuote => _pendingQuote;
  Map<String, dynamic>? get lastChargeReceipt => _lastChargeReceipt;
  int get lastChargedAmount =>
      TranslationQuote._intValue(_lastChargeReceipt?['chargedAmount']);
  String? get lastTranslationCreditType {
    final raw = _lastChargeReceipt?['translationCreditType']?.toString().trim();
    return raw == 'paid' || raw == 'free' ? raw : null;
  }

  bool _shouldSendAppVersion() {
    if (kIsWeb) return false;

    return true;
  }

  Future<String?> _getTranslationAppVersion() async {
    if (!_shouldSendAppVersion()) {
      return null;
    }

    return AppVersionService.getVersion();
  }

  Future<TranslationQuote> quoteTranslationCost({
    required String chargeKey,
    required String sourceContent,
    required String sourceHash,
    required String targetLanguage,
    required String platform,
    bool preferFreeCreditsFirst = false,
    String? fileName,
  }) async {
    await _ensureAuthReady();
    final appVersion = await AppVersionService.getVersion();
    final callable = _functions.httpsCallable(
      'quoteTranslationCost',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call({
      'quoteProtocolVersion': 1,
      'deviceId': _deviceId,
      'chargeKey': chargeKey,
      'sourceContent': sourceContent,
      'sourceHash': sourceHash,
      'targetLanguage': targetLanguage,
      'platform': platform,
      'appVersion': appVersion,
      if (fileName != null && fileName.trim().isNotEmpty)
        'fileName': fileName.trim(),
      if (platform == 'android' || platform == 'ios')
        'preferFreeCreditsFirst': preferFreeCreditsFirst,
    });
    final quote = TranslationQuote.fromCallable(
      result.data,
      sourceContent: sourceContent,
    );
    _chargeKey = chargeKey;
    _pendingQuote = quote;
    _pendingCharCount = quote.quotedCharacterCount;
    _pendingEstimatedTokens = quote.quotedAppTokens;
    _lastChargeMode = quote.chargeMode;
    _lastPlannedEstimatedTokens = quote.quotedAppTokens;
    _lastChargeReceipt = null;
    return quote;
  }

  Future<String?> prepareTranslationAccess({
    required String chargeKey,
    required bool useRewardedAd,
    bool preferFreeCreditsFirst = false,
    String? fileName,
    String? targetLanguage,
    String? platform,
    int? charCount,
    int? estimatedTokens,
    TranslationQuote? quote,
  }) async {
    await _ensureAuthReady();
    final appVersion = await _getTranslationAppVersion();
    final exactQuote = quote ?? _pendingQuote;
    final payload = {
      'deviceId': _deviceId,
      'chargeKey': chargeKey,
      if (fileName != null && fileName.trim().isNotEmpty)
        'fileName': fileName.trim(),
      if (targetLanguage != null && targetLanguage.trim().isNotEmpty)
        'targetLanguage': targetLanguage.trim(),
      if (platform != null && platform.trim().isNotEmpty)
        'platform': platform.trim(),
      if (appVersion != null) 'appVersion': appVersion,
      if (charCount != null && charCount > 0) 'charCount': charCount,
      if (estimatedTokens != null && estimatedTokens > 0)
        'estimatedTokens': estimatedTokens,
      if (exactQuote != null) ...{
        'quoteProtocolVersion': exactQuote.quoteProtocolVersion,
        'quoteId': exactQuote.quoteId,
        'contentHash': exactQuote.contentHash,
      },
      'useRewardedAd': useRewardedAd,
      if (platform == 'android' || platform == 'ios')
        'preferFreeCreditsFirst': preferFreeCreditsFirst,
    };

    try {
      final callable = _functions.httpsCallable(
        'checkTranslationAccess',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call(payload);
      _chargeKey = chargeKey;
      _approveChargeOnNextCall = true;
      _pendingQuote = exactQuote;
      _pendingCharCount =
          exactQuote?.quotedCharacterCount ?? charCount;
      _pendingEstimatedTokens =
          exactQuote?.quotedAppTokens ?? estimatedTokens;
      _capturePreparedChargePlan(result.data);
      return _readPreparedTranslationCreditType(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (_shouldUseCheckAccessFallback(e)) {
        try {
          final fallbackCallable = _functions.httpsCallableFromUrl(
            _callableUrl('checkTranslationAccess'),
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
          final fallbackResult = await fallbackCallable.call(payload);
          _chargeKey = chargeKey;
          _approveChargeOnNextCall = true;
          _pendingQuote = exactQuote;
          _pendingCharCount =
              exactQuote?.quotedCharacterCount ?? charCount;
          _pendingEstimatedTokens =
              exactQuote?.quotedAppTokens ?? estimatedTokens;
          _capturePreparedChargePlan(fallbackResult.data);
          return _readPreparedTranslationCreditType(fallbackResult.data);
        } on FirebaseFunctionsException catch (fallbackError) {
          _throwTranslationAccessError(fallbackError);
        }
      }
      _throwTranslationAccessError(e);
    }
  }

  void _capturePreparedChargePlan(dynamic data) {
    if (data is! Map) {
      _lastChargeMode = null;
      _lastPlannedEstimatedTokens = 0;
      return;
    }
    _lastChargeMode = (data['chargeMode'] as String?)?.trim();
    final planned = data['estimatedTokens'];
    if (planned is int) {
      _lastPlannedEstimatedTokens = planned < 0 ? 0 : planned;
    } else if (planned is num) {
      _lastPlannedEstimatedTokens = planned.floor().clamp(0, 1 << 62);
    } else {
      _lastPlannedEstimatedTokens = 0;
    }
  }

  String? _readPreparedTranslationCreditType(dynamic data) {
    if (data is! Map) {
      return null;
    }

    final raw = (data['translationCreditType'] as String?)?.trim();
    if (raw == 'paid' || raw == 'free') {
      return raw;
    }
    return null;
  }

  bool _shouldUseCheckAccessFallback(FirebaseFunctionsException error) {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        (error.code == 'internal' ||
            error.code == 'unavailable' ||
            error.code == 'unknown');
  }

  String _callableUrl(String functionName) {
    final projectId = _app.options.projectId;
    return 'https://us-central1-$projectId.cloudfunctions.net/$functionName';
  }

  Never _throwTranslationAccessError(FirebaseFunctionsException error) {
    final message = error.message ?? '';
    if (error.code == 'failed-precondition' &&
        message.contains('INSUFFICIENT_CREDIT')) {
      throw Exception('INSUFFICIENT_CREDIT');
    }
    if (error.code == 'failed-precondition' &&
        message.contains('REWARDED_AD_REQUIRED')) {
      throw Exception('REWARDED_AD_REQUIRED');
    }
    throw Exception('SERVER_ERROR:${error.code}:$message');
  }

  GeminiService() : _app = Firebase.app() {
    // Bind all Firebase clients to the same app instance.
    _auth = FirebaseAuth.instanceFor(app: _app);
    _functions = FirebaseFunctions.instanceFor(app: _app);
  }

  String _getFullLanguageName(String code) {
    final resolved = aiPanelLanguagePromptNameForCode(code);
    return resolved.isEmpty ? 'Turkish' : resolved;
  }

  String _dialectNotes(String code) {
    final notes = aiPanelLanguageDialectNotes(code);
    return notes.isEmpty ? '' : '\n- $notes\n';
  }

  Future<void> _ensureAuthReady() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _auth.signInAnonymously();
      return;
    }

    // Force token refresh to avoid stale auth in callable functions.
    try {
      await user.getIdToken(true);
    } catch (_) {
      // Best-effort refresh; we'll surface auth errors on the call.
    }
  }

  /// [SERVER-SIDE] Core Translation Call
  /// Tüm çeviri istekleri bu metod üzerinden Cloud Functions'a yönlendirilir.
  /// API Key ve Model seçimi SUNUCU tarafında yönetilir.
  Future<({String text, int inputTokens, int outputTokens, double costUsd})>
      _callCloudTranslate({
    required String text,
    String? systemPrompt,
    String? model, // Sunucuya loglama amaçlı gönderilir, kararı sunucu verir.
    String? targetLanguage,
    String? platform,
    bool approveCharge = false,
  }) async {
    final appVersion = await _getTranslationAppVersion();
    targetLanguage = (targetLanguage != null && targetLanguage.trim().isNotEmpty) ? _getFullLanguageName(targetLanguage.trim()) : null;

    await _ensureAuthReady();
    final callable = _functions.httpsCallable(
      'translateText',
      options: HttpsCallableOptions(
          timeout: const Duration(minutes: 2)), // Uzun timeout
    );

    final result = await callable.call({
      'text': text,
      'systemPrompt': systemPrompt,
      'model': model,
      'deviceId': _deviceId,
      if (targetLanguage != null && targetLanguage.trim().isNotEmpty)
        'targetLanguage': targetLanguage.trim(),
      if (platform != null && platform.trim().isNotEmpty)
        'platform': platform.trim(),
      if (_chargeKey != null && _chargeKey!.trim().isNotEmpty)
        'chargeKey': _chargeKey,
      if (appVersion != null) 'appVersion': appVersion,
      'approveCharge': approveCharge,
      if (_pendingQuote != null) ...{
        'quoteProtocolVersion': _pendingQuote!.quoteProtocolVersion,
        'quoteId': _pendingQuote!.quoteId,
        'contentHash': _pendingQuote!.contentHash,
      },
      if (approveCharge && _pendingQuote != null)
        'quoteSourceContent': _pendingQuote!.sourceContent,
      if (approveCharge && _pendingCharCount != null && _pendingCharCount! > 0)
        'charCount': _pendingCharCount,
      if (approveCharge &&
          _pendingEstimatedTokens != null &&
          _pendingEstimatedTokens! > 0)
        'estimatedTokens': _pendingEstimatedTokens,
    });

    final data = result.data as Map;
    final receipt = data['chargeReceipt'];
    if (receipt is Map) {
      _lastChargeReceipt = Map<String, dynamic>.from(receipt);
      final receiptMode = receipt['chargeMode']?.toString().trim();
      if (receiptMode != null && receiptMode.isNotEmpty) {
        _lastChargeMode = receiptMode;
      }
      final chargedAmount =
          TranslationQuote._intValue(receipt['chargedAmount']);
      if (_lastChargeMode == 'tokens' && chargedAmount > 0) {
        _lastPlannedEstimatedTokens = chargedAmount;
      }
    }
    final costUsd = double.tryParse((data['costUsd'] as String?) ?? '') ?? 0.0;
    return (
      text: (data['text'] as String?) ?? '',
      inputTokens: (data['inputTokens'] as int?) ?? 0,
      outputTokens: (data['outputTokens'] as int?) ?? 0,
      costUsd: costUsd,
    );
  }

  Stream<String> streamSrtTranslation(String content,
      {String targetLanguage = 'Turkish'}) async* {
    // Client-side key fetch kaldırıldı.
    final fullTargetLanguage = _getFullLanguageName(targetLanguage);

    // İçeriği satırlara böl
    final lines = const LineSplitter().convert(content);
    List<String> buffer = [];

    final systemPrompt =
        'You are a professional subtitle translator working to Netflix standards. '
        'Translate the following SRT-format texts into $fullTargetLanguage. '
        'NEVER change the timecodes or line numbers. '
        'Translate for meaning, not word-for-word. '
        'Keep it natural and fluent, matching everyday spoken language.'
        '${_dialectNotes(targetLanguage)}';

    Future<String?> generateWithRetry(String text) async {
      int attempts = 0;
      while (attempts < 3) {
        try {
          final shouldApprove = _approveChargeOnNextCall;
          final result = await _callCloudTranslate(
            text: text,
            systemPrompt: systemPrompt,
            targetLanguage: targetLanguage,
            approveCharge: shouldApprove,
          );
          if (shouldApprove && result.text.isNotEmpty) {
            _approveChargeOnNextCall = false;
          }
          return result.text;
        } catch (e) {
          attempts++;
          if (attempts >= 3) rethrow;
          await Future.delayed(Duration(seconds: attempts));
        }
      }
      return null;
    }

    for (var line in lines) {
      buffer.add(line);

      // 50 blok civarı (yaklaşık 200 satır) barajını geçtik VE güvenli bir kesme noktası bulduk
      if (buffer.length >= 200 && line.trim().isEmpty) {
        final chunk = buffer.join('\n');
        buffer.clear();
        final text = await generateWithRetry(chunk);
        if (text != null) {
          yield text;
        }
      }
    }

    // Kalan satırları işle
    if (buffer.isNotEmpty) {
      final chunk = buffer.join('\n');
      final text = await generateWithRetry(chunk);
      if (text != null) {
        yield text;
      }
    }
  }

  Future<({String text, int inputTokens, int outputTokens, double costUsd})>
      translateChunk(
    String chunk, {
    String targetLanguage = 'Turkish',
    String? contextHint,
    String? sourceLanguageHint,
    int? expectedBlockCount,
  }) async {
    // Client-side key fetch kaldırıldı.
    final fullTargetLanguage = _getFullLanguageName(targetLanguage);

    final ctx = (contextHint ?? '').trim();
    final srcHint = (sourceLanguageHint ?? '').trim();

    final systemPrompt =
        '''You are a professional subtitle translator working to Netflix standards.
Your task: Translate the given SRT-format subtitle blocks from [${srcHint.isNotEmpty ? srcHint : 'Source Language'}] into $fullTargetLanguage.

  ATTENTION / IMPORTANT:
  - YOU MUST PROVIDE THE TRANSLATION RESULT STRICTLY AND ONLY IN $fullTargetLanguage.
  - DO NOT USE ANY LANGUAGE OTHER THAN $fullTargetLanguage IN THE OUTPUT. IF THE TARGET LANGUAGE IS NOT TURKISH, NEVER WRITE TURKISH SENTENCES!
${_dialectNotes(targetLanguage)}
Rules:
1. Avoid "translationese" when translating. Write the way people speak in everyday $fullTargetLanguage.
2. Adapt idioms, slang, and cultural references to their most natural equivalents in $fullTargetLanguage culture, not word-for-word.
3. Stay fully faithful to the original meaning and context. Avoid over-summarizing that would lose content; however, keep sentences at a fluent length that can be read on screen.
4. Reflect the characters' emotion and the scene's tone. Prefer informal, natural, and fluent language over formality.
5. NEVER break the SRT format (timecodes and block numbers); preserve them unchanged.
6. If a line is so sexually explicit that a direct translation would cause problems, NEVER skip the line, leave it blank, or refuse to translate; translate it in softer, more veiled language while preserving meaning.
${expectedBlockCount != null ? '7. CRITICAL BLOCK COUNT CONSTRAINT: The input contains exactly $expectedBlockCount subtitle blocks. The output MUST contain EXACTLY $expectedBlockCount blocks with identical block numbers and timecodes. NEVER merge multiple blocks into one, and NEVER split any single block into multiple blocks.\n' : ''}${ctx.isNotEmpty ? 'Context (Movie/Series Info): $ctx\n' : ''}''';

    // Retry, çeviriyi yöneten üst katman tarafından (TranslationEngine) yapılır.
    // Burada yalnızca tek deneme; tek otorite runTranslation'daki döngüdür.
    final shouldApprove = _approveChargeOnNextCall;
    try {
      final result = await _callCloudTranslate(
        text: chunk,
        systemPrompt: systemPrompt,
        targetLanguage: targetLanguage,
        approveCharge: shouldApprove,
      ).timeout(const Duration(
          seconds: 120)); // Function soğuk başlangıç için süre tanıdık

      final text = result.text;
      if (text.isNotEmpty) {
        if (shouldApprove) {
          _approveChargeOnNextCall = false;
        }
        return (
          text: text,
          inputTokens: result.inputTokens,
          outputTokens: result.outputTokens,
          costUsd: result.costUsd,
        );
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      // Sunucu oturumun zaten tahsil edildiğini bildirirse, flag'i sıfırlayıp hemen approveCharge=false ile devam et
      if (errStr.contains('already charged') || errStr.contains('already_charged')) {
        _approveChargeOnNextCall = false;
        final retryResult = await _callCloudTranslate(
          text: chunk,
          systemPrompt: systemPrompt,
          targetLanguage: targetLanguage,
          approveCharge: false,
        ).timeout(const Duration(seconds: 120));

        final text = retryResult.text;
        if (text.isNotEmpty) {
          return (
            text: text,
            inputTokens: retryResult.inputTokens,
            outputTokens: retryResult.outputTokens,
            costUsd: retryResult.costUsd,
          );
        }
      }
      rethrow;
    }
    throw Exception('EMPTY_TRANSLATION');
  }

  /// One-time context priming for better consistency across chunked subtitle translations.
  ///
  /// Goal: infer a stable "translation memory" (movie guess, character names, tone,
  /// glossary/term preferences) from filename title/year + a short SRT sample.
  ///
  /// This keeps chunk prompts consistent without resending the full file each time.
  Future<({String text, int inputTokens, int outputTokens, double costUsd})>
      buildTranslationMemory({
    required String fileTitleYearHint,
    required String sampleSrt,
    String targetLanguage = 'Turkish',
    String? sourceLanguageHint,
  }) async {
    // Client-side key fetch kaldırıldı.

    final hint = fileTitleYearHint.trim();
    final sample = sampleSrt.trim();
    final srcHint = (sourceLanguageHint ?? '').trim();
    if (hint.isEmpty || sample.isEmpty) {
      return (text: '', inputTokens: 0, outputTokens: 0, costUsd: 0.0);
    }

    final systemPrompt =
        '''You are a professional film subtitle translation editor.
  I have a subtitle file and I will translate it in chunks.

  Goal: Produce a short "term memory" ONLY for NAME/TERM consistency in later chunks.
  - File hint (movie name/year): $hint
  ${srcHint.isNotEmpty ? '- Source language is likely: $srcHint\n' : ''}

  RULES:
  1) Output must be SHORT (maximum 1000 characters).
  2) Provide plain text only. Do not add markdown, code blocks, or explanations.
  3) Produce ONLY the following:
     - Character/place names (if they appear in the SRT sample)
     - 8-15 term/glossary preferences (especially names, titles, slang, technical words)
  4) Do not invent; if it is not in the sample, do not add it.
  5) If you are not sure, say "LEAVE AS IS" (do not invent placeholders).
  6) This memory is NOT for generating content; it must not be used to rewrite the text.
  ''';

    final userPrompt =
        '''Inspect the SRT sample below and produce a "translation memory" according to the rules above.
Target language: $targetLanguage

SRT SAMPLE (sample only):
$sample
''';

    // Retry, üst katman (TranslationEngine) tarafından yönetilir.
    final result = await _callCloudTranslate(
            text: userPrompt, systemPrompt: systemPrompt)
        .timeout(const Duration(seconds: 60));

    var text = result.text.trim();
    if (text.length > 1000) {
      text = text.substring(0, 1000);
    }
    return (
      text: text,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      costUsd: result.costUsd,
    );
  }

  /// TranslationService için çeviri metodu
  Future<({String text, int inputTokens, int outputTokens})> translate({
    required String text,
    required String targetLanguage,
    required String model,
    required String apiKey,
    String systemPrompt = '',
    List<String> ignoredWords = const [],
  }) async {
    final prompt = systemPrompt.isNotEmpty
        ? systemPrompt
        : '''You are a professional subtitle translator working to Netflix standards.
Your task: Translate the following text into $targetLanguage.

  ATTENTION / IMPORTANT:
  - YOU MUST PROVIDE THE TRANSLATION RESULT STRICTLY AND ONLY IN $targetLanguage.
  - DO NOT USE ANY LANGUAGE OTHER THAN $targetLanguage IN THE OUTPUT. IF THE TARGET LANGUAGE IS NOT TURKISH, NEVER WRITE TURKISH SENTENCES!
${_dialectNotes(targetLanguage)}
Rules:
1. Do not translate word-for-word; translate naturally while preserving meaning.
2. Use everyday speech patterns of the target language ($targetLanguage).
3. Preserve the format.
4. Localize idioms and cultural elements appropriately for the target language.''';

    // Cloud Function çağrısı
    final result = await _callCloudTranslate(
        text: text,
        systemPrompt: prompt,
        model: model // Server'a sadece bilgi olarak gider
        );

    return (
      text: result.text,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
    );
  }

  /// BATCH API METODLARI ///

  Future<String> startBatchTranslation({
    required List<Map<String, String>>
        chunks, // Her biri { id: '...', text: '...' } içerecek
    String targetLanguage = 'Turkish',
    String? sourceLanguageHint,
    String? contextHint,
    String? fcmToken,
    String? sourceHash,
    String? sourceContent,
    String? originalNameForGlobalCache,
    String? fileNameForHistory,
    int? totalLines,
    bool? canWriteUserHistory,
    String? completedPlatform,
    bool? isMultiFileBatch,
  }) async {
    await _ensureAuthReady();

    final fullTargetLanguage = _getFullLanguageName(targetLanguage);
    final ctx = (contextHint ?? '').trim();
    final srcHint = (sourceLanguageHint ?? '').trim();

    final systemPrompt =
        '''You are a professional subtitle translator working to Netflix standards.
Your task: Translate the given SRT-format subtitle blocks from [${srcHint.isNotEmpty ? srcHint : 'Source Language'}] into $fullTargetLanguage.

  ATTENTION / IMPORTANT:
  - YOU MUST PROVIDE THE TRANSLATION RESULT STRICTLY AND ONLY IN $fullTargetLanguage.
  - DO NOT USE ANY LANGUAGE OTHER THAN $fullTargetLanguage IN THE OUTPUT. IF THE TARGET LANGUAGE IS NOT TURKISH, NEVER WRITE TURKISH SENTENCES!
${_dialectNotes(targetLanguage)}
Rules:
1. Avoid "translationese" when translating. Write the way people speak in everyday $fullTargetLanguage.
2. Adapt idioms, slang, and cultural references to their most natural equivalents in $fullTargetLanguage culture, not word-for-word.
3. Stay fully faithful to the original meaning and context. Avoid over-summarizing that would lose content; however, keep sentences at a fluent length that can be read on screen.
4. Reflect the characters' emotion and the scene's tone.
5. NEVER break the SRT format (timecodes and block numbers); preserve them unchanged.
6. If a line is so sexually explicit that a direct translation would cause problems, NEVER skip the line, leave it blank, or refuse to translate; translate it in softer, more veiled language while preserving meaning.
${ctx.isNotEmpty ? 'Context (Movie/Series Info): $ctx\n' : ''}''';

    Future<String> attemptCall() async {
      final appVersion = await _getTranslationAppVersion();
      final callable = _functions.httpsCallable('startBatchTranslation');
      final result = await callable.call({
        'chunks': chunks,
        'systemPrompt': systemPrompt,
        'deviceId': _deviceId,
        if (_chargeKey != null && _chargeKey!.trim().isNotEmpty)
          'chargeKey': _chargeKey,
        if (_pendingQuote != null) ...{
          'quoteProtocolVersion': _pendingQuote!.quoteProtocolVersion,
          'quoteId': _pendingQuote!.quoteId,
          'contentHash': _pendingQuote!.contentHash,
        },
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (sourceHash != null) 'sourceHash': sourceHash,
        if (sourceContent != null) 'sourceContent': sourceContent,
        'targetLanguage': targetLanguage,
        if (originalNameForGlobalCache != null)
          'originalNameForGlobalCache': originalNameForGlobalCache,
        if (fileNameForHistory != null) 'fileNameForHistory': fileNameForHistory,
        if (totalLines != null) 'totalLines': totalLines,
        if (canWriteUserHistory != null)
          'canWriteUserHistory': canWriteUserHistory,
        if (completedPlatform != null) 'completedPlatform': completedPlatform,
        if (isMultiFileBatch != null) 'isMultiFileBatch': isMultiFileBatch,
        if (appVersion != null) 'appVersion': appVersion,
      });

      final data = result.data as Map;
      if (data['success'] == true) {
        final receipt = data['chargeReceipt'];
        if (receipt is Map) {
          _lastChargeReceipt = Map<String, dynamic>.from(receipt);
          _lastChargeMode = receipt['chargeMode']?.toString().trim();
          final chargedAmount =
              TranslationQuote._intValue(receipt['chargedAmount']);
          if (_lastChargeMode == 'tokens' && chargedAmount > 0) {
            _lastPlannedEstimatedTokens = chargedAmount;
          }
        }
        return data['jobName'] as String;
      }
      throw Exception('Failed to start batch job');
    }

    try {
      return await attemptCall();
    } catch (e) {
      if (e is FirebaseFunctionsException && e.code == 'unauthenticated') {
        // Try a one-time auth refresh + retry.
        await _ensureAuthReady();
        try {
          return await attemptCall();
        } catch (retryError) {
          throw Exception('SERVER_ERROR:unauthenticated:Auth refresh declined.');
        }
      }
      if (e is FirebaseFunctionsException) {
        throw Exception('SERVER_ERROR:${e.code}:${e.message}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkBatchTranslationStatus({
    required String jobName,
    String? sourceHash,
    String? sourceContent,
    String? targetLanguage,
    String? originalNameForGlobalCache,
    String? fileNameForHistory,
    int? totalLines,
    bool? canWriteUserHistory,
    String? completedPlatform,
  }) async {
    await _ensureAuthReady();
    final callable = _functions.httpsCallable('checkBatchTranslation');
    final result = await callable.call({
      'jobName': jobName,
      'deviceId': _deviceId,
      if (sourceHash != null) 'sourceHash': sourceHash,
      if (sourceContent != null) 'sourceContent': sourceContent,
      if (targetLanguage != null) 'targetLanguage': targetLanguage,
      if (originalNameForGlobalCache != null)
        'originalNameForGlobalCache': originalNameForGlobalCache,
      if (fileNameForHistory != null) 'fileNameForHistory': fileNameForHistory,
      if (totalLines != null) 'totalLines': totalLines,
      if (canWriteUserHistory != null)
        'canWriteUserHistory': canWriteUserHistory,
      if (completedPlatform != null) 'completedPlatform': completedPlatform,
    });

    return result.data as Map<String, dynamic>;
  }
}
