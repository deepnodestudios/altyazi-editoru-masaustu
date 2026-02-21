import 'dart:collection';

import 'translations/translations_ar.dart';
import 'translations/translations_cn.dart';
import 'translations/translations_cs.dart';
import 'translations/translations_da.dart';
import 'translations/translations_de.dart';
import 'translations/translations_el.dart';
import 'translations/translations_en.dart';
import 'translations/translations_es.dart';
import 'translations/translations_fa.dart';
import 'translations/translations_fr.dart';
import 'translations/translations_gu.dart';
import 'translations/translations_he.dart';
import 'translations/translations_hu.dart';
import 'translations/translations_id.dart';
import 'translations/translations_in.dart';
import 'translations/translations_it.dart';
import 'translations/translations_ja.dart';
import 'translations/translations_kn.dart';
import 'translations/translations_ko.dart';
import 'translations/translations_ml.dart';
import 'translations/translations_mr.dart';
import 'translations/translations_nl.dart';
import 'translations/translations_pa.dart';
import 'translations/translations_pl.dart';
import 'translations/translations_pt.dart';
import 'translations/translations_ro.dart';
import 'translations/translations_ru.dart';
import 'translations/translations_sv.dart';
import 'translations/translations_ta.dart';
import 'translations/translations_te.dart';
import 'translations/translations_th.dart';
import 'translations/translations_tr.dart';
import 'translations/translations_uk.dart';
import 'translations/translations_vi.dart';

// ---------------------------------------------------------------------------
// Translation map view with alias resolution
// ---------------------------------------------------------------------------

class _TranslationMapView extends MapBase<String, String> {
    _TranslationMapView(this._source, [String languageCode = 'EN']);

    final Map<String, String> _source;

    /// Backward-compatible key aliases so old code using e.g.
    /// `trans['cancel']` still works even though the canonical key is
    /// `btn_cancel`.
    static const Map<String, String> _keyAliases = {
        'batch_complete_title': 'notification_translation_completed_title',
        'batch_save_all_zip': 'save_all_zip_dialog_title',
        'btn_continue': 'battery_opt_continue_anyway',
        'continue': 'btn_resume',
        'cancel': 'btn_cancel',
        'save': 'btn_save',
        'error_prefix': 'error',
        'language': 'language_title',
        'new_translation': 'start_translation',
        'search_language_hint': 'search_hint',
        'share_selected_tooltip': 'share',
        'system_log_copied': 'log_copied',
        'decrease_font_size': 'editor_zoom_out_tooltip',
        'increase_font_size': 'editor_zoom_in_tooltip',
        'zip_saving_progress': 'zip_creating',
    };

    @override
    String? operator [](Object? key) {
        if (key is! String) return null;

        // Direct lookup
        final direct = _source[key];
        if (direct != null) return direct;

        // Alias resolution
        final alias = _keyAliases[key];
        if (alias != null) {
            final aliased = _source[alias];
            if (aliased != null) return aliased;
        }

        // If nothing found, return the key itself (safe fallback)
        return key;
    }

    @override
    void operator []=(String key, String value) {
        _source[key] = value;
    }

    @override
    void clear() {
        _source.clear();
    }

    @override
    Iterable<String> get keys => _source.keys;

    @override
    String? remove(Object? key) {
        return _source.remove(key);
    }
}

// ---------------------------------------------------------------------------
// Main Translations class
// ---------------------------------------------------------------------------

class Translations {
    static const List<String> supportedUiLanguages = <String>[
        'TR', 'EN', 'FR', 'DE', 'IT', 'ES', 'RU', 'EL', 'PT', 'AR',
        'IN', 'ID', 'CN', 'JA', 'KO',
        'NL', 'SV', 'PL', 'TH', 'VI', 'HE', 'FA',
        'TA', 'TE', 'ML', 'KN', 'PA', 'GU', 'MR',
        'UK', 'CS', 'RO', 'HU', 'DA',
    ];

    // Cache: language code → translation map view
    static final Map<String, Map<String, String>> _cache = {};

    static final Map<String, Map<String, String>> _globalFallbackCache = {};

