import os
import re
import glob

# Remaining languages mapped directly to their translations
translations = {
    "cs": {
        "batch_translation_beta": "Dávkový překlad (Beta)",
        "batch_api_triggered": "Batch API spuštěno pro {count} soubory.",
        "batch_all_completed": "Všechny soubory byly úspěšně přeloženy.",
        "batch_process_prefix": "Dávkový proces",
        "batch_process_canceled": "Proces zrušen.",
        "batch_file_sent": "{filename} odeslán na server. Úloha: {job}",
        "batch_error_prefix": "Chyba dávkového překladu",
        "batch_file_error": "U souboru {filename} došlo na serveru k chybě.",
        "batch_credit_partial": "Vaše kredity ({credits}) jsou menší než vybrané soubory ({total})...",
        "batch_process_ongoing": "Probíhá (kontrola každých 15 s, zbývající úlohy: {count})...",
        "batch_no_credit_log": "Nedostatečný kredit. Nemáte dostatek pro spuštění.",
        "batch_starting": "Spouštění dávkového překladu...",
        "batch_file_rate_limit": "Proces dosáhl limitu pro {filename}.",
        "batch_file_success": "{filename} úspěšně přeložen.",
        "insufficient_credit_batch_stop": "Nedostatek kreditů. Dávkový překlad byl zastaven."
    },
    "da": {
        "batch_translation_beta": "Batch-oversættelse (Beta)",
        "batch_api_triggered": "Batch API udløst for {count} filer.",
        "batch_all_completed": "Alle filer er blevet oversat med succes.",
        "batch_process_prefix": "Batch-proces",
        "batch_process_canceled": "Proces annulleret.",
        "batch_file_sent": "{filename} sendt til server. Job: {job}",
        "batch_error_prefix": "Batch-oversættelsesfejl",
        "batch_file_error": "{filename} stødte på en fejl på serveren.",
        "batch_credit_partial": "Dine kreditter ({credits}) er færre end de valgte filer ({total})...",
        "batch_process_ongoing": "I gang (tjekker hver 15. sek., resterende job: {count})...",
        "batch_no_credit_log": "Utilstrækkelige kreditter. Du har ikke nok saldo til at starte.",
        "batch_starting": "Starter batch-oversættelse...",
        "batch_file_rate_limit": "Processen nåede grænserne for {filename}.",
        "batch_file_success": "{filename} blev oversat.",
        "insufficient_credit_batch_stop": "Utilstrækkelige kredittter. Batch-oversættelse stoppet."
    },
    "el": {
        "batch_translation_beta": "Μαζική Μετάφραση (Beta)",
        "batch_api_triggered": "Το Batch API ενεργοποιήθηκε για {count} αρχεία.",
        "batch_all_completed": "Όλα τα αρχεία μεταφράστηκαν με επιτυχία.",
        "batch_process_prefix": "Μαζική Διαδικασία",
        "batch_process_canceled": "Η διαδικασία ακυρώθηκε.",
        "batch_file_sent": "Το {filename} στάλθηκε στον διακομιστή. Εργασία: {job}",
        "batch_error_prefix": "Σφάλμα Μαζικής Μετάφρασης",
        "batch_file_error": "Το {filename} αντιμετώπισε σφάλμα στον διακομιστή.",
        "batch_credit_partial": "Οι πιστώσεις σας ({credits}) είναι λιγότερες από τα επιλεγμένα αρχεία ({total})...",
        "batch_process_ongoing": "Σε εξέλιξη (έλεγχος κάθε 15s, υπολειπόμενες εργασίες: {count})...",
        "batch_no_credit_log": "Ανεπαρκείς πιστώσεις. Δεν έχετε αρκετό υπόλοιπο.",
        "batch_starting": "Έναρξη Μαζικής Μετάφρασης...",
        "batch_file_rate_limit": "Η διαδικασία έφτασε στα όρια για το {filename}.",
        "batch_file_success": "Το {filename} μεταφράστηκε με επιτυχία.",
        "insufficient_credit_batch_stop": "Ανεπαρκείς πιστώσεις. Η μαζική μετάφραση σταμάτησε."
    },
    "fa": {
        "batch_translation_beta": "ترجمه دسته‌ای (آزمایشی)",
        "batch_api_triggered": "رابط دسته‌ای برای {count} فایل فعال شد.",
        "batch_all_completed": "تمام فایل‌ها با موفقیت ترجمه شدند.",
        "batch_process_prefix": "فرآیند دسته‌ای",
        "batch_process_canceled": "فرآیند لغو شد.",
        "batch_file_sent": "{filename} به سرور ارسال شد. کار: {job}",
        "batch_error_prefix": "خطای ترجمه دسته‌ای",
        "batch_file_error": "{filename} با خطایی در سرور مواجه شد.",
        "batch_credit_partial": "اعتبار شما ({credits}) کمتر از فایل‌های انتخابی ({total}) است...",
        "batch_process_ongoing": "در حال انجام (بررسی هر ۱۵ ثانیه، کارهای باقیمانده: {count})...",
        "batch_no_credit_log": "اعتبار ناکافی. موجودی کافی برای شروع ندارید.",
        "batch_starting": "شروع ترجمه دسته‌ای...",
        "batch_file_rate_limit": "فرآیند برای {filename} به محدودیت رسید.",
        "batch_file_success": "{filename} با موفقیت ترجمه شد.",
        "insufficient_credit_batch_stop": "اعتبار ناکافی است. ترجمه دسته‌ای متوقف شد."
    },
    "gu": {
        "batch_translation_beta": "બૅચ અનુવાદ (બીટા)",
        "batch_api_triggered": "{count} ફાઇલો માટે બૅચ API ટ્રિગર થયું.",
        "batch_all_completed": "બધી ફાઇલોનો સફળતાપૂર્વક અનુવાદ થયો છે.",
        "batch_process_prefix": "બૅચ પ્રક્રિયા",
        "batch_process_canceled": "પ્રક્રિયા રદ કરવામાં આવી.",
        "batch_file_sent": "{filename} સર્વર પર મોકલવામાં આવી. જોબ: {job}",
        "batch_error_prefix": "બૅચ અનુવાદ ભૂલ",
        "batch_file_error": "{filename} માં સર્વર પર ભૂલ આવી.",
        "batch_credit_partial": "તમારી ક્રેડિટ્સ ({credits}) પસંદ કરેલી ફાઇલો ({total}) કરતાં ઓછી છે...",
        "batch_process_ongoing": "પ્રગતિમાં (દર 15 સેકન્ડે તપાસ, બાકી રહેલી જોબ્સ: {count})...",
        "batch_no_credit_log": "અપૂરતી ક્રેડિટ. શરૂ કરવા માટે તમારી પાસે પૂરતું બેલેન્સ નથી.",
        "batch_starting": "બૅચ અનુવાદ શરૂ થઈ રહ્યું છે...",
        "batch_file_rate_limit": "પ્રક્રિયા માટે {filename} મર્યાદા વટાવી ગઈ છે.",
        "batch_file_success": "{filename} સફળતાપૂર્વક અનુવાદિત.",
        "insufficient_credit_batch_stop": "અપૂરતી ક્રેડિટ. બૅચ અનુવાદ બંધ થઈ ગયું."
    },
    "he": {
        "batch_translation_beta": "תרגום באצ' (בטא)",
        "batch_api_triggered": "הופעל API עבור {count} קבצים.",
        "batch_all_completed": "כל הקבצים תורגמו בהצלחה.",
        "batch_process_prefix": "תהליך באצ'",
        "batch_process_canceled": "התהליך בוטל.",
        "batch_file_sent": "{filename} נשלח לשרת. משימה: {job}",
        "batch_error_prefix": "שגיאת תרגום באצ'",
        "batch_file_error": "{filename} נתקל בשגיאה בשרת.",
        "batch_credit_partial": "הקרדיטים שלך ({credits}) פחות מКоличество הקבצים שנבחרו ({total})...",
        "batch_process_ongoing": "בתהליך (בודק כל 15 שניות, משימות שנותרו: {count})...",
        "batch_no_credit_log": "אין מספיק קרדיטים להתחלת הפעולה.",
        "batch_starting": "מתחיל תרגום באצ'...",
        "batch_file_rate_limit": "התהליך הגיע למגבלות עבור {filename}.",
        "batch_file_success": "{filename} תורגם בהצלחה.",
        "insufficient_credit_batch_stop": "אין מספיק קרדיטים. תרגום הבאצ' הופסק."
    },
    "hu": {
        "batch_translation_beta": "Kötegelt fordítás (Béta)",
        "batch_api_triggered": "Kötegelt API elindítva {count} fájlhoz.",
        "batch_all_completed": "Minden fájl sikeresen lefordítva.",
        "batch_process_prefix": "Kötegelt feldolgozás",
        "batch_process_canceled": "Folyamat megszakítva.",
        "batch_file_sent": "{filename} elküldve a szerverre. Feladat: {job}",
        "batch_error_prefix": "Kötegelt fordítási hiba",
        "batch_file_error": "{filename} hibába ütközött a szerveren.",
        "batch_credit_partial": "A kreditjei ({credits}) kevesebbek, mint a kiválasztott fájlok ({total})...",
        "batch_process_ongoing": "Folyamatban (ellenőrzés 15mp-enként, hátralévő feladatok: {count})...",
        "batch_no_credit_log": "Nincs elég kredit az indításhoz.",
        "batch_starting": "Kötegelt fordítás indítása...",
        "batch_file_rate_limit": "A folyamat elérte a korlátokat a(z) {filename} esetében.",
        "batch_file_success": "{filename} sikeresen lefordítva.",
        "insufficient_credit_batch_stop": "Nincs elég kredit. A kötegelt fordítás leállt."
    },
    "id": {
        "batch_translation_beta": "Terjemahan Massal (Beta)",
        "batch_api_triggered": "API massal dipicu untuk {count} file.",
        "batch_all_completed": "Semua file telah berhasil diterjemahkan.",
        "batch_process_prefix": "Proses Massal",
        "batch_process_canceled": "Proses dibatalkan.",
        "batch_file_sent": "{filename} dikirim ke server. Pekerjaan: {job}",
        "batch_error_prefix": "Kesalahan Terjemahan Massal",
        "batch_file_error": "{filename} menemui kesalahan di server.",
        "batch_credit_partial": "Kredit Anda ({credits}) kurang dari file yang dipilih ({total})...",
        "batch_process_ongoing": "Sedang berlangsung (memeriksa setiap 15 d, sisa pekerjaan: {count})...",
        "batch_no_credit_log": "Kredit tidak cukup. Saldo tidak memadai untuk memulai.",
        "batch_starting": "Memulai Terjemahan Massal...",
        "batch_file_rate_limit": "Proses mencapai batas untuk {filename}.",
        "batch_file_success": "{filename} berhasil diterjemahkan.",
        "insufficient_credit_batch_stop": "Kredit tidak cukup. Terjemahan massal dihentikan."
    },
    "in": {
        "batch_translation_beta": "Terjemahan Massal (Beta)",
        "batch_api_triggered": "API massal dipicu untuk {count} file.",
        "batch_all_completed": "Semua file telah berhasil diterjemahkan.",
        "batch_process_prefix": "Proses Massal",
        "batch_process_canceled": "Proses dibatalkan.",
        "batch_file_sent": "{filename} dikirim ke server. Pekerjaan: {job}",
        "batch_error_prefix": "Kesalahan Terjemahan Massal",
        "batch_file_error": "{filename} menemui kesalahan di server.",
        "batch_credit_partial": "Kredit Anda ({credits}) kurang dari file yang dipilih ({total})...",
        "batch_process_ongoing": "Sedang berlangsung (memeriksa setiap 15 d, sisa pekerjaan: {count})...",
        "batch_no_credit_log": "Kredit tidak cukup. Saldo tidak memadai untuk memulai.",
        "batch_starting": "Memulai Terjemahan Massal...",
        "batch_file_rate_limit": "Proses mencapai batas untuk {filename}.",
        "batch_file_success": "{filename} berhasil diterjemahkan.",
        "insufficient_credit_batch_stop": "Kredit tidak cukup. Terjemahan massal dihentikan."
    },
    "kn": {
        "batch_translation_beta": "ಬ್ಯಾಚ್ ಅನುವಾದ (ಬೀಟಾ)",
        "batch_api_triggered": "{count} ಫೈಲ್‌ಗಳಿಗಾಗಿ ಬ್ಯಾಚ್ API ಟ್ರಿಗರ್ ಮಾಡಲಾಗಿದೆ.",
        "batch_all_completed": "ಎಲ್ಲಾ ಫೈಲ್‌ಗಳನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಅನುವಾದಿಸಲಾಗಿದೆ.",
        "batch_process_prefix": "ಬ್ಯಾಚ್ ಪ್ರಕ್ರಿಯೆ",
        "batch_process_canceled": "ಪ್ರಕ್ರಿಯೆಯನ್ನು ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.",
        "batch_file_sent": "{filename} ಸರ್ವರ್‌ಗೆ ಕಳುಹಿಸಲಾಗಿದೆ. ಕೆಲಸ: {job}",
        "batch_error_prefix": "ಬ್ಯಾಚ್ ಅನುವಾದ ದೋಷ",
        "batch_file_error": "{filename} ಸರ್ವರ್‌ನಲ್ಲಿ ದೋಷವನ್ನು ಎದುರಿಸಿದೆ.",
        "batch_credit_partial": "ನಿಮ್ಮ ಕ್ರೆಡಿಟ್‌ಗಳು ({credits}) ಆಯ್ಕೆಮಾಡಿದ ಫೈಲ್‌ಗಳಿಗಿಂತ ({total}) ಕಡಿಮೆ...",
        "batch_process_ongoing": "ಪ್ರಗತಿಯಲ್ಲಿದೆ (ಹದಿನೈದು ಸೆಕೆಂಡುಗಳಿಗೆ ಒಮ್ಮೆ, ಉಳಿದ ಕೆಲಸಗಳು: {count})...",
        "batch_no_credit_log": "ಸಾಕಷ್ಟು ಕ್ರೆಡಿಟ್‌ಗಳಿಲ್ಲ. ಪ್ರಾರಂಭಿಸಲು ನಿಮ್ಮ ಬಳಿ ಬ್ಯಾಲೆನ್ಸ್ ಇಲ್ಲ.",
        "batch_starting": "ಬ್ಯಾಚ್ ಅನುವಾದವನ್ನು ಪ್ರಾರಂಭಿಸಲಾಗುತ್ತಿದೆ...",
        "batch_file_rate_limit": "{filename} ಗೆ ಮಿತಿಗಳನ್ನು ತಲುಪಿದೆ.",
        "batch_file_success": "{filename} ಅನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಅನುವಾದಿಸಲಾಗಿದೆ.",
        "insufficient_credit_batch_stop": "ಸಾಕಷ್ಟು ಕ್ರೆಡಿಟ್‌ಗಳಿಲ್ಲ. ಬ್ಯಾಚ್ ಅನುವಾದವನ್ನು ನಿಲ್ಲಿಸಲಾಗಿದೆ."
    },
    "ml": {
        "batch_translation_beta": "ബാച്ച് വിവർത്തനം (ബീറ്റാ)",
        "batch_api_triggered": "{count} ഫയലുകൾക്കായി ബാച്ച് API ആരംഭിച്ചു.",
        "batch_all_completed": "എല്ലാ ഫയലുകളും വിജയകരമായി വിവർത്തനം ചെയ്തു.",
        "batch_process_prefix": "ബാച്ച് പ്രക്രിയ",
        "batch_process_canceled": "പ്രക്രിയ റദ്ദാക്കി.",
        "batch_file_sent": "{filename} സെർവറിലേക്ക് അയച്ചു. ജോലി: {job}",
        "batch_error_prefix": "ബാച്ച് വിവർത്തനത്തിൽ പിശക്",
        "batch_file_error": "{filename} സർവറിൽ പിശക് നേരിട്ടു.",
        "batch_credit_partial": "നിങ്ങളുടെ ക്രെഡിറ്റുകൾ ({credits}) തെരഞ്ഞെടുത്ത ഫയലുകളേക്കാൾ ({total}) കുറവാണ്...",
        "batch_process_ongoing": "പുരോഗമിക്കുന്നു (ഓരോ 15 സെക്കൻഡിലും പരിശോധിക്കുന്നു, ശേഷിക്കുന്ന ജോലികൾ: {count})...",
        "batch_no_credit_log": "ആവശ്യത്തിന് ക്രെഡിറ്റ് ഇല്ല.",
        "batch_starting": "ബാച്ച് വിവർത്തനം തുടങ്ങുന്നു...",
        "batch_file_rate_limit": "{filename} പരിധി ലംഘിച്ചു.",
        "batch_file_success": "{filename} വിജയകരമായി വിവർത്തനം ചെയ്തു.",
        "insufficient_credit_batch_stop": "ആവശ്യത്തിന് ക്രെഡിറ്റ് ഇല്ല. വിവർത്തനം നിർത്തി."
    },
    "mr": {
        "batch_translation_beta": "बॅच भाषांतर (बीटा)",
        "batch_api_triggered": "{count} फाइल्ससाठी बॅच API ट्रिगर केले.",
        "batch_all_completed": "सर्व फाइल्सचे यशस्वीरित्या भाषांतर झाले.",
        "batch_process_prefix": "बॅच प्रक्रिया",
        "batch_process_canceled": "प्रक्रिया रद्द केली.",
        "batch_file_sent": "{filename} सर्व्हरवर पाठवले. काम: {job}",
        "batch_error_prefix": "बॅच भाषांतर त्रुटी",
        "batch_file_error": "{filename} सर्व्हरवर त्रुटी आली.",
        "batch_credit_partial": "तुमचे क्रेडिट ({credits}) निवडलेल्या फाइल्सपेक्षा ({total}) कमी आहेत...",
        "batch_process_ongoing": "प्रगतीवर (दर 15 सेकंदांनी तपासत आहे, उर्वरित कामे: {count})...",
        "batch_no_credit_log": "अपुरे क्रेडिट. सुरू करण्यासाठी बॅलन्स नाही.",
        "batch_starting": "बॅच भाषांतर सुरू करत आहे...",
        "batch_file_rate_limit": "प्रक्रियेने {filename} ची मर्यादा गाठली.",
        "batch_file_success": "{filename} चे यशस्वीरित्या भाषांतर झाले.",
        "insufficient_credit_batch_stop": "अपुरे क्रेडिट. बॅच भाषांतर थांबवले."
    },
    "nl": {
        "batch_translation_beta": "Batchvertaling (Beta)",
        "batch_api_triggered": "Batch-API geactiveerd voor {count} bestanden.",
        "batch_all_completed": "Alle bestanden zijn succesvol vertaald.",
        "batch_process_prefix": "Batchproces",
        "batch_process_canceled": "Proces geannuleerd.",
        "batch_file_sent": "{filename} naar server gestuurd. Taak: {job}",
        "batch_error_prefix": "Fout bij batchvertaling",
        "batch_file_error": "{filename} is op de server op een fout gestuit.",
        "batch_credit_partial": "Uw credits ({credits}) zijn minder dan de geselecteerde bestanden ({total})...",
        "batch_process_ongoing": "Bezig (controle elke 15s, resterende taken: {count})...",
        "batch_no_credit_log": "Onvoldoende credits om te starten.",
        "batch_starting": "Batchvertaling starten...",
        "batch_file_rate_limit": "Proceslimiet bereikt voor {filename}.",
        "batch_file_success": "{filename} succesvol vertaald.",
        "insufficient_credit_batch_stop": "Onvoldoende credits. Batchvertaling gestopt."
    },
    "pa": {
        "batch_translation_beta": "ਬੈਚ ਅਨੁਵਾਦ (ਬੀਟਾ)",
        "batch_api_triggered": "{count} ਫਾਈਲਾਂ ਲਈ ਬੈਚ API ਟਰਿੱਗਰ ਕੀਤਾ ਗਿਆ।",
        "batch_all_completed": "ਸਾਰੀਆਂ ਫਾਈਲਾਂ ਦਾ ਸਫਲਤਾਪੂਰਵਕ ਅਨੁਵਾਦ ਹੋ ਗਿਆ ਹੈ।",
        "batch_process_prefix": "ਬੈਚ ਪ੍ਰਕਿਰਿਆ",
        "batch_process_canceled": "ਪ੍ਰਕਿਰਿਆ ਰੱਦ ਕੀਤੀ ਗਈ।",
        "batch_file_sent": "{filename} ਸਰਵਰ ਤੇ ਭੇਜੀ ਗਈ। ਕੰਮ: {job}",
        "batch_error_prefix": "ਬੈਚ ਅਨੁਵਾਦ ਗਲਤੀ",
        "batch_file_error": "{filename} ਨੂੰ ਸਰਵਰ ਤੇ ਗਲਤੀ ਮਿਲੀ।",
        "batch_credit_partial": "ਤੁਹਾਡੇ ਕਰੈਡਿਟ ({credits}) ਚੁਣੀਆਂ ਫਾਈਲਾਂ ({total}) ਤੋਂ ਘੱਟ ਹਨ...",
        "batch_process_ongoing": "ਚੱਲ ਰਿਹਾ ਹੈ (ਹਰ 15 ਸਕਿੰਟ, ਬਾਕੀ ਕੰਮ: {count})...",
        "batch_no_credit_log": "ਕ੍ਰੈਡਿਟ ਨਾਕਾਫ਼ੀ ਹੈ। ਹੋਰ ਬਕਾਇਆ ਚਾਹੀਦਾ ਹੈ।",
        "batch_starting": "ਬੈਚ ਅਨੁਵਾਦ ਸ਼ੁਰੂ ਹੋ ਰਿਹਾ ਹੈ...",
        "batch_file_rate_limit": "ਸੀਮਾ {filename} ਲਈ ਪੂਰੀ ਹੋ ਗਈ।",
        "batch_file_success": "{filename} ਸਫਲਤਾਪੂਰਵਕ ਅਨੁਵਾਦ ਹੋਈ।",
        "insufficient_credit_batch_stop": "ਕ੍ਰੈਡਿਟ ਨਾਕਾਫ਼ੀ ਹੈ। ਬੈਚ ਅਨੁਵਾਦ ਰੁਕ ਗਿਆ।"
    },
    "pl": {
        "batch_translation_beta": "Tłumaczenie wsadowe (Beta)",
        "batch_api_triggered": "Rozpoczęto proces API dla {count} plików.",
        "batch_all_completed": "Wszystkie pliki zostały pomyślnie przetłumaczone.",
        "batch_process_prefix": "Proces wsadowy",
        "batch_process_canceled": "Proces anulowany.",
        "batch_file_sent": "{filename} wysłany na serwer. Zadanie: {job}",
        "batch_error_prefix": "Błąd tłumaczenia wsadowego",
        "batch_file_error": "{filename} napotkał błąd na serwerze.",
        "batch_credit_partial": "Liczba kredytów ({credits}) mniejsza niż wybranych plików ({total})...",
        "batch_process_ongoing": "W toku (sprawdzanie co 15s, pozostałe zadania: {count})...",
        "batch_no_credit_log": "Niewystarczająca liczba kredytów do rozpoczęcia.",
        "batch_starting": "Uruchamianie tłumaczenia wsadowego...",
        "batch_file_rate_limit": "Przekroczono limity dla pliku {filename}.",
        "batch_file_success": "{filename} przetłumaczono pomyślnie.",
        "insufficient_credit_batch_stop": "Niewystarczające kredyty. Przerwano tłumaczenie wsadowe."
    },
    "ro": {
        "batch_translation_beta": "Traducere în lot (Beta)",
        "batch_api_triggered": "API-ul în lot a fost declanșat pentru {count} fișiere.",
        "batch_all_completed": "Toate fișierele au fost traduse cu succes.",
        "batch_process_prefix": "Proces în lot",
        "batch_process_canceled": "Proces anulat.",
        "batch_file_sent": "{filename} a fost trimis la server. Sarcină: {job}",
        "batch_error_prefix": "Eroare la traducerea în lot",
        "batch_file_error": "{filename} a întâmpinat o eroare pe server.",
        "batch_credit_partial": "Creditele ({credits}) sunt mai puține decât fișierele selectate ({total})...",
        "batch_process_ongoing": "În curs (se verifică la 15s, sarcini rămase: {count})...",
        "batch_no_credit_log": "Credite insuficiente pentru a începe.",
        "batch_starting": "Pornire traducere în lot...",
        "batch_file_rate_limit": "Procesul a atins limitele pentru {filename}.",
        "batch_file_success": "{filename} tradus cu succes.",
        "insufficient_credit_batch_stop": "Credite insuficiente. Traducerea în lot a fost oprită."
    },
    "sv": {
        "batch_translation_beta": "Satsöversättning (Beta)",
        "batch_api_triggered": "Sats-API aktiverat för {count} filer.",
        "batch_all_completed": "Alla filer har översatts framgångsrikt.",
        "batch_process_prefix": "Satsprocess",
        "batch_process_canceled": "Process avbruten.",
        "batch_file_sent": "{filename} skickades till servern. Jobb: {job}",
        "batch_error_prefix": "Fel vid satsöversättning",
        "batch_file_error": "{filename} stötte på ett fel på servern.",
        "batch_credit_partial": "Dina poäng ({credits}) är färre än filerna ({total})...",
        "batch_process_ongoing": "Pågår (kontroll var 15:e sekund, återstående: {count})...",
        "batch_no_credit_log": "Otillräckliga poäng för att starta.",
        "batch_starting": "Startar satsöversättning...",
        "batch_file_rate_limit": "Processen nådde gränsen för {filename}.",
        "batch_file_success": "{filename} översattes framgångsrikt.",
        "insufficient_credit_batch_stop": "Otillräckligt saldo. Satsöversättning stoppad."
    },
    "ta": {
        "batch_translation_beta": "தொகுப்பு மொழிபெயர்ப்பு (பீட்டா)",
        "batch_api_triggered": "{count} கோப்புகளுக்கு தொகுப்பு API தொடங்கப்பட்டது.",
        "batch_all_completed": "அனைத்து கோப்புகளும் வெற்றிகரமாக மொழிபெயர்க்கப்பட்டன.",
        "batch_process_prefix": "தொகுப்பு செயல்முறை",
        "batch_process_canceled": "செயல்முறை ரத்து செய்யப்பட்டது.",
        "batch_file_sent": "{filename} சேவையகத்திற்கு அனுப்பப்பட்டது. வேலை: {job}",
        "batch_error_prefix": "தொகுப்பு மொழிபெயர்ப்பு பிழை",
        "batch_file_error": "{filename} சேவையகத்தில் பிழையைச் சந்தித்தது.",
        "batch_credit_partial": "உங்கள் வரவுகள் ({credits}) தேர்ந்தெடுக்கப்பட்ட கோப்புகளை விட ({total}) குறைவு...",
        "batch_process_ongoing": "செயல்பாட்டில் உள்ளது (15விக்கு முறை, மீதமுள்ள வேலைகள்: {count})...",
        "batch_no_credit_log": "போதுமான வரவு இல்லை.",
        "batch_starting": "தொகுப்பு மொழிபெயர்ப்பைத் தொடங்குகிறது...",
        "batch_file_rate_limit": "{filename}க்கான வரம்பை அடைந்தது.",
        "batch_file_success": "{filename} வெற்றிகரமாக மொழிபெயர்க்கப்பட்டது.",
        "insufficient_credit_batch_stop": "வரவு போதாது. தொகுப்பு மொழிபெயர்ப்பு நிறுத்தப்பட்டது."
    },
    "te": {
        "batch_translation_beta": "బ్యాచ్ అనువాదం (బీటా)",
        "batch_api_triggered": "{count} ఫైళ్ల కోసం బ్యాచ్ API ప్రారంభించబడింది.",
        "batch_all_completed": "అన్ని ఫైళ్లు విజయవంతంగా అనువదించబడ్డాయి.",
        "batch_process_prefix": "బ్యాచ్ ప్రక్రియ",
        "batch_process_canceled": "ప్రక్రియ రద్దు చేయబడింది.",
        "batch_file_sent": "{filename} సర్వర్‌కు పంపబడింది. పని: {job}",
        "batch_error_prefix": "బ్యాచ్ అనువాద లోపం",
        "batch_file_error": "{filename} సర్వర్‌లో లోపాన్ని ఎదుర్కొంది.",
        "batch_credit_partial": "మీ క్రెడిట్‌లు ({credits}) ఎంచుకున్న ఫైళ్ల ({total}) కంటే తక్కువ...",
        "batch_process_ongoing": "పురోగతిలో ఉంది (ప్రతి 15s కి, మిగిలిన పనులు: {count})...",
        "batch_no_credit_log": "ప్రారంభించడానికి తగినంత బ్యాలెన్స్ లేదు.",
        "batch_starting": "బ్యాచ్ అనువాదం ప్రారంభమవుతోంది...",
        "batch_file_rate_limit": "{filename} పరిమితిని చేరుకుంది.",
        "batch_file_success": "{filename} విజయవంతంగా అనువదించబడింది.",
        "insufficient_credit_batch_stop": "తగినంత క్రెడిట్ లేదు. బ్యాచ్ అనువాదం ఆగిపోయింది."
    },
    "th": {
        "batch_translation_beta": "แปลเป็นชุด (เบต้า)",
        "batch_api_triggered": "เรียกใช้ Batch API สำหรับ {count} ไฟล์",
        "batch_all_completed": "แปลไฟล์ทั้งหมดเรียบร้อยแล้ว",
        "batch_process_prefix": "กระบวนการเป็นชุด",
        "batch_process_canceled": "ยกเลิกกระบวนการ",
        "batch_file_sent": "ส่ง {filename} ไปยังเซิร์ฟเวอร์แล้ว งาน: {job}",
        "batch_error_prefix": "ข้อผิดพลาดการแปลเป็นชุด",
        "batch_file_error": "{filename} พบข้อผิดพลาดบนเซิร์ฟเวอร์",
        "batch_credit_partial": "เครดิตของคุณ ({credits}) น้อยกว่าไฟล์ที่เลือก ({total})...",
        "batch_process_ongoing": "กำลังดำเนินการ (ตรวจสอบทุก 15 วินาที, งานที่เหลือ: {count})...",
        "batch_no_credit_log": "เครดิตไม่เพียงพอที่จะเริ่มต้น",
        "batch_starting": "กำลังเริ่มแปลเป็นชุด...",
        "batch_file_rate_limit": "กระบวนการถึงขีดจำกัดสำหรับ {filename}",
        "batch_file_success": "แปล {filename} สำเร็จแล้ว",
        "insufficient_credit_batch_stop": "เครดิตไม่พอ การแปลแบบกลุ่มถูกหยุด"
    },
    "uk": {
        "batch_translation_beta": "Пакетний переклад (бета)",
        "batch_api_triggered": "Пакетне API запущено для {count} файлів.",
        "batch_all_completed": "Усі файли успішно перекладено.",
        "batch_process_prefix": "Пакетний процес",
        "batch_process_canceled": "Процес скасовано.",
        "batch_file_sent": "{filename} надіслано на сервер. Завдання: {job}",
        "batch_error_prefix": "Помилка пакетного перекладу",
        "batch_file_error": "{filename} зіткнувся з помилкою на сервері.",
        "batch_credit_partial": "Ваших кредитів ({credits}) менше, ніж вибраних файлів ({total})...",
        "batch_process_ongoing": "В процесі (перевірка кожні 15 с, залишилось завдань: {count})...",
        "batch_no_credit_log": "Недостатньо кредитів. Немає балансу для початку.",
        "batch_starting": "Запуск пакетного перекладу...",
        "batch_file_rate_limit": "Процес досягнув обмежень для {filename}.",
        "batch_file_success": "{filename} успішно перекладено.",
        "insufficient_credit_batch_stop": "Недостатньо кредитів. Пакетний переклад зупинено."
    },
    "vi": {
        "batch_translation_beta": "Dịch hàng loạt (Beta)",
        "batch_api_triggered": "Đã kích hoạt API hàng loạt cho {count} tệp.",
        "batch_all_completed": "Tất cả các tệp đã được dịch thành công.",
        "batch_process_prefix": "Quy trình hàng loạt",
        "batch_process_canceled": "Đã hủy quy trình.",
        "batch_file_sent": "{filename} đã được gửi đến máy chủ. Công việc: {job}",
        "batch_error_prefix": "Lỗi dịch hàng loạt",
        "batch_file_error": "Tệp {filename} đã gặp lỗi trên máy chủ.",
        "batch_credit_partial": "Tín dụng của bạn ({credits}) ít hơn số tệp đã chọn ({total})...",
        "batch_process_ongoing": "Đang thực hiện (kiểm tra mỗi 15s, công việc còn lại: {count})...",
        "batch_no_credit_log": "Không đủ tín dụng. Bạn không có số dư để bắt đầu.",
        "batch_starting": "Đang bắt đầu dịch hàng loạt...",
        "batch_file_rate_limit": "Gặp giới hạn đối với tệp {filename}.",
        "batch_file_success": "Đã dịch {filename} thành công.",
        "insufficient_credit_batch_stop": "Thiếu tín dụng. Quá trình dịch hàng loạt đã dừng."
    }
}

