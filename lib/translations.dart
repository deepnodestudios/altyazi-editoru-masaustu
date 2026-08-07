import 'translations/translations_en.dart';
import 'translations/translations_fr.dart';
import 'translations/translations_de.dart';
import 'translations/translations_it.dart';
import 'translations/translations_es.dart';
import 'translations/translations_pt.dart';
import 'translations/translations_ru.dart';
import 'translations/translations_el.dart';
import 'translations/translations_ar.dart';
import 'translations/translations_in.dart';
import 'translations/translations_id.dart';
import 'translations/translations_cn.dart';
import 'translations/translations_ja.dart';
import 'translations/translations_ko.dart';
import 'translations/translations_tr.dart';
import 'translations/translations_nl.dart';
import 'translations/translations_sv.dart';
import 'translations/translations_pl.dart';
import 'translations/translations_he.dart';
import 'translations/translations_fa.dart';
import 'translations/translations_th.dart';
import 'translations/translations_vi.dart';
import 'translations/translations_ta.dart';
import 'translations/translations_te.dart';
import 'translations/translations_ml.dart';
import 'translations/translations_kn.dart';
import 'translations/translations_pa.dart';
import 'translations/translations_gu.dart';
import 'translations/translations_mr.dart';
import 'translations/translations_uk.dart';
import 'translations/translations_ro.dart';
import 'translations/translations_cs.dart';
import 'translations/translations_hu.dart';
import 'translations/translations_da.dart';
import 'translations/translations_extras.dart';
import 'translations/translations_v160.dart';
import 'translations/translations_restricted_regions.dart';
import 'translations/translations_purchase_bonus_tutorial.dart';
import 'translations/translations_bonus_policy.dart';
import 'translations/translations_desktop_tour.dart';
import 'translations/translations_maintenance.dart';

class Translations {
  /// All supported UI language codes.
  static const Set<String> supportedLanguageCodes = {
    'EN',
    'FR',
    'DE',
    'IT',
    'ES',
    'PT',
    'RU',
    'EL',
    'AR',
    'IN',
    'ID',
    'CN',
    'JA',
    'KO',
    'TR',
    'NL',
    'SV',
    'PL',
    'HE',
    'FA',
    'TH',
    'VI',
    'TA',
    'TE',
    'ML',
    'KN',
    'PA',
    'GU',
    'MR',
    'UK',
    'RO',
    'CS',
    'HU',
    'DA',
  };

  /// Native name for each language code (e.g. 'TR' → 'Türkçe').
  static const Map<String, String> autonymByCode = {
    'TR': 'TR - Türkçe',
    'EN': 'EN - English',
    'FR': 'FR - Français',
    'DE': 'DE - Deutsch',
    'IT': 'IT - Italiano',
    'ES': 'ES - Español',
    'PT': 'PT - Português',
    'RU': 'RU - Русский',
    'EL': 'EL - Ελληνικά',
    'NL': 'NL - Nederlands',
    'SV': 'SV - Svenska',
    'PL': 'PL - Polski',
    'AR': 'AR - العربية',
    'HE': 'HE - עברית',
    'FA': 'FA - فارسی',
    'IN': 'IN - हिन्दी',
    'ID': 'ID - Bahasa Indonesia',
    'CN': 'CN - 中文',
    'JA': 'JA - 日本語',
    'KO': 'KO - 한국어',
    'TH': 'TH - ไทย',
    'VI': 'VI - Tiếng Việt',
    'TA': 'TA - தமிழ்',
    'TE': 'TE - తెలుగు',
    'ML': 'ML - Malayalam',
    'KN': 'KN - Kannada',
    'PA': 'PA - Punjabi',
    'GU': 'GU - Gujarati',
    'MR': 'MR - Marathi',
    'UK': 'UK - Українська',
    'RO': 'RO - Română',
    'CS': 'CS - Čeština',
    'HU': 'HU - Magyar',
    'DA': 'DA - Dansk',
  };

