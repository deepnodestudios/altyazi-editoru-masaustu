import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/ai_language_options.dart';
import '../services/gemini_service.dart';
import '../services/subtitle_parser.dart';
import '../services/subtitle_builder.dart';
import '../services/translation_language_guard.dart';
import '../models/subtitle_block.dart';
import '../repositories/subtitle_repository.dart';

class TranslationResumeState {
  final String hash;
  final String filePath;
  final String targetLanguage;
  final bool clearSdh;
  final String sourceContent;
  final String? sourceEncoding;
  final List<String> chunks;
  final int nextChunkIndex;
  final String translatedText;
  final List<SubtitleBlock> translatedBlocks;
  final int processedLines;
  final int totalLines;
  final int totalBlocks;
  final String? chargeKey;

  TranslationResumeState({
    required this.hash,
    required this.filePath,
    required String targetLanguage,
    required this.clearSdh,
    required this.sourceContent,
    this.sourceEncoding,
    required this.chunks,
    required this.nextChunkIndex,
    required this.translatedText,
    required this.translatedBlocks,
    required this.processedLines,
    required this.totalLines,
    required this.totalBlocks,
    this.chargeKey,
  }) : targetLanguage = normalizeAiPanelLanguageCode(targetLanguage);

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'hash': hash,
    'filePath': filePath,
    'targetLanguage': targetLanguage,
    'clearSdh': clearSdh,
    'sourceContent': sourceContent,
    'sourceEncoding': sourceEncoding,
    'chunks': chunks,
    'nextChunkIndex': nextChunkIndex,
    'translatedText': translatedText,
    'translatedBlocks': translatedBlocks.map((b) => b.toJson()).toList(),
    'processedLines': processedLines,
    'totalLines': totalLines,
    'totalBlocks': totalBlocks,
    'chargeKey': chargeKey,
  };

  // JSON deserialization
  factory TranslationResumeState.fromJson(Map<String, dynamic> json) {
    final sourceContent = (json['sourceContent'] as String?) ?? '';
    int totalBlocks = 0;
    final tbRaw = json['totalBlocks'];
    if (tbRaw is num) {
      totalBlocks = tbRaw.toInt();
    }
    if (totalBlocks <= 0 && sourceContent.trim().isNotEmpty) {
      totalBlocks = SubtitleParser.parseSrt(sourceContent).length;
    }

    return TranslationResumeState(
      hash: json['hash'] ?? '',
      filePath: json['filePath'] ?? '',
      targetLanguage: json['targetLanguage'] ?? 'Turkish',
      clearSdh: json['clearSdh'] ?? false,
      sourceContent: sourceContent,
      sourceEncoding: json['sourceEncoding'],
      chunks: List<String>.from(json['chunks'] ?? []),
      nextChunkIndex: json['nextChunkIndex'] ?? 0,
      translatedText: json['translatedText'] ?? '',
      translatedBlocks:
          (json['translatedBlocks'] as List?)
              ?.map((b) => SubtitleBlock.fromJson(b))
              .toList() ??
          [],
      processedLines: json['processedLines'] ?? 0,
      totalLines: json['totalLines'] ?? 0,
      totalBlocks: totalBlocks,
      chargeKey: (json['chargeKey'] as String?)?.trim().isEmpty == true
          ? null
          : json['chargeKey'] as String?,
    );
  }
}

enum _RepairCallKind { split, alignment, untranslated, wrongLanguage }

class TranslationEngine {
  final GeminiService _geminiService;
  final SubtitleRepository _subtitleRepository = SubtitleRepository();

  // Progress Events
  Function(int current, int total, {bool isComplete})? onProgress;
  Function(String key, [String? param])? onLog;
  Function(List<SubtitleBlock> blocks)? onTranslatedBlocksUpdate;

  /// Optional hook invoked right before a chunk is translated.
  /// Use this for hard preconditions like credit checks.
  Future<void> Function(int chunkIndex, int totalChunks)? onBeforeChunk;

  /// Optional hook invoked right after a chunk is translated and persisted.
  /// Use this for side effects that must happen only after first real output.
  Future<void> Function(int chunkIndex, int totalChunks)? onAfterChunkSuccess;

  bool _isCancelled = false;
  bool _isPaused = false;
  Completer<void>? _pauseCompleter;
  String? _lastDetectedEncoding;
  String? _lastError;
  List<SubtitleBlock> _latestRealBlocks = [];
  StringBuffer fullTranslation = StringBuffer();
  int _splitRepairCalls = 0;
  int _alignmentRepairCalls = 0;
  int _untranslatedRepairCalls = 0;
  int _wrongLanguageRetries = 0;
  int _repairBudgetInitial = 0;
  int _repairBudgetRemaining = 0;

  String? get lastDetectedEncoding => _lastDetectedEncoding;
  String? get lastError => _lastError;
  List<SubtitleBlock> get latestRealBlocks => _latestRealBlocks;

  /// Mirrors mobile engine: usage tracked inside [GeminiService].
  Map<String, dynamic> get usageSnapshot => {
        ..._geminiService.usageSnapshot,
        'splitRepairCalls': _splitRepairCalls,
        'alignmentRepairCalls': _alignmentRepairCalls,
        'untranslatedRepairCalls': _untranslatedRepairCalls,
        'wrongLanguageRetries': _wrongLanguageRetries,
        'repairBudgetInitial': _repairBudgetInitial,
        'repairBudgetRemaining': _repairBudgetRemaining,
      };
  void resetUsage() {
    _geminiService.resetUsage();
    _splitRepairCalls = 0;
    _alignmentRepairCalls = 0;
    _untranslatedRepairCalls = 0;
    _wrongLanguageRetries = 0;
    _repairBudgetInitial = 0;
    _repairBudgetRemaining = 0;
  }

