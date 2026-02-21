import 'dart:io';

import 'package:altyazi_editoru/translations.dart';

/// Quick sanity checker for a few UI keys that must be localized
/// across all supported UI languages.
///
/// Run:
///   dart tool/check_required_ui_keys.dart
void main() {
  const keys = <String>[
    // User-requested UI labels
    'btn_cancel',
    'sort_tooltip',
    'sort_date_desc',
    'sort_date_asc',
    'sort_name_asc',
    'sort_name_desc',
    'clear_history_title',
    'clear_history_confirm',
    'add_file',
    'back',

    // Editor buttons/tooltips
    'editor_shift_time_tooltip',
    'editor_close_tooltip',
    'editor_save_tooltip',
  ];

  // Keys where EN value is legitimately the same in certain languages
  // (e.g. "Name" is the same word in German)
  const allowedSameEn = <String, Set<String>>{
    'DE': {'sort_name_asc', 'sort_name_desc'},
  };

  final langs = Translations.supportedUiLanguages;
  final en = Translations.get('EN');

  var totalProblems = 0;

  for (final lang in langs) {
    final trans = Translations.get(lang);

    final missing = <String>[];
    final empty = <String>[];
    final sameAsEnglish = <String>[];

    for (final key in keys) {
      final value = trans[key];
      if (value == null) {
        missing.add(key);
        continue;
      }

      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == key) {
        empty.add(key);
        continue;
      }

      if (lang != 'EN') {
        if (allowedSameEn[lang]?.contains(key) ?? false) continue;
        final enValue = en[key]?.trim();
        if (enValue != null && enValue.isNotEmpty && trimmed == enValue) {
          sameAsEnglish.add(key);
        }
      }
    }

    if (missing.isEmpty && empty.isEmpty && sameAsEnglish.isEmpty) {
      continue;
    }

    totalProblems++;
    stdout.writeln('[$lang]');
    if (missing.isNotEmpty) stdout.writeln('  missing: ${missing.join(', ')}');
    if (empty.isNotEmpty) stdout.writeln('  empty:   ${empty.join(', ')}');
    if (sameAsEnglish.isNotEmpty) {
      stdout.writeln('  sameEn:  ${sameAsEnglish.join(', ')}');
    }
  }

  if (totalProblems == 0) {
    stdout.writeln(
      'OK: all required keys look localized for all supported UI languages.',
    );
  } else {
    stdout.writeln('Found issues in $totalProblems language(s).');
  }
}
