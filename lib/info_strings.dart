/// This file is kept for backward compatibility.
/// All translation strings (including former InfoStrings data) now live in
/// the per-language files under lib/translations/.
///
/// [InfoStrings.get] simply delegates to [Translations.get] so that any
/// call-site importing this file continues to compile.
library;

import 'translations.dart';

class InfoStrings {
  static Map<String, String> get(String lang) => Translations.get(lang);
}
