// Centralized list of supported target languages for the AI panel.
// Mobile is the canonical source for cross-platform target language options.

const List<Map<String, String>> aiPanelLanguageOptions = [
  {'code': 'AF', 'label': 'Afrikaans'},
  {'code': 'SQ', 'label': 'Albanian'},
  {'code': 'AM', 'label': 'Amharic'},
  {'code': 'AR', 'label': 'Arabic'},
  {'code': 'HY', 'label': 'Armenian'},
  {'code': 'AZ', 'label': 'Azerbaijani'},
  {'code': 'EU', 'label': 'Basque'},
  {'code': 'BE', 'label': 'Belarusian'},
  {'code': 'BN', 'label': 'Bengali'},
  {'code': 'BS', 'label': 'Bosnian'},
  {'code': 'BG', 'label': 'Bulgarian'},
  {'code': 'CA', 'label': 'Catalan'},
  {'code': 'CEB', 'label': 'Cebuano'},
  {'code': 'ZH', 'label': 'Chinese'},
  {'code': 'ZH-CN', 'label': 'Chinese (Simplified, China)'},
  {'code': 'ZH-TW', 'label': 'Chinese (Traditional, Taiwan)'},
  {'code': 'ZH-HK', 'label': 'Chinese (Traditional, Hong Kong)'},
  {'code': 'CO', 'label': 'Corsican'},
  {'code': 'HR', 'label': 'Croatian'},
  {'code': 'CZ', 'label': 'Czech'},
  {'code': 'DA', 'label': 'Danish'},
  {'code': 'NL', 'label': 'Dutch'},
  {'code': 'EN', 'label': 'English'},
  {'code': 'EN-US', 'label': 'English (United States)'},
  {'code': 'EN-GB', 'label': 'English (United Kingdom)'},
  {'code': 'EN-AU', 'label': 'English (Australia)'},
  {'code': 'EN-CA', 'label': 'English (Canada)'},
  {'code': 'EO', 'label': 'Esperanto'},
  {'code': 'ET', 'label': 'Estonian'},
  {'code': 'FI', 'label': 'Finnish'},
  {'code': 'FR', 'label': 'Français'},
  {'code': 'FR-CA', 'label': 'Français (Canada)'},
  {'code': 'FY', 'label': 'Frisian'},
  {'code': 'GL', 'label': 'Galician'},
  {'code': 'KA', 'label': 'Georgian'},
  {'code': 'DE', 'label': 'Deutsch'},
  {'code': 'DE-AT', 'label': 'Deutsch (Österreich)'},
  {'code': 'DE-CH', 'label': 'Deutsch (Schweiz)'},
  {'code': 'EL', 'label': 'Greek'},
  {'code': 'GU', 'label': 'Gujarati'},
  {'code': 'HT', 'label': 'Haitian Creole'},
  {'code': 'HA', 'label': 'Hausa'},
  {'code': 'HAW', 'label': 'Hawaiian'},
  {'code': 'HE', 'label': 'Hebrew'},
  {'code': 'HI', 'label': 'Hindi'},
  {'code': 'HMN', 'label': 'Hmong'},
  {'code': 'HU', 'label': 'Hungarian'},
  {'code': 'IS', 'label': 'Icelandic'},
  {'code': 'IG', 'label': 'Igbo'},
  {'code': 'ID', 'label': 'Indonesian'},
  {'code': 'GA', 'label': 'Irish'},
  {'code': 'IT', 'label': 'Italiano'},
  {'code': 'JA', 'label': 'Japanese'},
  {'code': 'JW', 'label': 'Javanese'},
  {'code': 'KN', 'label': 'Kannada'},
  {'code': 'KK', 'label': 'Kazakh'},
  {'code': 'KM', 'label': 'Khmer'},
  {'code': 'KO', 'label': 'Korean'},
  {'code': 'KU', 'label': 'Kurdish'},
  {'code': 'KY', 'label': 'Kyrgyz'},
  {'code': 'LO', 'label': 'Lao'},
  {'code': 'LA', 'label': 'Latin'},
  {'code': 'LV', 'label': 'Latvian'},
  {'code': 'LT', 'label': 'Lithuanian'},
  {'code': 'LB', 'label': 'Luxembourgish'},
  {'code': 'MK', 'label': 'Macedonian'},
  {'code': 'MG', 'label': 'Malagasy'},
  {'code': 'MS', 'label': 'Malay'},
  {'code': 'ML', 'label': 'Malayalam'},
  {'code': 'MT', 'label': 'Maltese'},
  {'code': 'MI', 'label': 'Maori'},
  {'code': 'MR', 'label': 'Marathi'},
  {'code': 'MN', 'label': 'Mongolian'},
  {'code': 'MY', 'label': 'Myanmar'},
  {'code': 'NE', 'label': 'Nepali'},
  {'code': 'NO', 'label': 'Norwegian'},
  {'code': 'PS', 'label': 'Pashto'},
  {'code': 'FA', 'label': 'Persian'},
  {'code': 'PL', 'label': 'Polish'},
  {'code': 'PT', 'label': 'Português'},
  {'code': 'PT-BR', 'label': 'Português (Brasil)'},
  {'code': 'PA', 'label': 'Punjabi'},
  {'code': 'RO', 'label': 'Romanian'},
  {'code': 'RU', 'label': 'Русский'},
  {'code': 'SM', 'label': 'Samoan'},
  {'code': 'GD', 'label': 'Scots Gaelic'},
  {'code': 'SR', 'label': 'Serbian'},
  {'code': 'ST', 'label': 'Sesotho'},
  {'code': 'SN', 'label': 'Shona'},
  {'code': 'SD', 'label': 'Sindhi'},
  {'code': 'SI', 'label': 'Sinhala'},
  {'code': 'SK', 'label': 'Slovak'},
  {'code': 'SL', 'label': 'Slovenian'},
  {'code': 'SO', 'label': 'Somali'},
  {'code': 'ES', 'label': 'Español'},
  {'code': 'ES-ES', 'label': 'Español (España)'},
  {'code': 'ES-MX', 'label': 'Español (México)'},
  {'code': 'ES-AR', 'label': 'Español (Argentina)'},
  {'code': 'SU', 'label': 'Sundanese'},
  {'code': 'SW', 'label': 'Swahili'},
  {'code': 'SV', 'label': 'Swedish'},
  {'code': 'TL', 'label': 'Tagalog'},
  {'code': 'TG', 'label': 'Tajik'},
  {'code': 'TA', 'label': 'Tamil'},
  {'code': 'TE', 'label': 'Telugu'},
  {'code': 'TH', 'label': 'Thai'},
  {'code': 'TR', 'label': 'Türkçe'},
  {'code': 'UK', 'label': 'Ukrainian'},
  {'code': 'UR', 'label': 'Urdu'},
  {'code': 'UZ', 'label': 'Uzbek'},
  {'code': 'VI', 'label': 'Vietnamese'},
  {'code': 'CY', 'label': 'Welsh'},
  {'code': 'XH', 'label': 'Xhosa'},
  {'code': 'YI', 'label': 'Yiddish'},
  {'code': 'YO', 'label': 'Yoruba'},
  {'code': 'ZU', 'label': 'Zulu'},
];