  static const Map<String, Map<String, String>> _langMap = {
    'EN': translationsEn,
    'FR': translationsFr,
    'DE': translationsDe,
    'IT': translationsIt,
    'ES': translationsEs,
    'PT': translationsPt,
    'RU': translationsRu,
    'EL': translationsEl,
    'AR': translationsAr,
    'IN': translationsIn,
    'ID': translationsId,
    'CN': translationsCn,
    'JA': translationsJa,
    'KO': translationsKo,
    'TR': translationsTr,
    'NL': translationsNl,
    'SV': translationsSv,
    'PL': translationsPl,
    'HE': translationsHe,
    'FA': translationsFa,
    'TH': translationsTh,
    'VI': translationsVi,
    'TA': translationsTa,
    'TE': translationsTe,
    'ML': translationsMl,
    'KN': translationsKn,
    'PA': translationsPa,
    'GU': translationsGu,
    'MR': translationsMr,
    'UK': translationsUk,
    'RO': translationsRo,
    'CS': translationsCs,
    'HU': translationsHu,
    'DA': translationsDa,
  };

  static const Map<String, String> _batchSaveAllByCode = {
    'EN': 'Bulk Save',
    'FR': 'Enregistrer en lot',
    'DE': 'Stapel speichern',
    'IT': 'Salva in blocco',
    'ES': 'Guardar en lote',
    'PT': 'Salvar em lote',
    'RU': 'Пакетное сохранение',
    'EL': 'Μαζική αποθήκευση',
    'AR': 'حفظ جماعي',
    'IN': 'सामूहिक सहेजें',
    'ID': 'Simpan massal',
    'CN': '批量保存',
    'JA': '一括保存',
    'KO': '일괄 저장',
    'TR': 'Toplu Kaydet',
    'NL': 'Bulk opslaan',
    'SV': 'Spara i grupp',
    'PL': 'Zapisz zbiorczo',
    'HE': 'שמירה מרוכזת',
    'FA': 'ذخیره گروهی',
    'TH': 'บันทึกแบบกลุ่ม',
    'VI': 'Lưu hàng loạt',
    'TA': 'தொகுப்பாக சேமி',
    'TE': 'సమూహంగా సేవ్ చేయండి',
    'ML': 'കൂട്ടമായി സേവ് ചെയ്യുക',
    'KN': 'ಗುಂಪಾಗಿ ಉಳಿಸಿ',
    'PA': 'ਇਕੱਠੇ ਸੇਵ ਕਰੋ',
    'GU': 'એકસાથે સેવ કરો',
    'MR': 'एकत्र सेव्ह करा',
    'UK': 'Масове збереження',
    'RO': 'Salvează în lot',
    'CS': 'Hromadně uložit',
    'HU': 'Tömeges mentés',
    'DA': 'Gem samlet',
  };

    static const Map<String, String> _creditSourceSubscriptionByCode = {
        'EN': 'Subscription',
        'FR': 'Abonnement',
        'DE': 'Abonnement',
        'IT': 'Abbonamento',
        'ES': 'Suscripción',
        'PT': 'Assinatura',
        'RU': 'Подписка',
        'EL': 'Συνδρομή',
        'AR': 'اشتراك',
        'IN': 'सदस्यता',
        'ID': 'Langganan',
        'CN': '订阅',
        'JA': 'サブスクリプション',
        'KO': '구독',
        'TR': 'Abonelik',
        'NL': 'Abonnement',
        'SV': 'Prenumeration',
        'PL': 'Subskrypcja',
        'HE': 'מנוי',
        'FA': 'اشتراک',
        'TH': 'การสมัครสมาชิก',
        'VI': 'Gói đăng ký',
        'TA': 'சந்தா',
        'TE': 'సభ్యత్వం',
        'ML': 'സബ്സ്ക്രിപ്ഷൻ',
        'KN': 'ಚಂದಾದಾರಿಕೆ',
        'PA': 'ਸਬਸਕ੍ਰਿਪਸ਼ਨ',
        'GU': 'સબ્સ્ક્રિપ્શન',
        'MR': 'सदस्यता',
        'UK': 'Підписка',
        'RO': 'Abonament',
        'CS': 'Předplatné',
        'HU': 'Előfizetés',
        'DA': 'Abonnement',
    };