    static const Map<String, String> _appNameByLanguage = <String, String>{
        'TR': 'AI Altyazı Çeviri & Editör',
        'EN': 'AI Subtitle Translator & Editor',
        'FR': 'Traducteur & Éditeur de sous-titres IA',
        'DE': 'KI Untertitel-Übersetzer & Editor',
        'IT': 'Traduttore & Editor di sottotitoli IA',
        'ES': 'Traductor y Editor de subtítulos IA',
        'RU': 'ИИ Переводчик и Редактор субтитров',
        'EL': 'Μεταφραστής & Επεξεργαστής Υποτίτλων AI',
        'PT': 'Tradutor e Editor de legendas IA',
        'AR': 'مترجم ومحرر ترجمات بالذكاء الاصطناعي',
        'IN': 'AI उपशीर्षक अनुवादक और संपादक',
        'ID': 'Penerjemah & Editor Subtitle AI',
        'CN': 'AI 字幕翻译与编辑器',
        'JA': 'AI 字幕翻訳＆エディター',
        'KO': 'AI 자막 번역기 & 편집기',
        'NL': 'AI-ondertitelvertaler en -editor',
        'SV': 'AI-undertextöversättare och redigerare',
        'PL': 'Tłumacz i edytor napisów AI',
        'TH': 'นักแปลและแก้ไขคำบรรยาย AI',
        'VI': 'Trình dịch và chỉnh sửa phụ đề AI',
        'HE': 'מתרגם ועורך כתוביות AI',
        'FA': 'مترجم و ویرایشگر زیرنویس هوش مصنوعی',
        'TA': 'AI வசன வரி மொழிபெயர்ப்பான் மற்றும் தொகுப்பான்',
        'TE': 'AI సబ్‌టైటిల్ అనువాదకుడు & ఎడిటర్',
        'ML': 'AI സബ്ടൈറ്റിൽ വിവർത്തകനും എഡിറ്ററും',
        'KN': 'AI ಉಪಶೀರ್ಷಿಕೆ ಅನುವಾದಕ ಮತ್ತು ಸಂಪಾದಕ',
        'PA': 'AI ਸਬਟਾਈਟਲ ਅਨੁਵਾਦਕ ਅਤੇ ਸੰਪਾਦਕ',
        'GU': 'AI ઉપશીર્ષક અનુવાદક અને સંપાદક',
        'MR': 'AI उपशीर्षक अनुवादक आणि संपादक',
        'UK': 'AI Перекладач та Редактор субтитрів',
        'CS': 'AI Překladač a Editor titulků',
        'RO': 'AI Traducător și Editor de Subtitrări',
        'HU': 'AI Feliratfordító és Szerkesztő',
        'DA': 'AI Undertekstoversætter og Editor',
    };

    static String _normalizeLanguageCode(String rawCode) {
        final code = rawCode.trim().toUpperCase();
        if (code == 'HI') return 'IN';
        if (code == 'ZH') return 'CN';
        return code;
    }

    static String resolveAppName(
        String languageCode, {
        Map<String, String>? trans,
    }) {
        final normalized = _normalizeLanguageCode(languageCode);
        final localizedDefault =
            _appNameByLanguage[normalized] ?? _appNameByLanguage['EN']!;

        final candidate = trans?['app_name'];
        if (candidate == null) return localizedDefault;
        final trimmed = candidate.trim();
        if (trimmed.isEmpty || trimmed == 'app_name') return localizedDefault;

        final englishDefault = _appNameByLanguage['EN']!;
        if (normalized != 'EN' && trimmed == englishDefault) {
            return localizedDefault;
        }

        return trimmed;
    }

    static void clearCache() {
        _cache.clear();
        _globalFallbackCache.clear();
    }

    static Map<String, String> getWithGlobalFallback(String lang) {
        final normalized = lang.trim().toUpperCase();
        final cached = _globalFallbackCache[normalized];
        if (cached != null) return cached;

        final merged = <String, String>{...get(normalized)};

        final fallbackOrder = <String>[
            if (normalized != 'TR') 'TR',
            if (normalized != 'EN') 'EN',
            ...supportedUiLanguages.where(
                (code) => code != normalized && code != 'TR' && code != 'EN',
            ),
        ];

        for (final code in fallbackOrder) {
            final source = get(code);
            source.forEach((key, value) {
                merged.putIfAbsent(key, () => value);
            });
        }

        final immutable = Map<String, String>.unmodifiable(merged);
        final view = _TranslationMapView(immutable, normalized);
        _globalFallbackCache[normalized] = view;
        return view;
    }

    /// Routing table: language code → const translation data.
    static const Map<String, Map<String, String>> _data = {
        'EN': kTranslationsEN,
        'FR': kTranslationsFR,
        'DE': kTranslationsDE,
        'IT': kTranslationsIT,
        'ES': kTranslationsES,
        'PT': kTranslationsPT,
        'RU': kTranslationsRU,
        'EL': kTranslationsEL,
        'AR': kTranslationsAR,
        'IN': kTranslationsIN,
        'ID': kTranslationsID,
        'CN': kTranslationsCN,
        'JA': kTranslationsJA,
        'KO': kTranslationsKO,
        'NL': kTranslationsNL,
        'SV': kTranslationsSV,
        'PL': kTranslationsPL,
        'TH': kTranslationsTH,
        'VI': kTranslationsVI,
        'HE': kTranslationsHE,
        'FA': kTranslationsFA,
        'TA': kTranslationsTA,
        'TE': kTranslationsTE,
        'ML': kTranslationsML,
        'KN': kTranslationsKN,
        'PA': kTranslationsPA,
        'GU': kTranslationsGU,
        'MR': kTranslationsMR,
        'TR': kTranslationsTR,
        'UK': kTranslationsUK,
        'CS': kTranslationsCS,
        'RO': kTranslationsRO,
        'HU': kTranslationsHU,
        'DA': kTranslationsDA,
    };

    static Map<String, String> get(String lang) {
        lang = _normalizeLanguageCode(lang);

        final cached = _cache[lang];
        if (cached != null) return cached;

        final constData = _data[lang] ?? kTranslationsTR;
        final view = _TranslationMapView(
            Map<String, String>.from(constData), lang);
        _cache[lang] = view;
        return view;
    }
}