const Map<String, String> aiPanelLanguageCodeAliases = {
  'CS': 'CZ',
  'JV': 'JW',
  'PT-PT': 'PT',
};

const Map<String, String> aiPanelLanguageValueAliases = {
  'PORTUGUES (PORTUGAL)': 'PT',
  'PORTUGUÊS (PORTUGAL)': 'PT',
  'PORTUGUESE (PORTUGAL)': 'PT',
  'EUROPEAN PORTUGUESE': 'PT',
};

const Map<String, String> aiPanelLanguagePromptNames = {
  'EN-US': 'American English',
  'EN-GB': 'British English',
  'EN-AU': 'Australian English',
  'EN-CA': 'Canadian English',
  'ZH-CN': 'Chinese (Simplified)',
  'ZH-TW': 'Chinese (Traditional, Taiwan)',
  'ZH-HK': 'Chinese (Traditional, Hong Kong)',
  'FR-CA': 'Canadian French',
  'DE-AT': 'German (Austria)',
  'DE-CH': 'German (Switzerland)',
  'PT': 'Portuguese',
  'PT-BR': 'Brazilian Portuguese',
  'ES-ES': 'Spanish (Spain)',
  'ES-MX': 'Spanish (Mexico)',
  'ES-AR': 'Spanish (Argentina)',
};

String normalizeAiPanelLanguageCode(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final upper = trimmed.replaceAll('_', '-').toUpperCase();
  final aliasedValue = aiPanelLanguageValueAliases[upper] ?? upper;
  final canonical = aiPanelLanguageCodeAliases[aliasedValue] ?? aliasedValue;

  for (final option in aiPanelLanguageOptions) {
    final code = (option['code'] ?? '').trim();
    if (code.isNotEmpty && code.toUpperCase() == canonical) {
      return code;
    }
  }

  for (final option in aiPanelLanguageOptions) {
    final label = (option['label'] ?? '').trim();
    if (label.isNotEmpty && label.toUpperCase() == canonical) {
      return (option['code'] ?? '').trim();
    }
  }

  final looksLikeCode = RegExp(
    r'^[A-Za-z]{2,5}(?:-[A-Za-z0-9]{2,8})?$',
  ).hasMatch(canonical);
  return looksLikeCode ? canonical : trimmed;
}

String aiPanelLanguageLabelForCode(String value) {
  final normalized = normalizeAiPanelLanguageCode(value);
  if (normalized.isEmpty) return '';

  for (final option in aiPanelLanguageOptions) {
    final code = (option['code'] ?? '').trim();
    if (code == normalized) {
      return (option['label'] ?? '').trim();
    }
  }

  return normalized;
}

String aiPanelLanguagePromptNameForCode(String value) {
  final normalized = normalizeAiPanelLanguageCode(value);
  if (normalized.isEmpty) return '';
  return aiPanelLanguagePromptNames[normalized] ??
      aiPanelLanguageLabelForCode(normalized);
}

/// Extra dialect constraints for the translation system prompt.
String aiPanelLanguageDialectNotes(String value) {
  final normalized = normalizeAiPanelLanguageCode(value);
  if (normalized == 'MS') {
    return 'Write only standard Malaysian Bahasa Melayu. Do not mix in Bahasa Indonesia '
        '(use kereta not mobil, telefon not telepon, universiti not universitas, '
        'aktiviti not aktivitas, perbualan not percakapan).';
  }
  return '';
}

bool aiPanelLanguageCodesEqual(String left, String right) {
  final normalizedLeft = normalizeAiPanelLanguageCode(left);
  final normalizedRight = normalizeAiPanelLanguageCode(right);
  return normalizedLeft == normalizedRight;
}