  static const Map<String, String> _tourCreditHistoryTitleByCode = {
    'EN': 'Translation/Credit History',
    'FR': 'Historique traductions/crédits',
    'DE': 'Übersetzungs-/Guthabenverlauf',
    'IT': 'Cronologia traduzioni/crediti',
    'ES': 'Historial traducciones/créditos',
    'PT': 'Histórico traduções/créditos',
    'RU': 'История переводов/кредитов',
    'EL': 'Ιστορικό μεταφράσεων/πιστώσεων',
    'AR': 'سجل الترجمة/الرصيد',
    'IN': 'अनुवाद/क्रेडिट इतिहास',
    'ID': 'Riwayat Terjemahan/Kredit',
    'CN': '翻译/积分历史',
    'JA': '翻訳/クレジット履歴',
    'KO': '번역/크레딧 기록',
    'TR': 'Çeviri/Kredi Geçmişi',
    'NL': 'Vertaal-/creditgeschiedenis',
    'SV': 'Översättnings-/kredithistorik',
    'PL': 'Historia tłumaczeń/kredytów',
    'HE': 'היסטוריית תרגומים/קרדיטים',
    'FA': 'تاریخچه ترجمه/اعتبار',
    'TH': 'ประวัติการแปล/เครดิต',
    'VI': 'Lịch sử dịch/credit',
    'TA': 'மொழிபெயர்ப்பு/கிரெடிட் வரலாறு',
    'TE': 'అనువాదం/క్రెడిట్ చరిత్ర',
    'ML': 'വിവർത്തന/ക്രെഡിറ്റ് ചരിത്രം',
    'KN': 'ಅನುವಾದ/ಕ್ರೆಡಿಟ್ ಇತಿಹಾಸ',
    'PA': 'ਅਨੁਵਾਦ/ਕਰੈਡਿਟ ਇਤਿਹਾਸ',
    'GU': 'અનુવાદ/ક્રેડિટ ઇતિહાસ',
    'MR': 'भाषांतर/क्रेडिट इतिहास',
    'UK': 'Історія перекладів/кредитів',
    'RO': 'Istoricul traducerilor/creditelor',
    'CS': 'Historie překladů/kreditů',
    'HU': 'Fordítási/kreditelőzmények',
    'DA': 'Oversættelses-/kredithistorik',
  };

