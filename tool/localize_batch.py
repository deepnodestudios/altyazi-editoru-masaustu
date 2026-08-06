import os
import re
import glob

translations = {
    "tr": {
        "batch_translation_beta": "Toplu Çeviri (Beta)",
        "batch_api_triggered": "{count} dosya için Batch API tetiklendi.",
        "batch_all_completed": "Tüm dosyaların çevirisi tamamlandı.",
        "batch_process_prefix": "Batch İşlemi",
        "batch_process_canceled": "İşlem iptal edildi.",
        "batch_file_sent": "{filename} sunucuya gönderildi. Job: {job}",
        "batch_error_prefix": "Batch Çeviri Hatası",
        "batch_file_error": "{filename} sunucuda hata ile karşılaştı.",
        "batch_credit_partial": "Krediniz ({credits}), seçilen dosya sayısından ({total}) az...",
        "batch_process_ongoing": "Devam ediyor (15sn aralıklarla kontrol ediliyor, kalan iş: {count})...",
        "batch_no_credit_log": "Kredi yetersiz. İşlemi başlatabilmek için bakiyeniz bulunmuyor.",
        "batch_starting": "Toplu Çeviri Başlatılıyor...",
        "batch_file_rate_limit": "{filename} limitlere takıldı.",
        "batch_file_success": "{filename} çevirisi başarıyla tamamlandı.",
        "insufficient_credit_batch_stop": "Kredi yetersiz. Toplu çeviri durduruldu."
    },
    "en": {
        "batch_translation_beta": "Batch Translation (Beta)",
        "batch_api_triggered": "Batch API triggered for {count} files.",
        "batch_all_completed": "All files have been successfully translated.",
        "batch_process_prefix": "Batch Process",
        "batch_process_canceled": "Process canceled.",
        "batch_file_sent": "{filename} sent to server. Job: {job}",
        "batch_error_prefix": "Batch Translation Error",
        "batch_file_error": "{filename} encountered an error on the server.",
        "batch_credit_partial": "Your credits ({credits}) are less than the selected files ({total})...",
        "batch_process_ongoing": "In progress (calculating every 15s, remaining jobs: {count})...",
        "batch_no_credit_log": "Insufficient credits. You do not have enough balance to start.",
        "batch_starting": "Starting Batch Translation...",
        "batch_file_rate_limit": "Process hit limits for {filename}.",
        "batch_file_success": "{filename} translated successfully.",
        "insufficient_credit_batch_stop": "Insufficient credits. Batch translation stopped."
    },
    "es": {
        "batch_translation_beta": "Traducción por lotes (Beta)",
        "batch_api_triggered": "API por lotes ejecutada para {count} archivos.",
        "batch_all_completed": "Todos los archivos han sido traducidos con éxito.",
        "batch_process_prefix": "Proceso por lotes",
        "batch_process_canceled": "Proceso cancelado.",
        "batch_file_sent": "{filename} enviado al servidor. Trabajo: {job}",
        "batch_error_prefix": "Error de traducción por lotes",
        "batch_file_error": "{filename} encontró un error en el servidor.",
        "batch_credit_partial": "Tus créditos ({credits}) son menores que los archivos seleccionados ({total})...",
        "batch_process_ongoing": "En progreso (revisando cada 15s, trabajos restantes: {count})...",
        "batch_no_credit_log": "Créditos insuficientes. No tienes saldo suficiente para comenzar.",
        "batch_starting": "Iniciando traducción por lotes...",
        "batch_file_rate_limit": "El proceso alcanzó los límites para {filename}.",
        "batch_file_success": "{filename} traducido con éxito.",
        "insufficient_credit_batch_stop": "Créditos insuficientes. Traducción por lotes detenida."
    },
    "de": {
        "batch_translation_beta": "Stapelübersetzung (Beta)",
        "batch_api_triggered": "Stapel-API für {count} Dateien ausgelöst.",
        "batch_all_completed": "Alle Dateien wurden erfolgreich übersetzt.",
        "batch_process_prefix": "Stapelverarbeitung",
        "batch_process_canceled": "Prozess abgebrochen.",
        "batch_file_sent": "{filename} an den Server gesendet. Job: {job}",
        "batch_error_prefix": "Fehler bei Stapelübersetzung",
        "batch_file_error": "{filename} ist auf dem Server auf einen Fehler gestoßen.",
        "batch_credit_partial": "Ihre Credits ({credits}) sind weniger als die ausgewählten Dateien ({total})...",
        "batch_process_ongoing": "In Bearbeitung (Prüfung alle 15s, verbleibende Jobs: {count})...",
        "batch_no_credit_log": "Unzureichendes Guthaben. Sie haben nicht genug Guthaben, um zu starten.",
        "batch_starting": "Stapelübersetzung wird gestartet...",
        "batch_file_rate_limit": "Prozess hat Limits für {filename} erreicht.",
        "batch_file_success": "{filename} erfolgreich übersetzt.",
        "insufficient_credit_batch_stop": "Unzureichendes Guthaben. Stapelübersetzung gestoppt."
    },
    "fr": {
        "batch_translation_beta": "Traduction par lots (Bêta)",
        "batch_api_triggered": "API par lots déclenchée pour {count} fichiers.",
        "batch_all_completed": "Tous les fichiers ont été traduits avec succès.",
        "batch_process_prefix": "Processus par lots",
        "batch_process_canceled": "Processus annulé.",
        "batch_file_sent": "{filename} envoyé au serveur. Tâche : {job}",
        "batch_error_prefix": "Erreur de traduction par lots",
        "batch_file_error": "{filename} a rencontré une erreur sur le serveur.",
        "batch_credit_partial": "Vos crédits ({credits}) sont inférieurs aux fichiers sélectionnés ({total})...",
        "batch_process_ongoing": "En cours (vérification toutes les 15s, tâches restantes : {count})...",
        "batch_no_credit_log": "Crédits insuffisants. Vous n'avez pas assez de solde pour démarrer.",
        "batch_starting": "Démarrage de la traduction par lots...",
        "batch_file_rate_limit": "Le processus a atteint les limites pour {filename}.",
        "batch_file_success": "{filename} traduit avec succès.",
        "insufficient_credit_batch_stop": "Crédits insuffisants. Traduction par lots arrêtée."
    },
    "it": {
        "batch_translation_beta": "Traduzione in blocco (Beta)",
        "batch_api_triggered": "API in blocco attivata per {count} file.",
        "batch_all_completed": "Tutti i file sono stati tradotti con successo.",
        "batch_process_prefix": "Processo in blocco",
        "batch_process_canceled": "Processo annullato.",
        "batch_file_sent": "{filename} inviato al server. Lavoro: {job}",
        "batch_error_prefix": "Errore di traduzione in blocco",
        "batch_file_error": "{filename} ha riscontrato un errore sul server.",
        "batch_credit_partial": "I tuoi crediti ({credits}) sono inferiori ai file selezionati ({total})...",
        "batch_process_ongoing": "In corso (controllo ogni 15s, lavori rimanenti: {count})...",
        "batch_no_credit_log": "Crediti insufficienti. Non hai saldo sufficiente per iniziare.",
        "batch_starting": "Avvio della traduzione in blocco...",
        "batch_file_rate_limit": "Il processo ha raggiunto i limiti per {filename}.",
        "batch_file_success": "{filename} tradotto con successo.",
        "insufficient_credit_batch_stop": "Crediti insufficienti. Traduzione in blocco interrotta."
    },
    "pt": {
        "batch_translation_beta": "Tradução em Lote (Beta)",
        "batch_api_triggered": "API em lote acionada para {count} arquivos.",
        "batch_all_completed": "Todos os arquivos foram traduzidos com sucesso.",
        "batch_process_prefix": "Processo em Lote",
        "batch_process_canceled": "Processo cancelado.",
        "batch_file_sent": "{filename} enviado ao servidor. Job: {job}",
        "batch_error_prefix": "Erro de Tradução em Lote",
        "batch_file_error": "{filename} encontrou um erro no servidor.",
        "batch_credit_partial": "Seus créditos ({credits}) são menores que os arquivos selecionados ({total})...",
        "batch_process_ongoing": "Em andamento (verificando a cada 15s, trabalhos restantes: {count})...",
        "batch_no_credit_log": "Créditos insuficientes. Você não tem saldo para iniciar.",
        "batch_starting": "Iniciando a tradução em lote...",
        "batch_file_rate_limit": "O processo atingiu os limites para {filename}.",
        "batch_file_success": "{filename} traduzido com sucesso.",
        "insufficient_credit_batch_stop": "Créditos insuficientes. Tradução em lote interrompida."
    },
    "ru": {
        "batch_translation_beta": "Пакетный перевод (Бета)",
        "batch_api_triggered": "Пакетный API запущен для {count} файлов.",
        "batch_all_completed": "Все файлы были успешно переведены.",
        "batch_process_prefix": "Пакетная обработка",
        "batch_process_canceled": "Процесс отменен.",
        "batch_file_sent": "{filename} отправлен на сервер. Задача: {job}",
        "batch_error_prefix": "Ошибка пакетного перевода",
        "batch_file_error": "{filename} столкнулся с ошибкой на сервере.",
        "batch_credit_partial": "Ваших кредитов ({credits}) меньше, чем выбранных файлов ({total})...",
        "batch_process_ongoing": "В процессе (проверка каждые 15 сек, осталось задач: {count})...",
        "batch_no_credit_log": "Недостаточно кредитов. У вас нет баланса для начала.",
        "batch_starting": "Запуск пакетного перевода...",
        "batch_file_rate_limit": "Процесс достиг лимитов для {filename}.",
        "batch_file_success": "{filename} успешно переведен.",
        "insufficient_credit_batch_stop": "Недостаточно кредитов. Пакетный перевод остановлен."
    },
    "zh": {
        "batch_translation_beta": "批量翻译 (测试版)",
        "batch_api_triggered": "已为 {count} 个文件触发批量 API。",
        "batch_all_completed": "所有文件均已成功翻译。",
        "batch_process_prefix": "批量处理",
        "batch_process_canceled": "处理已取消。",
        "batch_file_sent": "{filename} 已发送到服务器。任务: {job}",
        "batch_error_prefix": "批量翻译错误",
        "batch_file_error": "{filename} 在服务器上遇到错误。",
        "batch_credit_partial": "您的积分 ({credits}) 少于选择的文件数 ({total})...",
        "batch_process_ongoing": "进行中 (每 15 秒检查一次，剩余任务: {count})...",
        "batch_no_credit_log": "积分不足。您没有足够的余额来开始。",
        "batch_starting": "正在启动批量翻译...",
        "batch_file_rate_limit": "{filename} 达到了限制。",
        "batch_file_success": "{filename} 翻译成功。",
        "insufficient_credit_batch_stop": "积分不足。批量翻译已停止。"
    },
    "ja": {
        "batch_translation_beta": "一括翻訳 (ベータ版)",
        "batch_api_triggered": "{count} ファイルの一括 API がトリガーされました。",
        "batch_all_completed": "すべてのファイルが正常に翻訳されました。",
        "batch_process_prefix": "一括処理",
        "batch_process_canceled": "プロセスがキャンセルされました。",
        "batch_file_sent": "{filename} がサーバーに送信されました。ジョブ: {job}",
        "batch_error_prefix": "一括翻訳エラー",
        "batch_file_error": "{filename} でサーバーエラーが発生しました。",
        "batch_credit_partial": "クレジット ({credits}) が選択されたファイル数 ({total}) より少ないです...",
        "batch_process_ongoing": "進行中 (15秒ごとに確認、残りのジョブ: {count})...",
        "batch_no_credit_log": "クレジットが不足しています。プロセスを開始するための残高がありません。",
        "batch_starting": "一括翻訳を開始しています...",
        "batch_file_rate_limit": "{filename} の制限に達しました。",
        "batch_file_success": "{filename} の翻訳が完了しました。",
        "insufficient_credit_batch_stop": "クレジット不足。一括翻訳が停止しました。"
    },
    "ko": {
        "batch_translation_beta": "일괄 번역 (베타)",
        "batch_api_triggered": "{count}개 파일에 대한 일괄 API가 트리거되었습니다.",
        "batch_all_completed": "모든 파일이 성공적으로 번역되었습니다.",
        "batch_process_prefix": "일괄 처리",
        "batch_process_canceled": "과정이 취소되었습니다.",
        "batch_file_sent": "{filename}이(가) 서버로 전송되었습니다. 작업: {job}",
        "batch_error_prefix": "일괄 번역 오류",
        "batch_file_error": "서버에서 {filename}에 오류가 발생했습니다.",
        "batch_credit_partial": "크레딧({credits})이 선택한 파일 수({total})보다 적습니다...",
        "batch_process_ongoing": "진행 중 (15초마다 확인, 남은 작업: {count})...",
        "batch_no_credit_log": "크레딧이 부족합니다. 시작할 잔액이 부족합니다.",
        "batch_starting": "일괄 번역 시작 중...",
        "batch_file_rate_limit": "{filename}에 대한 제한에 도달했습니다.",
        "batch_file_success": "{filename}이(가) 성공적으로 번역되었습니다.",
        "insufficient_credit_batch_stop": "크레딧 부족. 일괄 번역이 중지되었습니다."
    },
    "ar": {
        "batch_translation_beta": "ترجمة مجمعة (تجريبي)",
        "batch_api_triggered": "تم تشغيل واجهة برمجة التطبيقات المجمعة لـ {count} ملفات.",
        "batch_all_completed": "تمت ترجمة جميع الملفات بنجاح.",
        "batch_process_prefix": "عملية مجمعة",
        "batch_process_canceled": "تم إلغاء العملية.",
        "batch_file_sent": "تم إرسال {filename} إلى الخادم. المهمة: {job}",
        "batch_error_prefix": "خطأ في الترجمة المجمعة",
        "batch_file_error": "واجه {filename} خطأ على الخادم.",
        "batch_credit_partial": "أرصدتك ({credits}) أقل من الملفات المحددة ({total})...",
        "batch_process_ongoing": "قيد التقدم (جارٍ التحقق كل 15 ثانية، المهام المتبقية: {count})...",
        "batch_no_credit_log": "رصيد غير كافٍ. ليس لديك رصيد كاف للبدء.",
        "batch_starting": "بدء الترجمة المجمعة...",
        "batch_file_rate_limit": "العملية وصلت للحدود لـ {filename}.",
        "batch_file_success": "تمت ترجمة {filename} بنجاح.",
        "insufficient_credit_batch_stop": "أرصدة غير كافية. تم إيقاف الترجمة المجمعة."
    }
}

