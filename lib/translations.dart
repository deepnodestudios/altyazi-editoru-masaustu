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
import 'translations/translations_maintenance.dart';
import 'translations/translations_log_updates.dart';
import 'translations/translations_policy_change.dart';
import 'translations/translations_token_wallet.dart';
import 'translations/translations_bonus_policy.dart';

const Map<String, Map<String, String>> _desktopDialogTranslations = {
    'TR': {
        'window_close_title': 'Uygulamayi Kapat',
        'window_close_unsaved_warning':
            'Editorde kaydedilmemis degisiklikler var. Uygulamayi kapatmak istediginize emin misiniz?',
        'update_title': 'Yeni sürüm bulundu',
        'update_action': 'Güncelle',
        'update_later': 'Daha sonra',
        'update_new_version': 'Yeni sürüm',
        'update_current_version': 'Mevcut sürüm',
        'update_not_found': 'Yeni sürüm bulunamadı.',
        'update_downloading': 'Güncelleme indiriliyor',
        'update_download_failed':
            'Güncelleme indirilemedi. Tarayıcıda açılıyor.',
    },
    'EN': {
        'window_close_title': 'Close Application',
        'window_close_unsaved_warning':
            'There are unsaved changes in the editor. Are you sure you want to close the application?',
        'update_title': 'Update found',
        'update_action': 'Update',
        'update_later': 'Later',
        'update_new_version': 'New version',
        'update_current_version': 'Current version',
        'update_not_found': 'No update found.',
        'update_downloading': 'Downloading update',
        'update_download_failed':
            'Could not download the update. Opening in browser.',
    },
    'FR': {
        'window_close_title': 'Fermer l\'application',
        'window_close_unsaved_warning':
            'Il y a des modifications non enregistrees dans l\'editeur. Voulez-vous vraiment fermer l\'application ?',
        'update_title': 'Mise à jour trouvée',
        'update_action': 'Mettre à jour',
        'update_later': 'Plus tard',
        'update_new_version': 'Nouvelle version',
        'update_current_version': 'Version actuelle',
        'update_downloading': 'Téléchargement de la mise à jour',
        'update_download_failed':
            'Impossible de télécharger la mise à jour. Ouverture dans le navigateur.',
        'update_not_found': 'Aucune mise à jour trouvée.',
    },
    'DE': {
        'window_close_title': 'Anwendung schliessen',
        'window_close_unsaved_warning':
            'Im Editor gibt es nicht gespeicherte Aenderungen. Moechten Sie die Anwendung wirklich schliessen?',
        'update_title': 'Update gefunden',
        'update_action': 'Aktualisieren',
        'update_later': 'Später',
        'update_new_version': 'Neue Version',
        'update_current_version': 'Aktuelle Version',
        'update_downloading': 'Update wird heruntergeladen',
        'update_download_failed':
            'Update konnte nicht heruntergeladen werden. Wird im Browser geöffnet.',
        'update_not_found': 'Kein Update gefunden.',
    },
    'IT': {
        'window_close_title': 'Chiudi applicazione',
        'window_close_unsaved_warning':
            'Ci sono modifiche non salvate nell\'editor. Vuoi davvero chiudere l\'applicazione?',
        'update_title': 'Aggiornamento disponibile',
        'update_action': 'Aggiorna',
        'update_later': 'Più tardi',
        'update_new_version': 'Nuova versione',
        'update_current_version': 'Versione corrente',
        'update_downloading': 'Download dell\'aggiornamento in corso',
        'update_download_failed':
            'Impossibile scaricare l\'aggiornamento. Apertura nel browser.',
        'update_not_found': 'Nessun aggiornamento trovato.',
    },
    'ES': {
        'window_close_title': 'Cerrar aplicacion',
        'window_close_unsaved_warning':
            'Hay cambios sin guardar en el editor. Estas seguro de que deseas cerrar la aplicacion?',
        'update_title': 'Actualización encontrada',
        'update_action': 'Actualizar',
        'update_later': 'Más tarde',
        'update_new_version': 'Nueva versión',
        'update_current_version': 'Versión actual',
        'update_downloading': 'Descargando actualización',
        'update_download_failed':
            'No se pudo descargar la actualización. Abriendo en el navegador.',
        'update_not_found': 'No se encontró ninguna actualización.',
    },
    'RU': {
        'window_close_title': 'Закрыть приложение',
        'window_close_unsaved_warning':
            'В редакторе есть несохраненные изменения. Вы уверены, что хотите закрыть приложение?',
        'update_title': 'Найдено обновление',
        'update_action': 'Обновить',
        'update_later': 'Позже',
        'update_new_version': 'Новая версия',
        'update_current_version': 'Текущая версия',
        'update_downloading': 'Загрузка обновления',
        'update_download_failed':
            'Не удалось загрузить обновление. Открывается в браузере.',
        'update_not_found': 'Обновление не найдено.',
    },
    'EL': {
        'window_close_title': 'Κλεισιμο εφαρμογης',
        'window_close_unsaved_warning':
            'Υπαρχουν μη αποθηκευμενες αλλαγες στον επεξεργαστη. Ειστε βεβαιοι οτι θελετε να κλεισετε την εφαρμογη;',
        'update_title': 'Βρέθηκε ενημέρωση',
        'update_action': 'Ενημέρωση',
        'update_later': 'Αργότερα',
        'update_new_version': 'Νέα έκδοση',
        'update_current_version': 'Τρέχουσα έκδοση',
        'update_downloading': 'Λήψη ενημέρωσης',
        'update_download_failed':
            'Αποτυχία λήψης ενημέρωσης. Άνοιγμα στο πρόγραμμα περιήγησης.',
        'update_not_found': 'Δεν βρέθηκε ενημέρωση.',
    },
    'PT': {
        'window_close_title': 'Fechar a aplicacao',
        'window_close_unsaved_warning':
            'Existem alteracoes nao guardadas no editor. Tem a certeza de que pretende fechar a aplicacao?',
        'update_title': 'Atualização encontrada',
        'update_action': 'Atualizar',
        'update_later': 'Mais tarde',
        'update_new_version': 'Nova versão',
        'update_current_version': 'Versão atual',
        'update_downloading': 'A transferir atualização',
        'update_download_failed':
            'Não foi possível transferir a atualização. A abrir no navegador.',
        'update_not_found': 'Nenhuma atualização encontrada.',
    },
    'AR': {
        'window_close_title': 'إغلاق التطبيق',
        'window_close_unsaved_warning':
            'توجد تغييرات غير محفوظة في المحرر. هل أنت متأكد أنك تريد إغلاق التطبيق؟',
        'update_title': 'تم العثور على تحديث',
        'update_action': 'تحديث',
        'update_later': 'لاحقاً',
        'update_new_version': 'الإصدار الجديد',
        'update_current_version': 'الإصدار الحالي',
        'update_downloading': 'جارٍ تنزيل التحديث',
        'update_download_failed':
            'تعذر تنزيل التحديث. يتم الفتح في المتصفح.',
        'update_not_found': 'لم يتم العثور على تحديث.',
    },
    'IN': {
        'window_close_title': 'ऐप बंद करें',
        'window_close_unsaved_warning':
            'एडिटर में सहेजे न गए बदलाव हैं। क्या आप वाकई ऐप बंद करना चाहते हैं?',
        'update_title': 'अपडेट मिला',
        'update_action': 'अपडेट करें',
        'update_later': 'बाद में',
        'update_new_version': 'नया संस्करण',
        'update_current_version': 'वर्तमान संस्करण',
        'update_downloading': 'अपडेट डाउनलोड हो रहा है',
        'update_download_failed':
            'अपडेट डाउनलोड नहीं हो सका। ब्राउज़र में खोला जा रहा है।',
        'update_not_found': 'कोई अपडेट नहीं मिला।',
    },
    'ID': {
        'window_close_title': 'Tutup aplikasi',
        'window_close_unsaved_warning':
            'Ada perubahan yang belum disimpan di editor. Apakah Anda yakin ingin menutup aplikasi?',
        'update_title': 'Pembaruan ditemukan',
        'update_action': 'Perbarui',
        'update_later': 'Nanti',
        'update_new_version': 'Versi baru',
        'update_current_version': 'Versi saat ini',
        'update_downloading': 'Mengunduh pembaruan',
        'update_download_failed':
            'Pembaruan tidak dapat diunduh. Membuka di browser.',
        'update_not_found': 'Pembaruan tidak ditemukan.',
    },
    'CN': {
        'window_close_title': '关闭应用',
        'window_close_unsaved_warning':
            '编辑器中有未保存的更改。确定要关闭应用吗？',
        'update_title': '发现更新',
        'update_action': '更新',
        'update_later': '稍后',
        'update_new_version': '新版本',
        'update_current_version': '当前版本',
        'update_downloading': '正在下载更新',
        'update_download_failed':
            '无法下载更新，正在浏览器中打开。',
        'update_not_found': '未找到更新。',
    },
    'JA': {
        'window_close_title': 'アプリを閉じる',
        'window_close_unsaved_warning':
            'エディターに未保存の変更があります。本当にアプリを閉じますか？',
        'update_title': 'アップデートが見つかりました',
        'update_action': '更新',
        'update_later': '後で',
        'update_new_version': '新しいバージョン',
        'update_current_version': '現在のバージョン',
        'update_downloading': 'アップデートをダウンロード中',
        'update_download_failed':
            'アップデートをダウンロードできませんでした。ブラウザで開きます。',
        'update_not_found': 'アップデートが見つかりませんでした。',
    },
    'KO': {
        'window_close_title': '앱 닫기',
        'window_close_unsaved_warning':
            '편집기에 저장되지 않은 변경 사항이 있습니다. 정말 앱을 닫으시겠습니까?',
        'update_title': '업데이트가 발견되었습니다',
        'update_action': '업데이트',
        'update_later': '나중에',
        'update_new_version': '새 버전',
        'update_current_version': '현재 버전',
        'update_downloading': '업데이트 다운로드 중',
        'update_download_failed':
            '업데이트를 다운로드할 수 없습니다. 브라우저에서 엽니다.',
        'update_not_found': '업데이트를 찾을 수 없습니다.',
    },
    'NL': {
        'window_close_title': 'Applicatie sluiten',
        'window_close_unsaved_warning':
            'Er zijn niet-opgeslagen wijzigingen in de editor. Weet u zeker dat u de applicatie wilt sluiten?',
        'update_title': 'Update gevonden',
        'update_action': 'Bijwerken',
        'update_later': 'Later',
        'update_new_version': 'Nieuwe versie',
        'update_current_version': 'Huidige versie',
        'update_downloading': 'Update downloaden',
        'update_download_failed':
            'Update kon niet worden gedownload. Openen in browser.',
        'update_not_found': 'Geen update gevonden.',
    },
    'SV': {
        'window_close_title': 'Stang appen',
        'window_close_unsaved_warning':
            'Det finns osparade andringar i redigeraren. Ar du saker pa att du vill stanga appen?',
        'update_title': 'Uppdatering hittad',
        'update_action': 'Uppdatera',
        'update_later': 'Senare',
        'update_new_version': 'Ny version',
        'update_current_version': 'Aktuell version',
        'update_downloading': 'Laddar ner uppdatering',
        'update_download_failed':
            'Kunde inte ladda ner uppdateringen. Öppnar i webbläsaren.',
        'update_not_found': 'Ingen uppdatering hittades.',
    },
    'PL': {
        'window_close_title': 'Zamknij aplikacje',
        'window_close_unsaved_warning':
            'W edytorze sa niezapisane zmiany. Czy na pewno chcesz zamknac aplikacje?',
        'update_title': 'Znaleziono aktualizację',
        'update_action': 'Aktualizuj',
        'update_later': 'Później',
        'update_new_version': 'Nowa wersja',
        'update_current_version': 'Aktualna wersja',
        'update_downloading': 'Pobieranie aktualizacji',
        'update_download_failed':
            'Nie udało się pobrać aktualizacji. Otwieranie w przeglądarce.',
        'update_not_found': 'Nie znaleziono aktualizacji.',
    },
    'TH': {
        'window_close_title': 'ปิดแอป',
        'window_close_unsaved_warning':
            'มีการเปลี่ยนแปลงที่ยังไม่ได้บันทึกในตัวแก้ไข คุณแน่ใจหรือไม่ว่าต้องการปิดแอป?',
        'update_title': 'พบการอัปเดต',
        'update_action': 'อัปเดต',
        'update_later': 'ภายหลัง',
        'update_new_version': 'เวอร์ชันใหม่',
        'update_current_version': 'เวอร์ชันปัจจุบัน',
        'update_downloading': 'กำลังดาวน์โหลดการอัปเดต',
        'update_download_failed':
            'ไม่สามารถดาวน์โหลดการอัปเดตได้ กำลังเปิดในเบราว์เซอร์',
        'update_not_found': 'ไม่พบการอัปเดต',
    },
    'VI': {
        'window_close_title': 'Dong ung dung',
        'window_close_unsaved_warning':
            'Co thay doi chua duoc luu trong trinh chinh sua. Ban co chac muon dong ung dung khong?',
        'update_title': 'Đã tìm thấy bản cập nhật',
        'update_action': 'Cập nhật',
        'update_later': 'Để sau',
        'update_new_version': 'Phiên bản mới',
        'update_current_version': 'Phiên bản hiện tại',
        'update_downloading': 'Đang tải bản cập nhật',
        'update_download_failed':
            'Không thể tải bản cập nhật. Đang mở trong trình duyệt.',
        'update_not_found': 'Không tìm thấy bản cập nhật.',
    },
    'HE': {
        'window_close_title': 'סגירת היישום',
        'window_close_unsaved_warning':
            'יש שינויים שלא נשמרו בעורך. האם אתה בטוח שברצונך לסגור את היישום?',
        'update_title': 'נמצא עדכון',
        'update_action': 'עדכן',
        'update_later': 'מאוחר יותר',
        'update_new_version': 'גרסה חדשה',
        'update_current_version': 'הגרסה הנוכחית',
        'update_downloading': 'מוריד עדכון',
        'update_download_failed':
            'לא ניתן להוריד את העדכון. נפתח בדפדפן.',
        'update_not_found': 'לא נמצא עדכון.',
    },
    'FA': {
        'window_close_title': 'بستن برنامه',
        'window_close_unsaved_warning':
            'تغییرات ذخیره‌نشده‌ای در ویرایشگر وجود دارد. آیا مطمئن هستید که می‌خواهید برنامه را ببندید؟',
        'update_title': 'به‌روزرسانی یافت شد',
        'update_action': 'به‌روزرسانی',
        'update_later': 'بعداً',
        'update_new_version': 'نسخه جدید',
        'update_current_version': 'نسخه جاری',
        'update_downloading': 'در حال دانلود به‌روزرسانی',
        'update_download_failed':
            'دانلود به‌روزرسانی ممکن نشد. در مرورگر باز می‌شود.',
        'update_not_found': 'به‌روزرسانی یافت نشد.',
    },
    'TA': {
        'window_close_title': 'பயன்பாட்டை மூடு',
        'window_close_unsaved_warning':
            'திருத்தியில் சேமிக்கப்படாத மாற்றங்கள் உள்ளன. பயன்பாட்டை மூட விரும்புகிறீர்களா?',
        'update_title': 'புதுப்பிப்பு கண்டறியப்பட்டது',
        'update_action': 'புதுப்பிக்கவும்',
        'update_later': 'பின்னர்',
        'update_new_version': 'புதிய பதிப்பு',
        'update_current_version': 'தற்போதைய பதிப்பு',
        'update_downloading': 'புதுப்பிப்பு பதிவிறக்கப்படுகிறது',
        'update_download_failed':
            'புதுப்பிப்பைப் பதிவிறக்க முடியவில்லை. உலாவியில் திறக்கப்படுகிறது.',
        'update_not_found': 'புதுப்பிப்பு கண்டறியப்படவில்லை.',
    },
    'TE': {
        'window_close_title': 'యాప్‌ను మూసివేయి',
        'window_close_unsaved_warning':
            'ఎడిటర్‌లో సేవ్ చేయని మార్పులు ఉన్నాయి. మీరు నిజంగా యాప్‌ను మూసివేయాలనుకుంటున్నారా?',
        'update_title': 'అప్డేట్ కనుగొనబడింది',
        'update_action': 'అప్డేట్',
        'update_later': 'తరువాత',
        'update_new_version': 'కొత్త సంచిక',
        'update_current_version': 'ప్రస్తుత సంచిక',
        'update_downloading': 'అప్‌డేట్ డౌన్‌లోడ్ అవుతోంది',
        'update_download_failed':
            'అప్‌డేట్‌ను డౌన్‌లోడ్ చేయలేకపోయాం. బ్రౌజర్‌లో తెరుస్తోంది.',
        'update_not_found': 'అప్‌డేట్ కనుగొనబడలేదు.',
    },
    'ML': {
        'window_close_title': 'ആപ്പ് അടയ്ക്കുക',
        'window_close_unsaved_warning':
            'എഡിറ്ററിൽ സംരക്ഷിക്കാത്ത മാറ്റങ്ങൾ ഉണ്ട്. ആപ്പ് അടയ്ക്കണമെന്നുറപ്പാണോ?',
        'update_title': 'അപ്‌ഡേറ്റ് കണ്ടെത്തി',
        'update_action': 'സമകാലീകരിക്കുക',
        'update_later': 'പിന്നീട്',
        'update_new_version': 'പുതിയ പതിപ്പ്',
        'update_current_version': 'നിലവിലെ പതിപ്പ്',
        'update_downloading': 'അപ്‌ഡേറ്റ് ഡൗൺലോഡ് ചെയ്യുന്നു',
        'update_download_failed':
            'അപ്‌ഡേറ്റ് ഡൗൺലോഡ് ചെയ്യാൻ കഴിഞ്ഞില്ല. ബ്രൗസറിൽ തുറക്കുന്നു.',
        'update_not_found': 'അപ്‌ഡേറ്റ് കണ്ടെത്തിയില്ല.',
    },
    'KN': {
        'window_close_title': 'ಆಪ್ ಮುಚ್ಚಿ',
        'window_close_unsaved_warning':
            'ಎಡಿಟರ್‌ನಲ್ಲಿ ಉಳಿಸದ ಬದಲಾವಣೆಗಳಿವೆ. ಆಪ್ ಅನ್ನು ನಿಜವಾಗಿಯೂ ಮುಚ್ಚಬೇಕೆ?',
        'update_title': 'ಅಪ್‌ಡೇಟ್ ಕಂಡುಬಂದಿದೆ',
        'update_action': 'ಅಪ್‌ಡೇಟ್',
        'update_later': 'ನಂತರ',
        'update_new_version': 'ಹೊಸ ಸಂಚಿಕೆ',
        'update_current_version': 'ಪ್ರಸ್ತುತ ಸಂಚಿಕೆ',
        'update_downloading': 'ಅಪ್‌ಡೇಟ್ ಡೌನ್‌ಲೋಡ್ ಆಗುತ್ತಿದೆ',
        'update_download_failed':
            'ಅಪ್‌ಡೇಟ್ ಡೌನ್‌ಲೋಡ್ ಮಾಡಲಾಗಲಿಲ್ಲ. ಬ್ರೌಸರ್‌ನಲ್ಲಿ ತೆರೆಯಲಾಗುತ್ತಿದೆ.',
        'update_not_found': 'ಅಪ್‌ಡೇಟ್ ಕಂಡುಬಂದಿಲ್ಲ.',
    },
    'PA': {
        'window_close_title': 'ਐਪ ਬੰਦ ਕਰੋ',
        'window_close_unsaved_warning':
            'ਐਡੀਟਰ ਵਿੱਚ ਨਾ-ਸੇਵ ਕੀਤੀਆਂ ਤਬਦੀਲੀਆਂ ਹਨ। ਕੀ ਤੁਸੀਂ ਪੱਕੇ ਤੌਰ ਤੇ ਐਪ ਬੰਦ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'update_title': 'ਅਪਡੇਟ ਮਿਲੀ',
        'update_action': 'ਅਪਡੇਟ',
        'update_later': 'ਬਾਅਦ ਵਿੱਚ',
        'update_new_version': 'ਨਵਾਂ ਵਰਜ਼ਨ',
        'update_current_version': 'ਮੌਜੂਦਾ ਵਰਜ਼ਨ',
        'update_downloading': 'ਅਪਡੇਟ ਡਾਊਨਲੋਡ ਹੋ ਰਿਹਾ ਹੈ',
        'update_download_failed':
            'ਅਪਡੇਟ ਡਾਊਨਲੋਡ ਨਹੀਂ ਹੋ ਸਕਿਆ। ਬ੍ਰਾਊਜ਼ਰ ਵਿੱਚ ਖੋਲ੍ਹਿਆ ਜਾ ਰਿਹਾ ਹੈ।',
        'update_not_found': 'ਕੋਈ ਅਪਡੇਟ ਨਹੀਂ ਮਿਲੀ।',
    },
    'GU': {
        'window_close_title': 'એપ બંધ કરો',
        'window_close_unsaved_warning':
            'એડિટરમાં સેવ ન કરેલા ફેરફારો છે. શું તમે ખરેખર એપ બંધ કરવા માંગો છો?',
        'update_title': 'અપડેટ મળી',
        'update_action': 'અપડેટ કરો',
        'update_later': 'પછી',
        'update_new_version': 'નવું સંસ્કરણ',
        'update_current_version': 'વર્તમાન સંસ્કરણ',
        'update_downloading': 'અપડેટ ડાઉનલોડ થઈ રહ્યું છે',
        'update_download_failed':
            'અપડેટ ડાઉનલોડ થઈ શક્યું નહીં. બ્રાઉઝરમાં ખોલી રહ્યા છીએ.',
        'update_not_found': 'કોઈ અપડેટ મળ્યું નથી.',
    },
    'MR': {
        'window_close_title': 'अॅप बंद करा',
        'window_close_unsaved_warning':
            'एडिटरमध्ये सेव्ह न केलेले बदल आहेत. तुम्हाला अॅप खरोखर बंद करायचे आहे का?',
        'update_title': 'अपडेट सापडला',
        'update_action': 'अपडेट करा',
        'update_later': 'नंतर',
        'update_new_version': 'नवीन आवृत्ती',
        'update_current_version': 'सध्याची आवृत्ती',
        'update_downloading': 'अपडेट डाउनलोड होत आहे',
        'update_download_failed':
            'अपडेट डाउनलोड होऊ शकले नाही. ब्राउझरमध्ये उघडले जात आहे.',
        'update_not_found': 'अपडेट सापडला नाही.',
    },
    'UK': {
        'window_close_title': 'Закрити застосунок',
        'window_close_unsaved_warning':
            'У редакторі є незбережені зміни. Ви впевнені, що хочете закрити застосунок?',
        'update_title': 'Знайдено оновлення',
        'update_action': 'Оновити',
        'update_later': 'Пізніше',
        'update_new_version': 'Нова версія',
        'update_current_version': 'Поточна версія',
        'update_downloading': 'Завантаження оновлення',
        'update_download_failed':
            'Не вдалося завантажити оновлення. Відкривається в браузері.',
        'update_not_found': 'Оновлення не знайдено.',
    },
    'CS': {
        'window_close_title': 'Zavrit aplikaci',
        'window_close_unsaved_warning':
            'V editoru jsou neulozene zmeny. Opravdu chcete zavrit aplikaci?',
        'update_title': 'Aktualizace nalezena',
        'update_action': 'Aktualizovat',
        'update_later': 'Později',
        'update_new_version': 'Nová verze',
        'update_current_version': 'Aktuální verze',
        'update_downloading': 'Stahování aktualizace',
        'update_download_failed':
            'Aktualizaci se nepodařilo stáhnout. Otevírá se v prohlížeči.',
        'update_not_found': 'Nebyla nalezena žádná aktualizace.',
    },
    'RO': {
        'window_close_title': 'Inchide aplicatia',
        'window_close_unsaved_warning':
            'Exista modificari nesalvate in editor. Sigur doriti sa inchideti aplicatia?',
        'update_title': 'Actualizare găsită',
        'update_action': 'Actualizează',
        'update_later': 'Mai târziu',
        'update_new_version': 'Versiune nouă',
        'update_current_version': 'Versiune curentă',
        'update_downloading': 'Se descarcă actualizarea',
        'update_download_failed':
            'Actualizarea nu a putut fi descărcată. Se deschide în browser.',
        'update_not_found': 'Nu a fost găsită nicio actualizare.',
    },
    'HU': {
        'window_close_title': 'Alkalmazas bezarasa',
        'window_close_unsaved_warning':
            'Nem mentett modositasok vannak a szerkesztoben. Biztosan be szeretne zarni az alkalmazast?',
        'update_title': 'Frissítés található',
        'update_action': 'Frissítés',
        'update_later': 'Később',
        'update_new_version': 'Új verzió',
        'update_current_version': 'Jelenlegi verzió',
        'update_downloading': 'Frissítés letöltése',
        'update_download_failed':
            'A frissítés letöltése nem sikerült. Megnyitás böngészőben.',
        'update_not_found': 'Nem található frissítés.',
    },
    'DA': {
        'window_close_title': 'Luk appen',
        'window_close_unsaved_warning':
            'Der er ikke-gemte andringer i editoren. Er du sikker pa, at du vil lukke appen?',
        'update_title': 'Opdatering fundet',
        'update_action': 'Opdater',
        'update_later': 'Senere',
        'update_new_version': 'Ny version',
        'update_current_version': 'Nuværende version',
        'update_downloading': 'Downloader opdatering',
        'update_download_failed':
            'Opdateringen kunne ikke downloades. Åbner i browseren.',
        'update_not_found': 'Ingen opdatering fundet.',
    },
};

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
        'share_selected_tooltip': 'share',
        'system_log_copied': 'log_copied',
        'decrease_font_size': 'editor_zoom_out_tooltip',
        'increase_font_size': 'editor_zoom_in_tooltip',
        'window_close_confirm': 'close',
        'window_close_translation_warning': 'batch_background_notification_tip',
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

        return null;
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
        'NL': translationsNl,
        'SV': translationsSv,
        'PL': translationsPl,
        'TH': translationsTh,
        'VI': translationsVi,
        'HE': translationsHe,
        'FA': translationsFa,
        'TA': translationsTa,
        'TE': translationsTe,
        'ML': translationsMl,
        'KN': translationsKn,
        'PA': translationsPa,
        'GU': translationsGu,
        'MR': translationsMr,
        'TR': translationsTr,
        'UK': translationsUk,
        'CS': translationsCs,
        'RO': translationsRo,
        'HU': translationsHu,
        'DA': translationsDa,
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

    static Map<String, String> get(String lang) {
        lang = _normalizeLanguageCode(lang);

        final cached = _cache[lang];
        if (cached != null) return cached;

        final constData = _data[lang] ?? translationsTr;
        final merged = <String, String>{
            ...constData,
            ...?_desktopDialogTranslations[lang],
        };
        merged['tour_credit_history_title'] =
            _tourCreditHistoryTitleByCode[lang] ??
            _tourCreditHistoryTitleByCode['EN']!;
        merged['tour_credit_history_desc'] =
            _tourCreditHistoryDescByCode[lang] ??
            _tourCreditHistoryDescByCode['EN']!;
        // Ensure update dialog keys exist for all languages by falling back
        // to the Turkish value (primary) or English.
        merged.putIfAbsent(
            'update_title',
            () => _desktopDialogTranslations['TR']?['update_title'] ??
                _desktopDialogTranslations['EN']?['update_title'] ??
                'Update found');
        merged.putIfAbsent(
            'update_action',
            () => _desktopDialogTranslations['TR']?['update_action'] ??
                _desktopDialogTranslations['EN']?['update_action'] ??
                'Update');
        merged.putIfAbsent(
            'update_later',
            () => _desktopDialogTranslations['TR']?['update_later'] ??
                _desktopDialogTranslations['EN']?['update_later'] ??
                'Later');
        merged.putIfAbsent(
            'update_new_version',
            () => _desktopDialogTranslations['TR']?['update_new_version'] ??
                _desktopDialogTranslations['EN']?['update_new_version'] ??
                'New version');
        merged.putIfAbsent(
            'update_current_version',
            () => _desktopDialogTranslations['TR']?['update_current_version'] ??
                _desktopDialogTranslations['EN']?['update_current_version'] ??
                'Current version');
        merged.putIfAbsent(
            'update_downloading',
            () => _desktopDialogTranslations['TR']?['update_downloading'] ??
                _desktopDialogTranslations['EN']?['update_downloading'] ??
                'Downloading update');
        merged.putIfAbsent(
            'update_download_failed',
            () => _desktopDialogTranslations['TR']?['update_download_failed'] ??
                _desktopDialogTranslations['EN']?['update_download_failed'] ??
                'Could not download the update. Opening in browser.');
        merged.putIfAbsent(
            'update_not_found',
            () => _desktopDialogTranslations['TR']?['update_not_found'] ??
                _desktopDialogTranslations['EN']?['update_not_found'] ??
                'No update found.');
        final maintenance =
            translationsMaintenance[lang] ??
                translationsMaintenance['EN'] ??
                const {};
        merged.addAll(maintenance);
        final logUpdates =
            translationsLogUpdates[lang] ??
                translationsLogUpdates['EN'] ??
                const {};
        merged.addAll(logUpdates);
        merged.addAll(translationsPolicyChange['EN'] ?? const {});
        if (lang != 'EN') {
          merged.addAll(translationsPolicyChange[lang] ?? const {});
        }
        merged.addAll(translationsBonusPolicy['EN'] ?? const {});
        if (lang != 'EN') {
          merged.addAll(translationsBonusPolicy[lang] ?? const {});
        }
        merged.addAll(translationsTokenWallet['EN'] ?? const {});
        if (lang != 'EN') {
          merged.addAll(translationsTokenWallet[lang] ?? const {});
        }
        final view = _TranslationMapView(
            Map<String, String>.unmodifiable(merged), lang);
        _cache[lang] = view;
        return view;
    }
}
