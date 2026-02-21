import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/gemini_service.dart';
import '../services/subtitle_parser.dart';
import '../services/subtitle_builder.dart';
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
    required this.targetLanguage,
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
  });

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
      translatedBlocks: (json['translatedBlocks'] as List?)
        ?.map((b) => SubtitleBlock.fromJson(b))
        .toList() ?? [],
      processedLines: json['processedLines'] ?? 0,
      totalLines: json['totalLines'] ?? 0,
      totalBlocks: totalBlocks,
      chargeKey: (json['chargeKey'] as String?)?.trim().isEmpty == true
          ? null
          : json['chargeKey'] as String?,
    );
  }
}

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

  String? get lastDetectedEncoding => _lastDetectedEncoding;
  String? get lastError => _lastError;
  
  TranslationEngine(this._geminiService);

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
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
    s = s.replaceAll(RegExp(r'\b(480p|720p|1080p|2160p|bluray|brrip|webrip|webdl|x264|x265|h264|h265|yts|dvdrip)\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\b(greek|turkish|english|french|spanish|arabic|persian|russian)\b', caseSensitive: false), ' ');

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
    final sample = content.length > 12000 ? content.substring(0, 12000) : content;
    if (_containsGreekLetters(sample)) return 'Greek';
    return null;
  }

  static bool _containsGreekLetters(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0370 && rune <= 0x03FF) || (rune >= 0x1F00 && rune <= 0x1FFF)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsCyrillicLetters(String text) {
    for (final rune in text.runes) {
      // Cyrillic block + Cyrillic Supplement
      if ((rune >= 0x0400 && rune <= 0x052F) || (rune >= 0x2DE0 && rune <= 0x2DFF) || (rune >= 0xA640 && rune <= 0xA69F)) {
        return true;
      }
    }
    return false;
  }

  static int _countGreekLetters(String text) {
    int count = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x0370 && rune <= 0x03FF) || (rune >= 0x1F00 && rune <= 0x1FFF)) {
        count++;
      }
    }
    return count;
  }

  static int _countCyrillicLetters(String text) {
    int count = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x0400 && rune <= 0x052F) || (rune >= 0x2DE0 && rune <= 0x2DFF) || (rune >= 0xA640 && rune <= 0xA69F)) {
        count++;
      }
    }
    return count;
  }

  static bool _containsAnyLikelyLetter(String text) {
    for (final rune in text.runes) {
      // Basic Latin letters
      if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) return true;
      // Latin-1 Supplement + Latin Extended-A/B (covers many European alphabets)
      if (rune >= 0x00C0 && rune <= 0x024F) return true;
      // Greek
      if ((rune >= 0x0370 && rune <= 0x03FF) || (rune >= 0x1F00 && rune <= 0x1FFF)) return true;
      // Cyrillic
      if ((rune >= 0x0400 && rune <= 0x052F) || (rune >= 0x2DE0 && rune <= 0x2DFF) || (rune >= 0xA640 && rune <= 0xA69F)) return true;
      // Arabic
      if (rune >= 0x0600 && rune <= 0x06FF) return true;
      // Hebrew
      if (rune >= 0x0590 && rune <= 0x05FF) return true;
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
    return text
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

    for (int i = 0; i < sourceBlocks.length && i < translatedBlocks.length; i++) {
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
        stillMostlyGreek = dstGreek > 5 && srcGreek > 5 && dstGreek >= (srcGreek * 0.80).floor();
      } else {
        stillMostlyGreek = false;
      }

      final bool stillMostlyCyrillic;
      if (srcHasCyrillic) {
        final int srcCyr = _countCyrillicLetters(src.text);
        final int dstCyr = _countCyrillicLetters(dst.text);
        stillMostlyCyrillic = dstCyr > 5 && srcCyr > 5 && dstCyr >= (srcCyr * 0.80).floor();
      } else {
        stillMostlyCyrillic = false;
      }

      // General "unchanged" retry for sentence-like lines (works for Latin scripts too).
      final bool shouldRetryBecauseUnchanged = unchanged && _isMeaningfulSentenceLike(src.text);

      if (!shouldRetryBecauseUnchanged && !stillMostlyGreek && !stillMostlyCyrillic) continue;

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
      onLog?.call(
        'log_retranslated_lines',
        jsonEncode({'count': fixes}),
      );
    }

    return translatedBlocks;
  }

  Future<({String srt, List<SubtitleBlock> blocks})> _translateSrtChunkResilient(
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
      // Güvenlik filtresi (PROHIBITED) hatası alınırsa ve parça bölünebiliyorsa,
      // hatayı yut ve 'forceSplit' bayrağını açarak parçalama mantığına git.
      final err = e.toString();
      if ((err.contains('PROHIBITED') || err.contains('PromptFeedback') || err.contains('blockReason')) && expectedCount > 1 && depth < 5) {
        onLog?.call(
          'log_safety_filter_retry',
          jsonEncode({'depth': depth}),
        );
        forceSplit = true;
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
        final fixedBlocks = await _fixLikelyUntranslatedBlocks(
          sourceBlocks: expectedBlocks,
          translatedBlocks: parsed,
          targetLanguage: targetLanguage,
          contextHint: contextHint,
          sourceLanguageHint: sourceLanguageHint,
        );
        return (srt: SubtitleBuilder.buildSrt(fixedBlocks), blocks: fixedBlocks);
      }
    }

    // One retry with an explicit block-count constraint before splitting.
    if (!forceSplit && expectedCount > 0) {
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
          final fixedBlocks = await _fixLikelyUntranslatedBlocks(
            sourceBlocks: expectedBlocks,
            translatedBlocks: retryParsed,
            targetLanguage: targetLanguage,
            contextHint: contextHint,
            sourceLanguageHint: sourceLanguageHint,
          );
          return (srt: SubtitleBuilder.buildSrt(fixedBlocks), blocks: fixedBlocks);
        }
      } catch (_) {
        // ignore and fall back to splitting
      }
    }

    // If the model dropped blocks (often due to truncation), split and translate smaller pieces.
    if ((forceSplit || expectedCount > 1) && depth < 5) {
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

      final combinedBlocks = <SubtitleBlock>[...leftResult.blocks, ...rightResult.blocks];
      return (srt: SubtitleBuilder.buildSrt(combinedBlocks), blocks: combinedBlocks);
    }

    // Last resort: don't lose content. If parsing returned something, use it; otherwise keep original.
    onLog?.call(
      'log_translation_unverified',
      jsonEncode({'expected': expectedCount, 'got': parsed.length}),
    );
    if (parsed.isNotEmpty) {
      // Best-effort alignment even when counts mismatch.
      final minLen = parsed.length < expectedBlocks.length ? parsed.length : expectedBlocks.length;
      if (minLen > 0) {
        _alignTranslatedBlocksToSource(expectedBlocks.sublist(0, minLen), parsed.sublist(0, minLen));
      }
      return (srt: SubtitleBuilder.buildSrt(parsed), blocks: parsed);
    }
    return (srt: SubtitleBuilder.buildSrt(expectedBlocks), blocks: expectedBlocks);
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
      final srcLineCount = src.text.split('\n').where((l) => l.trim().isNotEmpty).length;
      if (srcLineCount <= 1) {
        // Normalize excessive newlines into single newline only when source is single-line.
        dst.text = dst.text.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
        continue;
      }

      final dstLines = dst.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (dstLines.length == srcLineCount) continue;

      final flat = dst.text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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

  void _logResumeDebug(String message) {
    onLog?.call(
      'log_resume_debug',
      jsonEncode({'message': message}),
    );
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

    // 1. Prepare Content
    String content;
    List<SubtitleBlock> translatedBlocks = [];
    StringBuffer fullTranslation = StringBuffer();
    
    // Check for Resume
    final filePath = _normalizePathForCompare(file.path);
    final resumePath =
        resumeState == null ? null : _normalizePathForCompare(resumeState.filePath);
    final isResuming = resumeState != null &&
        resumeState.hash == hash &&
        resumeState.targetLanguage == targetLanguage &&
        resumePath == filePath;

    if (resumeState != null && !isResuming) {
      _logResumeDebug(
        'engine mismatch '
        'hashMatch=${resumeState.hash == hash} '
        'langMatch=${resumeState.targetLanguage == targetLanguage} '
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
        final sampleBlocks = blocks.length > 24 ? blocks.sublist(0, 24) : blocks;
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
    final totalBlocksForProgress =
      (resumeTotalBlocks > 0) ? resumeTotalBlocks : contentBlockCount;
    final processedBlocksForProgress =
      isResuming ? resumeState.translatedBlocks.length : 0;

    totalLines = totalBlocksForProgress;
    processedLines = processedBlocksForProgress;

    onProgress?.call(processedLines, totalLines, isComplete: false);

    // 3. Prepare Chunks
    final List<String> chunks;
    int chunkIndex;
    
    if (isResuming) {
        chunks = resumeState.chunks;
        chunkIndex = resumeState.nextChunkIndex;
        fullTranslation.write(resumeState.translatedText);
        translatedBlocks = List<SubtitleBlock>.from(resumeState.translatedBlocks);
        // Ensure output file has current content
        if (outputFile != null && !await outputFile.exists()) {
             await outputFile.writeAsString(fullTranslation.toString());
        }
    } else {
      onLog?.call('log_translation_chunks_preparing');
      // İşlemi arka planda (isolate) yaparak arayüzün donmasını engelliyoruz
      final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
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
              jsonEncode({'chunkIndex': chunkIndex + 1, 'chunkTotal': chunks.length}),
            );
            await onBeforeChunk!(chunkIndex, chunks.length);
            onLog?.call(
              'log_translation_before_chunk_hook_done',
              jsonEncode({'chunkIndex': chunkIndex + 1, 'chunkTotal': chunks.length}),
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
                  jsonEncode({'chunkIndex': chunkIndex + 1, 'chunkTotal': chunks.length}),
                );
                final result = await _translateSrtChunkResilient(
                  chunk,
                  targetLanguage: targetLanguage,
                  contextHint: combinedContextHint.isEmpty ? null : combinedContextHint,
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

                // IMPORTANT: When writing chunks incrementally, preserve the globally-adjusted
                // indices. Otherwise each chunk will restart at 1 and the output SRT will have
                // repeated sequence numbers.
                final translatedChunkForOutput =
                    SubtitleBuilder.buildSrt(newBlocks, resequence: false);

                fullTranslation.write(translatedChunkForOutput);
                
                if (outputFile != null) {
                    await outputFile.writeAsString(translatedChunkForOutput, mode: FileMode.append);
                }
                
                // Update progress based on translated subtitle blocks.
                processedLines += newBlocks.length;
                
                // Notify controller with updated blocks for live view
                onTranslatedBlocksUpdate?.call(List<SubtitleBlock>.from(translatedBlocks));
                
                onProgress?.call(processedLines, totalLines, isComplete: false);

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
                   final errorMsg = raw.length > 700 ? '${raw.substring(0, 700)}…' : raw;
                     _lastError = '${e.runtimeType}: $errorMsg';
                     onLog?.call(exceededRetries ? 'log_max_retry_state_saving' : 'log_error_state_saving');
                     onLog?.call('log_error_detail', jsonEncode({'error': _lastError}));
                     return buildResumeState(chunkIndex);
                 }
                 
                 final waitSeconds = 3 + (attempt * 2); // Artan bekleme süresi: 5s, 7s, 9s...
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
