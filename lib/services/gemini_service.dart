import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/ai_language_options.dart';

import '../utils/io_platform_stub.dart'
  if (dart.library.io) '../utils/io_platform_io.dart' as io_platform;

class GeminiService {
  final FirebaseApp _app;
  late final FirebaseAuth _auth;
  late final FirebaseFunctions _functions;

  // Legacy/mobile-compatible fields.
  String? _deviceId;
  String? _chargeKey;

  String? _translationChargeKey;
  bool _approveChargeForTranslateCalls = false;

  // Usage tracking (mirrors mobile translation_engine).
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

  Future<String> _currentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.trim();
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> _walletGateFields() async {
    final appVersion = await _currentAppVersion();
    final platform = io_platform.operatingSystem.trim();
    return {
      if (appVersion.isNotEmpty) 'appVersion': appVersion,
      if (platform.isNotEmpty && platform != 'unknown') 'platform': platform,
    };
  }

  Future<void> prepareTranslationAccess({
    required String chargeKey,
    String? fileName,
    String? targetLanguage,
    String? platform,
    int? charCount,
    int? estimatedTokens,
  }) async {
    await _ensureAuthReady();
    try {
      final payload = {
        'deviceId': _deviceId,
        'chargeKey': chargeKey,
        if (fileName != null && fileName.trim().isNotEmpty)
          'fileName': fileName.trim(),
        if (targetLanguage != null && targetLanguage.trim().isNotEmpty)
          'targetLanguage': targetLanguage.trim(),
        if (targetLanguage != null && targetLanguage.trim().isNotEmpty)
          'targetLanguageName': _getFullLanguageName(targetLanguage.trim()),
        if (charCount != null && charCount > 0) 'charCount': charCount,
        if (estimatedTokens != null && estimatedTokens > 0)
          'estimatedTokens': estimatedTokens,
        ...await _walletGateFields(),
        if (platform != null && platform.trim().isNotEmpty)
          'platform': platform.trim(),
      };

      if (io_platform.isDesktop) {
        await _callCloudFunctionViaHttp('checkTranslationAccess', payload);
      } else {
        final callable = _functions.httpsCallable(
          'checkTranslationAccess',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        );
        await callable.call(payload);
      }

      setChargeKey(chargeKey);
      setTranslationChargeContext(chargeKey: chargeKey, approveCharge: true);
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? '';
      if (e.code == 'failed-precondition' &&
          message.contains('INSUFFICIENT_CREDIT')) {
        throw Exception('INSUFFICIENT_CREDIT');
      }
      throw Exception('Server Hatası (${e.code}): $message');
    }
  }

  GeminiService() : _app = Firebase.app() {
    // Bind all Firebase clients to the same app instance.
    _auth = FirebaseAuth.instanceFor(app: _app);
    _functions = FirebaseFunctions.instanceFor(app: _app);
  }

  /// Mobile-compatible API: optional device/session identifier.
  void setDeviceId(String? id) {
    final trimmed = id?.trim();
    _deviceId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Mobile-compatible API: stores a chargeKey used for translation sessions.
  ///
  /// The desktop/engine path typically uses [setTranslationChargeContext], but
  /// keeping this avoids breaking older/mobile call sites.
  void setChargeKey(String? key) {
    final trimmed = key?.trim();
    _chargeKey = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  String? _effectiveChargeKey(String? explicit) {
    final trimmed = explicit?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (_translationChargeKey != null && _translationChargeKey!.trim().isNotEmpty) {
      return _translationChargeKey!.trim();
    }
    if (_chargeKey != null && _chargeKey!.trim().isNotEmpty) return _chargeKey!.trim();
    return null;
  }
  String _getFullLanguageName(String codeOrName) {
    final resolved = aiPanelLanguagePromptNameForCode(codeOrName);
    return resolved.isEmpty ? 'Turkish' : resolved;
  }
  void setTranslationChargeContext({String? chargeKey, bool approveCharge = false}) {
    final trimmed = chargeKey?.trim();
    _translationChargeKey = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _approveChargeForTranslateCalls = approveCharge;
  }

  void clearTranslationChargeContext() {
    _translationChargeKey = null;
    _approveChargeForTranslateCalls = false;
  }

  Future<void> _ensureAuthReady() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _auth.signInAnonymously().timeout(const Duration(seconds: 25));
      return;
    }

    // Force token refresh to avoid stale auth in callable functions.
    try {
      await user.getIdToken(true).timeout(const Duration(seconds: 25));
    } catch (_) {
      // Best-effort refresh; we'll surface auth errors on the call.
    }
  }