target_keys = [
    "batch_translation_beta", "batch_api_triggered", "batch_all_completed", 
    "batch_process_prefix", "batch_process_canceled", "batch_file_sent",
    "batch_error_prefix", "batch_file_error", "batch_credit_partial", 
    "batch_process_ongoing", "batch_no_credit_log", "batch_starting", 
    "batch_file_rate_limit", "batch_file_success", "insufficient_credit_batch_stop"
]

trans_dir = r"lib\translations"
files = glob.glob(os.path.join(trans_dir, "translations_*.dart"))

for file_path in files:
    filename = os.path.basename(file_path)
    lang_code = filename.replace("translations_", "").replace(".dart", "")
    
    if lang_code in translations:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        updated_content = content
        
        # We will iterate through keys, find the lines mapping to them, and replace the values
        for k, v in translations[lang_code].items():
            val_esc = v.replace("'", "\\'")
            # Regex to find something like: 'batch_translation_beta': 'Some English String',
            # We want to replace just the string part.
            pattern = re.compile(rf"('{k}'\s*:\s*)'[^']*'(,?)")
            
            # Check if it was replaced. If not, maybe there were empty spaces or something
            if pattern.search(updated_content):
                updated_content = pattern.sub(rf"\1'{val_esc}'\2", updated_content)
                
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
        print(f"Updated {lang_code} with native translations.")