def get_trans(lang_code, key):
    lang_map = {'cn': 'zh', 'in': 'id'}
    req_lang = lang_map.get(lang_code, lang_code)
    if req_lang in translations:
        return translations[req_lang][key]
    return translations['en'][key]

import glob

trans_dir = r"c:\Users\mehme\Desktop\altyazi_editoru_Masaustu\lib\translations"
files = glob.glob(os.path.join(trans_dir, "translations_*.dart"))

keys_to_add = [
    "batch_translation_beta", "batch_api_triggered", "batch_all_completed", 
    "batch_process_prefix", "batch_process_canceled", "batch_file_sent",
    "batch_error_prefix", "batch_file_error", "batch_credit_partial", 
    "batch_process_ongoing", "batch_no_credit_log", "batch_starting", 
    "batch_file_rate_limit", "batch_file_success", "insufficient_credit_batch_stop"
]

for file_path in files:
    filename = os.path.basename(file_path)
    lang_code = filename.replace("translations_", "").replace(".dart", "")
    
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "'batch_translation_beta'" in content:
        print(f"Skipping {lang_code}, already exists.")
        continue

    end_idx = content.rfind('};')
    if end_idx == -1:
        print(f"Could not find closing bracket in {file_path}")
        continue
    
    new_keys_str = ""
    for k in keys_to_add:
        val = get_trans(lang_code, k)
        val_esc = val.replace("'", "\\'")
        new_keys_str += f"  '{k}': '{val_esc}',\n"
        
    updated_content = content[:end_idx] + new_keys_str + content[end_idx:]
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(updated_content)

print(f"Batch translation keys injected into {len(files)} files!")
