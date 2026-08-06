import os
import glob
import re

translations = {
    "ar": {"batch_complete_title": "اكتملت الترجمة"},
    "cn": {"batch_complete_title": "翻译完成"},
    "cs": {"batch_complete_title": "Překlad dokončen"},
    "da": {"batch_complete_title": "Oversættelse fuldført"},
    "de": {"batch_complete_title": "Übersetzung abgeschlossen"},
    "el": {"batch_complete_title": "Η μετάφραση ολοκληρώθηκε"},
    "en": {"batch_complete_title": "Translation Completed"},
    "es": {"batch_complete_title": "Traducción completada"},
    "fa": {"batch_complete_title": "ترجمه کامل شد"},
    "fr": {"batch_complete_title": "Traduction terminée"},
    "gu": {"batch_complete_title": "અનુવાદ પૂર્ણ"},
    "he": {"batch_complete_title": "התרגום הושלם"},
    "hu": {"batch_complete_title": "A fordítás befejeződött"},
    "id": {"batch_complete_title": "Terjemahan Selesai"},
    "in": {"batch_complete_title": "अनुवाद संपन्न"},
    "it": {"batch_complete_title": "Traduzione completata"},
    "ja": {"batch_complete_title": "翻訳完了"},
    "kn": {"batch_complete_title": "ಅನುವಾದ ಪೂರ್ಣಗೊಂಡಿದೆ"},
    "ko": {"batch_complete_title": "번역 완료"},
    "ml": {"batch_complete_title": "വിവർത്തനം പൂർത്തിയായി"},
    "mr": {"batch_complete_title": "भाषांतर पूर्ण झाले"},
    "nl": {"batch_complete_title": "Vertaling voltooid"},
    "pa": {"batch_complete_title": "ਅਨੁਵਾਦ ਪੂਰਾ ਹੋਇਆ"},
    "pl": {"batch_complete_title": "Tłumaczenie zakończone"},
    "pt": {"batch_complete_title": "Tradução concluída"},
    "ro": {"batch_complete_title": "Traducere finalizată"},
    "ru": {"batch_complete_title": "Перевод завершен"},
    "sv": {"batch_complete_title": "Översättning slutförd"},
    "ta": {"batch_complete_title": "மொழிபெயர்ப்பு முடிந்தது"},
    "te": {"batch_complete_title": "అనువాదం పూర్తయింది"},
    "th": {"batch_complete_title": "การแปลเสร็จสมบูรณ์"},
    "tr": {"batch_complete_title": "Çeviri Tamamlandı"},
    "uk": {"batch_complete_title": "Переклад завершено"},
    "vi": {"batch_complete_title": "Dịch hoàn tất"}
}

trans_dir = r"lib\translations"
files = glob.glob(os.path.join(trans_dir, "translations_*.dart"))

for file_path in files:
    filename = os.path.basename(file_path)
    lang_code = filename.replace("translations_", "").replace(".dart", "")
    
    if lang_code in translations:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        updated_content = content
        for k, v in translations[lang_code].items():
            # Replace existing value for the key
            pattern = re.compile(rf"('{k}'\s*:\s*)'[^']*'(,?)")
            if pattern.search(updated_content):
                v_esc = v.replace("'", "\\'")
                updated_content = pattern.sub(rf"\g<1>'{v_esc}'\g<2>", updated_content)
                print(f"Updated {k} in {filename}")
            else:
                # If not found, add it (though it should be there)
                print(f"Key {k} not found in {filename}, skipping update.")

        if updated_content != content:
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(updated_content)
    else:
        print(f"No translations for {lang_code}")
