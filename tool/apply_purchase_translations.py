import os
import glob
import re

translations = {
    "ar": {
        "purchase_windows_web_or_mobile": "يمكنك شراء الرصيد من تطبيقنا للهاتف المحمول أو موقعنا الإلكتروني واستخدامه هنا (Windows) مع نفس الحساب.",
        "install_app_cta": "تثبيت التطبيق",
        "buy_from_web": "الشراء من الموقع"
    },
    "cn": {
        "purchase_windows_web_or_mobile": "您可以从我们的移动应用或网站购买积分，并在（Windows）上使用同一个账户进行使用。",
        "install_app_cta": "安装应用",
        "buy_from_web": "从网站购买"
    },
    "cs": {
        "purchase_windows_web_or_mobile": "Kredity si můžete zakoupit v naší mobilní aplikaci nebo na webových stránkách a používat je zde (Windows) se stejným účtem.",
        "install_app_cta": "Instalovat aplikaci",
        "buy_from_web": "Koupit na webu"
    },
    "da": {
        "purchase_windows_web_or_mobile": "Du kan købeポイント i vores mobilapp eller på vores hjemmeside og bruge dem her (Windows) med den samme konto.",
        "install_app_cta": "Installer app",
        "buy_from_web": "Køb fra web"
    },
    "de": {
        "purchase_windows_web_or_mobile": "Sie können Guthaben in unserer mobilen App oder auf unserer Website kaufen und hier (Windows) mit demselben Konto verwenden.",
        "install_app_cta": "App installieren",
        "buy_from_web": "Über Website kaufen"
    },
    "el": {
        "purchase_windows_web_or_mobile": "Μπορείτε να αγοράσετε πιστώσεις από την εφαρμογή μας για κινητά ή τον ιστότοπό μας και να τις χρησιμοποιήσετε εδώ (Windows) με τον ίδιο λογαριασμό.",
        "install_app_cta": "Εγκατάσταση εφαρμογής",
        "buy_from_web": "Αγορά από τον ιστότοπο"
    },
    "en": {
        "purchase_windows_web_or_mobile": "You can buy credits from our mobile app or website and use them here (Windows) with the same account.",
        "install_app_cta": "Install App",
        "buy_from_web": "Buy from Web"
    },
    "es": {
        "purchase_windows_web_or_mobile": "Puedes comprar créditos desde nuestra aplicación móvil o sitio web y usarlos aquí (Windows) con la misma cuenta.",
        "install_app_cta": "Instalar aplicación",
        "buy_from_web": "Comprar en la web"
    },
    "fa": {
        "purchase_windows_web_or_mobile": "می‌توانید از اپلیکیشن موبایل یا وب‌سایت ما اعتبار خریداری کنید و در اینجا (Windows) با همان حساب کاربری استفاده کنید.",
        "install_app_cta": "نصب اپلیکیشن",
        "buy_from_web": "خرید از وب"
    },
    "fr": {
        "purchase_windows_web_or_mobile": "Vous pouvez acheter des crédits sur notre application mobile ou notre site web et les utiliser ici (Windows) avec le même compte.",
        "install_app_cta": "Installer l'application",
        "buy_from_web": "Acheter sur le web"
    },
    "gu": {
        "purchase_windows_web_or_mobile": "તમે અમારી મોબાઇલ એપ અથવા વેબસાઇટ પરથી ક્રેડિટ ખરીદી શકો છો અને તેનો ઉપયોગ અહીં (Windows) તે જ એકાઉન્ટ સાથે કરી શકો છો.",
        "install_app_cta": "એપ્લિકેશન ઇન્સ્ટોલ કરો",
        "buy_from_web": "વેબ પરથી ખરીદો"
    },
    "he": {
        "purchase_windows_web_or_mobile": "ניתן לרכוש קרדיטים מהאפליקציה בנייד או מהאתר שלנו ולהשתמש בהם כאן (Windows) עם אותו חשבון.",
        "install_app_cta": "התקן אפליקציה",
        "buy_from_web": "קנה מהאתר"
    },
    "hu": {
        "purchase_windows_web_or_mobile": "Krediteket vásárolhat mobilalkalmazásunkban vagy weboldalunkon, és ici (Windows) ugyanazzal a fiókkal használhatja azokat.",
        "install_app_cta": "Alkalmazás telepítése",
        "buy_from_web": "Vásárlás a weben"
    },
    "id": {
        "purchase_windows_web_or_mobile": "Anda dapat membeli kredit dari aplikasi seluler atau situs web kami và menggunakannya di sini (Windows) dengan akun yang sama.",
        "install_app_cta": "Instal Aplikasi",
        "buy_from_web": "Beli dari Web"
    },
    "in": {
        "purchase_windows_web_or_mobile": "आप हमारे मोबाइल ऐप या वेबसाइट से क्रेडिट खरीद सकते हैं और उसी खाते के साथ यहाँ (Windows) उनका उपयोग कर सकते हैं।",
        "install_app_cta": "ऐप इंस्टॉल करें",
        "buy_from_web": "वेब से खरीदें"
    },
    "it": {
        "purchase_windows_web_or_mobile": "Puoi acquistare crediti dalla nostra app mobile o dal sito web e usarli qui (Windows) con lo stesso account.",
        "install_app_cta": "Installa app",
        "buy_from_web": "Acquista sul web"
    },
    "ja": {
        "purchase_windows_web_or_mobile": "モバイルアプリまたはウェブサイトからクレジットを購入し、同じアカウントを使用してここ（Windows）で使用できます。",
        "install_app_cta": "アプリをインストール",
        "buy_from_web": "ウェブで購入"
    },
    "kn": {
        "purchase_windows_web_or_mobile": "ನೀವು ನಮ್ಮ ಮೊಬೈಲ್ ಅಪ್ಲಿಕೇಶನ್ ಅಥವಾ ವೆಬ್‌ಸೈಟ್‌ನಿಂದ ಕ್ರೆಡಿಟ್‌ಗಳನ್ನು ಖರೀದಿಸಬಹುದು ಮತ್ತು ಅದೇ ಖಾತೆಯೊಂದಿಗೆ ಇಲ್ಲಿ (Windows) ಬಳಸಬಹುದು.",
        "install_app_cta": "ಅಪ್ಲಿಕೇಶನ್ ಇನ್ಸ್ಟಾಲ್ ಮಾಡಿ",
        "buy_from_web": "ವೆಬ್‌ನಿಂದ ಖರೀದಿಸಿ"
    },
    "ko": {
        "purchase_windows_web_or_mobile": "모바일 앱이나 웹사이트에서 크레딧을 구매하고 (Windows)에서 동일한 계정으로 사용할 수 있습니다.",
        "install_app_cta": "앱 설치",
        "buy_from_web": "웹에서 구매"
    },
    "ml": {
        "purchase_windows_web_or_mobile": "ഞങ്ങളുടെ മൊബൈൽ ആപ്പിൽ നിന്നോ വെബ്‌സൈറ്റിൽ നിന്നോ നിങ്ങൾക്ക് ക്രെഡിറ്റുകൾ വാങ്ങാനും അതേ അക്കൗണ്ട് ഉപയോഗിച്ച് ഇവിടെ (Windows) ഉപയോഗിക്കാനും കഴിയും.",
        "install_app_cta": "ആപ്പ് ഇൻസ്റ്റാൾ ചെയ്യുക",
        "buy_from_web": "വെബ് സൈറ്റിൽ നിന്ന് വാങ്ങുക"
    },
    "mr": {
        "purchase_windows_web_or_mobile": "तुम्ही आमच्या मोबाईल ॲप किंवा वेबसाइटवरून क्रेडिट्स खरेदी करू शकता आणि येथे (Windows) त्याच खात्यासह वापरू शकता.",
        "install_app_cta": "ॲप इंस्टॉल करा",
        "buy_from_web": "वेबवरून खरेदी करा"
    },
    "nl": {
        "purchase_windows_web_or_mobile": "U kunt credits kopen via onze mobiele app of website en deze hier (Windows) gebruiken met hetzelfde account.",
        "install_app_cta": "App installeren",
        "buy_from_web": "Koop via web"
    },
    "pa": {
        "purchase_windows_web_or_mobile": "ਤੁਸੀਂ ਸਾਡੀ ਮੋਬਾਈਲ ਐਪ ਜਾਂ ਵੈੱਬਸਾਈਟ ਤੋਂ ਕ੍ਰੈਡਿಟ್ ਖਰੀਦ ਸਕਦੇ ਹੋ ਅਤੇ ਉਸੇ ਖਾਤੇ ਨਾਲ ਇੱਥੇ (Windows) ਵਰਤ ਸਕਦੇ ਹੋ।",
        "install_app_cta": "ਐਪ ਇੰਸਟੌਲ ਕਰੋ",
        "buy_from_web": "ਵੈੱਬ ਤੋਂ ਖਰੀਦੋ"
    },
    "pl": {
        "purchase_windows_web_or_mobile": "Możesz kupić kredyty w naszej aplikacji mobilnej lub na stronie internetowej i używać ich tutaj (Windows) na tym samym koncie.",
        "install_app_cta": "Zainstaluj aplikację",
        "buy_from_web": "Kup przez stronę"
    },
    "pt": {
        "purchase_windows_web_or_mobile": "Você pode comprar créditos em nosso aplicativo móvel ou site e usá-los aqui (Windows) com a mesma conta.",
        "install_app_cta": "Instalar aplicativo",
        "buy_from_web": "Comprar na web"
    },
    "ro": {
        "purchase_windows_web_or_mobile": "Puteți cumpăra credite din aplicația noastră mobilă sau de pe site-ul nostru și le puteți folosi aici (Windows) cu același cont.",
        "install_app_cta": "Instalează aplicația",
        "buy_from_web": "Cumpără de pe web"
    },
    "ru": {
        "purchase_windows_web_or_mobile": "Вы можете купить кредиты в нашем мобильном приложении или на сайте и использовать их здесь (Windows) с той же учетной записью.",
        "install_app_cta": "Установить приложение",
        "buy_from_web": "Купить на сайте"
    },
    "sv": {
        "purchase_windows_web_or_mobile": "Du kan köpa krediter i vår mobilapp eller på vår webbplats och använda dem här (Windows) med samma konto.",
        "install_app_cta": "Installera app",
        "buy_from_web": "Köp från webben"
    },
    "ta": {
        "purchase_windows_web_or_mobile": "எங்கள் மொபைல் செயலி அல்லது இணையதளத்தில் நீங்கள் கிரெடிட்களை வாங்கலாம் மற்றும் அதே கணக்கைப் பயன்படுத்தி இங்கே (Windows) பயன்படுத்தலாம்.",
        "install_app_cta": "செயலியை நிறுவு",
        "buy_from_web": "இணையதளத்தில் வாங்கவும்"
    },
    "te": {
        "purchase_windows_web_or_mobile": "మీరు మా మొబైல் యాప్ లేదా వెబ్‌సైట్ నుండి క్రెడిట్‌లను కొనుగోలు చేయవచ్చు మరియు అదే ఖాతాతో ఇక్కడ (Windows) ఉపయోగించవచ్చు.",
        "install_app_cta": "యాప్‌ను ఇన్‌స్టాల్ చేయండి",
        "buy_from_web": "వెబ్ నుండి కొనండి"
    },
    "th": {
        "purchase_windows_web_or_mobile": "คุณสามารถซื้อเครดิตได้จากแอปมือถือหรือเว็บไซต์ของเรา และใช้ที่นี่ (Windows) ด้วยบัญชีเดียวกัน",
        "install_app_cta": "ติดตั้งแอป",
        "buy_from_web": "ซื้อจากเว็บ"
    },
    "tr": {
        "purchase_windows_web_or_mobile": "Kredinizi mobil uygulamamızdan veya web sitemizden alıp, burada (Windows) aynı hesabınızla kullanabilirsiniz.",
        "install_app_cta": "Uygulamayı Yükle",
        "buy_from_web": "Web'den Al"
    },
    "uk": {
        "purchase_windows_web_or_mobile": "Ви можете придбати кредити в нашому мобільному додатку або на веб-сайті та використовувати їх тут (Windows) з тим самим обліковим записом.",
        "install_app_cta": "Встановити додаток",
        "buy_from_web": "Купити на сайті"
    },
    "vi": {
        "purchase_windows_web_or_mobile": "Bạn có thể mua tín dụng từ ứng dụng di động hoặc trang web của chúng tôi và sử dụng tại đây (Windows) với cùng một tài khoản.",
        "install_app_cta": "Cài đặt ứng dụng",
        "buy_from_web": "Mua từ web"
    }
}

trans_dir = r"lib\translations"
files = glob.glob(os.path.join(trans_dir, "translations_*.dart"))

for file_path in files:
    filename = os.path.basename(file_path)
    lang_code = filename.replace("translations_", "").replace(".dart", "")
    
    if lang_code in translations:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        match = re.search(r"};\s*$", content)
        if match:
            new_entries = ""
            for k, v in translations[lang_code].items():
                if f"'{k}':" not in content and f'"{k}":' not in content:
                    v_esc = v.replace("'", "\\'")
                    new_entries += f"  '{k}': '{v_esc}',\n"
            
            if new_entries:
                updated_content = content[:match.start()] + new_entries + content[match.start():]
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(updated_content)
                print(f"Updated {filename}")
            else:
                print(f"No new entries for {filename}")