  static const Map<String, String> _tourCreditHistoryDescByCode = {
    'EN':
        'Open History to access both tabs. In Translation History, you can review completed and unfinished subtitle projects, reopen them, and continue where you left off. In Credit History, you can see every credit added or spent with its source, time, and details.',
    'FR':
        'Ouvrez Historique pour accéder aux deux onglets. Dans Historique des traductions, vous pouvez revoir les projets de sous-titres terminés ou inachevés, les rouvrir et reprendre là où vous vous êtes arrêté. Dans Historique des crédits, vous voyez chaque crédit ajouté ou utilisé, avec sa source, l\'heure et les détails.',
    'DE':
        'Öffne Verlauf, um beide Tabs zu sehen. Im Übersetzungsverlauf kannst du abgeschlossene und unvollständige Untertitelprojekte prüfen, erneut öffnen und dort weitermachen, wo du aufgehört hast. Im Guthabenverlauf siehst du jede Guthabenbewegung mit Quelle, Zeit und Details.',
    'IT':
        'Apri Cronologia per accedere a entrambe le schede. In Cronologia traduzioni puoi rivedere i progetti di sottotitoli completati o incompleti, riaprirli e riprendere da dove avevi lasciato. In Cronologia crediti puoi vedere ogni credito aggiunto o speso con origine, ora e dettagli.',
    'ES':
        'Abre Historial para acceder a ambas pestañas. En Historial de traducciones puedes revisar proyectos de subtítulos terminados o sin terminar, reabrirlos y continuar donde lo dejaste. En Historial de créditos puedes ver cada crédito añadido o gastado con su origen, hora y detalles.',
    'PT':
        'Abra Histórico para acessar as duas abas. Em Histórico de Traduções, você pode revisar projetos de legendas concluídos ou inacabados, reabri-los e continuar de onde parou. Em Histórico de Créditos, você pode ver cada crédito adicionado ou gasto com origem, horário e detalhes.',
    'RU':
        'Откройте Историю, чтобы перейти к обеим вкладкам. В Истории переводов можно просматривать завершенные и незавершенные проекты субтитров, открывать их снова и продолжать с того места, где вы остановились. В Истории кредитов виден каждый добавленный или потраченный кредит с источником, временем и подробностями.',
    'EL':
        'Ανοίξτε το Ιστορικό για να δείτε και τις δύο καρτέλες. Στο Ιστορικό Μεταφράσεων μπορείτε να ελέγχετε ολοκληρωμένα και ημιτελή έργα υποτίτλων, να τα ανοίγετε ξανά και να συνεχίζετε από εκεί που σταματήσατε. Στο Ιστορικό Πιστώσεων βλέπετε κάθε πίστωση που προστέθηκε ή ξοδεύτηκε, με πηγή, ώρα και λεπτομέρειες.',
    'AR':
        'افتح السجل للوصول إلى علامتَي التبويب. في سجل الترجمة يمكنك مراجعة مشاريع الترجمة الفرعية المكتملة وغير المكتملة، وإعادة فتحها، والمتابعة من حيث توقفت. وفي سجل الرصيد يمكنك رؤية كل رصيد تمت إضافته أو إنفاقه مع المصدر والوقت والتفاصيل.',
    'IN':
        'इतिहास खोलें और दोनों टैब देखें। अनुवाद इतिहास में आप पूरे और अधूरे सबटाइटल प्रोजेक्ट देख सकते हैं, उन्हें फिर से खोल सकते हैं और जहां छोड़ा था वहीं से जारी रख सकते हैं। क्रेडिट इतिहास में आप जोड़े गए या खर्च किए गए हर क्रेडिट को उसके स्रोत, समय और विवरण के साथ देख सकते हैं।',
    'ID':
        'Buka Riwayat untuk membuka kedua tab. Di Riwayat Terjemahan, Anda bisa meninjau proyek subtitle yang selesai maupun belum selesai, membukanya lagi, dan melanjutkan dari titik terakhir. Di Riwayat Kredit, Anda bisa melihat setiap kredit yang ditambahkan atau dipakai beserta sumber, waktu, dan detailnya.',
    'CN':
        '打开历史即可查看这两个标签。在翻译历史中，你可以查看已完成和未完成的字幕项目，重新打开并从上次停下的地方继续。在积分历史中，你可以看到每一笔新增或消费的积分，以及它的来源、时间和详情。',
    'JA':
        '履歴を開くと、2つのタブにアクセスできます。翻訳履歴では、完了済みと未完了の字幕プロジェクトを確認し、再度開いて中断したところから続けられます。クレジット履歴では、追加または使用した各クレジットを、発生元、時間、詳細付きで確認できます。',
    'KO':
        '기록을 열면 두 탭을 모두 볼 수 있습니다. 번역 기록에서는 완료되었거나 진행 중인 자막 프로젝트를 확인하고 다시 열어 중단한 곳부터 이어할 수 있습니다. 크레딧 기록에서는 추가되거나 사용된 모든 크레딧을 출처, 시간, 상세 정보와 함께 확인할 수 있습니다.',
    'TR':
        'Her iki sekmeye erişmek için Geçmiş\'i açın. Çeviri Geçmişi\'nde tamamlanan ve yarım kalan altyazı projelerini inceleyebilir, yeniden açabilir ve kaldığınız yerden devam edebilirsiniz. Kredi Geçmişi\'nde ise eklenen veya harcanan her krediyi kaynağı, zamanı ve ayrıntılarıyla görebilirsiniz.',
    'NL':
        'Open Geschiedenis om beide tabbladen te openen. In Vertaalgeschiedenis kun je voltooide en onvoltooide ondertitelprojecten bekijken, opnieuw openen en verdergaan waar je was gebleven. In Creditgeschiedenis zie je elke toegevoegde of gebruikte credit met bron, tijd en details.',
    'SV':
        'Öppna Historik för att komma åt båda flikarna. I Översättningshistorik kan du granska avslutade och ofullständiga undertextprojekt, öppna dem igen och fortsätta där du slutade. I Kredithistorik kan du se varje kredit som lagts till eller använts, med källa, tid och detaljer.',
    'PL':
        'Otwórz Historię, aby przejść do obu kart. W Historii tłumaczeń możesz przeglądać ukończone i nieukończone projekty napisów, otwierać je ponownie i kontynuować od miejsca, w którym przerwałeś. W Historii kredytów zobaczysz każdy dodany lub wydany kredyt wraz ze źródłem, czasem i szczegółami.',
    'HE':
        'פתח את ההיסטוריה כדי לגשת לשתי הלשוניות. בהיסטוריית התרגומים אפשר לעיין בפרויקטי כתוביות שהושלמו ושעדיין לא הושלמו, לפתוח אותם מחדש ולהמשיך מהמקום שבו עצרת. בהיסטוריית הקרדיטים אפשר לראות כל קרדיט שנוסף או נוצל, עם המקור, השעה והפרטים.',
    'FA':
        'تاریخچه را باز کنید تا به هر دو زبانه دسترسی داشته باشید. در تاریخچه ترجمه می‌توانید پروژه‌های زیرنویس کامل‌شده و ناتمام را بررسی کنید، دوباره بازشان کنید و از همان جایی که مانده بودید ادامه دهید. در تاریخچه اعتبار می‌توانید هر اعتبار اضافه‌شده یا خرج‌شده را همراه با منبع، زمان و جزئیات ببینید.',
    'TH':
        'เปิดประวัติเพื่อดูทั้งสองแท็บ ในประวัติการแปล คุณสามารถดูโปรเจกต์คำบรรยายที่เสร็จแล้วและยังไม่เสร็จ เปิดกลับมาอีกครั้ง และทำต่อจากจุดที่ค้างไว้ได้ ในประวัติเครดิต คุณจะเห็นทุกเครดิตที่เพิ่มหรือใช้ไป พร้อมที่มา เวลา และรายละเอียด',
    'VI':
        'Mở Lịch sử để xem cả hai tab. Trong Lịch sử dịch, bạn có thể xem lại các dự án phụ đề đã hoàn thành hoặc còn dang dở, mở lại và tiếp tục từ chỗ đã dừng. Trong Lịch sử credit, bạn có thể xem từng credit đã được thêm hoặc đã dùng, kèm nguồn, thời gian và chi tiết.',
    'TA':
        'இரு தாவல்களையும் பார்க்க வரலாற்றைத் திறக்கவும். மொழிபெயர்ப்பு வரலாற்றில் முடிந்ததும் முடியாததுமான வசனவரி திட்டங்களைப் பார்த்து, மீண்டும் திறந்து, நிறுத்திய இடத்திலிருந்து தொடரலாம். கிரெடிட் வரலாற்றில் சேர்க்கப்பட்ட அல்லது செலவழிக்கப்பட்ட ஒவ்வொரு கிரெடிட்டையும் அதன் மூலம், நேரம், விவரங்களுடன் பார்க்கலாம்.',
    'TE':
        'రెండు ట్యాబ్‌లను చూడటానికి చరిత్రను తెరవండి. అనువాద చరిత్రలో పూర్తయిన మరియు పూర్తికాని సబ్‌టైటిల్ ప్రాజెక్ట్‌లను చూడవచ్చు, మళ్లీ తెరవవచ్చు, ఆపిన చోటు నుంచే కొనసాగించవచ్చు. క్రెడిట్ చరిత్రలో జోడించిన లేదా ఖర్చు చేసిన ప్రతి క్రెడిట్‌ను దాని మూలం, సమయం, వివరాలతో చూడవచ్చు.',
    'ML':
        'രണ്ട് ടാബുകളും കാണാൻ ചരിത്രം തുറക്കുക. വിവർത്തന ചരിത്രത്തിൽ പൂർത്തിയായതും പൂർത്തിയാകാത്തതുമായ സബ്ടൈറ്റിൽ പ്രോജക്റ്റുകൾ പരിശോധിക്കാം, വീണ്ടും തുറക്കാം, നിർത്തിയിടത്ത് നിന്ന് തുടരാം. ക്രെഡിറ്റ് ചരിത്രത്തിൽ ചേർത്തതോ ചെലവഴിച്ചതോ ആയ ഓരോ ക്രെഡിറ്റും അതിന്റെ ഉറവിടം, സമയം, വിശദാംശങ്ങൾ സഹിതം കാണാം.',
    'KN':
        'ಎರಡೂ ಟ್ಯಾಬ್‌ಗಳನ್ನು ನೋಡಲು ಇತಿಹಾಸವನ್ನು ತೆರೆಯಿರಿ. ಅನುವಾದ ಇತಿಹಾಸದಲ್ಲಿ ಪೂರ್ಣಗೊಂಡ ಹಾಗೂ ಅಪೂರ್ಣ ಸಬ್‌ಟೈಟಲ್ ಯೋಜನೆಗಳನ್ನು ಪರಿಶೀಲಿಸಿ, ಮತ್ತೆ ತೆರೆಯಬಹುದು, ನಿಲ್ಲಿಸಿದ ಜಾಗದಿಂದ ಮುಂದುವರಿಸಬಹುದು. ಕ್ರೆಡಿಟ್ ಇತಿಹಾಸದಲ್ಲಿ ಸೇರಿಸಿದ ಅಥವಾ ಖರ್ಚಾದ ಪ್ರತಿಯೊಂದು ಕ್ರೆಡಿಟ್‌ನ್ನು ಅದರ ಮೂಲ, ಸಮಯ ಮತ್ತು ವಿವರಗಳೊಂದಿಗೆ ನೋಡಬಹುದು.',
    'PA':
        'ਦੋਵੇਂ ਟੈਬਾਂ ਵੇਖਣ ਲਈ ਇਤਿਹਾਸ ਖੋਲ੍ਹੋ। ਅਨੁਵਾਦ ਇਤਿਹਾਸ ਵਿੱਚ ਤੁਸੀਂ ਪੂਰੇ ਹੋਏ ਅਤੇ ਅਧੂਰੇ ਸਬਟਾਈਟਲ ਪ੍ਰੋਜੈਕਟ ਵੇਖ ਸਕਦੇ ਹੋ, ਉਹਨਾਂ ਨੂੰ ਮੁੜ ਖੋਲ੍ਹ ਸਕਦੇ ਹੋ ਅਤੇ ਜਿੱਥੇ ਛੱਡਿਆ ਸੀ ਉੱਥੋਂ ਜਾਰੀ ਰੱਖ ਸਕਦੇ ਹੋ। ਕਰੈਡਿਟ ਇਤਿਹਾਸ ਵਿੱਚ ਤੁਸੀਂ ਜੋੜੇ ਜਾਂ ਖਰਚੇ ਹਰ ਕਰੈਡਿਟ ਨੂੰ ਉਸਦੇ ਸਰੋਤ, ਸਮੇਂ ਅਤੇ ਵੇਰਵਿਆਂ ਨਾਲ ਵੇਖ ਸਕਦੇ ਹੋ।',
    'GU':
        'બંને ટૅબ જોવા માટે ઇતિહાસ ખોલો. અનુવાદ ઇતિહાસમાં તમે પૂર્ણ અને અધૂરા સબટાઇટલ પ્રોજેક્ટ્સ જોઈ શકો છો, ફરી ખોલી શકો છો અને જ્યાં અટક્યા હતા ત્યાંથી આગળ વધી શકો છો. ક્રેડિટ ઇતિહાસમાં ઉમેરાયેલા અથવા ખર્ચાયેલા દરેક ક્રેડિટને તેના સ્ત્રોત, સમય અને વિગતો સાથે જોઈ શકો છો.',
    'MR':
        'दोन्ही टॅब पाहण्यासाठी इतिहास उघडा. भाषांतर इतिहासात तुम्ही पूर्ण झालेले आणि अपूर्ण सबटायटल प्रकल्प पाहू शकता, ते पुन्हा उघडू शकता आणि जिथे थांबलात तिथून पुढे सुरू ठेवू शकता. क्रेडिट इतिहासात जोडलेले किंवा खर्च झालेले प्रत्येक क्रेडिट त्याचा स्रोत, वेळ आणि तपशीलांसह पाहू शकता.',
    'UK':
        'Відкрийте Історію, щоб перейти до обох вкладок. В Історії перекладів можна переглядати завершені й незавершені проєкти субтитрів, знову відкривати їх і продовжувати з того місця, де ви зупинилися. В Історії кредитів видно кожен доданий або витрачений кредит із джерелом, часом і подробицями.',
    'RO':
        'Deschide Istoric pentru a accesa ambele file. În Istoricul traducerilor poți revizui proiectele de subtitrări finalizate sau neterminate, le poți redeschide și continua de unde ai rămas. În Istoricul creditelor vezi fiecare credit adăugat sau consumat, împreună cu sursa, ora și detaliile.',
    'CS':
        'Otevřete Historii a přejděte na obě karty. V Historii překladů můžete procházet dokončené i nedokončené projekty titulků, znovu je otevřít a pokračovat tam, kde jste skončili. V Historii kreditů uvidíte každý přidaný nebo utracený kredit se zdrojem, časem a podrobnostmi.',
    'HU':
        'Az Előzmények megnyitásával mindkét fület eléred. A Fordítási előzményekben átnézheted a befejezett és befejezetlen feliratprojekteket, újra megnyithatod őket, és onnan folytathatod, ahol abbahagytad. A Kreditelőzményekben minden hozzáadott vagy elköltött kreditet látsz a forrással, időponttal és részletekkel együtt.',
    'DA':
        'Åbn Historik for at få adgang til begge faner. I Oversættelseshistorik kan du gennemgå afsluttede og ufærdige undertekstprojekter, åbne dem igen og fortsætte, hvor du slap. I Kredithistorik kan du se hver kredit, der er tilføjet eller brugt, med kilde, tidspunkt og detaljer.',
  };

