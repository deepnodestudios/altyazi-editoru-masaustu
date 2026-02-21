// ignore_for_file: avoid_print, avoid_relative_lib_imports
// Reads the LIVE Translations.get(lang) output for every supported language
// and writes one Dart source file per language into lib/translations/.
//
// Usage:  dart run tool/split_translations.dart
//
// The generated files are deterministic (sorted keys, consistent escaping).

import 'dart:io';
import '../lib/translations.dart';

// Keys that exist only in _keyDefaultsEn / _keyDefaultsByLang (not in _source)
// We probe these explicitly so they appear in the generated output.
const _probeKeys = <String>[
  'btn_cancel', 'back', 'forward', 'root', 'fullscreen',
  'history_no_results', 'internet_error', 'live_view_scroll_down',
  'compare_with_source', 'n_items_selected', 'no_content_to_save_error',
  'onboarding_title_3', 'onboarding_desc_3', 'open_file_location',
  'purchase_processing', 'system_log_empty', 'timecode_limit_exceeded',
  'yandex_code_title', 'yandex_code_label', 'yandex_code_help',
  'yandex_code_open_browser', 'delete_confirm', 'delete_permanent_warning',
  'delete_all_permanent_warning', 'delete_project_title', 'delete_project_confirm',
  'filter_tooltip', 'filter_all', 'filter_completed', 'filter_partial',
  'batch_save_individual_prompt', 'batch_save_all_srt', 'select_all',
  'deselect_all', 'save_selected', 'save_all_srt_dialog_title',
  'snackbar_saved_all_files', 'saving_files_progress',
  'check_updates', 'update_title', 'update_action', 'update_not_found',
  'update_new_version', 'update_current_version', 'update_later',
  'credit_history_title', 'credit_history_added', 'credit_history_spent',
  'credit_history_error', 'credit_history_empty', 'credit_history_cache_hit',
  'copy', 'cut', 'paste', 'delete',
  'lang_nl', 'lang_sv', 'lang_pl', 'lang_th', 'lang_vi',
  'lang_he', 'lang_fa', 'lang_ta', 'lang_te', 'lang_ml',
  'lang_kn', 'lang_pa', 'lang_gu', 'lang_mr',
];

const _langNames = <String, String>{
  'EN': 'English',  'TR': 'Turkish',  'FR': 'French',  'DE': 'German',
  'IT': 'Italian',  'ES': 'Spanish',  'PT': 'Portuguese','RU': 'Russian',
  'EL': 'Greek',    'AR': 'Arabic',   'IN': 'Hindi',    'ID': 'Indonesian',
  'CN': 'Chinese',  'JA': 'Japanese', 'KO': 'Korean',
  'NL': 'Dutch',    'SV': 'Swedish',  'PL': 'Polish',   'TH': 'Thai',
  'VI': 'Vietnamese','HE':'Hebrew',   'FA': 'Persian',   'TA': 'Tamil',
  'TE': 'Telugu',   'ML': 'Malayalam','KN': 'Kannada',   'PA': 'Punjabi',
  'GU': 'Gujarati', 'MR': 'Marathi',
};

void main() {
  final dir = Directory('lib/translations');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  for (final lang in Translations.supportedUiLanguages) {
    final trans = Translations.get(lang);

    final entries = <String, String>{};

    // 1. Collect all keys from the merged _source map
    for (final key in trans.keys) {
      final val = trans[key];
      if (val != null) entries[key] = val;
    }

    // 2. Probe extra keys that may only be in _keyDefaultsByLang / _keyDefaultsEn
    for (final key in _probeKeys) {
      if (entries.containsKey(key)) continue;
      final val = trans[key];
      if (val != null && val != key) entries[key] = val;
    }

    // 3. Generate Dart file
    final uc = lang.toUpperCase();
    final lc = lang.toLowerCase();
    final name = _langNames[uc] ?? uc;

    final buf = StringBuffer()
      ..writeln('// $uc – $name translations')
      ..writeln('// Auto-generated – do not hand-edit.')
      ..writeln('// Source: translations.dart + info_strings.dart')
      ..writeln('// ignore_for_file: file_names, lines_longer_than_80_chars')
      ..writeln()
      ..writeln('const Map<String, String> kTranslations$uc = <String, String>{');

    final sortedKeys = entries.keys.toList()..sort();
    for (final key in sortedKeys) {
      buf.writeln('  ${_literal(key)}: ${_literal(entries[key]!)},');
    }
    buf.writeln('};');

    final outPath = 'lib/translations/translations_$lc.dart';
    File(outPath).writeAsStringSync(buf.toString());
    stderr.writeln('  ✓ $outPath — ${entries.length} keys');
  }

  stderr.writeln(
    '\nDone! ${Translations.supportedUiLanguages.length} files generated.',
  );
}

/// Returns a valid Dart string literal for [s].
/// Always uses single-quoted strings with explicit \n escaping.
String _literal(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\n');
  return "'$escaped'";
}
