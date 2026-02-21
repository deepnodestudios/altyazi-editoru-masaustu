import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:locale_names/locale_names.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../app_settings.dart';
import '../constants/ai_language_options.dart';
import '../controllers/translation_controller.dart';
import '../models/batch_file_item.dart';
import '../utils/background_runner.dart';
import '../utils/string_utils.dart';
import '../widgets/batch_save_dialog.dart';
import '../widgets/cloud_source_sheet.dart';
import '../widgets/dropbox_picker_sheet.dart';
import '../widgets/gdrive_picker_sheet.dart';
import '../widgets/ai_panel/credit_card_section.dart';
import '../widgets/ai_panel/batch_processing_banner.dart';
import '../widgets/ai_panel/english_source_tip_banner.dart';
import '../widgets/ai_panel/file_picker_section.dart';
import '../widgets/ai_panel/header_section.dart';
import '../widgets/ai_panel/language_selector_section.dart';
import '../widgets/ai_panel/live_subtitle_section.dart';
import '../widgets/ai_panel/layout_constants.dart';
import '../widgets/ai_panel/panel_footer.dart';
import '../widgets/ai_panel/primary_actions_section.dart';
import '../widgets/ai_panel/selected_files_section.dart';
import '../widgets/ai_panel/target_language_picker_bottom_sheet.dart';
import '../widgets/ai_panel/file_content_dialog.dart';
import '../widgets/purchase_dialog.dart';
import '../widgets/yandex_picker_sheet.dart';
import 'history_tab.dart';

class AITranslationPanel extends StatefulWidget {
  const AITranslationPanel({super.key});

  @override
  State<AITranslationPanel> createState() => _AITranslationPanelState();
}

class _AITranslationPanelState extends State<AITranslationPanel> {
  bool? _lastTickerModeEnabled;

  bool _isDropZoneActive = false;
  late ConfettiController _confettiController;
  StreamSubscription? _purchaseSubscription;
  StreamSubscription? _batchCompleteSubscription;
  TranslationController? _controllerRef;
  TranslationStatus? _lastKnownStatus;
  bool _historyDialogOpen = false;

  // Çoklu dosya seçimi
  final List<BatchFileItem> _selectedFiles = [];
  final Map<String, String> _originalPaths = {};
  bool _isBulkProcessing = false;
  String _estimatedTime = "0 min";
  final GlobalKey _languageSelectorTapKey = GlobalKey();
  final GlobalKey _desktopCreditCardKey = GlobalKey();
  final GlobalKey _desktopHistoryButtonKey = GlobalKey();
  final GlobalKey _desktopLeftTopControlsKey = GlobalKey();
  final GlobalKey _desktopLeftTopBandContentKey = GlobalKey();
  final GlobalKey _desktopPrimaryActionsKey = GlobalKey();
  final GlobalKey _desktopActionButtonsBlockKey = GlobalKey();
  final GlobalKey _desktopBatchBannerKey = GlobalKey();
  final GlobalKey _desktopFilePickerKey = GlobalKey();
  bool _desktopTopBandSyncQueued = false;
  bool _desktopCreditBandSyncQueued = false;
  bool _desktopTopControlsSyncQueued = false;
  bool _desktopPrimaryActionsSyncQueued = false;
  bool _desktopActionButtonsBlockSyncQueued = false;
  bool _desktopBatchBannerSyncQueued = false;
  double _desktopTopBandHeight = 136.0;
  double _desktopCreditCardTopOffset = 8.0;
  double _desktopCreditCardBandHeight = 120.0;
  double _desktopTopControlsHeight = 280.0;
  double _desktopPrimaryActionsTopOffset = 120.0;
  double _desktopBatchBannerTopOffset = 90.0;
  double _desktopFilePickerBottomOffset = 240.0;
  String? _desktopPreviewFilePath;
  String? _desktopPreviewFileName;

  int _lastSeenBatchFilesRevision = -1;

  List<Map<String, String>>? _cachedLanguageOptions;
  String? _cachedLocale;

  void _resetDesktopLayoutSyncMeasurements() {
    _desktopTopBandSyncQueued = false;
    _desktopCreditBandSyncQueued = false;
    _desktopTopControlsSyncQueued = false;
    _desktopPrimaryActionsSyncQueued = false;
    _desktopActionButtonsBlockSyncQueued = false;
    _desktopBatchBannerSyncQueued = false;

    // Reset to safe defaults (avoid a visible "0px" broken layout) and then
    // re-measure on subsequent frames.
    _desktopTopBandHeight = 136.0;
    _desktopCreditCardTopOffset = 8.0;
    _desktopCreditCardBandHeight = 120.0;
    _desktopTopControlsHeight = 280.0;
    _desktopPrimaryActionsTopOffset = 120.0;
    _desktopBatchBannerTopOffset = 90.0;
    _desktopFilePickerBottomOffset = 240.0;
  }

  void _onBecameActiveTab() {
    if (!mounted) return;

    setState(_resetDesktopLayoutSyncMeasurements);

    // Trigger a fresh sync once the first active frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleDesktopTopBandHeightSync();
      _scheduleDesktopCreditBandSync();
      _scheduleDesktopTopControlsHeightSync();
      _scheduleDesktopPrimaryActionsTopSync();
      _scheduleDesktopActionButtonsBlockHeightSync();
      _scheduleDesktopBatchBannerTopSync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final enabled = TickerMode.valuesOf(context).enabled;
    final previous = _lastTickerModeEnabled;
    _lastTickerModeEnabled = enabled;

    // TabBarView/PageView toggles TickerMode; use this to detect when the
    // translation tab becomes visible again after being offstage.
    if (previous == false && enabled == true) {
      _onBecameActiveTab();
    }
  }