  bool _shouldUseHttpCallableFallback(Object e) {
    final error = e.toString().toLowerCase();
    return error.contains('unable to establish connection on channel') ||
        error.contains('cloud_functions_platform_interface') ||
        error.contains('missingpluginexception');
  }

  bool _isNonRetriableTranslateError(Object e) {
    final error = e.toString().toLowerCase();
    return error.contains('http 400') ||
        error.contains('http 401') ||
        error.contains('http 403') ||
        error.contains('permission-denied') ||
        error.contains('device verification failed') ||
        error.contains('unauthenticated');
  }

  Future<({String text, int inputTokens, int outputTokens, String costUsd, String model})>
      _callCloudTranslateViaHttpCallable({
    required String text,
    String? systemPrompt,
    String? model,
    String? chargeKey,
    bool approveCharge = false,
  }) async {
    await _ensureAuthReady();

    final projectId = _app.options.projectId.trim();
    if (projectId.isEmpty) {
      throw Exception('Server Hatası: Firebase projectId bulunamadı.');
    }

    final endpoint = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/translateText',
    );

    final user = _auth.currentUser;
    final idToken = await user?.getIdToken().timeout(const Duration(seconds: 25));

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    final effectiveChargeKey = _effectiveChargeKey(chargeKey);
    final payload = jsonEncode({
      'data': {
        'text': text,
        'systemPrompt': systemPrompt,
        'model': model,
        if (_deviceId != null && _deviceId!.trim().isNotEmpty) 'deviceId': _deviceId,
        if (effectiveChargeKey != null) 'chargeKey': effectiveChargeKey,
        // Keep the field stable (mobile sends it always).
        'approveCharge': approveCharge == true,
        ...await _walletGateFields(),
      },
    });

    http.Response response;
    try {
      final timeout = io_platform.isDesktop
          ? const Duration(minutes: 4)
          : const Duration(minutes: 2);
      response = await http
          .post(endpoint, headers: headers, body: payload)
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw Exception('Bağlantı Hatası (http callable timeout): ${e.message ?? e.toString()}');
    }

    final dynamic decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final map = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      final resultRaw = map?['result'] ?? map?['data'];
      final result = resultRaw is Map
          ? Map<String, dynamic>.from(resultRaw)
          : <String, dynamic>{};

      return (
        text: (result['text'] as String?) ?? '',
        inputTokens: (result['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (result['outputTokens'] as num?)?.toInt() ?? 0,
        costUsd: (result['costUsd'] as String?) ?? '0.000000',
        model: (result['modelUsed'] as String?) ?? '',
      );
    }

    final errorMap = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    final errorPayload = errorMap?['error'];

    String message = '';
    String? status;
    String? code;
    String? details;

    if (errorPayload is Map) {
      final m = errorPayload['message']?.toString();
      if (m != null && m.isNotEmpty) message = m;
      status = errorPayload['status']?.toString();
      code = errorPayload['code']?.toString();
      final d = errorPayload['details']?.toString();
      if (d != null && d.isNotEmpty) details = d;
    }

    if (message.isEmpty) {
      // Some CF responses put the message at top-level.
      final topMessage = errorMap?['message']?.toString();
      if (topMessage != null && topMessage.isNotEmpty) {
        message = topMessage;
      }
    }

    if (message.isEmpty) {
      message = response.body;
    }

    // Avoid flooding logs; include a small tail snippet.
    final bodySnippet = response.body.length <= 500
        ? response.body
        : '${response.body.substring(0, 500)}…';
    final fields = <String>[];
    if (status != null && status.isNotEmpty) fields.add('status=$status');
    if (code != null && code.isNotEmpty) fields.add('code=$code');
    final meta = fields.isEmpty ? '' : ' (${fields.join(', ')})';
    final extra = (details == null || details.isEmpty) ? '' : '\n$details';

    throw Exception(
      'Server Hatası (http ${response.statusCode})$meta: $message$extra\nresponse: $bodySnippet',
    );
  }