    static const Map<String, String> _historySignInPromptByCode = {
        'EN': 'Sign in to keep your translation history.',
        'FR': 'Connectez-vous pour conserver votre historique de traduction.',
        'DE': 'Melden Sie sich an, um Ihren Übersetzungsverlauf zu speichern.',
        'IT': 'Accedi per conservare la cronologia delle traduzioni.',
        'ES': 'Inicia sesión para conservar tu historial de traducciones.',
        'PT': 'Inicie sessão para manter o seu histórico de traduções.',
        'RU': 'Войдите, чтобы сохранять историю переводов.',
        'EL': 'Συνδεθείτε για να διατηρείτε το ιστορικό μεταφράσεών σας.',
        'AR': 'سجل الدخول للاحتفاظ بسجل الترجمات الخاص بك.',
        'IN': 'अपने अनुवाद इतिहास को सहेजने के लिए साइन इन करें।',
        'ID': 'Masuk untuk menyimpan riwayat terjemahan Anda.',
        'CN': '登录以保留你的翻译历史记录。',
        'JA': '翻訳履歴を保存するにはログインしてください。',
        'KO': '번역 기록을 저장하려면 로그인하세요.',
        'TR': 'Çeviri geçmişi kaydı tutmak için oturum açın.',
        'NL': 'Log in om uw vertaalgeschiedenis te bewaren.',
        'SV': 'Logga in för att spara din översättningshistorik.',
        'PL': 'Zaloguj się, aby zachować historię tłumaczeń.',
        'HE': 'התחבר כדי לשמור את היסטוריית התרגומים שלך.',
        'FA': 'برای نگه داشتن تاریخچه ترجمه‌های خود وارد شوید.',
        'TH': 'ลงชื่อเข้าใช้เพื่อบันทึกประวัติการแปลของคุณ',
        'VI': 'Đăng nhập để lưu lịch sử bản dịch của bạn.',
        'TA': 'உங்கள் மொழிபெயர்ப்பு வரலாற்றை சேமிக்க உள்நுழைக.',
        'TE': 'మీ అనువాద చరిత్రను నిల్వ ఉంచడానికి సైన్ ఇన్ చేయండి.',
        'ML': 'നിങ്ങളുടെ വിവർത്തന ചരിത്രം സൂക്ഷിക്കാൻ സൈൻ ഇൻ ചെയ്യുക.',
        'KN': 'ನಿಮ್ಮ ಅನುವಾದ ಇತಿಹಾಸವನ್ನು ಉಳಿಸಿಕೊಳ್ಳಲು ಸೈನ್ ಇನ್ ಮಾಡಿ.',
        'PA': 'ਆਪਣਾ ਅਨੁਵਾਦ ਇਤਿਹਾਸ ਸੰਭਾਲਣ ਲਈ ਸਾਈਨ ਇਨ ਕਰੋ।',
        'GU': 'તમારો અનુવાદ ઇતિહાસ સાચવવા માટે સાઇન ઇન કરો.',
        'MR': 'तुमचा भाषांतर इतिहास जतन करण्यासाठी साइन इन करा.',
        'UK': 'Увійдіть, щоб зберігати історію перекладів.',
        'RO': 'Conectează-te pentru a păstra istoricul traducerilor.',
        'CS': 'Přihlaste se, chcete-li uchovat historii překladů.',
        'HU': 'Jelentkezz be a fordítási előzményeid megőrzéséhez.',
        'DA': 'Log ind for at gemme din oversættelseshistorik.',
    };

