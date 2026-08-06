import codecs
import re

with open(r'lib\services\gemini_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

helper = """  Future<Map<String, dynamic>> _callCloudFunctionViaHttp(String functionName, Map<String, dynamic> data) async {
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

    http.Response response;
    try {
      final timeout = io_platform.isDesktop
          ? const Duration(minutes: 4)
          : const Duration(minutes: 2);
      response = await http.post(endpoint, headers: headers, body: payload).timeout(timeout);
    } catch (e) {
      throw Exception('Bağlantı Hatası: $e');
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
"""

if "_callCloudFunctionViaHttp" not in text:
    idx = text.find("/// BATCH API METODLARI ///")
    text = text[:idx] + helper + "\n  " + text[idx:]

old_check = """  Future<Map<String, dynamic>> checkBatchTranslationStatus({
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
  }"""

new_check = """  Future<Map<String, dynamic>> checkBatchTranslationStatus({
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
  }"""

text = text.replace(old_check, new_check)

old_start = """    Future<String> attemptCall() async {
      final callable = _functions.httpsCallable('startBatchTranslation');
      final result = await callable.call({
        'chunks': chunks,
        'systemPrompt': systemPrompt,
        'deviceId': _deviceId,
        if (_chargeKey != null && _chargeKey!.trim().isNotEmpty)
          'chargeKey': _chargeKey,
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
      });

      final data = result.data as Map;
      if (data['success'] == true) {
        return data['jobName'] as String;
      }
      throw Exception('Failed to start batch job');
    }"""

new_start = """    Future<String> attemptCall() async {
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
    }"""

text = text.replace(old_start, new_start)

with open(r'lib\services\gemini_service.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Check successfully patched!")
