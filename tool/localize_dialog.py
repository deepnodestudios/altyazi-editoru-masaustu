import os
import re
import glob

# Provide translations covering all required keys for major languages
translations = {
    "tr": {
        "batch_info_dialog_title": "Bilgilendirme",
        "batch_info_dialog_message": "Çeviriniz sunucuda arka planda gerçekleştirilmektedir. Tamamlandığında bildirim ile haber verilecektir.\n\nDilerseniz diğer işlerinize devam edebilirsiniz.",
        "dont_show_again": "Bir daha gösterme"
    },
    "en": {
        "batch_info_dialog_title": "Information",
        "batch_info_dialog_message": "Your translation is being processed in the background on our servers. You will be notified when it is complete.\n\nYou can continue with your other tasks in the meantime.",
        "dont_show_again": "Don't show again"
    },
    "es": {
        "batch_info_dialog_title": "Información",
        "batch_info_dialog_message": "Su traducción se está procesando en segundo plano en nuestros servidores. Se le notificará cuando se complete.\n\nMientras tanto, puede continuar con sus otras tareas.",
        "dont_show_again": "No volver a mostrar"
    },
    "de": {
        "batch_info_dialog_title": "Information",
        "batch_info_dialog_message": "Ihre Übersetzung wird im Hintergrund auf unseren Servern verarbeitet. Sie werden benachrichtigt, wenn sie abgeschlossen ist.\n\nIn der Zwischenzeit können Sie mit Ihren anderen Aufgaben fortfahren.",
        "dont_show_again": "Nicht mehr anzeigen"
    },
    "fr": {
        "batch_info_dialog_title": "Information",
        "batch_info_dialog_message": "Votre traduction est en cours de traitement en arrière-plan sur nos serveurs. Vous serez informé une fois qu'elle sera terminée.\n\nVous pouvez continuer vos autres tâches en attendant.",
        "dont_show_again": "Ne plus afficher"
    },
    "it": {
        "batch_info_dialog_title": "Informazioni",
        "batch_info_dialog_message": "La tua traduzione è in fase di elaborazione in background sui nostri server. Verrai avvisato una volta completata.\n\nNel frattempo, puoi continuare con le tue altre attività.",
        "dont_show_again": "Non mostrare più"
    },
    "pt": {
        "batch_info_dialog_title": "Informação",
        "batch_info_dialog_message": "Sua tradução está sendo processada em segundo plano em nossos servidores. Você será notificado quando estiver concluída.\n\nEnquanto isso, você pode continuar com suas outras tarefas.",
        "dont_show_again": "Não mostrar novamente"
    },
    "ru": {
        "batch_info_dialog_title": "Информация",
        "batch_info_dialog_message": "Ваш перевод обрабатывается в фоновом режиме на наших серверах. Вы будете уведомлены после завершения.\n\nТем временем вы можете продолжать выполнять другие задачи.",
        "dont_show_again": "Больше не показывать"
    },
    "zh": {
        "batch_info_dialog_title": "信息",
        "batch_info_dialog_message": "您的翻译正在我们的服务器后台处理。完成后将会通知您。\n\n在此期间，您可以继续执行其他任务。",
        "dont_show_again": "不再显示"
    },
    "ja": {
        "batch_info_dialog_title": "情報",
        "batch_info_dialog_message": "翻訳はサーバーのバックグラウンドで処理されています。完了すると通知されます。\n\nその間、他のタスクを続けることができます。",
        "dont_show_again": "今後表示しない"
    },
    "ko": {
        "batch_info_dialog_title": "안내",
        "batch_info_dialog_message": "번역이 서버의 백그라운드에서 처리되고 있습니다. 완료되면 알려드립니다.\n\n그동안 다른 작업을 계속할 수 있습니다.",
        "dont_show_again": "다시 보지 않기"
    },
    "ar": {
        "batch_info_dialog_title": "معلومات",
        "batch_info_dialog_message": "تتم معالجة ترجمتك في الخلفية على خوادمنا. سيتم إعلامك عند اكتمالها.\n\nيمكنك الاستمرار في أداء مهامك الأخرى في هذه الأثناء.",
        "dont_show_again": "لا تظهر هذا مجدداً"
    },
    # And mapping the rest of the languages roughly (I will just translate the rest inline using AI logic)
    "cs": {
        "batch_info_dialog_title": "Informace",
        "batch_info_dialog_message": "Váš překlad je zpracováván na pozadí na našich serverech. Jakmile bude dokončen, budete upozorněni.\n\nZatím můžete pokračovat v dalších úkolech.",
        "dont_show_again": "Příště nezobrazovat"
    },
    "da": {
        "batch_info_dialog_title": "Information",
        "batch_info_dialog_message": "Din oversættelse behandles i baggrunden på vores servere. Du får besked, når den er færdig.\n\nI mellemtiden kan du fortsætte med dine andre opgaver.",
        "dont_show_again": "Vis ikke igen"
    },
    "el": {
        "batch_info_dialog_title": "Πληροφορίες",
        "batch_info_dialog_message": "Η μετάφρασή σας επεξεργάζεται στο παρασκήνιο στους διακομιστές μας. Θα ειδοποιηθείτε όταν ολοκληρωθεί.\n\nΜπορείτε να συνεχίσετε με τις άλλες εργασίες σας εν τω μεταξύ.",
        "dont_show_again": "Να μην εμφανιστεί ξανά"
    },
    "fa": {
        "batch_info_dialog_title": "اطلاعات",
        "batch_info_dialog_message": "ترجمه شما در پس‌زمینه سرورهای ما در حال پردازش است. پس از تکمیل به شما اطلاع داده خواهد شد.\n\nدر این مدت می‌توانید به کارهای دیگر خود بپردازید.",
        "dont_show_again": "دیگر نشان نده"
    },
    "gu": {
        "batch_info_dialog_title": "માહિતી",
        "batch_info_dialog_message": "તમારો અનુવાદ અમારા સર્વર પર પૃષ્ઠભૂમિમાં પ્રક્રિયા થઈ રહ્યો છે. જ્યારે તે પૂર્ણ થશે ત્યારે તમને સૂચિત કરવામાં આવશે.\n\nદરમિયાન તમે તમારા અન્ય કાર્યો ચાલુ રાખી શકો છો.",
        "dont_show_again": "ફરીથી ન બતાવો"
    },
    "he": {
        "batch_info_dialog_title": "מידע",
        "batch_info_dialog_message": "התרגום שלך מעובד ברקע בשרתים שלנו. תקבל הודעה כשהוא יושלם.\n\nבנתיים תוכל להמשיך בשאר המשימות שלך.",
        "dont_show_again": "אל תציג שוב"
    },
    "hu": {
        "batch_info_dialog_title": "Információ",
        "batch_info_dialog_message": "A fordítás a háttérben zajlik szervereinken. Értesítjük, amint befejeződött.\n\nAddig nyugodtan folytathatja egyéb teendőit.",
        "dont_show_again": "Ne mutassa többet"
    },
    "id": {
        "batch_info_dialog_title": "Informasi",
        "batch_info_dialog_message": "Terjemahan Anda sedang diproses di latar belakang di server kami. Anda akan diberi tahu setelah selesai.\n\nSementara itu, Anda dapat melanjutkan tugas lainnya.",
        "dont_show_again": "Jangan tampilkan lagi"
    },
    "in": {
        "batch_info_dialog_title": "Informasi",
        "batch_info_dialog_message": "Terjemahan Anda sedang diproses di latar belakang di server kami. Anda akan diberi tahu setelah selesai.\n\nSementara itu, Anda dapat melanjutkan tugas lainnya.",
        "dont_show_again": "Jangan tampilkan lagi"
    },
    "kn": {
        "batch_info_dialog_title": "ಮಾಹಿತಿ",
        "batch_info_dialog_message": "ನಿಮ್ಮ ಅನುವಾದವನ್ನು ನಮ್ಮ ಸರ್ವರ್‌ಗಳ ಹಿನ್ನೆಲೆಯಲ್ಲಿ ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲಾಗುತ್ತಿದೆ. ಪೂರ್ಣಗೊಂಡ ನಂತರ ನಿಮಗೆ ಸೂಚಿಸಲಾಗುತ್ತದೆ.\n\nಈ ನಡುವೆ ನೀವು ನಿಮ್ಮ ಇತರ ಕಾರ್ಯಗಳನ್ನು ಮುಂದುವರಿಸಬಹುದು.",
        "dont_show_again": "ಮತ್ತೆ ತೋರಿಸಬೇಡಿ"
    },
    "ml": {
        "batch_info_dialog_title": "വിവരം",
        "batch_info_dialog_message": "നിങ്ങളുടെ വിവർത്തനം ഞങ്ങളുടെ സെർവറുകളിൽ പശ്ചാത്തലത്തിൽ പ്രോസസ്സ് ചെയ്യുകയാണ്. പൂർത്തിയാകുമ്പോൾ നിങ്ങളെ അറിയിക്കും.\n\nഅതിനിടയിൽ നിങ്ങളുടെ മറ്റ് ജോലികൾ തുടരാവുന്നതാണ്.",
        "dont_show_again": "ഇനി കാണിക്കരുത്"
    },
    "mr": {
        "batch_info_dialog_title": "माहिती",
        "batch_info_dialog_message": "तुमचे भाषांतर आमच्या सर्व्हरवरील पार्श्वभूमीवर प्रक्रियेत आहे. पूर्ण झाल्यावर तुम्हाला सूचित केले जाईल.\n\nदरम्यानच्या काळात तुम्ही तुमची इतर कामे सुरू ठेवू शकता.",
        "dont_show_again": "पुन्हा दाखवू नका"
    },
    "nl": {
        "batch_info_dialog_title": "Informatie",
        "batch_info_dialog_message": "Uw vertaling wordt op de achtergrond op onze servers verwerkt. U krijgt een melding wanneer dit is voltooid.\n\nOndertussen kunt u doorgaan met uw andere taken.",
        "dont_show_again": "Niet meer weergeven"
    },
    "pa": {
        "batch_info_dialog_title": "ਜਾਣਕਾਰੀ",
        "batch_info_dialog_message": "ਤੁਹਾਡਾ ਅਨੁਵਾਦ ਸਾਡੇ ਸਰਵਰਾਂ 'ਤੇ ਪਿਛੋਕੜ ਵਿੱਚ ਪ੍ਰੋਸੈਸ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ। ਪੂਰਾ ਹੋਣ 'ਤੇ ਤੁਹਾਨੂੰ ਸੂਚਿਤ ਕੀਤਾ ਜਾਵੇਗਾ।\n\nਤੁਸੀਂ ਇਸ ਦੌਰਾਨ ਆਪਣੇ ਹੋਰ ਕੰਮ ਜਾਰੀ ਰੱਖ ਸਕਦੇ ਹੋ।",
        "dont_show_again": "ਦੁਬਾਰਾ ਨਾ ਦਿਖਾਓ"
    },
    "pl": {
        "batch_info_dialog_title": "Informacja",
        "batch_info_dialog_message": "Twoje tłumaczenie jest przetwarzane w tle na naszych serwerach. Zostaniesz powiadomiony po zakończeniu.\n\nW międzyczasie możesz kontynuować inne zadania.",
        "dont_show_again": "Nie pokazuj ponownie"
    },
    "ro": {
        "batch_info_dialog_title": "Informație",
        "batch_info_dialog_message": "Traducerea ta este procesată în fundal pe serverele noastre. Vei fi notificat când este gata.\n\nÎntre timp, poți continua cu celelalte sarcini.",
        "dont_show_again": "Nu mai afișa"
    },
    "sv": {
        "batch_info_dialog_title": "Information",
        "batch_info_dialog_message": "Din översättning bearbetas i bakgrunden på våra servrar. Du kommer att meddelas när den är klar.\n\nUnder tiden kan du fortsätta med dina andra uppgifter.",
        "dont_show_again": "Visa inte igen"
    },
    "ta": {
        "batch_info_dialog_title": "தகவல்",
        "batch_info_dialog_message": "உங்கள் மொழிபெயர்ப்பு எங்கள் சேவையகங்களின் பின்புலத்தில் செயலாக்கப்படுகிறது. முடிந்ததும் உங்களுக்குத் தெரிவிக்கப்படும்.\n\nஇதற்கிடையில் உங்கள் மற்ற வேலைகளை நீங்கள் தொடரலாம்.",
        "dont_show_again": "மீண்டும் காட்டாதே"
    },
    "te": {
        "batch_info_dialog_title": "సమాచారం",
        "batch_info_dialog_message": "మీ అనువాదం మా సర్వర్లలో నేపథ్యంలో ప్రాసెస్ చేయబడుతోంది. పూర్తయిన తర్వాత మీకు తెలియజేయబడుతుంది.\n\nఈలోగా మీరు మీ ఇతర పనులను కొనసాగించవచ్చు.",
        "dont_show_again": "మళ్లీ చూపించవద్దు"
    },
    "th": {
        "batch_info_dialog_title": "ข้อมูล",
        "batch_info_dialog_message": "งานแปลของคุณกำลังประมวลผลอยู่เบื้องหลังในเซิร์ฟเวอร์ของเรา เราจะแจ้งให้ทราบเมื่อดำเนินการเสร็จสิ้น\n\nระหว่างนี้คุณสามารถทำงานอื่นต่อไปได้",
        "dont_show_again": "ไม่ต้องแสดงอีก"
    },
    "uk": {
        "batch_info_dialog_title": "Інформація",
        "batch_info_dialog_message": "Ваш переклад обробляється у фоновому режимі на наших серверах. Вас буде сповіщено по завершенню.\n\nТим часом ви можете продовжувати виконувати інші завдання.",
        "dont_show_again": "Більше не показувати"
    },
    "vi": {
        "batch_info_dialog_title": "Thông tin",
        "batch_info_dialog_message": "Bản dịch của bạn đang được xử lý dưới nền trên máy chủ của chúng tôi. Bạn sẽ nhận được thông báo khi hoàn tất.\n\nTrong lúc đó, bạn có thể tiếp tục các công việc khác.",
        "dont_show_again": "Không hiển thị lại"
    }
}

target_keys = ["batch_info_dialog_title", "batch_info_dialog_message", "dont_show_again"]

def get_trans(lang_code, key):
    lang_map = {'cn': 'zh', 'in': 'id'}
    req_lang = lang_map.get(lang_code, lang_code)
    if req_lang in translations:
        return translations[req_lang][key]
    return translations['en'][key]

trans_dir = r"lib\translations"
files = glob.glob(os.path.join(trans_dir, "translations_*.dart"))

for file_path in files:
    filename = os.path.basename(file_path)
    lang_code = filename.replace("translations_", "").replace(".dart", "")
    
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # if already present, skip
    if "'batch_info_dialog_title'" in content:
        continue

    end_idx = content.rfind('};')
    if end_idx == -1:
        continue
    
    new_keys_str = ""
    for k in target_keys:
        val = get_trans(lang_code, k).replace("'", "\\'").replace("\n", "\\n")
        new_keys_str += f"  '{k}': '{val}',\n"
        
    updated_content = content[:end_idx] + new_keys_str + content[end_idx:]
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(updated_content)

print(f"Batch info dialog keys injected into {len(files)} files!")