  /// [SERVER-SIDE] Core Translation Call
  /// Tüm çeviri istekleri bu metod üzerinden Cloud Functions'a yönlendirilir.
  /// API Key ve Model seçimi SUNUCU tarafında yönetilir.
  void _accumulateUsage(({String text, int inputTokens, int outputTokens, String costUsd, String model}) result) {
    _usageApiCalls += 1;
    _usageInputTokens += result.inputTokens;
    _usageOutputTokens += result.outputTokens;
    _usageCostUsd += double.tryParse(result.costUsd) ?? 0;
    if (result.model.isNotEmpty) {
      _usageModel = result.model;
    }
  }

  Future<({String text, int inputTokens, int outputTokens, String costUsd, String model})> _callCloudTranslate({
    required String text,
    String? systemPrompt,
    String? model, // Sunucuya loglama amaçlı gönderilir, kararı sunucu verir.
    String? chargeKey,
    bool approveCharge = false,
  }) async {
    try {
      // On desktop (especially Windows), Firebase Functions gRPC callable can hang.
      // Prefer the HTTP callable endpoint for reliability.
      if (io_platform.isDesktop) {
        final result = await _callCloudTranslateViaHttpCallable(
          text: text,
          systemPrompt: systemPrompt,
          model: model,
          chargeKey: chargeKey,
          approveCharge: approveCharge,
        );
        _accumulateUsage(result);
        return result;
      }

      await _ensureAuthReady().timeout(const Duration(seconds: 25));
      final callable = _functions.httpsCallable(
        'translateText', 
        options: HttpsCallableOptions(timeout: const Duration(minutes: 2)), // Uzun timeout
      );

      final effectiveChargeKey = _effectiveChargeKey(chargeKey);
      
      final result = await callable
          .call({
        'text': text,
        'systemPrompt': systemPrompt,
        'model': model,
        if (_deviceId != null && _deviceId!.trim().isNotEmpty) 'deviceId': _deviceId,
        if (effectiveChargeKey != null) 'chargeKey': effectiveChargeKey,
        // Keep the field stable (mobile sends it always).
        'approveCharge': approveCharge == true,
        ...await _walletGateFields(),
      })
          .timeout(const Duration(minutes: 2));

      final data = result.data as Map;
      final translated = (
        text: (data['text'] as String?) ?? '',
        inputTokens: (data['inputTokens'] as int?) ?? 0,
        outputTokens: (data['outputTokens'] as int?) ?? 0,
        costUsd: (data['costUsd'] as String?) ?? '0.000000',
        model: (data['modelUsed'] as String?) ?? '',
      );
      _accumulateUsage(translated);
      return translated;
    } catch (e) {
      if (e is TimeoutException || _shouldUseHttpCallableFallback(e)) {
        final result = await _callCloudTranslateViaHttpCallable(
          text: text,
          systemPrompt: systemPrompt,
          model: model,
          chargeKey: chargeKey,
          approveCharge: approveCharge,
        );
        _accumulateUsage(result);
        return result;
      }

      if (e is FirebaseFunctionsException && e.code == 'unauthenticated') {
        // Try a one-time auth refresh + retry.
        await _ensureAuthReady();
        try {
          final retryCallable = _functions.httpsCallable(
            'translateText',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          );
          final effectiveChargeKey = _effectiveChargeKey(chargeKey);
          final retryResult = await retryCallable.call({
            'text': text,
            'systemPrompt': systemPrompt,
            'model': model,
            if (_deviceId != null && _deviceId!.trim().isNotEmpty)
              'deviceId': _deviceId,
            if (effectiveChargeKey != null) 'chargeKey': effectiveChargeKey,
            'approveCharge': approveCharge == true,
            ...await _walletGateFields(),
          });

          final retryData = retryResult.data as Map;
          final retried = (
            text: (retryData['text'] as String?) ?? '',
            inputTokens: (retryData['inputTokens'] as int?) ?? 0,
            outputTokens: (retryData['outputTokens'] as int?) ?? 0,
            costUsd: (retryData['costUsd'] as String?) ?? '0.000000',
            model: (retryData['modelUsed'] as String?) ?? '',
          );
          _accumulateUsage(retried);
          return retried;
        } catch (retryError) {
          throw Exception('Server Hatası (unauthenticated): ${retryError.toString()}');
        }
      }

      // FirebaseFunctionsException detaylarını yakalayabiliriz
      if (e is FirebaseFunctionsException) {
        throw Exception('Server Hatası (${e.code}): ${e.message}');
      }
      throw Exception('Bağlantı Hatası: $e');
    }
  }

