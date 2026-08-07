// System log strings for desktop update checks and related UI events.
const Map<String, Map<String, String>> translationsLogUpdates = {
  'EN': {
    'log_update_check_started': 'Checking for updates...',
    'log_update_check_failed_param': 'Update check failed: {error}',
    'log_update_not_available_param': 'No update available (current: {current})',
    'log_update_available_param':
        'Update available: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Desktop notification failed',
    'log_referral_dialog_opened': 'Referral dialog opened ({source})',
    'log_ad_reward_dialog_opened': 'Ad reward dialog opened',
  },
  'TR': {
    'log_update_check_started': 'Güncelleme kontrol ediliyor...',
    'log_update_check_failed_param': 'Güncelleme kontrolü başarısız: {error}',
    'log_update_not_available_param': 'Güncelleme yok (mevcut: {current})',
    'log_update_available_param':
        'Güncelleme mevcut: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Masaüstü bildirimi gösterilemedi',
    'log_referral_dialog_opened': 'Referans diyaloğu açıldı ({source})',
    'log_ad_reward_dialog_opened': 'Reklam ödülü diyaloğu açıldı',
  },
  'FR': {
    'log_update_check_started': 'Recherche de mises à jour...',
    'log_update_check_failed_param':
        'Échec de la vérification des mises à jour : {error}',
    'log_update_not_available_param':
        'Aucune mise à jour disponible (actuelle : {current})',
    'log_update_available_param':
        'Mise à jour disponible : {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Échec de la notification bureau',
    'log_referral_dialog_opened': 'Dialogue de parrainage ouvert ({source})',
    'log_ad_reward_dialog_opened': 'Dialogue de récompense publicitaire ouvert',
  },
  'DE': {
    'log_update_check_started': 'Suche nach Updates...',
    'log_update_check_failed_param': 'Update-Prüfung fehlgeschlagen: {error}',
    'log_update_not_available_param':
        'Kein Update verfügbar (aktuell: {current})',
    'log_update_available_param':
        'Update verfügbar: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Desktop-Benachrichtigung fehlgeschlagen',
    'log_referral_dialog_opened': 'Empfehlungsdialog geöffnet ({source})',
    'log_ad_reward_dialog_opened': 'Werbebelohnungsdialog geöffnet',
  },
  'IT': {
    'log_update_check_started': 'Controllo aggiornamenti...',
    'log_update_check_failed_param':
        'Controllo aggiornamenti non riuscito: {error}',
    'log_update_not_available_param':
        'Nessun aggiornamento disponibile (attuale: {current})',
    'log_update_available_param':
        'Aggiornamento disponibile: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Notifica desktop non riuscita',
    'log_referral_dialog_opened': 'Finestra referral aperta ({source})',
    'log_ad_reward_dialog_opened': 'Finestra ricompensa annuncio aperta',
  },
  'ES': {
    'log_update_check_started': 'Comprobando actualizaciones...',
    'log_update_check_failed_param':
        'Error al comprobar actualizaciones: {error}',
    'log_update_not_available_param':
        'No hay actualización disponible (actual: {current})',
    'log_update_available_param':
        'Actualización disponible: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Error en la notificación de escritorio',
    'log_referral_dialog_opened': 'Diálogo de referidos abierto ({source})',
    'log_ad_reward_dialog_opened': 'Diálogo de recompensa publicitaria abierto',
  },
  'PT': {
    'log_update_check_started': 'A verificar atualizações...',
    'log_update_check_failed_param':
        'Falha na verificação de atualizações: {error}',
    'log_update_not_available_param':
        'Nenhuma atualização disponível (atual: {current})',
    'log_update_available_param':
        'Atualização disponível: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Falha na notificação do desktop',
    'log_referral_dialog_opened': 'Diálogo de indicação aberto ({source})',
    'log_ad_reward_dialog_opened': 'Diálogo de recompensa de anúncio aberto',
  },
  'RU': {
    'log_update_check_started': 'Проверка обновлений...',
    'log_update_check_failed_param': 'Ошибка проверки обновлений: {error}',
    'log_update_not_available_param':
        'Обновление недоступно (текущая: {current})',
    'log_update_available_param':
        'Доступно обновление: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Не удалось показать уведомление',
    'log_referral_dialog_opened': 'Открыто окно рефералов ({source})',
    'log_ad_reward_dialog_opened': 'Открыто окно рекламной награды',
  },
  'EL': {
    'log_update_check_started': 'Έλεγχος ενημερώσεων...',
    'log_update_check_failed_param': 'Αποτυχία ελέγχου ενημερώσεων: {error}',
    'log_update_not_available_param':
        'Δεν υπάρχει διαθέσιμη ενημέρωση (τρέχουσα: {current})',
    'log_update_available_param':
        'Διαθέσιμη ενημέρωση: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Αποτυχία ειδοποίησης επιφάνειας εργασίας',
    'log_referral_dialog_opened': 'Άνοιξε ο διάλογος παραπομπής ({source})',
    'log_ad_reward_dialog_opened': 'Άνοιξε ο διάλογος ανταμοιβής διαφήμισης',
  },
  'AR': {
    'log_update_check_started': 'جارٍ التحقق من التحديثات...',
    'log_update_check_failed_param': 'فشل التحقق من التحديثات: {error}',
    'log_update_not_available_param':
        'لا يوجد تحديث متاح (الحالي: {current})',
    'log_update_available_param':
        'يتوفر تحديث: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'فشل إشعار سطح المكتب',
    'log_referral_dialog_opened': 'تم فتح نافذة الإحالة ({source})',
    'log_ad_reward_dialog_opened': 'تم فتح نافذة مكافأة الإعلان',
  },
  'IN': {
    'log_update_check_started': 'अपडेट की जाँच हो रही है...',
    'log_update_check_failed_param': 'अपडेट जाँच विफल: {error}',
    'log_update_not_available_param':
        'कोई अपडेट उपलब्ध नहीं (वर्तमान: {current})',
    'log_update_available_param':
        'अपडेट उपलब्ध: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'डेस्कटॉप सूचना विफल',
    'log_referral_dialog_opened': 'रेफरल डायलॉग खोला गया ({source})',
    'log_ad_reward_dialog_opened': 'विज्ञापन इनाम डायलॉग खोला गया',
  },
  'ID': {
    'log_update_check_started': 'Memeriksa pembaruan...',
    'log_update_check_failed_param': 'Pemeriksaan pembaruan gagal: {error}',
    'log_update_not_available_param':
        'Tidak ada pembaruan (saat ini: {current})',
    'log_update_available_param':
        'Pembaruan tersedia: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Notifikasi desktop gagal',
    'log_referral_dialog_opened': 'Dialog referral dibuka ({source})',
    'log_ad_reward_dialog_opened': 'Dialog hadiah iklan dibuka',
  },
  'CN': {
    'log_update_check_started': '正在检查更新...',
    'log_update_check_failed_param': '更新检查失败：{error}',
    'log_update_not_available_param': '没有可用更新（当前：{current}）',
    'log_update_available_param': '有可用更新：{current} -> {latest} ({file})',
    'log_notification_desktop_failed': '桌面通知失败',
    'log_referral_dialog_opened': '已打开推荐对话框（{source}）',
    'log_ad_reward_dialog_opened': '已打开广告奖励对话框',
  },
  'JA': {
    'log_update_check_started': '更新を確認しています...',
    'log_update_check_failed_param': '更新確認に失敗しました: {error}',
    'log_update_not_available_param': '利用可能な更新はありません（現在: {current}）',
    'log_update_available_param':
        '更新があります: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'デスクトップ通知に失敗しました',
    'log_referral_dialog_opened': '紹介ダイアログを開きました ({source})',
    'log_ad_reward_dialog_opened': '広告報酬ダイアログを開きました',
  },
  'KO': {
    'log_update_check_started': '업데이트 확인 중...',
    'log_update_check_failed_param': '업데이트 확인 실패: {error}',
    'log_update_not_available_param': '사용 가능한 업데이트 없음 (현재: {current})',
    'log_update_available_param':
        '업데이트 사용 가능: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': '데스크톱 알림 실패',
    'log_referral_dialog_opened': '추천 대화상자 열림 ({source})',
    'log_ad_reward_dialog_opened': '광고 보상 대화상자 열림',
  },
  'NL': {
    'log_update_check_started': 'Controleren op updates...',
    'log_update_check_failed_param': 'Updatecontrole mislukt: {error}',
    'log_update_not_available_param':
        'Geen update beschikbaar (huidig: {current})',
    'log_update_available_param':
        'Update beschikbaar: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Desktopmelding mislukt',
    'log_referral_dialog_opened': 'Verwijzingsdialoog geopend ({source})',
    'log_ad_reward_dialog_opened': 'Advertentiebeloningsdialoog geopend',
  },
  'SV': {
    'log_update_check_started': 'Söker efter uppdateringar...',
    'log_update_check_failed_param': 'Uppdateringskontroll misslyckades: {error}',
    'log_update_not_available_param':
        'Ingen uppdatering tillgänglig (nuvarande: {current})',
    'log_update_available_param':
        'Uppdatering tillgänglig: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Skrivbordsavisering misslyckades',
    'log_referral_dialog_opened': 'Hänvisningsdialog öppnad ({source})',
    'log_ad_reward_dialog_opened': 'Annonsbelöningsdialog öppnad',
  },
  'PL': {
    'log_update_check_started': 'Sprawdzanie aktualizacji...',
    'log_update_check_failed_param':
        'Sprawdzenie aktualizacji nie powiodło się: {error}',
    'log_update_not_available_param':
        'Brak dostępnej aktualizacji (bieżąca: {current})',
    'log_update_available_param':
        'Dostępna aktualizacja: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Powiadomienie na pulpicie nie powiodło się',
    'log_referral_dialog_opened': 'Otwarto okno polecenia ({source})',
    'log_ad_reward_dialog_opened': 'Otwarto okno nagrody reklamowej',
  },
  'HE': {
    'log_update_check_started': 'בודק עדכונים...',
    'log_update_check_failed_param': 'בדיקת עדכונים נכשלה: {error}',
    'log_update_not_available_param':
        'אין עדכון זמין (נוכחי: {current})',
    'log_update_available_param':
        'עדכון זמין: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'התראת שולחן עבודה נכשלה',
    'log_referral_dialog_opened': 'דו-שיח הפניה נפתח ({source})',
    'log_ad_reward_dialog_opened': 'דו-שיח תגמול פרסומת נפתח',
  },
  'FA': {
    'log_update_check_started': 'در حال بررسی به‌روزرسانی...',
    'log_update_check_failed_param': 'بررسی به‌روزرسانی ناموفق بود: {error}',
    'log_update_not_available_param':
        'به‌روزرسانی موجود نیست (فعلی: {current})',
    'log_update_available_param':
        'به‌روزرسانی موجود است: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'اعلان دسکتاپ ناموفق بود',
    'log_referral_dialog_opened': 'پنجره معرفی باز شد ({source})',
    'log_ad_reward_dialog_opened': 'پنجره پاداش تبلیغ باز شد',
  },
  'TH': {
    'log_update_check_started': 'กำลังตรวจสอบการอัปเดต...',
    'log_update_check_failed_param': 'ตรวจสอบการอัปเดตล้มเหลว: {error}',
    'log_update_not_available_param':
        'ไม่มีการอัปเดต (ปัจจุบัน: {current})',
    'log_update_available_param':
        'มีการอัปเดต: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'การแจ้งเตือนบนเดสก์ท็อปล้มเหลว',
    'log_referral_dialog_opened': 'เปิดกล่องโต้ตอบการแนะนำแล้ว ({source})',
    'log_ad_reward_dialog_opened': 'เปิดกล่องโต้ตอบรางวัลโฆษณาแล้ว',
  },
  'VI': {
    'log_update_check_started': 'Đang kiểm tra cập nhật...',
    'log_update_check_failed_param': 'Kiểm tra cập nhật thất bại: {error}',
    'log_update_not_available_param':
        'Không có bản cập nhật (hiện tại: {current})',
    'log_update_available_param':
        'Có bản cập nhật: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Thông báo desktop thất bại',
    'log_referral_dialog_opened': 'Đã mở hộp thoại giới thiệu ({source})',
    'log_ad_reward_dialog_opened': 'Đã mở hộp thoại thưởng quảng cáo',
  },
  'TA': {
    'log_update_check_started': 'புதுப்பிப்புகளைச் சரிபார்க்கிறது...',
    'log_update_check_failed_param': 'புதுப்பிப்பு சரிபார்ப்பு தோல்வி: {error}',
    'log_update_not_available_param':
        'புதுப்பிப்பு இல்லை (தற்போதைய: {current})',
    'log_update_available_param':
        'புதுப்பிப்பு கிடைக்கிறது: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'டெஸ்க்டாப் அறிவிப்பு தோல்வி',
    'log_referral_dialog_opened': 'பரிந்துரை உரையாடல் திறக்கப்பட்டது ({source})',
    'log_ad_reward_dialog_opened': 'விளம்பர வெகுமதி உரையாடல் திறக்கப்பட்டது',
  },
  'TE': {
    'log_update_check_started': 'అప్‌డేట్‌లను తనిఖీ చేస్తోంది...',
    'log_update_check_failed_param': 'అప్‌డేట్ తనిఖీ విఫలమైంది: {error}',
    'log_update_not_available_param':
        'అప్‌డేట్ అందుబాటులో లేదు (ప్రస్తుతం: {current})',
    'log_update_available_param':
        'అప్‌డేట్ అందుబాటులో ఉంది: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'డెస్క్‌టాప్ నోటిఫికేషన్ విఫలమైంది',
    'log_referral_dialog_opened': 'రెఫరల్ డైలాగ్ తెరవబడింది ({source})',
    'log_ad_reward_dialog_opened': 'ప్రకటన రివార్డ్ డైలాగ్ తెరవబడింది',
  },
  'ML': {
    'log_update_check_started': 'അപ്‌ഡേറ്റുകൾ പരിശോധിക്കുന്നു...',
    'log_update_check_failed_param': 'അപ്‌ഡേറ്റ് പരിശോധന പരാജയപ്പെട്ടു: {error}',
    'log_update_not_available_param':
        'അപ്‌ഡേറ്റ് ലഭ്യമല്ല (നിലവിലെ: {current})',
    'log_update_available_param':
        'അപ്‌ഡേറ്റ് ലഭ്യമാണ്: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'ഡെസ്ക്ടോപ്പ് അറിയിപ്പ് പരാജയപ്പെട്ടു',
    'log_referral_dialog_opened': 'റഫറൽ ഡയലോഗ് തുറന്നു ({source})',
    'log_ad_reward_dialog_opened': 'പരസ്യ റിവാർഡ് ഡയലോഗ് തുറന്നു',
  },
  'KN': {
    'log_update_check_started': 'ನವೀಕರಣಗಳನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ...',
    'log_update_check_failed_param': 'ನವೀಕರಣ ಪರಿಶೀಲನೆ ವಿಫಲವಾಗಿದೆ: {error}',
    'log_update_not_available_param':
        'ನವೀಕರಣ ಲಭ್ಯವಿಲ್ಲ (ಪ್ರಸ್ತುತ: {current})',
    'log_update_available_param':
        'ನವೀಕರಣ ಲಭ್ಯವಿದೆ: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'ಡೆಸ್ಕ್‌ಟಾಪ್ ಅಧಿಸೂಚನೆ ವಿಫಲವಾಗಿದೆ',
    'log_referral_dialog_opened': 'ರೆಫರಲ್ ಸಂವಾದ ತೆರೆಯಲಾಗಿದೆ ({source})',
    'log_ad_reward_dialog_opened': 'ಜಾಹೀರಾತು ಬಹುಮಾನ ಸಂವಾದ ತೆರೆಯಲಾಗಿದೆ',
  },
  'PA': {
    'log_update_check_started': 'ਅਪਡੇਟਾਂ ਦੀ ਜਾਂਚ ਕੀਤੀ ਜਾ ਰਹੀ ਹੈ...',
    'log_update_check_failed_param': 'ਅਪਡੇਟ ਜਾਂਚ ਅਸਫਲ: {error}',
    'log_update_not_available_param':
        'ਕੋਈ ਅਪਡੇਟ ਉਪਲਬਧ ਨਹੀਂ (ਮੌਜੂਦਾ: {current})',
    'log_update_available_param':
        'ਅਪਡੇਟ ਉਪਲਬਧ: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'ਡੈਸਕਟਾਪ ਸੂਚਨਾ ਅਸਫਲ',
    'log_referral_dialog_opened': 'ਰੈਫਰਲ ਡਾਇਲਾਗ ਖੋਲ੍ਹਿਆ ਗਿਆ ({source})',
    'log_ad_reward_dialog_opened': 'ਇਸ਼ਤਿਹਾਰ ਇਨਾਮ ਡਾਇਲਾਗ ਖੋਲ੍ਹਿਆ ਗਿਆ',
  },
  'GU': {
    'log_update_check_started': 'અપડેટ તપાસ થઈ રહી છે...',
    'log_update_check_failed_param': 'અપડેટ તપાસ નિષ્ફળ: {error}',
    'log_update_not_available_param':
        'કોઈ અપડેટ ઉપલબ્ધ નથી (વર્તમાન: {current})',
    'log_update_available_param':
        'અપડેટ ઉપલબ્ધ: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'ડેસ્કટોપ સૂચના નિષ્ફળ',
    'log_referral_dialog_opened': 'રેફરલ ડાયલોગ ખોલ્યો ({source})',
    'log_ad_reward_dialog_opened': 'જાહેરાત ઇનામ ડાયલોગ ખોલ્યો',
  },
  'MR': {
    'log_update_check_started': 'अपडेट तपासले जात आहे...',
    'log_update_check_failed_param': 'अपडेट तपासणी अयशस्वी: {error}',
    'log_update_not_available_param':
        'अपडेट उपलब्ध नाही (सध्याची: {current})',
    'log_update_available_param':
        'अपडेट उपलब्ध: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'डेस्कटॉप सूचना अयशस्वी',
    'log_referral_dialog_opened': 'रेफरल डायलॉग उघडला ({source})',
    'log_ad_reward_dialog_opened': 'जाहिरात बक्षीस डायलॉग उघडला',
  },
  'UK': {
    'log_update_check_started': 'Перевірка оновлень...',
    'log_update_check_failed_param': 'Помилка перевірки оновлень: {error}',
    'log_update_not_available_param':
        'Оновлення недоступне (поточна: {current})',
    'log_update_available_param':
        'Доступне оновлення: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Не вдалося показати сповіщення',
    'log_referral_dialog_opened': 'Відкрито діалог рефералів ({source})',
    'log_ad_reward_dialog_opened': 'Відкрито діалог рекламної винагороди',
  },
  'RO': {
    'log_update_check_started': 'Se verifică actualizările...',
    'log_update_check_failed_param':
        'Verificarea actualizărilor a eșuat: {error}',
    'log_update_not_available_param':
        'Nicio actualizare disponibilă (curentă: {current})',
    'log_update_available_param':
        'Actualizare disponibilă: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Notificarea desktop a eșuat',
    'log_referral_dialog_opened': 'Dialog de recomandare deschis ({source})',
    'log_ad_reward_dialog_opened': 'Dialog de recompensă reclamă deschis',
  },
  'CS': {
    'log_update_check_started': 'Kontrola aktualizací...',
    'log_update_check_failed_param': 'Kontrola aktualizací selhala: {error}',
    'log_update_not_available_param':
        'Žádná aktualizace není k dispozici (aktuální: {current})',
    'log_update_available_param':
        'Aktualizace je k dispozici: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Desktopové oznámení selhalo',
    'log_referral_dialog_opened': 'Otevřen dialog doporučení ({source})',
    'log_ad_reward_dialog_opened': 'Otevřen dialog odměny za reklamu',
  },
  'HU': {
    'log_update_check_started': 'Frissítések ellenőrzése...',
    'log_update_check_failed_param': 'Frissítés-ellenőrzés sikertelen: {error}',
    'log_update_not_available_param':
        'Nincs elérhető frissítés (jelenlegi: {current})',
    'log_update_available_param':
        'Frissítés elérhető: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Asztali értesítés sikertelen',
    'log_referral_dialog_opened': 'Ajánló párbeszéd megnyitva ({source})',
    'log_ad_reward_dialog_opened': 'Hirdetésjutalom párbeszéd megnyitva',
  },
  'DA': {
    'log_update_check_started': 'Søger efter opdateringer...',
    'log_update_check_failed_param': 'Opdateringstjek mislykkedes: {error}',
    'log_update_not_available_param':
        'Ingen opdatering tilgængelig (nuværende: {current})',
    'log_update_available_param':
        'Opdatering tilgængelig: {current} -> {latest} ({file})',
    'log_notification_desktop_failed': 'Skrivebordsnotifikation mislykkedes',
    'log_referral_dialog_opened': 'Henvisningsdialog åbnet ({source})',
    'log_ad_reward_dialog_opened': 'Annoncebelønningsdialog åbnet',
  },
};
