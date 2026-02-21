import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/subtitle_block.dart';
import 'gemini_service.dart';
import 'subtitle_parser.dart';

/// Çeviri işlemlerini yöneten servis
/// Gemini API entegrasyonu ile çalışır
class TranslationService extends ChangeNotifier {
  final GeminiService _geminiService;
  
  Function(String key, [String? param])? onLog;
  
  TranslationService(this._geminiService);

  /// Batch çeviri yap (birden fazla altyazı bloğu)
  Future<List<SubtitleBlock>> translateBatch(
    List<SubtitleBlock> batch, {
    required String targetLanguage,
    required String model,
    required String apiKey,
    required List<String> ignoredWords,
    required Set<String> keptWords,
    String systemPrompt = '',
  }) async {
    final List<SubtitleBlock> results = [];
    int currentOutputIndex = 1;

    try {
      // Batch içeriğini hazırla
      final StringBuffer sb = StringBuffer();
      for (final block in batch) {
        sb.writeln("${block.index}|${block.timecode}|${block.text}");
      }
      final String batchText = sb.toString();

      final effectiveSystemPrompt = systemPrompt.isNotEmpty
          ? systemPrompt
          : '''Sen Netflix standartlarında çalışan profesyonel bir altyazı çevirmenisin.
Görevin: Aşağıdaki "ID|Zaman|Metin" formatındaki satırların SADECE "Metin" kısımlarını $targetLanguage diline çevirmek.

Kurallar:
1. ASLA kelime kelime çeviri yapma. Anlama ve bağlama odaklan.
2. Deyimleri ve argoları $targetLanguage kültürüne uyarla.
3. Resmiyetten kaçın, doğal ve akıcı bir dil kullan.
4. Çıktı formatı KESİNLİKLE "ID|Zaman|Çeviri" şeklinde olmalı.
5. Satır sayısını ve ID'leri değiştirme.''';

      // Çeviri yap
      final response = await _geminiService.translate(
        text: batchText,
        targetLanguage: targetLanguage,
        model: model,
        apiKey: apiKey,
        systemPrompt: effectiveSystemPrompt,
        ignoredWords: ignoredWords,
      );

      // Yanıtı parse et
      final lines = response.text.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        final parts = line.split('|');
        if (parts.length >= 3) {
          try {
            final timecode = parts[1].trim();
            final text = parts.sublist(2).join('|').trim();

            // Maskelenmiş kelimeleri geri yükle
            String restoredText = text;
            for (int i = 0; i < ignoredWords.length; i++) {
              restoredText = restoredText.replaceAll(
                RegExp('\\[\\s*\\[\\s*$i\\s*\\]\\s*\\]'),
                ignoredWords[i],
              );
            }

            results.add(SubtitleBlock(
              index: currentOutputIndex,
              timecode: timecode,
              text: restoredText,
            ));
            currentOutputIndex++;
          } catch (e) {
            onLog?.call('log_line_parse_error', jsonEncode({'error': e.toString()}));
          }
        }
      }

      return results;
    } catch (e) {
      onLog?.call('log_translation_error', jsonEncode({'error': e.toString()}));
      rethrow;
    }
  }

  /// Tekli çeviri yap (tek altyazı bloğu)
  Future<SubtitleBlock> translateSingle(
    SubtitleBlock block, {
    required String targetLanguage,
    required String model,
    required String apiKey,
    required List<String> ignoredWords,
    String systemPrompt = '',
  }) async {
    try {
      // Metni hazırla
      String textToTranslate = block.text.replaceAll('\n', ' ');
      
      // Maskeleme uygula
      String maskedText = textToTranslate;
      for (int i = 0; i < ignoredWords.length; i++) {
        String word = ignoredWords[i];
        if (maskedText.toLowerCase().contains(word.toLowerCase())) {
          maskedText = maskedText.replaceAll(
            RegExp(RegExp.escape(word), caseSensitive: false),
            "[[$i]]",
          );
        }
      }

      // Çevir
      final response = await _geminiService.translate(
        text: maskedText,
        targetLanguage: targetLanguage,
        model: model,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        ignoredWords: [],
      );

      // Maskeleri geri yükle
      String translatedText = response.text;
      for (int i = 0; i < ignoredWords.length; i++) {
        translatedText = translatedText.replaceAll(
          RegExp('\\[\\s*\\[\\s*$i\\s*\\]\\s*\\]'),
          ignoredWords[i],
        );
      }

      return SubtitleBlock(
        index: block.index,
        timecode: block.timecode,
        text: translatedText,
      );
    } catch (e) {
      onLog?.call('log_single_translation_error', jsonEncode({'error': e.toString()}));
      rethrow;
    }
  }

  /// SDH temizleme (yalnızca parantez/köşeli parantez içi açıklamalar)
  Future<List<SubtitleBlock>> cleanSDH(List<SubtitleBlock> blocks) async {
    final List<SubtitleBlock> cleaned = [];
    
    int currentIndex = 1;
    for (final block in blocks) {
      final cleanedText = SubtitleParser.normalizeSdhCleanedText(block.text);
      if (SubtitleParser.hasMeaningfulDialogueText(cleanedText)) {
        cleaned.add(SubtitleBlock(
          index: currentIndex,
          timecode: block.timecode,
          text: cleanedText,
        ));
        currentIndex++;
      }
    }
    
    return cleaned;
  }

  /// Batch boyutunu optimize et (token limitlerine göre)
  int calculateOptimalBatchSize({
    required List<SubtitleBlock> blocks,
    required int maxTokens,
    int averageCharsPerToken = 4,
  }) {
    if (blocks.isEmpty) return 0;

    int totalChars = 0;
    int batchSize = 0;

    for (final block in blocks) {
      final blockChars = block.text.length + block.timecode.length + 10; // Padding for formatting
      if ((totalChars + blockChars) / averageCharsPerToken > maxTokens) {
        break;
      }
      totalChars += blockChars;
      batchSize++;
    }

    return batchSize > 0 ? batchSize : 1; // En az 1
  }
}