  bool _reserveRepairCall(_RepairCallKind kind, {int count = 1}) {
    if (count <= 0) return true;
    if (_repairBudgetRemaining < count) {
      onLog?.call(
        'log_repair_budget_exhausted',
        jsonEncode({
          'initial': _repairBudgetInitial,
          'remaining': _repairBudgetRemaining,
          'requested': count,
          'kind': kind.name,
        }),
      );
      return false;
    }
    _repairBudgetRemaining -= count;
    switch (kind) {
      case _RepairCallKind.split:
        _splitRepairCalls += count;
      case _RepairCallKind.alignment:
        _alignmentRepairCalls += count;
      case _RepairCallKind.untranslated:
        _untranslatedRepairCalls += count;
      case _RepairCallKind.wrongLanguage:
        _wrongLanguageRetries += count;
    }
    return true;
  }

  TranslationEngine(this._geminiService);

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx >= 0 ? normalized.substring(idx + 1) : normalized;
  }

  static String _stripExtension(String name) {
    final idx = name.lastIndexOf('.');
    return idx > 0 ? name.substring(0, idx) : name;
  }

  static String _buildContextHintFromFilePath(String filePath) {
    final raw = _stripExtension(_basename(filePath));
    var s = raw;
    // Remove common bracketed tags.
    s = s.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    s = s.replaceAll(RegExp(r'\([^\)]*\)'), ' ');
    // Replace separators with spaces.
    s = s.replaceAll(RegExp(r'[._]+'), ' ');
    s = s.replaceAll('-', ' ');

    // Remove very common quality tags and language suffixes (best-effort).
    s = s.replaceAll(
      RegExp(
        r'\b(480p|720p|1080p|2160p|bluray|brrip|webrip|webdl|x264|x265|h264|h265|yts|dvdrip)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    s = s.replaceAll(
      RegExp(
        r'\b(greek|turkish|english|french|spanish|arabic|persian|russian)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';

    // If it contains a 4-digit year, format a bit nicer.
    final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(s);
    if (yearMatch != null) {
      final year = yearMatch.group(1);
      final title = s.replaceAll(RegExp(r'\b(19\d{2}|20\d{2})\b'), '').trim();
      if (title.isNotEmpty) return '$title ($year)';
    }

    return s;
  }

  static String? _guessSourceLanguageHint(String content) {
    // Very lightweight: if Greek letters are present, hint Greek.
    final sample = content.length > 12000
        ? content.substring(0, 12000)
        : content;
    if (_containsGreekLetters(sample)) return 'Greek';
    return null;
  }

  static bool _containsGreekLetters(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0370 && rune <= 0x03FF) ||
          (rune >= 0x1F00 && rune <= 0x1FFF)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsCyrillicLetters(String text) {
    for (final rune in text.runes) {
      // Cyrillic block + Cyrillic Supplement
      if ((rune >= 0x0400 && rune <= 0x052F) ||
          (rune >= 0x2DE0 && rune <= 0x2DFF) ||
          (rune >= 0xA640 && rune <= 0xA69F)) {
        return true;
      }
    }
    return false;
  }

  static int _countGreekLetters(String text) {
    int count = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x0370 && rune <= 0x03FF) ||
          (rune >= 0x1F00 && rune <= 0x1FFF)) {
        count++;
      }
    }
    return count;
  }

  static int _countCyrillicLetters(String text) {
    int count = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x0400 && rune <= 0x052F) ||
          (rune >= 0x2DE0 && rune <= 0x2DFF) ||
          (rune >= 0xA640 && rune <= 0xA69F)) {
        count++;
      }
    }
    return count;
  }

  static bool _containsAnyLikelyLetter(String text) {
    for (final rune in text.runes) {
      // Basic Latin letters
      if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
        return true;
      }
      // Latin-1 Supplement + Latin Extended-A/B (covers many European alphabets)
      if (rune >= 0x00C0 && rune <= 0x024F) {
        return true;
      }
      // Greek
      if ((rune >= 0x0370 && rune <= 0x03FF) ||
          (rune >= 0x1F00 && rune <= 0x1FFF)) {
        return true;
      }
      // Cyrillic
      if ((rune >= 0x0400 && rune <= 0x052F) ||
          (rune >= 0x2DE0 && rune <= 0x2DFF) ||
          (rune >= 0xA640 && rune <= 0xA69F)) {
        return true;
      }
      // Arabic
      if (rune >= 0x0600 && rune <= 0x06FF) {
        return true;
      }
      // Hebrew
      if (rune >= 0x0590 && rune <= 0x05FF) {
        return true;
      }
    }
    return false;
  }

  static bool _isMeaningfulSentenceLike(String text) {
    final norm = _normalizeForCompare(text);
    if (norm.length < 12) return false;
    if (!_containsAnyLikelyLetter(norm)) return false;
    // Avoid retranslating very short fragments / single words.
    final spaces = ' '.allMatches(norm).length;
    return spaces >= 2;
  }

  static String _normalizeForCompare(String text) {
    return text.replaceAll('\r', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Detects block-content drift: when the model merges two source blocks into
  /// one translated block (or vice versa), block COUNT stays equal but per-block
  /// line counts diverge. Returns true when a meaningful share of blocks drift.
  bool _hasSignificantLineAlignmentShift(
    List<SubtitleBlock> sourceBlocks,
    List<SubtitleBlock> translatedBlocks,
  ) {
    final mismatched =
        _lineAlignmentMismatchIndices(sourceBlocks, translatedBlocks);
    final n = sourceBlocks.length < translatedBlocks.length
        ? sourceBlocks.length
        : translatedBlocks.length;
    return n > 0 && mismatched.length >= 2 && mismatched.length / n > 0.15;
  }

  List<int> _lineAlignmentMismatchIndices(
    List<SubtitleBlock> sourceBlocks,
    List<SubtitleBlock> translatedBlocks,
  ) {
    final n = sourceBlocks.length < translatedBlocks.length
        ? sourceBlocks.length
        : translatedBlocks.length;
    final mismatched = <int>[];
    for (int i = 0; i < n; i++) {
      final srcLines = sourceBlocks[i].text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .length;
      final dstLines = translatedBlocks[i].text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .length;
      if (srcLines != dstLines) mismatched.add(i);
    }
    return mismatched;
  }

  /// Repairs only blocks whose line alignment drifted.
  Future<List<SubtitleBlock>> _translateBlocksIndividually({
    required List<SubtitleBlock> sourceBlocks,
    required List<SubtitleBlock> translatedBlocks,
    required List<int> repairIndices,
    required String targetLanguage,
    String? contextHint,
    String? sourceLanguageHint,
  }) async {
    final repaired = translatedBlocks
        .map((block) => SubtitleBlock(
              index: block.index,
              timecode: block.timecode,
              text: block.text,
            ))
        .toList();
    for (final i in repairIndices) {
      if (i < 0 || i >= sourceBlocks.length || i >= repaired.length) continue;
      if (!_reserveRepairCall(_RepairCallKind.alignment)) break;
      final src = sourceBlocks[i];
      try {
        final singleSrt = SubtitleBuilder.buildSrt([src]);
        final singleTranslated = await _geminiService.translateChunk(
          singleSrt,
          targetLanguage: targetLanguage,
          contextHint: contextHint,
          sourceLanguageHint: sourceLanguageHint,
          expectedBlockCount: 1,
        );
        final parsed = SubtitleParser.parseSrt(singleTranslated);
        if (parsed.length == 1) {
          repaired[i] = SubtitleBlock(
            index: i + 1,
            timecode: src.timecode,
            text: parsed.first.text.trim(),
          );
        }
      } catch (_) {
        // Best-effort repair only; keep existing translated block.
      }
    }
    return repaired;
  }

  Future<List<SubtitleBlock>> _fixLikelyUntranslatedBlocks({
    required List<SubtitleBlock> sourceBlocks,
    required List<SubtitleBlock> translatedBlocks,
    required String targetLanguage,
    String? contextHint,
    String? sourceLanguageHint,
  }) async {
    final lowerTarget = targetLanguage.toLowerCase();
    if (lowerTarget.contains('greek') || lowerTarget.contains('yunanca')) {
      return translatedBlocks;
    }

    // Only do a small number of targeted retries to avoid runaway cost.
    const maxFixesPerChunk = 20;
    int fixes = 0;

    for (
      int i = 0;
      i < sourceBlocks.length && i < translatedBlocks.length;
      i++
    ) {
      if (fixes >= maxFixesPerChunk) break;

      final src = sourceBlocks[i];
      final dst = translatedBlocks[i];

      final srcNorm = _normalizeForCompare(src.text);
      final dstNorm = _normalizeForCompare(dst.text);
      final bool unchanged = srcNorm.isNotEmpty && srcNorm == dstNorm;

      // Script-retention heuristics (helps when model keeps the original language).
      final bool srcHasGreek = _containsGreekLetters(src.text);
      final bool srcHasCyrillic = _containsCyrillicLetters(src.text);

      final bool stillMostlyGreek;
      if (srcHasGreek) {
        final int srcGreek = _countGreekLetters(src.text);
        final int dstGreek = _countGreekLetters(dst.text);
        stillMostlyGreek =
            dstGreek > 5 &&
            srcGreek > 5 &&
            dstGreek >= (srcGreek * 0.80).floor();
      } else {
        stillMostlyGreek = false;
      }

      final bool stillMostlyCyrillic;
      if (srcHasCyrillic) {
        final int srcCyr = _countCyrillicLetters(src.text);
        final int dstCyr = _countCyrillicLetters(dst.text);
        stillMostlyCyrillic =
            dstCyr > 5 && srcCyr > 5 && dstCyr >= (srcCyr * 0.80).floor();
      } else {
        stillMostlyCyrillic = false;
      }

      // General "unchanged" retry for sentence-like lines (works for Latin scripts too).
      final bool shouldRetryBecauseUnchanged =
          unchanged && _isMeaningfulSentenceLike(src.text);

      if (!shouldRetryBecauseUnchanged &&
          !stillMostlyGreek &&
          !stillMostlyCyrillic) {
        continue;
      }
      if (!_reserveRepairCall(_RepairCallKind.untranslated)) break;

      try {
        final singleSrt = SubtitleBuilder.buildSrt([src]);
        final singleTranslated = await _geminiService.translateChunk(
          singleSrt,
          targetLanguage: targetLanguage,
          contextHint: contextHint,
          sourceLanguageHint: sourceLanguageHint,
        );
        final parsed = SubtitleParser.parseSrt(singleTranslated);
        if (parsed.length == 1) {
          translatedBlocks[i].text = parsed.first.text;
          fixes++;
        }
      } catch (_) {
        // Ignore and keep best-effort translation.
      }
    }

    if (fixes > 0) {
      onLog?.call('log_retranslated_lines', jsonEncode({'count': fixes}));
    }

    return translatedBlocks;
  }

  Future<List<SubtitleBlock>> _retryIfOffTargetLanguage({
    required String chunk,
    required List<SubtitleBlock> expectedBlocks,
    required List<SubtitleBlock> translatedBlocks,
    required String targetLanguage,
    String? contextHint,
    String? sourceLanguageHint,
  }) async {
    final sample = SubtitleBuilder.buildSrt(translatedBlocks);
    if (!translationLooksOffTarget(sample, targetLanguage)) {
      return translatedBlocks;
    }

    onLog?.call(
      'log_wrong_language_retry',
      jsonEncode({
        'target': targetLanguage,
        'blocks': expectedBlocks.length,
      }),
    );
    if (!_reserveRepairCall(_RepairCallKind.wrongLanguage)) {
      return translatedBlocks;
    }

    try {
      final retryTranslated = await _geminiService.translateChunk(
        chunk,
        targetLanguage: targetLanguage,
        contextHint: wrongLanguageRetryHint(
          existingContextHint: contextHint,
          targetLanguage: targetLanguage,
        ),
        sourceLanguageHint: sourceLanguageHint,
        expectedBlockCount: expectedBlocks.length,
      );
      final retryParsed = SubtitleParser.parseSrt(retryTranslated);
      if (retryParsed.length != expectedBlocks.length) {
        return translatedBlocks;
      }
      _alignTranslatedBlocksToSource(expectedBlocks, retryParsed);
      return retryParsed;
    } catch (_) {
      return translatedBlocks;
    }
  }

  Future<({String srt, List<SubtitleBlock> blocks})>
      _translateSrtChunkResilient(
    String chunk, {
    required String targetLanguage,
    String? contextHint,
    String? sourceLanguageHint,
    int depth = 0,
  }) async {
    final expectedBlocks = SubtitleParser.parseSrt(chunk);
    final expectedCount = expectedBlocks.length;

    String translated = '';
    List<SubtitleBlock> parsed = [];
    bool forceSplit = false;

    try {
      translated = await _geminiService.translateChunk(
        chunk,
        targetLanguage: targetLanguage,
        contextHint: contextHint,
        sourceLanguageHint: sourceLanguageHint,
      );
      parsed = SubtitleParser.parseSrt(translated);
    } catch (e) {
      final err = e.toString();
      final isSafetyBlocked = err.contains('PROHIBITED') ||
          err.contains('PromptFeedback') ||
          err.contains('blockReason');

      if (isSafetyBlocked && expectedCount > 1 && depth < 5) {
        onLog?.call('log_safety_filter_retry', jsonEncode({'depth': depth}));
        forceSplit = true;
      } else if (isSafetyBlocked) {
        onLog?.call(
          'log_safety_filter_fallback',
          jsonEncode({'depth': depth, 'blocks': expectedCount}),
        );
        return (
          srt: SubtitleBuilder.buildSrt(expectedBlocks),
          blocks: expectedBlocks,
        );
      } else {
        rethrow;
      }
    }

    if (!forceSplit) {
      if (expectedCount == 0) {
        return (srt: translated, blocks: parsed);
      }

      if (parsed.length == expectedCount) {
        _alignTranslatedBlocksToSource(expectedBlocks, parsed);
        final languageFixed = await _retryIfOffTargetLanguage(
          chunk: chunk,
          expectedBlocks: expectedBlocks,
          translatedBlocks: parsed,
          targetLanguage: targetLanguage,
          contextHint: contextHint,
          sourceLanguageHint: sourceLanguageHint,
        );
        final fixedBlocks = await _fixLikelyUntranslatedBlocks(
          sourceBlocks: expectedBlocks,
          translatedBlocks: languageFixed,
          targetLanguage: targetLanguage,
          contextHint: contextHint,
          sourceLanguageHint: sourceLanguageHint,
        );
        if (!_hasSignificantLineAlignmentShift(expectedBlocks, fixedBlocks)) {
          return (
            srt: SubtitleBuilder.buildSrt(fixedBlocks),
            blocks: fixedBlocks,
          );
        }
        // Line alignment shifted (model merged/split blocks): repair block-by-block.
        onLog?.call(
          'log_line_alignment_shift',
          jsonEncode({'blocks': expectedCount, 'depth': depth}),
        );
        final repaired = await _translateBlocksIndividually(
          sourceBlocks: expectedBlocks,
          translatedBlocks: fixedBlocks,
          repairIndices:
              _lineAlignmentMismatchIndices(expectedBlocks, fixedBlocks),
          targetLanguage: targetLanguage,
          contextHint: contextHint,
          sourceLanguageHint: sourceLanguageHint,
        );
        return (
          srt: SubtitleBuilder.buildSrt(repaired),
          blocks: repaired,
        );
      }
    }

    // One retry with an explicit block-count constraint before splitting.
    if (!forceSplit &&
        expectedCount > 0 &&
        _reserveRepairCall(_RepairCallKind.alignment)) {
      try {
        final retryTranslated = await _geminiService.translateChunk(
          chunk,
          targetLanguage: targetLanguage,
          contextHint: contextHint,
          sourceLanguageHint: sourceLanguageHint,
          expectedBlockCount: expectedCount,
        );
        final retryParsed = SubtitleParser.parseSrt(retryTranslated);
        if (retryParsed.length == expectedCount) {
          _alignTranslatedBlocksToSource(expectedBlocks, retryParsed);
          final languageFixed = await _retryIfOffTargetLanguage(
            chunk: chunk,
            expectedBlocks: expectedBlocks,
            translatedBlocks: retryParsed,
            targetLanguage: targetLanguage,
            contextHint: contextHint,
            sourceLanguageHint: sourceLanguageHint,
          );
          final fixedBlocks = await _fixLikelyUntranslatedBlocks(
            sourceBlocks: expectedBlocks,
            translatedBlocks: languageFixed,
            targetLanguage: targetLanguage,
            contextHint: contextHint,
            sourceLanguageHint: sourceLanguageHint,
          );
          if (!_hasSignificantLineAlignmentShift(expectedBlocks, fixedBlocks)) {
            return (
              srt: SubtitleBuilder.buildSrt(fixedBlocks),
              blocks: fixedBlocks,
            );
          }
          onLog?.call(
            'log_line_alignment_shift',
            jsonEncode({'blocks': expectedCount, 'depth': depth}),
          );
          final repaired = await _translateBlocksIndividually(
            sourceBlocks: expectedBlocks,
            translatedBlocks: fixedBlocks,
            repairIndices:
                _lineAlignmentMismatchIndices(expectedBlocks, fixedBlocks),
            targetLanguage: targetLanguage,
            contextHint: contextHint,
            sourceLanguageHint: sourceLanguageHint,
          );
          return (
            srt: SubtitleBuilder.buildSrt(repaired),
            blocks: repaired,
          );
        }
      } catch (_) {
        // ignore and fall back to splitting
      }
    }

    // If the model dropped blocks (often due to truncation), split and translate smaller pieces.
    if ((forceSplit || expectedCount > 1) &&
        depth < 5 &&
        _reserveRepairCall(_RepairCallKind.split, count: 2)) {
      onLog?.call(
        'log_block_count_mismatch',
        jsonEncode({'expected': expectedCount, 'got': parsed.length}),
      );
      final mid = expectedCount ~/ 2;
      final left = SubtitleBuilder.buildSrt(expectedBlocks.sublist(0, mid));
      final right = SubtitleBuilder.buildSrt(expectedBlocks.sublist(mid));

      final leftResult = await _translateSrtChunkResilient(
        left,
        targetLanguage: targetLanguage,
        contextHint: contextHint,
        sourceLanguageHint: sourceLanguageHint,
        depth: depth + 1,
      );
      final rightResult = await _translateSrtChunkResilient(
        right,
        targetLanguage: targetLanguage,
        contextHint: contextHint,
        sourceLanguageHint: sourceLanguageHint,
        depth: depth + 1,
      );

      final combinedBlocks = <SubtitleBlock>[
        ...leftResult.blocks,
        ...rightResult.blocks,
      ];
      return (
        srt: SubtitleBuilder.buildSrt(combinedBlocks),
        blocks: combinedBlocks,
      );
    }

    // Last resort: don't lose content. If parsing returned something, use it; otherwise keep original.
    onLog?.call(
      'log_translation_unverified',
      jsonEncode({'expected': expectedCount, 'got': parsed.length}),
    );
    if (parsed.isNotEmpty) {
      // Best-effort alignment even when counts mismatch.
      final minLen = parsed.length < expectedBlocks.length
          ? parsed.length
          : expectedBlocks.length;
      if (minLen > 0) {
        _alignTranslatedBlocksToSource(
          expectedBlocks.sublist(0, minLen),
          parsed.sublist(0, minLen),
        );
      }
      return (srt: SubtitleBuilder.buildSrt(parsed), blocks: parsed);
    }
    return (
      srt: SubtitleBuilder.buildSrt(expectedBlocks),
      blocks: expectedBlocks,
    );
  }

  void _alignTranslatedBlocksToSource(
    List<SubtitleBlock> sourceBlocks,
    List<SubtitleBlock> translatedBlocks,
  ) {
    final n = sourceBlocks.length < translatedBlocks.length
        ? sourceBlocks.length
        : translatedBlocks.length;

    for (int i = 0; i < n; i++) {
      final src = sourceBlocks[i];
      final dst = translatedBlocks[i];

      // Always trust original timecodes.
      dst.timecode = src.timecode;

      // Avoid adding surrounding quotes when the source doesn't have them.
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
        cleaned = cleaned.replaceFirst(RegExp(r'\s*("|”|»)\s*$'), '');
        dst.text = cleaned.trim();
      }

      // Try to preserve the source line count per block.
      final srcLineCount = src.text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .length;
      if (srcLineCount <= 1) {
        // Normalize excessive newlines into single newline only when source is single-line.
        dst.text = dst.text.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
        continue;
      }

      final dstLines = dst.text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (dstLines.length == srcLineCount) continue;

      final flat = dst.text
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (flat.isEmpty) continue;

      final words = flat.split(' ');
      final targetLines = <String>[];
      final totalChars = flat.length;
      final approxPerLine = (totalChars / srcLineCount).ceil();

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
      if (current.isNotEmpty) targetLines.add(current.toString().trim());

      // If we still didn't hit the desired line count, don't force it too hard.
      // Best-effort: join/split once.
      if (targetLines.isNotEmpty) {
        // Ensure exactly srcLineCount by merging extras into the last line.
        if (targetLines.length > srcLineCount) {
          final head = targetLines.sublist(0, srcLineCount - 1);
          final tail = targetLines.sublist(srcLineCount - 1).join(' ');
          dst.text = [...head, tail].join('\n');
        } else if (targetLines.length < srcLineCount) {
          // Pad by splitting the last line if possible.
          while (targetLines.length < srcLineCount && targetLines.isNotEmpty) {
            final last = targetLines.removeLast();
            final parts = last.split(' ');
            if (parts.length <= 2) {
              targetLines.add(last);
              break;
            }
            final mid = parts.length ~/ 2;
            targetLines.add(parts.sublist(0, mid).join(' '));
            targetLines.add(parts.sublist(mid).join(' '));
          }
          dst.text = targetLines.take(srcLineCount).join('\n');
        } else {
          dst.text = targetLines.join('\n');
        }
      }
    }
  }

  String _normalizePathForCompare(String path) {
    final normalized = path.replaceAll('/', Platform.pathSeparator);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  /// Writes the accumulated translation as a full replace.
  /// Resume/retry must not append onto a leftover file — that stacks duplicate
  /// cues with the same timestamps (Antboy-style overlay).
  Future<void> _rewriteOutputFile(
    File? outputFile,
    StringBuffer fullTranslation,
    List<SubtitleBlock> translatedBlocks,
  ) async {
    if (outputFile == null) return;
    var content = fullTranslation.toString();
    if (content.trim().isEmpty && translatedBlocks.isNotEmpty) {
      content = SubtitleBuilder.buildSrt(translatedBlocks, resequence: false);
      fullTranslation
        ..clear()
        ..write(content);
    }
    await outputFile.writeAsString(content);
  }

  void _logResumeDebug(String message) {
    onLog?.call('log_resume_debug', jsonEncode({'message': message}));
  }

  void pause() {
    _isPaused = true;
    _pauseCompleter = Completer<void>();
    onLog?.call('log_translation_paused');
  }

  void resume() {
    _isPaused = false;
    _pauseCompleter?.complete();
    _pauseCompleter = null;
    onLog?.call('log_translation_resumed');
  }

  void cancel() {
    _isCancelled = true;
    // Resume Pause if necessary to break loop
    if (_isPaused && _pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
  }

  Future<TranslationResumeState?> runTranslation({
    required File file,
    required String hash,
    required String targetLanguage,
    required bool clearSdh,
    File? outputFile,
    TranslationResumeState? resumeState,
    String? chargeKey,
  }) async {
    _isCancelled = false;
    resetUsage();

    // 1. Prepare Content
    String content;
    List<SubtitleBlock> translatedBlocks = [];
    StringBuffer fullTranslation = StringBuffer();

    // Check for Resume
    final filePath = _normalizePathForCompare(file.path);
    final resumePath = resumeState == null
        ? null
        : _normalizePathForCompare(resumeState.filePath);
    final languageMatches =
        resumeState != null &&
        aiPanelLanguageCodesEqual(resumeState.targetLanguage, targetLanguage);
    final isResuming =
        resumeState != null &&
        resumeState.hash == hash &&
        languageMatches &&
        resumePath == filePath;

    if (resumeState != null && !isResuming) {
      _logResumeDebug(
        'engine mismatch '
        'hashMatch=${resumeState.hash == hash} '
        'langMatch=$languageMatches '
        'pathMatch=${resumePath == filePath} '
        'fileRaw=${file.path} resumeRaw=${resumeState.filePath} '
        'fileNorm=$filePath resumeNorm=$resumePath',
      );
    }

    if (isResuming) {
      content = resumeState.sourceContent;
      _lastDetectedEncoding = resumeState.sourceEncoding;
      onLog?.call(
        'log_resume_continue',
        jsonEncode({
          'index': resumeState.nextChunkIndex,
          'blocks': resumeState.translatedBlocks.length,
          'done': resumeState.processedLines,
          'total': resumeState.totalLines,
        }),
      );
    } else {
      final result = await _subtitleRepository.readFileWithEncoding(file.path);
      content = result.content;
      _lastDetectedEncoding = result.encoding;
      if (clearSdh) {
        onLog?.call('log_sdh_cleaning');
        content = SubtitleParser.clearSdh(content);
      }
    }

    final contextHint = _buildContextHintFromFilePath(file.path);
    final sourceLanguageHint = _guessSourceLanguageHint(content);

    // One-time context priming: ask Gemini to infer movie/characters/terminology from
    // filename title/year + a short sample. Then reuse across all chunks.
    String translationMemory = '';
    try {
      if (contextHint.isNotEmpty) {
        final blocks = SubtitleParser.parseSrt(content);
        final sampleBlocks = blocks.length > 24
            ? blocks.sublist(0, 24)
            : blocks;
        final sampleSrt = SubtitleBuilder.buildSrt(sampleBlocks);
        translationMemory = await _geminiService.buildTranslationMemory(
          fileTitleYearHint: contextHint,
          sampleSrt: sampleSrt,
          targetLanguage: targetLanguage,
          sourceLanguageHint: sourceLanguageHint,
        );
        if (translationMemory.trim().isNotEmpty) {
          onLog?.call('log_context_memory_built');
        }
      }
    } catch (_) {
      // Best-effort only; continue without memory.
    }

    final combinedContextHint = (() {
      final base = contextHint.trim();
      final mem = translationMemory.trim();
      if (base.isEmpty && mem.isEmpty) return '';
      if (mem.isEmpty) return base;
      return '$base\n\nTerim hafızası (isim/terimler):\n$mem';
    })();

    // 2. Prepare Counts
    // Progress must be based on subtitle *block* counts (not newline counts),
    // otherwise History % (which is block-based) and the progress bar drift.
    final int totalLines;
    int processedLines;

    final contentBlockCount = SubtitleParser.parseSrt(content).length;
    final resumeTotalBlocks = isResuming ? resumeState.totalBlocks : 0;
    final totalBlocksForProgress = (resumeTotalBlocks > 0)
        ? resumeTotalBlocks
        : contentBlockCount;
    final processedBlocksForProgress = isResuming
        ? resumeState.translatedBlocks.length
        : 0;

    totalLines = totalBlocksForProgress;
    processedLines = processedBlocksForProgress;

    onProgress?.call(processedLines, totalLines, isComplete: false);

    // 3. Prepare Chunks
    final List<String> chunks;
    int chunkIndex;

    if (isResuming) {
      final sourceBlocks = SubtitleParser.parseSrt(content);
      final alreadyCount = resumeState.translatedBlocks.length;

      // EĞER ÇEVİRİ YARIM KALMIŞSA MOBİL-MASAÜSTÜ FARK ETMEKSİZİN KALANLARI YENİDEN HESAPLA!
      if (alreadyCount > 0 && alreadyCount < sourceBlocks.length) {
        final remainingBlocks = sourceBlocks.sublist(alreadyCount);
        final remainingSrt = SubtitleBuilder.buildSrt(remainingBlocks);

        final isDesktop =
            !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
        chunks = await compute(
          isDesktop
              ? SubtitleParser.buildSrtChunksAdaptiveDesktop
              : SubtitleParser.buildSrtChunksAdaptive,
          remainingSrt,
        );
        chunkIndex = 0;

        _logResumeDebug(
          'cross-platform resume: alreadyBlocks=$alreadyCount totalBlocks=${sourceBlocks.length} remainingBlocks=${remainingBlocks.length} chunks=${chunks.length}',
        );
      } else {
        chunks = resumeState.chunks;
        chunkIndex = resumeState.nextChunkIndex;
      }

      if (alreadyCount > 0 ||
          (resumeState.nextChunkIndex > 0 &&
              resumeState.translatedText.trim().isNotEmpty)) {
        fullTranslation.write(resumeState.translatedText);
        translatedBlocks =
            List<SubtitleBlock>.from(resumeState.translatedBlocks);
      } else {
        _logResumeDebug(
          'resume from start: discarding stale output so a full rerun does not concatenate',
        );
      }
      _latestRealBlocks = List<SubtitleBlock>.from(translatedBlocks);
      await _rewriteOutputFile(
        outputFile,
        fullTranslation,
        translatedBlocks,
      );
    } else {
      onLog?.call('log_translation_chunks_preparing');
      // İşlemi arka planda (isolate) yaparak arayüzün donmasını engelliyoruz
      final isDesktop =
          !kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
      chunks = await compute(
        isDesktop
            ? SubtitleParser.buildSrtChunksAdaptiveDesktop
            : SubtitleParser.buildSrtChunksAdaptive,
        content,
      );
      chunkIndex = 0;
      // Clean output file
      if (outputFile != null && await outputFile.exists()) {
        await outputFile.delete();
      }
    }

    _repairBudgetInitial =
        (chunks.length / 2).ceil().clamp(4, 16);
    _repairBudgetRemaining = _repairBudgetInitial;
    if (chunks.isNotEmpty) {
      onLog?.call(
        'log_translation_start_chunks',
        jsonEncode({'chunkCount': chunks.length}),
      );
    }

    TranslationResumeState buildResumeState(int nextChunkIndex) {
      final int totalBlocks = isResuming
          ? (resumeState.totalBlocks > 0
                ? resumeState.totalBlocks
                : SubtitleParser.parseSrt(content).length)
          : SubtitleParser.parseSrt(content).length;
      return TranslationResumeState(
        hash: hash,
        filePath: file.path,
        targetLanguage: targetLanguage,
        clearSdh: clearSdh,
        sourceContent: content,
        sourceEncoding: _lastDetectedEncoding,
        chunks: chunks,
        nextChunkIndex: nextChunkIndex,
        translatedText: fullTranslation.toString(),
        translatedBlocks: translatedBlocks,
        processedLines: processedLines,
        totalLines: totalLines,
        totalBlocks: totalBlocks,
        chargeKey: chargeKey ?? resumeState?.chargeKey,
      );
    }

    // 4. Processing Loop
    Future<void> displayAnimationFuture = Future.value();
    List<SubtitleBlock> previewBlocks = List.from(translatedBlocks);
    int previewProcessedLines = processedLines;

    for (; chunkIndex < chunks.length; chunkIndex++) {
      if (_isCancelled) {
        onLog?.call('log_translation_cancelled');
        return null;
      }

      onLog?.call(
        'log_translation_chunk_begin',
        jsonEncode({'chunkIndex': chunkIndex + 1, 'chunkTotal': chunks.length}),
      );

      if (_isPaused) {
        onLog?.call('log_translation_waiting_resume');
        await _pauseCompleter?.future;
      }

      // Hard precondition checks (e.g., credits) before doing any network work.
      if (onBeforeChunk != null) {
        try {
          onLog?.call(
            'log_translation_before_chunk_hook_start',
            jsonEncode({
              'chunkIndex': chunkIndex + 1,
              'chunkTotal': chunks.length,
            }),
          );
          await onBeforeChunk!(chunkIndex, chunks.length);
          onLog?.call(
            'log_translation_before_chunk_hook_done',
            jsonEncode({
              'chunkIndex': chunkIndex + 1,
              'chunkTotal': chunks.length,
            }),
          );
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('Yetersiz')) {
            _lastError = 'Yetersiz bakiye';
            onLog?.call('log_insufficient_credit_stop');
            return buildResumeState(chunkIndex);
          }
          rethrow;
        }
      }

      final chunk = chunks[chunkIndex];
      const maxRetries = 8; // Bağlantı sorunları için daha fazla deneme
      int attempt = 0;

      while (true) {
        if (_isCancelled) {
          onLog?.call('log_translation_cancelled');
          return null;
        }

        try {
          final startedAt = DateTime.now();
          onLog?.call(
            'log_translation_chunk_call_start',
            jsonEncode({
              'chunkIndex': chunkIndex + 1,
              'chunkTotal': chunks.length,
            }),
          );
          final result = await _translateSrtChunkResilient(
            chunk,
            targetLanguage: targetLanguage,
            contextHint: combinedContextHint.isEmpty
                ? null
                : combinedContextHint,
            sourceLanguageHint: sourceLanguageHint,
          );
          final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
          onLog?.call(
            'log_translation_chunk_call_done',
            jsonEncode({
              'chunkIndex': chunkIndex + 1,
              'chunkTotal': chunks.length,
              'elapsedMs': elapsedMs,
            }),
          );
          final newBlocks = result.blocks;

          // Adjust indices
          for (int i = 0; i < newBlocks.length; i++) {
            newBlocks[i].index = translatedBlocks.length + i + 1;
          }
          translatedBlocks.addAll(newBlocks);
          _latestRealBlocks = List<SubtitleBlock>.from(translatedBlocks);

          // IMPORTANT: When writing chunks incrementally, preserve the globally-adjusted
          // indices. Otherwise each chunk will restart at 1 and the output SRT will have
          // repeated sequence numbers.
          final translatedChunkForOutput = SubtitleBuilder.buildSrt(
            newBlocks,
            resequence: false,
          );

          fullTranslation.write(translatedChunkForOutput);
          await _rewriteOutputFile(
            outputFile,
            fullTranslation,
            translatedBlocks,
          );

          processedLines += newBlocks.length;

          // UI animasyonunu asenkron yürüt:
          // Bu sayede fonksiyon hemen 'break' yapıp sonraki chunk'ı indirmeye başlayacak.
          // Blokların ekrana gelme süresi, api isteğinin uzunluğuna göre bekleme süresine (next chunk zamanına) yayılıyor.
          final blocksToAnimate = List<SubtitleBlock>.from(newBlocks);
          // elapsedMs o chunk'ın inme süresi. UI animasyonunu totalde bu süreye yay.
          final chunkTotalDelayMs = (elapsedMs * 0.9).clamp(
            2000,
            15000,
          ); // çok uzarsa da en fazla 15sn'ye böl
          final defaultDelayMs = blocksToAnimate.isNotEmpty
              ? (chunkTotalDelayMs ~/ blocksToAnimate.length)
              : 0;

          displayAnimationFuture = displayAnimationFuture.then((_) async {
            for (final block in blocksToAnimate) {
              if (_isCancelled) break;
              previewBlocks.add(block);
              previewProcessedLines++;

              // Önizleme için indeksleri hep sıralı tutalım
              for (int j = 0; j < previewBlocks.length; j++) {
                previewBlocks[j].index = j + 1;
              }

              onTranslatedBlocksUpdate?.call(
                List<SubtitleBlock>.from(previewBlocks),
              );
              onProgress?.call(
                previewProcessedLines,
                totalLines,
                isComplete: false,
              );

              await Future.delayed(
                Duration(milliseconds: defaultDelayMs.toInt()),
              );
            }
          });

          if (onAfterChunkSuccess != null) {
            try {
              await onAfterChunkSuccess!(chunkIndex, chunks.length);
            } catch (e) {
              final msg = e.toString();
              _lastError = msg;
              if (msg.contains('Yetersiz')) {
                onLog?.call('log_insufficient_credit_stop');
              }
              onLog?.call('log_error_state_saving');
              return buildResumeState(chunkIndex + 1);
            }
          }
          break; // Success, move to next chunk
        } catch (e) {
          attempt++;
          final isTransient = _isTransientNetworkError(e);

          if (isTransient) {
            final online = await _hasInternetConnection();
            if (!online) {
              _lastError = 'İnternet bağlantısı yok';
              onLog?.call('log_no_internet_stop');
              onLog?.call('log_error_state_saving');
              return buildResumeState(chunkIndex);
            }
          }

          final exceededRetries = attempt > maxRetries;

          if (exceededRetries || !isTransient) {
            // Return State to Controller for saving
            final raw = e.toString();
            final errorMsg = raw.length > 700
                ? '${raw.substring(0, 700)}…'
                : raw;
            _lastError = '${e.runtimeType}: $errorMsg';
            onLog?.call(
              exceededRetries
                  ? 'log_max_retry_state_saving'
                  : 'log_error_state_saving',
            );
            onLog?.call('log_error_detail', jsonEncode({'error': _lastError}));
            return buildResumeState(chunkIndex);
          }

          final waitSeconds =
              3 + (attempt * 2); // Artan bekleme süresi: 5s, 7s, 9s...
          onLog?.call(
            'log_retrying_after_error',
            jsonEncode({
              'type': e.runtimeType.toString(),
              'seconds': waitSeconds,
              'attempt': attempt,
              'max': maxRetries,
            }),
          );
          await Future.delayed(Duration(seconds: waitSeconds));
        }
      }
    }

    if (_isCancelled) return null;

    // Wait for any remaining UI animation to finish smoothly
    await displayAnimationFuture;

    onProgress?.call(totalLines, totalLines, isComplete: true);
    return null; // Completed successfully, no resume state needed
  }

  bool _isTransientNetworkError(Object e) {
    final errorString = e.toString().toLowerCase();
    return e is SocketException ||
        e is TimeoutException ||
        e is HandshakeException ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504');
  }
}
