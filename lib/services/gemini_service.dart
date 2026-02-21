import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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

  Future<({String text, int inputTokens, int outputTokens})>
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
  Future<({String text, int inputTokens, int outputTokens})> _callCloudTranslate({
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
        return _callCloudTranslateViaHttpCallable(
          text: text,
          systemPrompt: systemPrompt,
          model: model,
          chargeKey: chargeKey,
          approveCharge: approveCharge,
        );
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
      })
          .timeout(const Duration(minutes: 2));

      final data = result.data as Map;
      return (
        text: (data['text'] as String?) ?? '',
        inputTokens: (data['inputTokens'] as int?) ?? 0,
        outputTokens: (data['outputTokens'] as int?) ?? 0,
      );
    } catch (e) {
      if (e is TimeoutException || _shouldUseHttpCallableFallback(e)) {
        return _callCloudTranslateViaHttpCallable(
          text: text,
          systemPrompt: systemPrompt,
          model: model,
          chargeKey: chargeKey,
          approveCharge: approveCharge,
        );
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
          });

          final retryData = retryResult.data as Map;
          return (
            text: (retryData['text'] as String?) ?? '',
            inputTokens: (retryData['inputTokens'] as int?) ?? 0,
            outputTokens: (retryData['outputTokens'] as int?) ?? 0,
          );
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

    final systemPrompt = 'Sen Netflix standartlarında çalışan profesyonel bir altyazı çevirmenisin. '
        'Aşağıdaki SRT formatındaki metinleri $targetLanguage diline çevir. '
        'Zaman kodlarını ve satır numaralarını ASLA değiştirme. '
        'Kelime kelime değil, anlam odaklı çevir. '
        'Günlük konuşma diline uygun, doğal ve akıcı olsun.';

    Future<String?> generateWithRetry(String text) async {
      int attempts = 0;
      while (attempts < 3) {
        try {
          final result = await _callCloudTranslate(
            text: text,
            systemPrompt: systemPrompt,
            chargeKey: _effectiveChargeKey(null),
            approveCharge: true,
          );
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

    final ctx = (contextHint ?? '').trim();
    final srcHint = (sourceLanguageHint ?? '').trim();

    final systemPrompt = '''Sen Netflix standartlarında çalışan profesyonel bir altyazı çevirmenisin.
Görevin: Verilen SRT formatındaki altyazı bloklarını [${srcHint.isNotEmpty ? srcHint : 'Kaynak Dil'}]'den $targetLanguage diline çevirmek.

Kurallar:
1. Çeviriyi yaparken "çeviri kokan" cümlelerden kaçın. Hedef dilde ($targetLanguage) günlük hayatta nasıl konuşuluyorsa öyle yaz.
2. Deyimleri, argoları ve kültürel referansları kelimesi kelimesine değil, $targetLanguage kültüründeki en doğal karşılıklarıyla uyarla.
3. Cümleleri mümkün olduğunca kısa ve öz tut (altyazı okuma hızı için). Gereksiz dolgu kelimelerini at.
4. Karakterlerin duygusunu ve sahnenin tonunu yansıt. Resmiyetten uzak, samimi ve akıcı bir dil kullan.
5. SRT formatını (Zaman kodları ve Blok Numaraları) ASLA bozma ve değiştirmeden aynen koru.
${expectedBlockCount != null ? '6. Çıktıda tam olarak $expectedBlockCount blok olmalı.\n' : ''}${ctx.isNotEmpty ? 'Bağlam (Film/Dizi Bilgisi): $ctx\n' : ''}''';

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

    final hint = fileTitleYearHint.trim();
    final sample = sampleSrt.trim();
    final srcHint = (sourceLanguageHint ?? '').trim();
    if (hint.isEmpty || sample.isEmpty) return '';

    final systemPrompt = '''Sen profesyonel bir film altyazısı çeviri editörüsün.
  Elimde bir altyazı dosyası var ve onu parça parça çevireceğim.

  Amaç: SONRAKİ parçalarda sadece İSİM/TERİM tutarlılığı için kısa bir "terim hafızası" üret.
  - Dosya ipucu (film adı/yıl): $hint
  ${srcHint.isNotEmpty ? '- Kaynak dil olasılıkla: $srcHint\n' : ''}

  KURALLAR:
  1) Çıktı KISA olmalı (maksimum 1000 karakter).
  2) Sadece düz metin ver. Markdown, kod bloğu, açıklama ekleme.
  3) SADECE şunları üret:
     - Karakter/yer adları (SRT örneğinde geçiyorsa)
     - 8-15 adet terim/glossary tercihi (özellikle isimler, ünvanlar, argo, teknik kelimeler)
  4) Uydurma yapma; örnekte yoksa ekleme.
  5) Emin değilsen "OLDUĞU GİBİ BIRAK" de (placeholder üretme).
  6) Bu hafıza içerik üretmek için DEĞİL; metni yeniden yazdırmak için kullanılamaz.
  ''';

    final userPrompt = '''Aşağıdaki SRT örneğini incele ve yukarıdaki kurallara göre "çeviri hafızası" üret.
Hedef dil: $targetLanguage

SRT ÖRNEĞİ (sadece örnek):
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
        : '''Sen Netflix standartlarında çalışan profesyonel bir altyazı çevirmenisin.
Görevin: Aşağıdaki metni $targetLanguage diline çevirmek.
Kurallar:
1. Metni kelime kelime değil, anlam bütünlüğünü koruyarak doğal bir şekilde çevir.
2. Hedef dilin ($targetLanguage) günlük konuşma kalıplarını kullan.
3. Formatı koru.
4. Deyimleri ve kültürel öğeleri hedef dile uygun şekilde yerelleştir.''';
    
    // Cloud Function çağrısı
    final result = await _callCloudTranslate(
      text: text,
      systemPrompt: prompt,
      model: model // Server'a sadece bilgi olarak gider
    );
    
    return result;
  }
}