  static String _normalizeTourWelcomeDesc(String value) {
    if (value.isEmpty) return value;
    return value.replaceAll(RegExp(r'(?<!\d)5(?!\d)'), '2');
  }

  /// Returns the fully-merged translation map for the given language code.
  ///
  /// Falls back to English ('EN') for unknown language codes.
  static Map<String, String> get(String lang) {
    final code = lang.trim().toUpperCase();
    final resolvedCode = _langMap.containsKey(code) ? code : 'EN';
    final base = _langMap[resolvedCode] ?? translationsEn;
    final baseEn = _langMap['EN'] ?? translationsEn;
    final extrasEn = translationsExtras['EN'] ?? const {};
    final extras = translationsExtras[resolvedCode] ??
        translationsExtras['EN'] ??
        const {};
    final v160En = translationsV160['EN'] ?? const {};
    final v160 =
        translationsV160[resolvedCode] ?? translationsV160['EN'] ?? const {};
    final merged = {
      ...baseEn,
      ...base,
      ...extrasEn,
      ...extras,
      ...v160En,
      ...v160,
    };
    final batchSaveAll =
        _batchSaveAllByCode[resolvedCode] ?? _batchSaveAllByCode['EN']!;
    merged['batch_save_all'] = batchSaveAll;
    merged['credit_source_subscription'] =
        _creditSourceSubscriptionByCode[resolvedCode] ??
            _creditSourceSubscriptionByCode['EN']!;
    merged['tour_credit_history_title'] =
        _tourCreditHistoryTitleByCode[resolvedCode] ??
            _tourCreditHistoryTitleByCode['EN']!;
    merged['tour_credit_history_desc'] =
        _tourCreditHistoryDescByCode[resolvedCode] ??
            _tourCreditHistoryDescByCode['EN']!;
    merged['history_sign_in_prompt'] =
        _historySignInPromptByCode[resolvedCode] ??
            _historySignInPromptByCode['EN']!;
    merged['tour_previous'] = resolvedCode == 'TR'
        ? 'Önceki'
        : resolvedCode == 'EN'
            ? 'Previous'
            : (merged['back'] ?? 'Back');
    merged['tour_next'] = resolvedCode == 'TR'
        ? 'Sonraki'
        : (merged['onboarding_next'] ?? merged['forward'] ?? 'Next');
    merged['batch_save_all_zip'] = batchSaveAll;
    final welcomeDesc = merged['tour_welcome_desc'];
    if (welcomeDesc != null) {
      merged['tour_welcome_desc'] = _normalizeTourWelcomeDesc(welcomeDesc);
    }
    final restricted =
        translationsRestrictedRegions[resolvedCode] ??
            translationsRestrictedRegions['EN'] ??
            const {};
    merged.addAll(restricted);
    final purchaseBonusTutorial =
        translationsPurchaseBonusTutorial[resolvedCode] ??
            translationsPurchaseBonusTutorial['EN'] ??
            const {};
    merged.addAll(purchaseBonusTutorial);
    final bonusPolicy =
        translationsBonusPolicy[resolvedCode] ??
            translationsBonusPolicy['EN'] ??
            const {};
    merged.addAll(bonusPolicy);
    final desktopTour =
        translationsDesktopTour[resolvedCode] ??
            translationsDesktopTour['EN'] ??
            const {};
    merged.addAll(desktopTour);
    final maintenance =
        translationsMaintenance[resolvedCode] ??
            translationsMaintenance['EN'] ??
            const {};
    merged.addAll(maintenance);
    return merged;
  }
}