  Stream<String> streamSrtTranslation(String content, {String targetLanguage = 'Turkish'}) async* {
    // Client-side key fetch kaldırıldı.
    
    // İçeriği satırlara böl
    final lines = const LineSplitter().convert(content);
    List<String> buffer = [];

    final fullLanguageName = _getFullLanguageName(targetLanguage);

    final systemPrompt = 'You are a professional subtitle translator working to Netflix standards. '
        'Translate the following SRT-format texts into $fullLanguageName. '
        'NEVER change the timecodes or line numbers. '
        'Translate for meaning, not word-for-word. '
        'Keep it natural and fluent, matching everyday spoken language.';

    Future<String?> generateWithRetry(String text) async {
      int attempts = 0;
      while (attempts < 3) {
        try {
          final result = await _callCloudTranslate(
            text: text,
            systemPrompt: systemPrompt,
            chargeKey: _effectiveChargeKey(null),
            approveCharge: _approveChargeForTranslateCalls,
          );
          if (_approveChargeForTranslateCalls && result.text.isNotEmpty) {
            _approveChargeForTranslateCalls = false;
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

  Future<String> translateChunk(
    String chunk, {
    String targetLanguage = 'Turkish',
    String? contextHint,
    String? sourceLanguageHint,
    int? expectedBlockCount,
  }) async {
    // Client-side key fetch kaldırıldı.

    final fullLanguageName = _getFullLanguageName(targetLanguage);
    final ctx = (contextHint ?? '').trim();
    final srcHint = (sourceLanguageHint ?? '').trim();

    final systemPrompt = '''You are a professional subtitle translator working to Netflix standards.
Your task: Translate the given SRT-format subtitle blocks from [${srcHint.isNotEmpty ? srcHint : 'Source Language'}] into $fullLanguageName.

ATTENTION / IMPORTANT:
- YOU MUST PROVIDE THE TRANSLATION RESULT STRICTLY AND ONLY IN $fullLanguageName.
- DO NOT USE ANY LANGUAGE OTHER THAN $fullLanguageName IN THE OUTPUT. IF THE TARGET LANGUAGE IS NOT TURKISH, NEVER WRITE TURKISH SENTENCES!

Rules:
1. Avoid "translationese" when translating. Write the way people speak in everyday $fullLanguageName.
2. Adapt idioms, slang, and cultural references to their most natural equivalents in $fullLanguageName culture, not word-for-word.
3. Keep sentences as short and concise as possible (for subtitle reading speed). Drop unnecessary filler words.
4. Reflect the characters' emotion and the scene's tone. Prefer informal, natural, and fluent language over formality.
5. NEVER break the SRT format (timecodes and block numbers); preserve them unchanged.
6. If a line is so sexually explicit that a direct translation would cause problems, NEVER skip the line, leave it blank, or refuse to translate; translate it in softer, more veiled language while preserving meaning.
${expectedBlockCount != null ? '7. The output must contain exactly $expectedBlockCount blocks.\n' : ''}${ctx.isNotEmpty ? 'Context (Movie/Series Info): $ctx\n' : ''}''';

    int attempts = 0;
    while (attempts < 3) {
      try {
        // Cloud Function çağrısı
        final timeout = io_platform.isDesktop
            ? const Duration(minutes: 4)
            : const Duration(seconds: 120);
        final result = await _callCloudTranslate(
          text: chunk, 
          systemPrompt: systemPrompt,
          chargeKey: _translationChargeKey,
          approveCharge: _approveChargeForTranslateCalls,
        ).timeout(timeout); // Function soğuk başlangıç için süre tanıdık
        
        final text = result.text;
        if (text.isNotEmpty) {
          if (_approveChargeForTranslateCalls) {
            _approveChargeForTranslateCalls = false;
          }
          return text;
        }
        throw Exception('Boş çeviri sonucu alındı.');
      } catch (e) {
        attempts++;
        if (attempts >= 3 || _isNonRetriableTranslateError(e)) rethrow;
        await Future.delayed(Duration(seconds: attempts));
      }
    }

    throw Exception('Çeviri denemeleri başarısız oldu.');
  }

  /// One-time context priming for better consistency across chunked subtitle translations.
  ///
  /// Goal: infer a stable "translation memory" (movie guess, character names, tone,
  /// glossary/term preferences) from filename title/year + a short SRT sample.
  ///
  /// This keeps chunk prompts consistent without resending the full file each time.
  Future<String> buildTranslationMemory({
    required String fileTitleYearHint,
    required String sampleSrt,
    String targetLanguage = 'Turkish',
    String? sourceLanguageHint,
  }) async {
    // Client-side key fetch kaldırıldı.

    final fullLanguageName = _getFullLanguageName(targetLanguage);
    final hint = fileTitleYearHint.trim();
    final sample = sampleSrt.trim();
    final srcHint = (sourceLanguageHint ?? '').trim();
    if (hint.isEmpty || sample.isEmpty) return '';

    final systemPrompt = '''You are a professional film subtitle translation editor.
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

    final userPrompt = '''Inspect the SRT sample below and produce a "translation memory" according to the rules above.
Target language: $fullLanguageName

SRT SAMPLE (sample only):
$sample
''';

    int attempts = 0;
    while (attempts < 3) {
      try {
        final result = await _callCloudTranslate(
          text: userPrompt,
          systemPrompt: systemPrompt
        ).timeout(const Duration(seconds: 60));

        var text = result.text.trim();
        if (text.isEmpty) return '';
        if (text.length > 1000) {
          text = text.substring(0, 1000);
        }
        return text;
      } catch (e) {
        attempts++;
        if (attempts >= 3) rethrow;
        await Future.delayed(Duration(seconds: attempts));
      }
    }

    return '';
  }

  /// TranslationService için çeviri metodu
  Future<({String text, int inputTokens, int outputTokens, String costUsd, String model})> translate({
    required String text,
    required String targetLanguage,
    required String model,
    required String apiKey,
    String systemPrompt = '',
    List<String> ignoredWords = const [],
  }) async {
    
    final fullLanguageName = _getFullLanguageName(targetLanguage);

    final prompt = systemPrompt.isNotEmpty
        ? systemPrompt
        : '''You are a professional subtitle translator working to Netflix standards.
Your task: Translate the following text into $fullLanguageName.

ATTENTION / IMPORTANT:
- YOU MUST PROVIDE THE TRANSLATION RESULT STRICTLY AND ONLY IN $fullLanguageName.
- DO NOT USE ANY LANGUAGE OTHER THAN $fullLanguageName IN THE OUTPUT. IF THE TARGET LANGUAGE IS NOT TURKISH, NEVER WRITE TURKISH SENTENCES!

Rules:
1. Do not translate word-for-word; translate naturally while preserving meaning.
2. Use everyday speech patterns of the target language ($fullLanguageName).
3. Preserve the format.
4. Localize idioms and cultural elements appropriately for the target language.''';
    
    // Cloud Function çağrısı
    final result = await _callCloudTranslate(
      text: text,
      systemPrompt: prompt,
      model: model // Server'a sadece bilgi olarak gider
    );
    
    return result;
  }

    Future<Map<String, dynamic>> _callCloudFunctionViaHttp(String functionName, Map<String, dynamic> data) async {
    final projectId = _app.options.projectId.trim();
    if (projectId.isEmpty) {
      throw Exception('Server Hatası: Firebase projectId bulunamadı.');
    }

    final endpoint = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/$functionName',
    );

    final user = _auth.currentUser;
    final idToken = await user?.getIdToken().timeout(const Duration(seconds: 25));
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    final payload = jsonEncode({'data': data});

http.Response? response;
      int attempt = 0;
      const maxAttempts = 3;
      while (true) {
        attempt++;
        try {
          final timeout = io_platform.isDesktop
              ? const Duration(minutes: 4)
              : const Duration(minutes: 2);
          response = await http.post(endpoint, headers: headers, body: payload).timeout(timeout);
          break;
        } catch (e) {
          if (attempt >= maxAttempts) {
            throw Exception('Bağlantı Hatası ($attempt. deneme başarısız): $e');
          }
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
    }

    final dynamic decoded = response.body.isEmpty ? const <String, dynamic>{} : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final map = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      final resultRaw = map?['result'] ?? map?['data'];
      return resultRaw is Map ? Map<String, dynamic>.from(resultRaw) : <String, dynamic>{};
    }

    final errorMap = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    final errorPayload = errorMap?['error'];
    String message = 'Bilinmeyen Hata';
    if (errorPayload is Map) {
      message = errorPayload['message']?.toString() ?? message;
    }
    throw FirebaseFunctionsException(message: message, code: 'unknown');
  }

  /// BATCH API METODLARI ///

  Future<String> startBatchTranslation({
    required List<Map<String, String>> chunks,
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

    if ((_chargeKey ?? '').trim().isEmpty) {
      throw Exception('SERVER_ERROR:failed-precondition:Translation session not prepared.');
    }

    final fullTargetLanguage = _getFullLanguageName(targetLanguage);
    final ctx = (contextHint ?? '').trim();
    final srcHint = (sourceLanguageHint ?? '').trim();

    final systemPrompt =
        '''You are a professional subtitle translator working to Netflix standards.
Your task: Translate the given SRT-format subtitle blocks from [${srcHint.isNotEmpty ? srcHint : 'Source Language'}] into $fullTargetLanguage.

ATTENTION / IMPORTANT:
- YOU MUST PROVIDE THE TRANSLATION RESULT STRICTLY AND ONLY IN $fullTargetLanguage.
- DO NOT USE ANY LANGUAGE OTHER THAN $fullTargetLanguage IN THE OUTPUT. IF THE TARGET LANGUAGE IS NOT TURKISH, NEVER WRITE TURKISH SENTENCES!

Rules:
1. Avoid "translationese" when translating. Write the way people speak in everyday $fullTargetLanguage.
2. Adapt idioms, slang, and cultural references to their most natural equivalents in $fullTargetLanguage culture, not word-for-word.
3. Keep sentences as short and concise as possible.
4. Reflect the characters' emotion and the scene's tone.
5. NEVER break the SRT format (timecodes and block numbers); preserve them unchanged.
6. If a line is so sexually explicit that a direct translation would cause problems, NEVER skip the line, leave it blank, or refuse to translate; translate it in softer, more veiled language while preserving meaning.
${ctx.isNotEmpty ? 'Context (Movie/Series Info): $ctx\n' : ''}''';

    Future<String> attemptCall() async {
      final data = {
        'chunks': chunks,
        'systemPrompt': systemPrompt,
        'deviceId': _deviceId,
        if (_chargeKey != null && _chargeKey!.trim().isNotEmpty)
          'chargeKey': _chargeKey,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (sourceHash != null) 'sourceHash': sourceHash,
        if (sourceContent != null) 'sourceContent': sourceContent,
        'targetLanguage': targetLanguage,
        'targetLanguageName': fullTargetLanguage,
        if (originalNameForGlobalCache != null)
          'originalNameForGlobalCache': originalNameForGlobalCache,
        if (fileNameForHistory != null) 'fileNameForHistory': fileNameForHistory,
        if (totalLines != null) 'totalLines': totalLines,
        if (canWriteUserHistory != null)
          'canWriteUserHistory': canWriteUserHistory,
        if (completedPlatform != null) 'completedPlatform': completedPlatform,
        if (isMultiFileBatch != null) 'isMultiFileBatch': isMultiFileBatch,
      };

      Map resultData;
      if (io_platform.isDesktop) {
        resultData = await _callCloudFunctionViaHttp('startBatchTranslation', data);
      } else {
        final callable = _functions.httpsCallable('startBatchTranslation');
        final result = await callable.call(data);
        resultData = result.data as Map;
      }

      if (resultData['success'] == true) {
        return resultData['jobName'] as String;
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
    final data = {
      'jobName': jobName,
      'deviceId': _deviceId,
      if (sourceHash != null) 'sourceHash': sourceHash,
      if (sourceContent != null) 'sourceContent': sourceContent,
      if (targetLanguage != null) 'targetLanguage': targetLanguage,
      if (targetLanguage != null)
        'targetLanguageName': _getFullLanguageName(targetLanguage),
      if (originalNameForGlobalCache != null)
        'originalNameForGlobalCache': originalNameForGlobalCache,
      if (fileNameForHistory != null) 'fileNameForHistory': fileNameForHistory,
      if (totalLines != null) 'totalLines': totalLines,
      if (canWriteUserHistory != null)
        'canWriteUserHistory': canWriteUserHistory,
      if (completedPlatform != null) 'completedPlatform': completedPlatform,
    };
    
    if (io_platform.isDesktop) {
      return await _callCloudFunctionViaHttp('checkBatchTranslation', data);
    } else {
      final callable = _functions.httpsCallable('checkBatchTranslation');
      final result = await callable.call(data);
      final mapData = result.data;
      if (mapData is Map) {
        return Map<String, dynamic>.from(mapData);
      }
      return {};
    }
  }
}
