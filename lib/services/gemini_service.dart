import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
    this.firstTranslationFree = false,
    this.firstFreeCoverageTokens = 0,
    this.chargeAppTokens = 0,
    this.regularAppTokens = 0,
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
  final bool firstTranslationFree;
  final int firstFreeCoverageTokens;
  final int chargeAppTokens;
  final int regularAppTokens;

  bool get chargesTokens => chargeMode == 'tokens';
  bool get isFullyFreeFirstTranslation =>
      firstTranslationFree && chargeAppTokens <= 0;

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
    final quotedAppTokens = _intValue(raw['quotedAppTokens']);
    final quote = TranslationQuote(
      quoteProtocolVersion: _intValue(raw['quoteProtocolVersion']),
      quoteVersion: raw['quoteVersion']?.toString() ?? '',
      quoteId: raw['quoteId']?.toString() ?? '',
      contentHash: raw['contentHash']?.toString() ?? '',
      quotedCharacterCount: _intValue(raw['quotedCharacterCount']),
      characterMultiplier:
          (raw['characterMultiplier'] as num?)?.toDouble() ?? 0,
      quotedAppTokens: quotedAppTokens,
      sufficient: raw['sufficient'] == true,
      chargeMode: raw['chargeMode']?.toString() ?? 'tokens',
      fromPaidTokens: _intValue(raw['fromPaidTokens']),
      fromGrantTokens: _intValue(raw['fromGrantTokens']),
      requiresRewardedAd: raw['requiresRewardedAd'] == true,
      translationCreditType:
          creditType == 'paid' || creditType == 'free' ? creditType : null,
      spendableTokens: _intValue(raw['spendableTokens']),
      sourceContent: sourceContent,
      firstTranslationFree: raw['firstTranslationFree'] == true,
      firstFreeCoverageTokens: _intValue(raw['firstFreeCoverageTokens']),
      chargeAppTokens: raw['chargeAppTokens'] != null
          ? _intValue(raw['chargeAppTokens'])
          : quotedAppTokens,
      regularAppTokens: raw['regularAppTokens'] != null
          ? _intValue(raw['regularAppTokens'])
          : quotedAppTokens,
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

  /// Masaüstü controller uyumluluğu: mevcut charge bağlamını ayarlar.
  void setTranslationChargeContext({String? chargeKey, bool approveCharge = false}) {
    final trimmed = chargeKey?.trim();
    _chargeKey = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _approveChargeOnNextCall = approveCharge;
  }

  /// Masaüstü controller uyumluluğu: charge bağlamını temizler.
  void clearTranslationChargeContext() {
    _chargeKey = null;
    _approveChargeOnNextCall = false;
  }

  // Usage tracking (cost takibi; mobil engine ile uyumlu).
  int _usageInputTokens = 0;
  int _usageOutputTokens = 0;
  int _usageApiCalls = 0;
  int _usageApiRetries = 0;
  int _usageResendRounds = 0;
  double _usageCostUsd = 0;
  String _usageModel = '';

  Map<String, dynamic> get usageSnapshot => {
        'inputTokens': _usageInputTokens,
        'outputTokens': _usageOutputTokens,
        'apiCalls': _usageApiCalls,
        'apiRetries': _usageApiRetries,
        'resendRounds': _usageResendRounds,
        'costUsd': _usageCostUsd,
        'model': _usageModel,
      };

  void resetUsage() {
    _usageInputTokens = 0;
    _usageOutputTokens = 0;
    _usageApiCalls = 0;
    _usageApiRetries = 0;
    _usageResendRounds = 0;
    _usageCostUsd = 0;
    _usageModel = '';
  }

  void _accumulateUsage(
      ({String text, int inputTokens, int outputTokens, double costUsd}) result) {
    _usageApiCalls += 1;
    _usageInputTokens += result.inputTokens;
    _usageOutputTokens += result.outputTokens;
    _usageCostUsd += result.costUsd;
  }

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

  bool get _supportsFunctionsPlugin =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<dynamic> _callCloudFunction({
    required String functionName,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_supportsFunctionsPlugin) {
      try {
        final callable = _functions.httpsCallable(
          functionName,
          options: HttpsCallableOptions(timeout: timeout),
        );
        final result = await callable.call(data);
        return result.data;
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'unknown' &&
            e.code != 'internal' &&
            e.code != 'unavailable') {
          rethrow;
        }
      } catch (_) {
        // Platform channel error on unsupported platforms, fall back to HTTP.
      }
    }

    return await _callCloudFunctionViaHttp(
      functionName: functionName,
      data: data,
      timeout: timeout,
    );
  }

  Future<dynamic> _callCloudFunctionViaHttp({
    required String functionName,
    required Map<String, dynamic> data,
    required Duration timeout,
  }) async {
    await _ensureAuthReady();

    final projectId = _app.options.projectId.trim();
    if (projectId.isEmpty) {
      throw FirebaseFunctionsException(
        message: 'Server Error: Firebase projectId not found.',
        code: 'internal',
      );
    }

    final endpoint = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/$functionName',
    );

    final user = _auth.currentUser;
    final idToken = await user?.getIdToken();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (idToken != null && idToken.isNotEmpty)
        'Authorization': 'Bearer $idToken',
    };

    final payload = jsonEncode({'data': data});

    http.Response response;
    try {
      response = await http
          .post(endpoint, headers: headers, body: payload)
          .timeout(timeout);
    } on TimeoutException {
      throw FirebaseFunctionsException(
        message: 'Request timed out ($functionName)',
        code: 'deadline-exceeded',
      );
    } catch (e) {
      throw FirebaseFunctionsException(
        message: 'Connection failed ($functionName): $e',
        code: 'unavailable',
      );
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw FirebaseFunctionsException(
        message:
            'Invalid response from server (${response.statusCode}): ${response.body}',
        code: 'internal',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map) {
        if (decoded.containsKey('result')) {
          return decoded['result'];
        }
        if (decoded.containsKey('data')) {
          return decoded['data'];
        }
      }
      return decoded;
    }

    String code = 'unknown';
    String message = response.body;
    dynamic details;

    if (decoded is Map && decoded['error'] != null) {
      final errorPayload = decoded['error'];
      if (errorPayload is Map) {
        message = errorPayload['message']?.toString() ?? message;
        final rawStatus = errorPayload['status']?.toString();
        if (rawStatus != null && rawStatus.isNotEmpty) {
          code = rawStatus.toLowerCase().replaceAll('_', '-');
        }
        details = errorPayload['details'];
      }
    } else {
      if (response.statusCode == 401) {
        code = 'unauthenticated';
      } else if (response.statusCode == 403) {
        code = 'permission-denied';
      } else if (response.statusCode == 404) {
        code = 'not-found';
      } else if (response.statusCode == 400) {
        code = 'invalid-argument';
      } else if (response.statusCode == 503) {
        code = 'unavailable';
      } else if (response.statusCode == 504) {
        code = 'deadline-exceeded';
      }
    }

    throw FirebaseFunctionsException(
      message: message,
      code: code,
      details: details,
    );
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
    final resultData = await _callCloudFunction(
      functionName: 'quoteTranslationCost',
      data: {
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
      },
      timeout: const Duration(seconds: 30),
    );
    final quote = TranslationQuote.fromCallable(
      resultData,
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
      final resultData = await _callCloudFunction(
        functionName: 'checkTranslationAccess',
        data: payload,
        timeout: const Duration(seconds: 30),
      );
      _chargeKey = chargeKey;
      _approveChargeOnNextCall = true;
      _pendingQuote = exactQuote;
      _pendingCharCount =
          exactQuote?.quotedCharacterCount ?? charCount;
      _pendingEstimatedTokens =
          exactQuote?.quotedAppTokens ?? estimatedTokens;
      _capturePreparedChargePlan(resultData);
      return _readPreparedTranslationCreditType(resultData);
    } on FirebaseFunctionsException catch (e) {
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
    final resultData = await _callCloudFunction(
      functionName: 'translateText',
      data: {
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
      },
      timeout: const Duration(minutes: 4),
    );

    final data = resultData is Map ? resultData : const {};
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
    final translated = (
      text: (data['text'] as String?) ?? '',
      inputTokens: (data['inputTokens'] as int?) ?? 0,
      outputTokens: (data['outputTokens'] as int?) ?? 0,
      costUsd: costUsd,
    );
    _accumulateUsage(translated);
    return translated;
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

}