  Future<void> _openHistoryPage() async {
    if (!mounted) return;
    if (_historyDialogOpen) return;
    _historyDialogOpen = true;
    try {
      await showHistorySheet(context);
    } catch (e, st) {
      // If History dialog fails to build for any reason, don't crash the app.
      debugPrint('Failed to open History sheet: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Geçmiş açılamadı. Lütfen tekrar deneyin.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      _historyDialogOpen = false;
    }
  }

  Future<String?> _showTargetLanguagePickerBottomSheet({
    required AppSettings settings,
    required String currentCode,
    Rect? anchorRect,
  }) async {
    final trans = settings.trans;
    final colorScheme = Theme.of(context).colorScheme;
    final options = _getSortedLanguageOptions(settings.language);
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final screenWidth = MediaQuery.of(context).size.width;
    final leftPanelWidth = (screenWidth * 0.5).clamp(420.0, 560.0);

    return showAiPanelTargetLanguagePickerBottomSheet(
      context: context,
      trans: trans,
      colorScheme: colorScheme,
      options: options,
      currentCode: currentCode,
      maxSheetWidth: isDesktop ? leftPanelWidth : null,
      alignToLeft: isDesktop,
      anchorRect: anchorRect,
    );
  }

  Rect? _resolveGlobalRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  void _scheduleDesktopTopBandHeightSync({int attempt = 0}) {
    if (_desktopTopBandSyncQueued) return;
    _desktopTopBandSyncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopTopBandSyncQueued = false;
      if (!mounted) return;

      final topBandRect = _resolveGlobalRect(_desktopLeftTopBandContentKey);
      if (topBandRect == null) {
        // When returning to this tab, the subtree can be present but not laid
        // out yet for 1-2 frames. Retry a few times to avoid stale offsets.
        if (attempt < 8) {
          _scheduleDesktopTopBandHeightSync(attempt: attempt + 1);
        }
        return;
      }

      final targetHeight = topBandRect.height.clamp(96.0, 260.0);
      if ((targetHeight - _desktopTopBandHeight).abs() < 0.5) return;
      setState(() {
        _desktopTopBandHeight = targetHeight;
      });
    });
  }

  void _scheduleDesktopCreditBandSync({int attempt = 0}) {
    if (_desktopCreditBandSyncQueued) return;
    _desktopCreditBandSyncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopCreditBandSyncQueued = false;
      if (!mounted) return;

      final controlsCtx = _desktopLeftTopControlsKey.currentContext;
      final historyCtx = _desktopHistoryButtonKey.currentContext;
      final selectorCtx = _languageSelectorTapKey.currentContext;
      if (controlsCtx == null || historyCtx == null || selectorCtx == null) {
        if (attempt < 8) {
          _scheduleDesktopCreditBandSync(attempt: attempt + 1);
        }
        return;
      }
      final controlsBox = controlsCtx.findRenderObject()! as RenderBox;
      final historyBox = historyCtx.findRenderObject()! as RenderBox;
      final selectorBox = selectorCtx.findRenderObject()! as RenderBox;
      // globalToLocal dönüşümü FittedBox ölçeğini iptal eder → sanal koordinat.
      final targetTop = controlsBox
          .globalToLocal(historyBox.localToGlobal(Offset.zero))
          .dy
          .clamp(0.0, 120.0);
      final targetBottom = controlsBox
          .globalToLocal(
              selectorBox.localToGlobal(Offset(0, selectorBox.size.height)))
          .dy
          .clamp(80.0, 260.0);
      final targetHeight = (targetBottom - targetTop).clamp(88.0, 220.0);

      final topChanged =
          (targetTop - _desktopCreditCardTopOffset).abs() >= 0.5;
      final heightChanged =
          (targetHeight - _desktopCreditCardBandHeight).abs() >= 0.5;
      if (!topChanged && !heightChanged) return;

      setState(() {
        _desktopCreditCardTopOffset = targetTop;
        _desktopCreditCardBandHeight = targetHeight;
      });
    });
  }

  void _scheduleDesktopTopControlsHeightSync({int attempt = 0}) {
    if (_desktopTopControlsSyncQueued) return;
    _desktopTopControlsSyncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopTopControlsSyncQueued = false;
      if (!mounted) return;

      final controlsRect = _resolveGlobalRect(_desktopLeftTopControlsKey);
      if (controlsRect == null) {
        if (attempt < 8) {
          _scheduleDesktopTopControlsHeightSync(attempt: attempt + 1);
        }
        return;
      }

      final targetHeight = controlsRect.height.clamp(180.0, 520.0);
      if ((targetHeight - _desktopTopControlsHeight).abs() < 0.5) return;
      setState(() {
        _desktopTopControlsHeight = targetHeight;
      });
    });
  }

  void _scheduleDesktopPrimaryActionsTopSync({int attempt = 0}) {
    if (_desktopPrimaryActionsSyncQueued) return;
    _desktopPrimaryActionsSyncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopPrimaryActionsSyncQueued = false;
      if (!mounted) return;

      final controlsCtx = _desktopLeftTopControlsKey.currentContext;
      final primaryCtx = _desktopPrimaryActionsKey.currentContext;
      if (controlsCtx == null || primaryCtx == null) {
        if (attempt < 8) {
          _scheduleDesktopPrimaryActionsTopSync(attempt: attempt + 1);
        }
        return;
      }
      final controlsBox = controlsCtx.findRenderObject()! as RenderBox;
      final primaryBox = primaryCtx.findRenderObject()! as RenderBox;
      // globalToLocal dönüşümü FittedBox ölçeğini iptal eder → sanal koordinat.
      final targetOffset = controlsBox
          .globalToLocal(primaryBox.localToGlobal(Offset.zero))
          .dy
          .clamp(8.0, 800.0);
      if ((targetOffset - _desktopPrimaryActionsTopOffset).abs() < 0.5) return;
      setState(() {
        _desktopPrimaryActionsTopOffset = targetOffset;
      });
    });
  }

  void _scheduleDesktopActionButtonsBlockHeightSync({int attempt = 0}) {
    if (_desktopActionButtonsBlockSyncQueued) return;
    _desktopActionButtonsBlockSyncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopActionButtonsBlockSyncQueued = false;
      if (!mounted) return;

      final controlsCtx = _desktopLeftTopControlsKey.currentContext;
      final filePickerCtx = _desktopFilePickerKey.currentContext;
      if (controlsCtx == null || filePickerCtx == null) {
        if (attempt < 8) {
          _scheduleDesktopActionButtonsBlockHeightSync(attempt: attempt + 1);
        }
        return;
      }
      final controlsBox = controlsCtx.findRenderObject()! as RenderBox;
      final filePickerBox = filePickerCtx.findRenderObject()! as RenderBox;
      // "Dosya Ekle" butonunun alt kenarını (trailing gap háriç) sol panel
      // kontrolleri başlangıcına göre sanal koordinatta ölç.
      // globalToLocal FittedBox ölçeğini iptal eder → ölçekten bağımsız.
      final filePickerLocalTop = controlsBox
          .globalToLocal(filePickerBox.localToGlobal(Offset.zero))
          .dy;
      // filePickerSection içindeki trailing SizedBox(16) hariç buton alt kenarı:
      // renderObject.size.height = toplam yükseklik (buton + trailing gap).
      // "Dosya Ekle" face bottom = filePickerLocalTop + height - kAiPanelSectionGap
      final filePickerFaceBottom =
          filePickerLocalTop + filePickerBox.size.height - kAiPanelSectionGap;
      if ((filePickerFaceBottom - _desktopFilePickerBottomOffset).abs() < 0.5) {
        return;
      }
      setState(() {
        _desktopFilePickerBottomOffset = filePickerFaceBottom;
      });
    });
  }

  void _scheduleDesktopBatchBannerTopSync({int attempt = 0}) {
    if (_desktopBatchBannerSyncQueued) return;
    _desktopBatchBannerSyncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _desktopBatchBannerSyncQueued = false;
      if (!mounted) return;

      final controlsCtx = _desktopLeftTopControlsKey.currentContext;
      final bannerCtx = _desktopBatchBannerKey.currentContext;
      if (controlsCtx == null || bannerCtx == null) {
        if (attempt < 8) {
          _scheduleDesktopBatchBannerTopSync(attempt: attempt + 1);
        }
        return;
      }
      final controlsBox = controlsCtx.findRenderObject()! as RenderBox;
      final bannerBox = bannerCtx.findRenderObject()! as RenderBox;
      // globalToLocal dönüşümü FittedBox ölçeğini iptal eder → sanal koordinat.
      final targetOffset = controlsBox
          .globalToLocal(bannerBox.localToGlobal(Offset.zero))
          .dy
          .clamp(8.0, 800.0);
      if ((targetOffset - _desktopBatchBannerTopOffset).abs() < 0.5) return;
      setState(() {
        _desktopBatchBannerTopOffset = targetOffset;
      });
    });
  }

  String _localizedTargetLanguageLabel(
    String code,
    Locale uiLocale,
    String fallbackLabel,
  ) {
    final targetLocale = _localeFromLanguageOptionCode(code);

    final localized = targetLocale.displayLanguageIn(uiLocale).trim();
    if (localized.isEmpty) return fallbackLabel;

    // Prevent implicit English fallback when UI language isn't English.
    if (uiLocale.languageCode.toLowerCase() != 'en') {
      final english = targetLocale.defaultDisplayLanguage.trim();
      final nativeName = targetLocale.nativeDisplayLanguage.trim();
      final looksLikeEnglishFallback =
          localized == english && nativeName.isNotEmpty && nativeName != english;
      if (looksLikeEnglishFallback) return nativeName;
    }

    return localized;
  }

  Locale _uiLocaleFromAppLanguage(String appLanguageCode) {
    final normalized = appLanguageCode.trim().toLowerCase();
    // App uses some non-standard codes for UI languages.
    switch (normalized) {
      case 'cn':
        return const Locale('zh');
      case 'in':
        return const Locale('hi');
      default:
        return Locale(normalized);
    }
  }

  Locale _localeFromLanguageOptionCode(String optionCode) {
    final normalized = optionCode.trim().replaceAll('_', '-');
    if (normalized.isEmpty) return const Locale('en');

    final parts = normalized.split('-').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return const Locale('en');

    final languageCode = _normalizeLanguageCodeForLocaleNames(parts.first);
    String? scriptCode;
    String? countryCode;

    for (final part in parts.skip(1)) {
      if (scriptCode == null && _looksLikeScriptSubtag(part)) {
        scriptCode = _toTitleCase(part);
        continue;
      }
      if (countryCode == null && _looksLikeRegionSubtag(part)) {
        countryCode = part.toUpperCase();
      }
    }

    return Locale.fromSubtags(
      languageCode: languageCode,
      scriptCode: scriptCode,
      countryCode: countryCode,
    );
  }

  String _normalizeLanguageCodeForLocaleNames(String raw) {
    final up = raw.trim().toUpperCase();
    // Fix a few non-BCP47 codes used in our list.
    switch (up) {
      case 'CZ':
        return 'cs';
      case 'JW':
        return 'jv';
      default:
        return up.toLowerCase();
    }
  }

  bool _looksLikeScriptSubtag(String value) {
    final v = value.trim();
    if (v.length != 4) return false;
    return RegExp(r'^[A-Za-z]{4}$').hasMatch(v);
  }

  bool _looksLikeRegionSubtag(String value) {
    final v = value.trim();
    if (RegExp(r'^[A-Za-z]{2}$').hasMatch(v)) return true;
    return RegExp(r'^[0-9]{3}$').hasMatch(v);
  }

  String _toTitleCase(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1).toLowerCase();
  }

  List<Map<String, String>> _getSortedLanguageOptions(String locale) {
    if (_cachedLocale == locale && _cachedLanguageOptions != null) {
      return _cachedLanguageOptions!;
    }

    final uiLocale = _uiLocaleFromAppLanguage(locale);

    final list = aiPanelLanguageOptions
        .map(
          (e) => {
            'code': e['code'] ?? '',
            'label': _localizedTargetLanguageLabel(
              e['code'] ?? '',
              uiLocale,
              e['label'] ?? '',
            ),
          },
        )
        .toList();

    list.sort(
      (a, b) => _compareLocaleLabels(
        a['label'] ?? '',
        b['label'] ?? '',
        locale,
      ),
    );
    _cachedLocale = locale;
    _cachedLanguageOptions = list;
    return list;
  }

  int _compareLocaleLabels(String a, String b, String locale) {
    final normalized = locale.toUpperCase();

    switch (normalized) {
      case 'TR':
        return _compareWithCustomAlphabet(
          a,
          b,
          _turkishAlphabetOrder,
          _turkishLower,
        );
      case 'ES':
        return _compareWithCustomAlphabet(
          _stripDiacriticsExceptEnye(a),
          _stripDiacriticsExceptEnye(b),
          _spanishAlphabetOrder,
          _latinLower,
        );
      case 'DE':
        return _compareLatinDefault(
          _normalizeGerman(a),
          _normalizeGerman(b),
        );
      case 'FR':
      case 'IT':
      case 'PT':
      case 'ID':
      case 'IN':
        return _compareLatinDefault(
          _stripDiacritics(a),
          _stripDiacritics(b),
        );
      case 'RU':
        return _compareWithCustomAlphabet(
          a,
          b,
          _russianAlphabetOrder,
          _latinLower,
        );
      case 'EL':
        return _compareWithCustomAlphabet(
          _normalizeGreek(a),
          _normalizeGreek(b),
          _greekAlphabetOrder,
          _latinLower,
        );
      case 'AR':
        return _compareWithCustomAlphabet(
          a,
          b,
          _arabicAlphabetOrder,
          _latinLower,
        );
      case 'CN':
      case 'JA':
      case 'KO':
      default:
        return _compareLatinDefault(a, b);
    }
  }

  int _compareLatinDefault(String a, String b) {
    return _latinLower(a).compareTo(_latinLower(b));
  }

  int _compareWithCustomAlphabet(
    String a,
    String b,
    Map<String, int> order,
    String Function(String) lower,
  ) {
    final la = lower(a);
    final lb = lower(b);
    final minLen = la.length < lb.length ? la.length : lb.length;

    for (int i = 0; i < minLen; i++) {
      final ca = la[i];
      final cb = lb[i];
      if (ca == cb) continue;
      final oa = order[ca];
      final ob = order[cb];
      if (oa != null && ob != null) {
        return oa.compareTo(ob);
      }
      if (oa != null) return -1;
      if (ob != null) return 1;
      return ca.compareTo(cb);
    }

    return la.length.compareTo(lb.length);
  }

  String _latinLower(String input) => input.toLowerCase();

  String _turkishLower(String input) {
    return input
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase();
  }

  String _normalizeGreek(String input) {
    return input
        .replaceAll('Ά', 'Α')
        .replaceAll('Έ', 'Ε')
        .replaceAll('Ή', 'Η')
        .replaceAll('Ί', 'Ι')
        .replaceAll('Ό', 'Ο')
        .replaceAll('Ύ', 'Υ')
        .replaceAll('Ώ', 'Ω')
        .replaceAll('ς', 'σ')
        .toLowerCase();
  }

  String _normalizeGerman(String input) {
    return input
        .replaceAll('Ä', 'A')
        .replaceAll('Ö', 'O')
        .replaceAll('Ü', 'U')
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ß', 'ss');
  }

  String _stripDiacriticsExceptEnye(String input) {
    return _stripDiacritics(input)
        .replaceAll('Ñ', 'ñ')
        .replaceAll('ñ', 'ñ');
  }

  String _stripDiacritics(String input) {
    const replacements = {
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'Å': 'A',
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'Ç': 'C',
      'ç': 'c',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Ñ': 'N',
      'ñ': 'n',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ý': 'Y',
      'ý': 'y',
      'ÿ': 'y',
    };

    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      buffer.write(replacements[ch] ?? ch);
    }
    return buffer.toString();
  }

  static const Map<String, int> _turkishAlphabetOrder = {
    'a': 0,
    'b': 1,
    'c': 2,
    'ç': 3,
    'd': 4,
    'e': 5,
    'f': 6,
    'g': 7,
    'ğ': 8,
    'h': 9,
    'ı': 10,
    'i': 11,
    'j': 12,
    'k': 13,
    'l': 14,
    'm': 15,
    'n': 16,
    'o': 17,
    'ö': 18,
    'p': 19,
    'r': 20,
    's': 21,
    'ş': 22,
    't': 23,
    'u': 24,
    'ü': 25,
    'v': 26,
    'y': 27,
    'z': 28,
  };

  static const Map<String, int> _spanishAlphabetOrder = {
    'a': 0,
    'b': 1,
    'c': 2,
    'd': 3,
    'e': 4,
    'f': 5,
    'g': 6,
    'h': 7,
    'i': 8,
    'j': 9,
    'k': 10,
    'l': 11,
    'm': 12,
    'n': 13,
    'ñ': 14,
    'o': 15,
    'p': 16,
    'q': 17,
    'r': 18,
    's': 19,
    't': 20,
    'u': 21,
    'v': 22,
    'w': 23,
    'x': 24,
    'y': 25,
    'z': 26,
  };

  static const Map<String, int> _russianAlphabetOrder = {
    'а': 0,
    'б': 1,
    'в': 2,
    'г': 3,
    'д': 4,
    'е': 5,
    'ё': 6,
    'ж': 7,
    'з': 8,
    'и': 9,
    'й': 10,
    'к': 11,
    'л': 12,
    'м': 13,
    'н': 14,
    'о': 15,
    'п': 16,
    'р': 17,
    'с': 18,
    'т': 19,
    'у': 20,
    'ф': 21,
    'х': 22,
    'ц': 23,
    'ч': 24,
    'ш': 25,
    'щ': 26,
    'ъ': 27,
    'ы': 28,
    'ь': 29,
    'э': 30,
    'ю': 31,
    'я': 32,
  };

  static const Map<String, int> _greekAlphabetOrder = {
    'α': 0,
    'β': 1,
    'γ': 2,
    'δ': 3,
    'ε': 4,
    'ζ': 5,
    'η': 6,
    'θ': 7,
    'ι': 8,
    'κ': 9,
    'λ': 10,
    'μ': 11,
    'ν': 12,
    'ξ': 13,
    'ο': 14,
    'π': 15,
    'ρ': 16,
    'σ': 17,
    'τ': 18,
    'υ': 19,
    'φ': 20,
    'χ': 21,
    'ψ': 22,
    'ω': 23,
  };

  static const Map<String, int> _arabicAlphabetOrder = {
    'ا': 0,
    'ب': 1,
    'ت': 2,
    'ث': 3,
    'ج': 4,
    'ح': 5,
    'خ': 6,
    'د': 7,
    'ذ': 8,
    'ر': 9,
    'ز': 10,
    'س': 11,
    'ش': 12,
    'ص': 13,
    'ض': 14,
    'ط': 15,
    'ظ': 16,
    'ع': 17,
    'غ': 18,
    'ف': 19,
    'ق': 20,
    'ك': 21,
    'ل': 22,
    'م': 23,
    'ن': 24,
    'ه': 25,
    'و': 26,
    'ي': 27,
  };

  Future<void> _ensureAndroidBackgroundExecution(AppSettings settings) async {
    // This is the key part for "screen off still continues" on Android.
    if (!Platform.isAndroid) return;

    final trans = settings.trans;
    final bool ignoring = await settings.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    if (ignoring) return;

    Future<void> showBatteryWarningSnackBar() async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trans['battery_opt_warning'] ??
                'Android, ekran kapalıyken uygulamayı uyku moduna alıp çeviriyi durdurabilir. Pil optimizasyonunda uygulamayı "Sınırsız / Kısıtlama yok" yapmanız önerilir.',
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: trans['battery_opt_open_settings'] ?? 'Ayarlara Git',
            onPressed: () {
              unawaited(() async {
                final s = context.read<AppSettings>();
                final ok = await s.requestIgnoreBatteryOptimizations();
                if (!ok) {
                  await s.openBatteryOptimizationSettings();
                }
              }());
            },
          ),
        ),
      );
    }

    if (!settings.batteryOptimizationPrompted) {
      if (!mounted) return;
      final int? choice = await showDialog<int>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(trans['battery_opt_title'] ?? 'Arka Planda Devam'),
            content: Text(
              trans['battery_opt_message'] ??
                  'Ekran kapalıyken çevirinin devam etmesi için Android pil optimizasyonu bu uygulamayı uykuya almamalı.\n\nÖneri: Ayarlar > Pil > Pil optimizasyonu (veya Arka plan kısıtlamaları) bölümünden bu uygulamayı "Sınırsız / Kısıtlama yok" yapın.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 0),
                child: Text(trans['battery_opt_continue_anyway'] ?? 'Şimdilik Devam'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 1),
                child: Text(trans['battery_opt_app_settings'] ?? 'Uygulama Ayarları'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 2),
                child: Text(trans['battery_opt_open_settings'] ?? 'Ayarlara Git'),
              ),
            ],
          );
        },
      );

      await settings.setBatteryOptimizationPrompted(true);

      if (choice == 2) {
        final ok = await settings.requestIgnoreBatteryOptimizations();
        if (!ok) {
          await settings.openBatteryOptimizationSettings();
        }
        return;
      }
      if (choice == 1) {
        await settings.openAppDetailsSettings();
        return;
      }

      // User chose to continue anyway.
      await showBatteryWarningSnackBar();
      return;
    }

    // Already prompted once: keep it lightweight.
    await showBatteryWarningSnackBar();
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _lastSeenBatchFilesRevision = context.read<AppSettings>().batchFilesRevision;
    _loadSavedFiles(); // Kaydedilmiş dosyaları yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialConnection();
      if (mounted) {
        final controller = context.read<TranslationController>();
        _controllerRef = controller;
        _lastKnownStatus = controller.status;
        controller.addListener(_onControllerStatusChanged);
        _purchaseSubscription = controller.purchaseSuccessStream.listen((_) {
          _confettiController.play();
        });
        _batchCompleteSubscription = controller.batchCompleteStream.listen((results) {
          _showBatchSaveDialog(results);
        });
      }
    });
  }

  /// Çeviri durumu değiştiğinde çağrılır.
  /// Tekli çeviri tamamlanıp listede bekleyen dosya varsa otomatik batch başlatır.
  void _onControllerStatusChanged() {
    if (!mounted) return;
    final controller = _controllerRef;
    if (controller == null) return;

    final currentStatus = controller.status;
    final wasNotRunning = _lastKnownStatus != TranslationStatus.running;
    final wasRunning = _lastKnownStatus == TranslationStatus.running ||
                       _lastKnownStatus == TranslationStatus.paused;
    final isNowComplete = currentStatus == TranslationStatus.completed;

    // Translation starts: prefer live view over file preview automatically.
    // User can still manually reopen any file preview from the list.
    if (currentStatus == TranslationStatus.running && wasNotRunning) {
      if (_desktopPreviewFilePath != null || _desktopPreviewFileName != null) {
        setState(() {
          _desktopPreviewFilePath = null;
          _desktopPreviewFileName = null;
        });
      }
    }

    if (wasRunning && isNowComplete && !_isBulkProcessing) {
      if (_selectedFiles.length <= 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isBulkProcessing) return;
          unawaited(_showSingleCompletionDialogAndReset(controller));
        });
      } else if (_selectedFiles.isNotEmpty) {
        // Çoklu çeviri bitti ve listede dosya var → otomatik devam et
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedFiles.isNotEmpty && !_isBulkProcessing) {
            _startBulkProcess(controller);
          }
        });
      }
    }

    _lastKnownStatus = currentStatus;
  }

  void _showBatchSaveDialog(Map<String, String> results) {
    if (results.isEmpty) return;
    // Batch completion: show the dialog and then reset to initial UI state.
    () async {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => BatchSaveDialog(results: results),
      );

      if (!mounted) return;

      final controller = _controllerRef ?? context.read<TranslationController>();
      controller.clearAfterCompletion();
      await _clearAllFiles();
    }();
  }

  Future<void> _showSingleCompletionDialogAndReset(
    TranslationController controller,
  ) async {
    final export = await controller.getTranslatedFileExport();
    if (!mounted) return;

    if (export != null) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => BatchSaveDialog(
          results: {export.name: export.content},
        ),
      );

      if (!mounted) return;
    }

    // Always return to initial UI state even if we couldn't read the output.
    controller.clearAfterCompletion();
    await _clearAllFiles();
  }

  Future<void> _checkInitialConnection() async {
    final settings = context.read<AppSettings>();
    final colorScheme = Theme.of(context).colorScheme;
    await settings.checkConnectivity();
    if (mounted && settings.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.trans['internet_error'] ?? 'İnternet bağlantısı yok! AI özellikleri çalışmayabilir.'),
          backgroundColor: colorScheme.errorContainer,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: settings.trans['btn_retry'] ?? 'Tekrar Dene',
            textColor: colorScheme.onErrorContainer,
            onPressed: () {
              _checkInitialConnection();
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controllerRef?.removeListener(_onControllerStatusChanged);
    _purchaseSubscription?.cancel();
    _batchCompleteSubscription?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  String _normalizePathForCompare(String rawPath) {
    return rawPath.trim().replaceAll('\\', '/').toLowerCase();
  }

  bool _containsSelectedPath(String rawPath) {
    final normalized = _normalizePathForCompare(rawPath);
    return _selectedFiles.any(
      (file) => _normalizePathForCompare(file.path) == normalized,
    );
  }

  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  void _clearDesktopPreviewUnsafe() {
    _desktopPreviewFilePath = null;
    _desktopPreviewFileName = null;
  }

  void _syncDesktopPreviewWithSelectedFilesUnsafe() {
    if (!_isDesktopPlatform) return;
    if (_desktopPreviewFilePath == null || _desktopPreviewFileName == null) {
      return;
    }
    if (_selectedFiles.isEmpty) {
      _clearDesktopPreviewUnsafe();
      return;
    }

    final previewNorm = _normalizePathForCompare(_desktopPreviewFilePath!);
    final stillExists = _selectedFiles.any(
      (file) => _normalizePathForCompare(file.path) == previewNorm,
    );
    if (!stillExists) {
      _clearDesktopPreviewUnsafe();
    }
  }

  void _preloadPreviewForItems(Iterable<BatchFileItem> items) {
    if (!_isDesktopPlatform) return;
    for (final item in items) {
      if (item.path.isEmpty) continue;
      preloadAiPanelFileContentPreview(item.path);
    }
  }

  // Kalıcı dosya yönetimi
  Future<void> _loadSavedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getStringList('batch_files') ?? [];
      
      final List<BatchFileItem> loadedFiles = [];
      final Set<String> seenPaths = <String>{};
      for (var jsonStr in filesJson) {
        final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
        final item = BatchFileItem.fromJson(map);
        if (item.path.isEmpty) continue;
        final normalized = _normalizePathForCompare(item.path);
        if (seenPaths.contains(normalized)) continue;
        final file = File(item.path);
        // Sadece var olan dosyaları yükle
        if (await file.exists()) {
          seenPaths.add(normalized);
          loadedFiles.add(item);
        }
      }

      // Orijinal yolları yükle
      final originalPathsJson = prefs.getString('batch_original_paths');
      if (originalPathsJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(originalPathsJson);
          _originalPaths.clear();
          decoded.forEach((k, v) {
            if (v is String) _originalPaths[k] = v;
          });
        } catch (e) {
          debugPrint('Orijinal yollar yüklenirken hata: $e');
        }
      }
      
      if (loadedFiles.isNotEmpty && mounted) {
        setState(() {
          _selectedFiles.clear();
          _selectedFiles.addAll(loadedFiles);
          _syncDesktopPreviewWithSelectedFilesUnsafe();
        });
        _preloadPreviewForItems(loadedFiles);
        _updateEstimatedTime();
      }
    } catch (e) {
      debugPrint('Kaydedilmiş dosyalar yüklenirken hata: $e');
    }
  }

  Future<void> _reloadSavedFilesSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getStringList('batch_files') ?? [];

      final List<BatchFileItem> loadedFiles = [];
      final List<String> keptJson = [];
      final Set<String> seenPaths = <String>{};
      for (var jsonStr in filesJson) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
          final item = BatchFileItem.fromJson(map);
          if (item.path.isEmpty) continue;
          final normalized = _normalizePathForCompare(item.path);
          if (seenPaths.contains(normalized)) continue;
          final file = File(item.path);
          if (await file.exists()) {
            seenPaths.add(normalized);
            loadedFiles.add(item);
            keptJson.add(jsonStr);
          }
        } catch (_) {
          // ignore malformed entries
        }
      }

      // Orijinal yolları sessizce güncelle
      final originalPathsJson = prefs.getString('batch_original_paths');
      if (originalPathsJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(originalPathsJson);
          _originalPaths.clear();
          decoded.forEach((k, v) {
            if (v is String) _originalPaths[k] = v;
          });
        } catch (_) {}
      }

      // If some entries were dropped (missing files), clean up persisted storage
      // so we don't keep trying to process paths that no longer exist.
      if (keptJson.length != filesJson.length) {
        await prefs.setStringList('batch_files', keptJson);
      }

      if (!mounted) return;

      if (_sameSelectedFiles(loadedFiles)) {
        return;
      }

      setState(() {
        _selectedFiles
          ..clear()
          ..addAll(loadedFiles);
        _syncDesktopPreviewWithSelectedFilesUnsafe();
      });
      _preloadPreviewForItems(loadedFiles);
      _updateEstimatedTime();
    } catch (e) {
      debugPrint('Batch listesi senkronize edilirken hata: $e');
    }
  }

  Future<void> _saveFilesList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = _selectedFiles.map((f) => jsonEncode(f.toJson())).toList();
      await prefs.setStringList('batch_files', filesJson);
      await prefs.setString('batch_original_paths', jsonEncode(_originalPaths));
    } catch (e) {
      debugPrint('Dosya listesi kaydedilirken hata: $e');
    }
  }

  Future<String> _copyFileToPermanentStorage(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    // Use the same permanent folder as TranslationController so paths stay stable
    // across History resume and batch processing.
    final subtitlesDir = Directory(path.join(appDir.path, 'subtitles'));
    if (!await subtitlesDir.exists()) {
      await subtitlesDir.create(recursive: true);
    }

    // Stabil isim: <orijinalAd>_<md5>.<ext>
    // Bu sayede aynı dosya tekrar eklenirse yeni proje/entry üretmeyiz.
    final originalName = path.basename(sourceFile.path);
    final ext = path.extension(originalName);
    final base = path.basenameWithoutExtension(originalName);

    final hash = await runInBackground(
      _computeFileMd5FromPath,
      sourceFile.path,
    );

    final newFileName = '${base}_$hash$ext';
    final newPath = path.join(subtitlesDir.path, newFileName);

    final outFile = File(newPath);
    if (await outFile.exists()) {
      return newPath;
    }

    await sourceFile.copy(newPath);
    return newPath;
  }

  Future<void> _updateEstimatedTime() async {
    final settings = context.read<AppSettings>();
    final minuteShort = settings.trans['minute_short'] ?? 'min';

    if (_selectedFiles.isEmpty) {
      if (mounted) setState(() => _estimatedTime = "0 $minuteShort");
      return;
    }

    int totalBytes = 0;
    for (var f in _selectedFiles) {
      final file = File(f.path);
      if (await file.exists()) {
        totalBytes += await file.length();
      }
    }

    // Tahmin: 100KB ~ 1 dakika (Gemini Flash) -> 1MB ~ 10 dakika
    double minutes = (totalBytes / 1024) / 100;
    if (minutes < 1 && totalBytes > 0) minutes = 1;

    if (mounted) {
      setState(() => _estimatedTime = "~${minutes.ceil()} $minuteShort");
    }
  }

  bool _isSubtitlePath(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.endsWith('.srt') || lower.endsWith('.vtt');
  }

  String? _normalizeDroppedFilePath(String rawPath) {
    final raw = rawPath.trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('file:')) {
      final uri = Uri.tryParse(raw);
      if (uri == null) return null;
      try {
        final filePath = uri.toFilePath(windows: Platform.isWindows);
        return filePath.trim().isEmpty ? null : filePath;
      } catch (_) {
        return null;
      }
    }

    var decoded = Uri.decodeFull(raw).trim();
    if (decoded.isEmpty) return null;

    if (Platform.isWindows) {
      // Some drag sources provide /C:/path on Windows.
      if (RegExp(r'^/[a-zA-Z]:[/\\]').hasMatch(decoded)) {
        decoded = decoded.substring(1);
      }
      // Normalize slashes for file IO consistency.
      decoded = decoded.replaceAll('/', r'\');
    }

    return decoded;
  }

  Future<Uri?> _readDroppedFileUri(DropItem item) async {
    final reader = item.dataReader;
    if (reader == null) return null;

    final completer = Completer<Uri?>();
    final progress = reader.getValue<Uri>(
      Formats.fileUri,
      (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) return null;
    return completer.future;
  }

  Future<List<String>> _extractDroppedPaths(PerformDropEvent event) async {
    final unique = <String>{};
    for (final item in event.session.items) {
      final uri = await _readDroppedFileUri(item);
      if (uri == null || uri.scheme.toLowerCase() != 'file') continue;
      final normalized = _normalizeDroppedFilePath(uri.toString());
      if (normalized != null && normalized.isNotEmpty) {
        unique.add(normalized);
      }
    }
    return unique.toList(growable: false);
  }

  Future<void> _enqueueLocalSubtitlePaths(
    TranslationController controller,
    List<String> sourcePaths,
  ) async {
    final settings = context.read<AppSettings>();

    final ignoredNames = <String>[];
    final acceptedPaths = <String>[];

    for (final sourcePath in sourcePaths) {
      if (sourcePath.trim().isEmpty) continue;
      final fileName = path.basename(sourcePath);
      if (!_isSubtitlePath(sourcePath)) {
        ignoredNames.add(fileName);
        continue;
      }

      final file = File(sourcePath);
      if (!await file.exists()) {
        ignoredNames.add(fileName);
        continue;
      }

      acceptedPaths.add(sourcePath);
    }

    if (ignoredNames.isNotEmpty && mounted) {
      final shown = ignoredNames.take(3).join(', ');
      final more = ignoredNames.length > 3
          ? ' (+${ignoredNames.length - 3})'
          : '';
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (settings.trans['only_srt_vtt_skipped'] ?? 'Only .srt / .vtt supported. Skipped: {files}').replaceAll('{files}', '$shown$more'),
          ),
          backgroundColor: colorScheme.tertiaryContainer,
        ),
      );
    }

    if (acceptedPaths.isEmpty) {
      await _updateEstimatedTime();
      return;
    }

    final toEnqueue = <BatchFile>[];
    final addedItems = <BatchFileItem>[];
    for (final sourcePath in acceptedPaths) {
      final fileName = path.basename(sourcePath);
      try {
        final permanentPath = await _copyFileToPermanentStorage(File(sourcePath));
        if (_containsSelectedPath(permanentPath)) {
          continue;
        }

        final item = BatchFileItem(
          name: fileName,
          path: permanentPath,
          source: CloudSource.device.name,
        );

        addedItems.add(item);
        toEnqueue.add(BatchFile(name: fileName, path: permanentPath));

        if (mounted) {
          setState(() {
            _selectedFiles.add(item);
            _originalPaths[permanentPath] = sourcePath;
          });
        }

        await Future<void>.delayed(Duration.zero);
      } catch (e) {
        debugPrint('Dosya eklenirken hata: $e');
      }
    }

    if (addedItems.isNotEmpty) {
      _preloadPreviewForItems(addedItems);
    }

    await _saveFilesList();

    if ((controller.isBatchProcessing || controller.isLoading) &&
        toEnqueue.isNotEmpty) {
      controller.enqueueBatchFiles(
        files: toEnqueue,
        clearSdh: settings.sdhClear,
        targetLanguage: settings.targetLanguage,
      );
    }

    if (!_isBulkProcessing && !controller.isLoading && _selectedFiles.isNotEmpty) {
      final lastPath = _selectedFiles.last.path;
      unawaited(controller.handlePickedFile(File(lastPath)));
    }

    unawaited(_updateEstimatedTime());
  }

  Future<void> _handleMultipleFileSelection(TranslationController controller) async {
    final settings = context.read<AppSettings>();
    final trans = settings.trans;

    try {
      // Kaynak Seçim Menüsü
      final source = await showCloudSourceSheet(
        context: context,
        trans: trans,
        isSave: false,
      );

      if (source == null) return;

      if (source == CloudSource.device) {
        // Yerel Dosya Seçimi
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['srt', 'vtt'],
          allowMultiple: true,
          dialogTitle: cloudSourceDialogTitle(source, trans, isSave: false),
        );

        if (result != null) {
          final paths = result.files
              .map((file) => file.path)
              .whereType<String>()
              .toList();
          await _enqueueLocalSubtitlePaths(controller, paths);
        }
      } else {
        // Bulut Dosya Seçimi
        await _handleCloudPick(settings, controller, source);
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (settings.trans['error_with_details'] ?? 'Error: {error}')
                  .replaceAll('{error}', e.toString()),
            ),
            backgroundColor: colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _handleCloudPick(
    AppSettings settings,
    TranslationController controller,
    CloudSource source,
  ) async {
    final trans = settings.trans;

    // Seçilen dosyaları tutacak geçici liste
    List<({String name, String idOrPath})> selectedCloudFiles = [];

    try {
      if (source == CloudSource.googleDrive) {
        final files = await showGoogleDriveSubtitleMultiPickerSheet(
          context,
          settings: settings,
          trans: trans,
        );
        if (files != null) {
          selectedCloudFiles = files.map((f) => (name: f.name, idOrPath: f.id)).toList();
        }
      } else if (source == CloudSource.dropbox) {
        final files = await showDropboxSubtitleMultiPickerSheet(
          context,
          settings: settings,
          trans: trans,
        );
        if (files != null) {
          selectedCloudFiles = files.map((f) => (name: f.name, idOrPath: f.path)).toList();
        }
      } else if (source == CloudSource.yandexDisk) {
        final files = await showYandexDiskSubtitleMultiPickerSheet(
          context,
          settings: settings,
          trans: trans,
        );
        if (files != null) {
          selectedCloudFiles = files.map((f) => (name: f.name, idOrPath: f.path)).toList();
        }
      }

      if (selectedCloudFiles.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
        }

        try {
          final tempDir = await getTemporaryDirectory();

          final toEnqueue = <BatchFile>[];
          final addedItems = <BatchFileItem>[];

          for (var fileInfo in selectedCloudFiles) {
            String? content;
            if (source == CloudSource.googleDrive) {
              final res = await settings.cloudStorage.downloadGDriveFileWithEncoding(fileInfo.idOrPath);
              content = res['content'];
            } else if (source == CloudSource.dropbox) {
              final res = await settings.cloudStorage.downloadDropboxFileWithEncoding(fileInfo.idOrPath);
              content = res['content'];
            } else if (source == CloudSource.yandexDisk) {
              final res = await settings.cloudStorage.downloadYandexDiskFileWithEncoding(fileInfo.idOrPath);
              content = res['content'];
            }

            if (content != null) {
              final tempFile = File('${tempDir.path}/${fileInfo.name}');
              await tempFile.writeAsString(content);
              
              // Kalıcı storage'a kopyala
              final permanentPath = await _copyFileToPermanentStorage(tempFile);
              
              // Temp dosyayı sil
              await tempFile.delete();

              // Eğer liste boşsa, ilk dosyayı önizleme için yükle
              if (_selectedFiles.isEmpty && selectedCloudFiles.first == fileInfo) {
                if (!_isBulkProcessing && !controller.isLoading) {
                  await controller.handlePickedFile(File(permanentPath));
                }
              }

              final alreadyExists = _containsSelectedPath(permanentPath);

              if (!alreadyExists) {
                addedItems.add(
                  BatchFileItem(
                    name: fileInfo.name,
                    path: permanentPath,
                    source: source.name,
                  ),
                );
              }

              if (!alreadyExists) {
                toEnqueue.add(BatchFile(name: fileInfo.name, path: permanentPath));
              }
            }
          }

          if (addedItems.isNotEmpty && mounted) {
            setState(() {
              _selectedFiles.addAll(addedItems);
            });
            _preloadPreviewForItems(addedItems);
          }
          await _saveFilesList(); // Dosya listesini kaydet

          if ((controller.isBatchProcessing || controller.isLoading) && toEnqueue.isNotEmpty) {
            controller.enqueueBatchFiles(
              files: toEnqueue,
              clearSdh: settings.sdhClear,
              targetLanguage: settings.targetLanguage,
            );
          }

          _updateEstimatedTime();
        } finally {
          if (mounted) Navigator.pop(context); // Loading'i kapat
        }
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (settings.trans['cloud_error_with_details'] ??
                      'Cloud error: {error}')
                  .replaceAll('{error}', e.toString()),
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            backgroundColor: colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _saveTranslatedWithCloudChoice(
    BuildContext context,
    AppSettings settings,
    TranslationController controller,
  ) async {
    final export = await controller.getTranslatedFileExport();
    if (export == null) return;
    if (!context.mounted) return;

    final trans = settings.trans;
    final source = await showCloudSourceSheet(
      context: context,
      trans: trans,
      isSave: true,
    );
    if (source == null || !context.mounted) return;

    final content = export.content;
    final fileName = export.name;

    if (source == CloudSource.device) {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final isAndroidIos = Platform.isAndroid || Platform.isIOS;
      final dialogTitle = cloudSourceDialogTitle(source, trans, isSave: true);
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt'],
        bytes: isAndroidIos ? bytes : null,
      );
      if (!context.mounted) return;
      if (savedPath != null && !isAndroidIos) {
        await File(savedPath).writeAsBytes(bytes, flush: true);
      }
      if (savedPath != null) {
        settings.addLog('log_saved', isAndroidIos ? fileName : savedPath);
      }
      return;
    }

    if (source == CloudSource.googleDrive) {
      final folderId = await showGoogleDriveFolderPickerSheet(
        context,
        settings: settings,
        trans: trans,
      );
      if (folderId == null || !context.mounted) return;
      await settings.cloudStorage.uploadTextFileToGDrive(
        fileName: fileName,
        content: content,
        folderId: folderId,
      );
      settings.addLog(
        'log_saved',
        StringUtils.fillTemplate(
          trans['log_saved_to_provider'] ?? '{provider}: {name}',
          {
            'provider': trans['cloud_source_drive'] ?? 'Google Drive',
            'name': fileName,
          },
        ),
      );
      return;
    }

    if (source == CloudSource.dropbox) {
      final folderPath = await showDropboxFolderPickerSheet(
        context,
        settings: settings,
        trans: trans,
      );
      if (folderPath == null || !context.mounted) return;
      await settings.cloudStorage.uploadTextFileToDropbox(
        fileName: fileName,
        content: content,
        folderPath: folderPath,
      );
      settings.addLog(
        'log_saved',
        StringUtils.fillTemplate(
          trans['log_saved_to_provider'] ?? '{provider}: {name}',
          {
            'provider': trans['cloud_source_dropbox'] ?? 'Dropbox',
            'name': fileName,
          },
        ),
      );
      return;
    }

    if (source == CloudSource.yandexDisk) {
      final folderPath = await showYandexDiskFolderPickerSheet(
        context,
        settings: settings,
        trans: trans,
      );
      if (folderPath == null || !context.mounted) return;
      await settings.cloudStorage.uploadTextFileToYandexDisk(
        fileName: fileName,
        content: content,
        folderPath: folderPath,
      );
      settings.addLog(
        'log_saved',
        StringUtils.fillTemplate(
          trans['log_saved_to_provider'] ?? '{provider}: {name}',
          {
            'provider': trans['cloud_source_yandex'] ?? 'Yandex Disk',
            'name': fileName,
          },
        ),
      );
    }
  }

  Future<void> _removeFileFromList(int index) async {
    final fileToRemove = _selectedFiles[index];
    setState(() {
      _selectedFiles.removeAt(index);
      _originalPaths.remove(fileToRemove.path);
      _syncDesktopPreviewWithSelectedFilesUnsafe();
    });
    await _saveFilesList();
    
    // Kalıcı dosyayı da sil (helper fonksiyonu kullan)
    await _deleteLocalFile(fileToRemove.path);
    
    _updateEstimatedTime();
  }

  Future<void> _clearAllFiles() async {
    final settings = context.read<AppSettings>();

    // Tüm kalıcı dosyaları sil
    for (var fileInfo in _selectedFiles) {
      await _deleteLocalFile(fileInfo.path);
    }
    
    setState(() {
      _selectedFiles.clear();
      _originalPaths.clear();
      _estimatedTime = "0 ${settings.trans['minute_short'] ?? 'min'}";
      _clearDesktopPreviewUnsafe();
    });
    await _saveFilesList();
  }

  Future<void> _deleteLocalFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Dosya diskten silindi: $path');
      }
    } catch (e) {
      debugPrint('Dosya silinirken hata: $e');
    }
  }

  Future<void> _showFileContentDialog(int index) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final item = _selectedFiles[index];

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop) {
      setState(() {
        _desktopPreviewFilePath = item.path;
        _desktopPreviewFileName = item.name;
      });
      return;
    }

    await showAiPanelFileContentDialog(
      context: context,
      trans: settings.trans,
      filePath: item.path,
      fileName: item.name,
    );
  }

  void _showAddCreditDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PurchaseDialog(),
    );
  }

  Future<bool> _confirmPauseTranslation(BuildContext context, Map<String, String> trans) async {
    final bool? shouldPause = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(trans['pause_warning_title'] ?? 'Duraklatılsın mı?'),
          content: Text(
            trans['pause_warning_message'] ??
                'Bu çeviriyi duraklatırsanız (özellikle uzun/tek parça çevirilerde), çeviri üslubu ve anlam bütünlüğü olumsuz etkilenebilir. Mümkünse duraklatmadan devam etmeniz önerilir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(trans['pause_warning_cancel'] ?? (trans['cancel'] ?? 'İptal')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(trans['pause_warning_pause'] ?? (trans['pause'] ?? 'Duraklat')),
            ),
          ],
        );
      },
    );
    return shouldPause == true;
  }

  Future<bool> _confirmStopTranslationWarning(BuildContext context, Map<String, String> trans) async {
    final bool? shouldStop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(trans['stop_warning_title'] ?? 'Durdurulsun mu?'),
          content: Text(
            trans['stop_warning_message'] ??
                'Çeviriyi durdurmak, bağlam tutarlılığını ve kaliteyi olumsuz etkileyebilir. Mümkünse tamamlanmasını bekleyin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(trans['stop_warning_cancel'] ?? (trans['cancel'] ?? 'İptal')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(trans['stop_warning_stop'] ?? (trans['stop'] ?? 'Durdur')),
            ),
          ],
        );
      },
    );
    return shouldStop == true;
  }

  Future<void> _startBulkProcess(TranslationController controller) async {
    if (controller.userCredits <= 0) {
      _showAddCreditDialog(context);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<AppSettings>();
    final colorScheme = Theme.of(context).colorScheme;

    // Batch başlamadan önce geçersiz dosyaları temizle
    setState(() {
      _selectedFiles.removeWhere((f) {
        return f.path.isEmpty || !File(f.path).existsSync();
      });
      _syncDesktopPreviewWithSelectedFilesUnsafe();
    });

    String normalizeHistoryName(String value) {
      var normalized = value.trim().toLowerCase();
      normalized = normalized.replaceFirst(RegExp(r'^\d{10,}_'), '');
      normalized = normalized.replaceFirst(
        RegExp(r'_[a-f0-9]{32}(?=\.[^.]+$)', caseSensitive: false),
        '',
      );
      return normalized;
    }

    final normalizedTarget = settings.targetLanguage.trim().toLowerCase();
    final completedNames = settings.projects
        .where(
          (project) =>
              project.isCompleted &&
              !project.isPartial &&
              project.targetLanguage.trim().toLowerCase() == normalizedTarget,
        )
        .map((project) => normalizeHistoryName(project.fileName))
        .toSet();

    final skippedCompleted = <BatchFileItem>[];
    if (completedNames.isNotEmpty) {
      setState(() {
        _selectedFiles.removeWhere((file) {
          final shouldSkip = completedNames.contains(normalizeHistoryName(file.name));
          if (shouldSkip) {
            skippedCompleted.add(file);
          }
          return shouldSkip;
        });

        if (skippedCompleted.isNotEmpty) {
          final skippedPaths = skippedCompleted.map((e) => e.path).toSet();
          _originalPaths.removeWhere(
            (key, value) => skippedPaths.contains(key) || skippedPaths.contains(value),
          );
          _syncDesktopPreviewWithSelectedFilesUnsafe();
        }
      });

      if (skippedCompleted.isNotEmpty) {
        await _saveFilesList();
        if (mounted) {
          final shownNames = skippedCompleted.take(3).map((e) => e.name).join(', ');
          final extraCount = skippedCompleted.length - 3;
          final extra = extraCount > 0 ? ' +$extraCount' : '';
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                StringUtils.fillTemplate(
                  settings.trans['completed_files_skipped_warning'] ??
                      'Skipped completed files from history: {names}{extra}',
                  {
                    'names': shownNames,
                    'extra': extra,
                  },
                ),
              ),
            ),
          );
        }
      }
    }

    if (_selectedFiles.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(settings.trans['no_valid_files_found'] ?? 'No valid file found.'),
          backgroundColor: colorScheme.tertiaryContainer,
        ),
      );
      return;
    }

    setState(() {
      _isBulkProcessing = true;
    });

    await _ensureAndroidBackgroundExecution(settings);
    if (!mounted) return;
    final files = _selectedFiles
        .map(
          (f) => BatchFile(
            name: f.name,
            path: f.path,
          ),
        )
        .where((f) => f.path.isNotEmpty)
        .toList();

    final summary = await controller.startBatchTranslationQueue(
      files: files,
      clearSdh: settings.sdhClear,
      targetLanguage: settings.targetLanguage,
      playCompletionSound: true,
    );

    if (mounted) {
      setState(() {
        final completed = summary.completedPaths.toSet();
        for (final path in completed) {
          unawaited(_deleteLocalFile(path));
        }
        _selectedFiles.removeWhere((f) => completed.contains(f.path));
        _originalPaths.removeWhere((k, v) => completed.contains(k));

        // Hata alan dosyaları listenin sonuna taşı
        if (summary.errors.isNotEmpty) {
          final errorFileNames = summary.errors.map((e) => e.fileName).toSet();
          final failedFiles = _selectedFiles.where((f) => errorFileNames.contains(f.name)).toList();
          
          if (failedFiles.isNotEmpty) {
            _selectedFiles.removeWhere((f) => errorFileNames.contains(f.name));
            _selectedFiles.addAll(failedFiles);
          }
        }

        _isBulkProcessing = false;
        _syncDesktopPreviewWithSelectedFilesUnsafe();
      });
      
      await _saveFilesList(); // Listeyi kaydet

      if (!mounted) return;

      if (summary.outOfCredits) {
        final colorScheme = Theme.of(context).colorScheme;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              settings.trans['out_of_credits_stopped'] ?? 'Insufficient credits, operation stopped.',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            backgroundColor: colorScheme.errorContainer,
          ),
        );
      }

      // Hata Raporu Gösterimi
      if (summary.errors.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            title: Text(
              settings.trans['process_report_title'] ?? 'Process Report',
              style: TextStyle(color: Theme.of(ctx).colorScheme.tertiary),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((settings.trans['batch_files_translated_count'] ?? '{count} files translated successfully.').replaceAll('{count}', summary.successCount.toString())),
                  const SizedBox(height: 10),
                  Text((settings.trans['batch_files_error_count'] ?? '{count} files had errors:').replaceAll('{count}', summary.errors.length.toString()),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: summary.errors.length,
                      itemBuilder: (c, i) => Text(
                        "• ${summary.errors[i].fileName}: ${summary.errors[i].message}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(c).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(settings.trans['ok'] ?? 'OK')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _startTranslationForSelectedFile(
    TranslationController controller,
    int index,
  ) async {
    if (index < 0 || index >= _selectedFiles.length) return;
    if (controller.status == TranslationStatus.running ||
        controller.status == TranslationStatus.paused ||
        controller.isLoading) {
      return;
    }

    if (index != 0) {
      setState(() {
        final item = _selectedFiles.removeAt(index);
        _selectedFiles.insert(0, item);
      });
      await _saveFilesList();
    }

    await _startBulkProcess(controller);
  }

  Widget _buildFooter(BuildContext context, AppSettings settings, TranslationController controller) {
    return AiPanelFooter(
      settings: settings,
      controller: controller,
      selectedFilesNotEmpty: _selectedFiles.isNotEmpty,
      estimatedTimeText: _estimatedTime,
    );
  }

  Widget _buildHeaderSection(
    BuildContext context, {
    required AppSettings settings,
    required ColorScheme colorScheme,
    bool balancedTopBand = false,
    Key? historyButtonKey,
  }) {
    return AiPanelHeaderSection(
      sdhClear: settings.sdhClear,
      onSdhClearChanged: (val) => settings.toggleSdhClear(val),
      sdhClearLabel: settings.trans['clear_sdh'] ?? 'SDH Temizle',
      hideInfoButtons: settings.hideInfoButtons,
      onInfoTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(settings.trans['clear_sdh'] ?? 'SDH Temizle'),
            content: Text(settings.trans['clear_sdh_info'] ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(settings.trans['ok'] ?? 'Tamam'),
              ),
            ],
          ),
        );
      },
      historyLabel: settings.trans['history'] ?? 'History',
      onOpenHistory: _openHistoryPage,
      historyButtonKey: historyButtonKey,
      colorScheme: colorScheme,
      balancedTopBand: balancedTopBand,
    );
  }

  Widget _buildCreditCardSection(
    BuildContext context, {
    required AppSettings settings,
    required TranslationController controller,
    required ColorScheme colorScheme,
  }) {
    return AiPanelCreditCardSection(
      settings: settings,
      controller: controller,
      onAddCredits: () => _showAddCreditDialog(context),
    );
  }

  Widget _buildEnglishSourceTipBanner(
    AppSettings settings, {
    bool fillHeight = false,
    double? fontSize,
  }) {
    return AiPanelEnglishSourceTipBanner(
      text: settings.trans['english_source_tip'] ??
          'İpucu: En iyi çeviri kalitesi için kaynak yada hedef altyazı diliniz mümkün olduğunca İngilizce olsun.',
      fillHeight: fillHeight,
      fontSize: fontSize,
    );
  }

  Widget _buildLanguageSelectorSection(
    BuildContext context, {
    required AppSettings settings,
    required ColorScheme colorScheme,
    bool balancedTopBand = false,
  }) {
    final displayText = () {
      final list = _getSortedLanguageOptions(settings.language);
      final selectedCode = settings.targetLanguage.trim();
      final selectedCodeUpper = selectedCode.toUpperCase();
      final match = list.firstWhere(
        (e) => (e['code'] ?? '').trim().toUpperCase() == selectedCodeUpper,
        orElse: () => const {'code': '', 'label': ''},
      );
      final label = (match['label'] ?? '').trim();
      final code = (match['code'] ?? selectedCode).trim();
      if (label.isNotEmpty && code.isNotEmpty) return '$label ($code)';
      if (label.isNotEmpty) return label;
      if (selectedCode.isNotEmpty) return selectedCode.toUpperCase();
      return settings.trans['language'] ?? 'Language';
    }();

    return AiPanelLanguageSelectorSection(
      displayText: displayText,
      selectorTapKey: _languageSelectorTapKey,
      balancedTopBand: balancedTopBand,
      onTap: () {
        () async {
          final anchorRect = _resolveGlobalRect(_languageSelectorTapKey);
          final picked = await _showTargetLanguagePickerBottomSheet(
            settings: settings,
            currentCode: settings.targetLanguage,
            anchorRect: anchorRect,
          );
          if (picked != null && picked.isNotEmpty) {
            settings.setTranslationConfig(lang: picked);
          }
        }();
      },
    );
  }

  Widget _maybeBuildBatchProcessingBanner({
    required AppSettings settings,
    required TranslationController controller,
    required ColorScheme colorScheme,
  }) {
    if (!(controller.isBatchProcessing || _isBulkProcessing)) {
      return const SizedBox.shrink();
    }

    final queueTotal = controller.batchQueueLength > 0
        ? controller.batchQueueLength
        : _selectedFiles.length;
    final message =
        '${settings.trans['batch_processing'] ?? 'Toplu çeviri sürüyor'}: '
        '${controller.batchSuccessCount + controller.batchErrorCount}'
        '/$queueTotal ${settings.trans['completed'] ?? 'tamamlandı'} '
        '• ${settings.trans['error'] ?? 'Hata'}: ${controller.batchErrorCount}';

    return AiPanelBatchProcessingBanner(
      message: message,
      colorScheme: colorScheme,
    );
  }

  Widget _buildPrimaryActionsSection(
    BuildContext context, {
    required AppSettings settings,
    required TranslationController controller,
  }) {
    return AiPanelPrimaryActionsSection(
      settings: settings,
      controller: controller,
      isBulkProcessing: _isBulkProcessing,
      selectedFilesCount: _selectedFiles.length,
      onSave: () => _saveTranslatedWithCloudChoice(
        context,
        settings,
        controller,
      ),
      onNewTranslation: () {
        controller.reset();
        unawaited(_clearAllFiles());
      },
      onStartTranslation: () => _startBulkProcess(controller),
      onPauseOrResume: () async {
        if (controller.status == TranslationStatus.paused) {
          controller.resumeTranslation();
          return;
        }
        final shouldPause = await _confirmPauseTranslation(
          context,
          settings.trans,
        );
        if (shouldPause) {
          controller.pauseTranslation();
        }
      },
      onStop: () => _handleStopPressed(context, settings, controller),
    );
  }

  Future<void> _handleStopPressed(
    BuildContext context,
    AppSettings settings,
    TranslationController controller,
  ) async {
    final shouldStop =
        await _confirmStopTranslationWarning(context, settings.trans);
    if (!shouldStop) return;

    final isBulk = _isBulkProcessing || _selectedFiles.length > 1;
    final filePathToRemove = controller.selectedFile?.path;

    await controller.stopTranslation(
      clearSdh: settings.sdhClear,
      targetLanguage: settings.targetLanguage,
      isBulkProcessing: isBulk,
    );

    if (isBulk) {
      setState(() {
        if (filePathToRemove != null) {
          final normToRemove = _normalizePathForCompare(filePathToRemove);
          final shouldRemoveFromList = controller.batchCompletedPaths.any(
            (p) => _normalizePathForCompare(p) == normToRemove,
          );
          if (shouldRemoveFromList) {
            _selectedFiles.removeWhere((f) {
              final p = _normalizePathForCompare(f.path);
              return p == normToRemove;
            });
          }
        }
        _isBulkProcessing = false;
      });
      await _saveFilesList();
      return;
    }

    setState(() {
      _selectedFiles.clear();
      _originalPaths.clear();
      _isBulkProcessing = false;
    });
    await _saveFilesList();
  }

  Widget _buildFilePickerSection(
    BuildContext context, {
    required AppSettings settings,
    required TranslationController controller,
  }) {
    return AiPanelFilePickerSection(
      settings: settings,
      onAddFiles: () => _handleMultipleFileSelection(controller),
    );
  }

  Future<void> _removeFileByPath(String p) async {
    if (p.isEmpty) return;
    final idx = _selectedFiles.indexWhere((f) => f.path == p);
    if (idx == -1) return;
    await _removeFileFromList(idx);
  }

  Widget _maybeBuildSelectedFilesSection({
    required AppSettings settings,
    required TranslationController controller,
    required ColorScheme colorScheme,
    required int activeIndex,
    bool scrollableList = false,
  }) {
    return AiPanelSelectedFilesSection(
      settings: settings,
      colorScheme: colorScheme,
      selectedFiles: _selectedFiles,
      activeIndex: activeIndex,
      isTranslationRunning: controller.status == TranslationStatus.running,
      onClearAll: () => unawaited(_clearAllFiles()),
      onRemoveByPath: _removeFileByPath,
      scrollableList: scrollableList,
      onGetOriginalPath: (p) => _originalPaths[p] ?? p,
      onReorder: (oldIndex, newIndex, selectedPaths, draggedPath) {
        if (oldIndex < 0 || oldIndex >= _selectedFiles.length) return;

        final selectedIndices = <int>[];
        for (var i = 0; i < _selectedFiles.length; i++) {
          if (selectedPaths.contains(_selectedFiles[i].path)) {
            selectedIndices.add(i);
          }
        }

        final draggedIsSelected = selectedPaths.contains(draggedPath);
        final canMultiReorder = draggedIsSelected && selectedIndices.length > 1;

        if (canMultiReorder) {
          selectedIndices.sort();
          final normalizedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
          final rawDelta = normalizedNew - oldIndex;

          final minIndex = selectedIndices.first;
          final maxIndex = selectedIndices.last;
          final minDelta = -minIndex;
          final maxDelta = (_selectedFiles.length - 1) - maxIndex;
          final delta = rawDelta.clamp(minDelta, maxDelta);
          if (delta == 0) return;

          if (activeIndex != -1) {
            if (selectedIndices.contains(activeIndex)) return;

            for (final idx in selectedIndices) {
              final shifted = idx + delta;
              final crossesActive =
                  (idx < activeIndex && shifted >= activeIndex) ||
                  (idx > activeIndex && shifted <= activeIndex);
              if (crossesActive) return;
            }
          }

          final selectedSet = selectedIndices.toSet();
          final original = List<BatchFileItem>.from(_selectedFiles);
          final selectedItems = <BatchFileItem>[];
          final unselectedItems = <BatchFileItem>[];

          for (var i = 0; i < original.length; i++) {
            if (selectedSet.contains(i)) {
              selectedItems.add(original[i]);
            } else {
              unselectedItems.add(original[i]);
            }
          }

          final shiftedSelectedIndices = selectedIndices
              .map((idx) => idx + delta)
              .toSet();

          final reordered = <BatchFileItem>[];
          var selectedCursor = 0;
          var unselectedCursor = 0;
          for (var i = 0; i < original.length; i++) {
            if (shiftedSelectedIndices.contains(i)) {
              reordered.add(selectedItems[selectedCursor++]);
            } else {
              reordered.add(unselectedItems[unselectedCursor++]);
            }
          }

          setState(() {
            _selectedFiles
              ..clear()
              ..addAll(reordered);
          });
          return;
        }

        if (activeIndex != -1) {
          if (oldIndex == activeIndex) return;
          if (activeIndex == 0 && newIndex <= 0) {
            newIndex = 1;
          }

          final normalizedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
          final crossesActive =
              (oldIndex < activeIndex && normalizedNew >= activeIndex) ||
                  (oldIndex > activeIndex && normalizedNew <= activeIndex);
          if (crossesActive) return;
        }

        setState(() {
          if (oldIndex < newIndex) newIndex -= 1;
          final item = _selectedFiles.removeAt(oldIndex);
          _selectedFiles.insert(newIndex, item);
        });
      },
      onTapPreview: (index) => unawaited(_showFileContentDialog(index)),
      onStartTranslation: (index) => _startTranslationForSelectedFile(controller, index),
    );
  }

  Widget _maybeBuildLiveSubtitleSection({
    required AppSettings settings,
    required TranslationController controller,
    required ColorScheme colorScheme,
    bool forceVisible = false,
    bool fillHeight = false,
  }) {
    final isRunningOrPaused = controller.status == TranslationStatus.running ||
        controller.status == TranslationStatus.paused;
    final shouldShow = forceVisible ||
        (controller.sourceBlocks.isNotEmpty && isRunningOrPaused);
    if (!shouldShow) return const SizedBox.shrink();

    return AiPanelLiveSubtitleSection(
      source: controller.sourceBlocks,
      target: controller.translatedBlocks,
      followEnabled: controller.status == TranslationStatus.running,
      fillHeight: fillHeight,
      showStartingSoonOverlay:
          isRunningOrPaused &&
              controller.sourceBlocks.isNotEmpty &&
              controller.translatedBlocks.isEmpty,
      startingSoonText: settings.trans['translation_starting_soon'] ??
          'Çeviri birkaç saniye içinde başlayacak',
      colorScheme: colorScheme,
    );
  }

  Widget _buildDesktopEmptyPreviewState(
    AppSettings settings,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.playlist_add_check_circle_rounded,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 12),
              Text(
                settings.trans['empty_translation_list_hint'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopIdlePreviewState(
    AppSettings settings,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          settings.trans['click_for_content_long'] ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSpacer(BuildContext context) {
    return const SizedBox.shrink();
  }

  String _normalizeForMatch(String p) {
    // UI equality only: tolerate different directory roots (batch_files vs subtitles)
    // and path separator/casing differences.
    return p.replaceAll('\\', '/').toLowerCase();
  }

  int _findActiveIndex(String activePath) {
    final activeNorm = _normalizeForMatch(activePath);

    final exact = _selectedFiles.indexWhere((f) {
      return _normalizeForMatch(f.path) == activeNorm;
    });
    if (exact != -1) return exact;

    // Fallback: controller may be working on a copied file under another
    // directory but with same <name>_<md5>.<ext>.
    
    String stripHash(String p) {
      final name = path.basename(p);
      final base = path.basenameWithoutExtension(name).replaceFirst(RegExp(r'_[a-fA-F0-9]{32}$'), '');
      return _normalizeForMatch(base + path.extension(name));
    }

    final activeStripped = stripHash(activePath);
    return _selectedFiles.indexWhere((f) {
      return stripHash(f.path) == activeStripped;
    });
  }

  int _computeActiveIndex(TranslationController controller) {
    final activePath = controller.selectedFile?.path;
    final isRunningOrPaused = controller.status == TranslationStatus.running ||
        controller.status == TranslationStatus.paused;
    if (activePath == null || !isRunningOrPaused) return -1;
    return _findActiveIndex(activePath);
  }

  bool _sameSelectedFiles(List<BatchFileItem> next) {
    if (_selectedFiles.length != next.length) return false;
    for (int i = 0; i < _selectedFiles.length; i++) {
      final current = _selectedFiles[i];
      final incoming = next[i];
      if (current.path != incoming.path ||
          current.name != incoming.name ||
          current.source != incoming.source) {
        return false;
      }
    }
    return true;
  }

  void _syncSelectedFilesWithController(TranslationController controller) {
    // Çeviri tamamlandıysa (tek dosya), listeden kaldır
    if (!_isBulkProcessing && controller.isTranslationComplete) {
      final completedPath = controller.selectedFile?.path;
      if (completedPath != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final index =
              _selectedFiles.indexWhere((f) => f.path == completedPath);
          if (index != -1 && mounted) {
            setState(() {
              _selectedFiles.removeAt(index);
              _originalPaths.remove(completedPath);
              _syncDesktopPreviewWithSelectedFilesUnsafe();
              unawaited(_saveFilesList());
              unawaited(_deleteLocalFile(completedPath));
            });
          }
        });
      }
    }

    // Toplu işlem sırasında tamamlanan dosyaları anlık olarak listeden kaldır
    if (_isBulkProcessing) {
      final completedSet = controller.batchCompletedPaths.toSet();
      final toRemove =
          _selectedFiles.where((f) => completedSet.contains(f.path)).toList();

      if (toRemove.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              for (final f in toRemove) {
                unawaited(_deleteLocalFile(f.path));
              }
              _selectedFiles
                  .removeWhere((f) => completedSet.contains(f.path));
              _originalPaths.removeWhere((k, v) => completedSet.contains(k));
              _syncDesktopPreviewWithSelectedFilesUnsafe();
              unawaited(_saveFilesList());
            });
          }
        });
      }
    }
  }

  void _bindControllerCallbacks({
    required BuildContext context,
    required AppSettings settings,
    required TranslationController controller,
    required ColorScheme colorScheme,
  }) {
    // Controller'ın loglama fonksiyonunu AppSettings'e bağla
    controller.onLog = (key, [param]) => settings.addLog(key, param);
    controller.onProgress = settings.showProgressNotification;
    controller.onError = (title, message) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title, style: TextStyle(color: colorScheme.error)),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(settings.trans['ok'] ?? 'Tamam'),
            ),
          ],
        ),
      );
    };
    controller.onWakelock = (enabled) {
      final s = context.read<AppSettings>();
      if (enabled) {
        if (s.keepScreenOn) {
          s.setWakelockEnabled(true);
        }
        return;
      }
      // Always try to release wakelock when translation stops.
      s.setWakelockEnabled(false);
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final colorScheme = Theme.of(context).colorScheme;

    final rev = settings.batchFilesRevision;
    if (_lastSeenBatchFilesRevision != rev) {
      _lastSeenBatchFilesRevision = rev;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_reloadSavedFilesSilently());
      });
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Ctrl+O — Dosya ekle
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          final controller = context.read<TranslationController>();
          _handleMultipleFileSelection(controller);
        },
        // Ctrl+Enter — Çeviriyi başlat
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          final controller = context.read<TranslationController>();
          if (_selectedFiles.isNotEmpty &&
              !_isBulkProcessing &&
              controller.status == TranslationStatus.idle) {
            _startBulkProcess(controller);
          }
        },
        // F5 — Geçmişi aç
        const SingleActivator(LogicalKeyboardKey.f5): () {
          _openHistoryPage();
        },
      },
      child: Focus(
        autofocus: true,
        child: Consumer<TranslationController>(
      builder: (context, controller, child) {
        final activeIndex = _computeActiveIndex(controller);
        _syncSelectedFilesWithController(controller);
        _bindControllerCallbacks(
          context: context,
          settings: settings,
          controller: controller,
          colorScheme: colorScheme,
        );

        return DropRegion(
          formats: const [Formats.fileUri],
          onDropOver: (event) {
            if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              return DropOperation.none;
            }
            if (!_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = true);
            }
            if (event.session.allowedOperations.contains(DropOperation.copy)) {
              return DropOperation.copy;
            }
            if (event.session.allowedOperations.contains(DropOperation.move)) {
              return DropOperation.move;
            }
            return DropOperation.none;
          },
          onDropLeave: (_) {
            if (_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = false);
            }
          },
          onDropEnded: (_) {
            if (_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = false);
            }
          },
          onPerformDrop: (event) async {
            if (_isDropZoneActive && mounted) {
              setState(() => _isDropZoneActive = false);
            }
            if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              return;
            }
            final droppedPaths = await _extractDroppedPaths(event);
            unawaited(_enqueueLocalSubtitlePaths(controller, droppedPaths));
          },
          child: Stack(
            children: [
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop =
                        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
                    final useSplitLayout = isDesktop;

                    Widget buildLeftContent() {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!useSplitLayout) ...[
                            _buildCreditCardSection(
                              context,
                              settings: settings,
                              controller: controller,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: kAiPanelSectionGap),
                            _buildHeaderSection(
                              context,
                              settings: settings,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: kAiPanelSectionGap),
                          ],
                          if (!settings.hideInfoButtons &&
                              controller.status == TranslationStatus.idle) ...[
                            _buildEnglishSourceTipBanner(settings),
                            const SizedBox(height: kAiPanelSectionGap),
                          ],
                          _buildLanguageSelectorSection(
                            context,
                            settings: settings,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: kAiPanelSectionGap),
                          _maybeBuildBatchProcessingBanner(
                            settings: settings,
                            controller: controller,
                            colorScheme: colorScheme,
                          ),
                          _buildPrimaryActionsSection(
                            context,
                            settings: settings,
                            controller: controller,
                          ),
                          _buildFilePickerSection(
                            context,
                            settings: settings,
                            controller: controller,
                          ),
                          _maybeBuildSelectedFilesSection(
                            settings: settings,
                            controller: controller,
                            colorScheme: colorScheme,
                            activeIndex: activeIndex,
                          ),
                          if (!useSplitLayout) ...[
                            const SizedBox(height: kAiPanelSectionGap),
                            _maybeBuildLiveSubtitleSection(
                              settings: settings,
                              controller: controller,
                              colorScheme: colorScheme,
                            ),
                          ],
                          _buildBottomSpacer(context),
                        ],
                      );
                    }

                    if (!useSplitLayout) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                        child: buildLeftContent(),
                      );
                    }

                    final isCompactDesktopWidth = constraints.maxWidth < 980;
                    final leftPaneMinWidth = isCompactDesktopWidth
                        ? 300.0
                        : 420.0;
                    final leftPaneMaxWidth = isCompactDesktopWidth
                        ? 520.0
                        : 560.0;
                    final leftPaneWidth =
                        (constraints.maxWidth * 0.5).clamp(
                          leftPaneMinWidth,
                          leftPaneMaxWidth,
                        );
                    final hasFooterFileNameRow =
                      (controller.status == TranslationStatus.running ||
                        controller.status == TranslationStatus.paused) &&
                      controller.currentFileName != null;
                    final isCompactDesktopHeight = constraints.maxHeight < 420;
                    // Footer artık sadece ilerleme çubuğu (log main.dart'ta ortak).
                    // Bu yüzden split layout'ta alttan sadece footer'ın üstüne binmemek
                    // için küçük, sabit bir inset ayırıyoruz.
                    final desktopBottomInset =
                        (isCompactDesktopHeight ? 44.0 : 44.0) +
                        (hasFooterFileNameRow ? 28.0 : 0.0);

                    _scheduleDesktopTopBandHeightSync();
                    _scheduleDesktopCreditBandSync();
                    _scheduleDesktopTopControlsHeightSync();
                    _scheduleDesktopPrimaryActionsTopSync();
                    _scheduleDesktopActionButtonsBlockHeightSync();
                    _scheduleDesktopBatchBannerTopSync();
                    const desktopSectionGap = kAiPanelSectionGap;
                    final showInfoBanner =
                        !settings.hideInfoButtons &&
                        controller.status == TranslationStatus.idle;
                    final creditCardTopOffset =
                      _desktopCreditCardTopOffset > 0
                        ? _desktopCreditCardTopOffset
                        : 8.0;
                    final creditCardHeight =
                      _desktopCreditCardBandHeight > 0
                        ? _desktopCreditCardBandHeight
                        : 120.0;
                    final infoBoxTopOffset =
                      _desktopPrimaryActionsTopOffset > 0
                        ? _desktopPrimaryActionsTopOffset
                        : 120.0;
                    // infoBoxHeight = "Çeviriyi Başlat" üst kenarından
                    // "Dosya Ekle" alt kenarına kadar tam mesafe.
                    // Her ikisi de globalToLocal ile ölçüldüğünden
                    // hiçbir ölçekte hiza bozulmaz.
                    final infoBoxHeight = (_desktopFilePickerBottomOffset - infoBoxTopOffset)
                        .clamp(88.0, 400.0);
                    final rightAlignedTopHeight = showInfoBanner
                      ? (_desktopTopControlsHeight > 0
                        ? _desktopTopControlsHeight
                        : (infoBoxTopOffset + infoBoxHeight).clamp(
                          220.0,
                          520.0,
                        ))
                      : (_desktopPrimaryActionsTopOffset > 0
                          ? _desktopPrimaryActionsTopOffset
                          : (creditCardTopOffset + creditCardHeight));

                    Widget buildDesktopCreditCard() {
                      return SizedBox(
                        height: creditCardHeight,
                        child: KeyedSubtree(
                          key: _desktopCreditCardKey,
                          child: _buildCreditCardSection(
                            context,
                            settings: settings,
                            controller: controller,
                            colorScheme: colorScheme,
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: constraints.maxHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: leftPaneWidth,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                0,
                                0,
                                8,
                                desktopBottomInset,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  KeyedSubtree(
                                    key: _desktopLeftTopControlsKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        KeyedSubtree(
                                          key: _desktopLeftTopBandContentKey,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _buildHeaderSection(
                                                context,
                                                settings: settings,
                                                colorScheme: colorScheme,
                                                balancedTopBand: true,
                                                historyButtonKey:
                                                    _desktopHistoryButtonKey,
                                              ),
                                              const SizedBox(
                                                height: desktopSectionGap,
                                              ),
                                              _buildLanguageSelectorSection(
                                                context,
                                                settings: settings,
                                                colorScheme: colorScheme,
                                                balancedTopBand: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: desktopSectionGap),
                                        KeyedSubtree(
                                          key: _desktopBatchBannerKey,
                                          child: _maybeBuildBatchProcessingBanner(
                                            settings: settings,
                                            controller: controller,
                                            colorScheme: colorScheme,
                                          ),
                                        ),
                                        KeyedSubtree(
                                          key: _desktopPrimaryActionsKey,
                                          child: KeyedSubtree(
                                            key: _desktopActionButtonsBlockKey,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _buildPrimaryActionsSection(
                                                  context,
                                                  settings: settings,
                                                  controller: controller,
                                                ),
                                                KeyedSubtree(
                                                  key: _desktopFilePickerKey,
                                                  child: _buildFilePickerSection(
                                                    context,
                                                    settings: settings,
                                                    controller: controller,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: _maybeBuildSelectedFilesSection(
                                      settings: settings,
                                      controller: controller,
                                      colorScheme: colorScheme,
                                      activeIndex: activeIndex,
                                      scrollableList: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                8,
                                0,
                                0,
                                desktopBottomInset,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showInfoBanner)
                                    SizedBox(
                                      height: rightAlignedTopHeight,
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            top: creditCardTopOffset,
                                            left: 0,
                                            right: 0,
                                            height: creditCardHeight,
                                            child: buildDesktopCreditCard(),
                                          ),
                                          Positioned(
                                            top: infoBoxTopOffset,
                                            left: 0,
                                            right: 0,
                                            height: infoBoxHeight,
                                            child: _buildEnglishSourceTipBanner(
                                              settings,
                                              fillHeight: true,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else ...[
                                    buildDesktopCreditCard(),
                                    const SizedBox(height: desktopSectionGap),
                                  ],
                                  Expanded(
                                    child: _selectedFiles.isEmpty
                                        ? _buildDesktopEmptyPreviewState(
                                            settings,
                                            colorScheme,
                                          )
                                        : (_desktopPreviewFilePath != null &&
                                                _desktopPreviewFileName != null
                                            ? AiPanelFileContentPreviewPanel(
                                                trans: settings.trans,
                                                filePath:
                                                    _desktopPreviewFilePath!,
                                                fileName:
                                                    _desktopPreviewFileName!,
                                                onClose: () {
                                                  setState(() {
                                                    _desktopPreviewFilePath =
                                                        null;
                                                    _desktopPreviewFileName =
                                                        null;
                                                  });
                                                },
                                              )
                                            : ((controller.status ==
                                                            TranslationStatus
                                                                .running ||
                                                        controller.status ==
                                                            TranslationStatus
                                                                .paused) &&
                                                    controller
                                                        .sourceBlocks.isNotEmpty
                                                ? _maybeBuildLiveSubtitleSection(
                                                    settings: settings,
                                                    controller: controller,
                                                    colorScheme: colorScheme,
                                                    forceVisible: true,
                                                    fillHeight: true,
                                                  )
                                                : _buildDesktopIdlePreviewState(
                                                    settings,
                                                    colorScheme,
                                                  ))),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_isDropZoneActive)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        settings.trans['add_file'] ?? 'DOSYA EKLE',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildFooter(context, settings, controller),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                  colorScheme.tertiary,
                  colorScheme.error,
                  colorScheme.inversePrimary,
                ],
              ),
            ),
            ],
          ),
        );
      },
    ),
    ),
    );
  }
}

String _computeFileMd5FromPath(String filePath) {
  final bytes = File(filePath).readAsBytesSync();
  return md5.convert(bytes).toString();
}
