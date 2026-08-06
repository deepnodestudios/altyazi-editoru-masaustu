import os
import glob
import re

translations = {
    "ar": {
        "delete_project_title": "حذف المشروع",
        "delete_project_confirm": "سيتم حذف هذا المشروع.",
        "delete_permanent_warning": "لا يمكن التراجع عن هذا الإجراء!"
    },
    "cn": {
        "delete_project_title": "删除项目",
        "delete_project_confirm": "此项目将被删除。",
        "delete_permanent_warning": "此操作无法撤销！"
    },
    "cs": {
        "delete_project_title": "Smazat projekt",
        "delete_project_confirm": "Tento projekt bude smazán.",
        "delete_permanent_warning": "Tuto akci nelze vrátit!"
    },
    "da": {
        "delete_project_title": "Slet projekt",
        "delete_project_confirm": "Dette projekt vil blive slettet.",
        "delete_permanent_warning": "Denne handling kan ikke fortrydes!"
    },
    "de": {
        "delete_project_title": "Projekt löschen",
        "delete_project_confirm": "Dieses Projekt wird gelöscht.",
        "delete_permanent_warning": "Dieser Vorgang kann nicht rückgängig gemacht werden!"
    },
    "el": {
        "delete_project_title": "Διαγραφή έργου",
        "delete_project_confirm": "Αυτό το έργο θα διαγραφεί.",
        "delete_permanent_warning": "Αυτή η ενέργεια δεν μπορεί να αναιρεθεί!"
    },
    "en": {
        "delete_project_title": "Delete Project",
        "delete_project_confirm": "This project will be deleted.",
        "delete_permanent_warning": "This action cannot be undone!"
    },
    "es": {
        "delete_project_title": "Eliminar proyecto",
        "delete_project_confirm": "Este proyecto será eliminado.",
        "delete_permanent_warning": "¡Esta acción no se puede deshacer!"
    },
    "fa": {
        "delete_project_title": "حذف پروژه",
        "delete_project_confirm": "این پروژه حذف خواهد شد.",
        "delete_permanent_warning": "این عمل غیرقابل بازگشت است!"
    },
    "fr": {
        "delete_project_title": "Supprimer le projet",
        "delete_project_confirm": "Ce projet sera supprimé.",
        "delete_permanent_warning": "Cette action est irréversible !"
    },
    "gu": {
        "delete_project_title": "પ્રોજેક્ટ કાઢી નાખો",
        "delete_project_confirm": "આ પ્રોજેક્ટ કાઢી નાખવામાં આવશે.",
        "delete_permanent_warning": "આ ક્રિયા પાછી ખેંચી શકાતી નથી!"
    },
    "he": {
        "delete_project_title": "מחיקת פרויקט",
        "delete_project_confirm": "פרויקט זה יימחק.",
        "delete_permanent_warning": "לא ניתן לבטל פעולה זו!"
    },
    "hu": {
        "delete_project_title": "Projekt törlése",
        "delete_project_confirm": "Ez a projekt törlésre kerül.",
        "delete_permanent_warning": "Ez a művelet nem vonható vissza!"
    },
    "id": {
        "delete_project_title": "Hapus Proyek",
        "delete_project_confirm": "Proyek ini akan dihapus.",
        "delete_permanent_warning": "Tindakan ini tidak dapat dibatalkan!"
    },
    "in": {
        "delete_project_title": "परियोजना हटाएं",
        "delete_project_confirm": "यह परियोजना हटा दी जाएगी।",
        "delete_permanent_warning": "यह क्रिया वापस नहीं ली जा सकती!"
    },
    "it": {
        "delete_project_title": "Elimina progetto",
        "delete_project_confirm": "Questo progetto verrà eliminato.",
        "delete_permanent_warning": "Questa azione non può essere annullata!"
    },
    "ja": {
        "delete_project_title": "プロジェクトを削除",
        "delete_project_confirm": "このプロジェクトは削除されます。",
        "delete_permanent_warning": "この操作は取り消せません！"
    },
    "kn": {
        "delete_project_title": "ಪ್ರಾಜೆಕ್ಟ್ ಅಳಿಸಿ",
        "delete_project_confirm": "ಈ ಪ್ರಾಜೆಕ್ಟ್ ಅಳಿಸಲಾಗುವುದು.",
        "delete_permanent_warning": "ಈ ಕ್ರಿಯೆಯನ್ನು ರದ್ದುಗೊಳಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ!"
    },
    "ko": {
        "delete_project_title": "프로젝트 삭제",
        "delete_project_confirm": "이 프로젝트는 삭제됩니다.",
        "delete_permanent_warning": "이 작업은 되돌릴 수 없습니다!"
    },
    "ml": {
        "delete_project_title": "പ്രോജക്റ്റ് ഇല്ലാതാക്കുക",
        "delete_project_confirm": "ഈ പ്രോജക്റ്റ് ഇല്ലാതാക്കപ്പെടും.",
        "delete_permanent_warning": "ഈ നടപടി പഴയപടിയാക്കാൻ കഴിയില്ല!"
    },
    "mr": {
        "delete_project_title": "प्रकल्प हटवा",
        "delete_project_confirm": "हा प्रकल्प हटवला जाईल.",
        "delete_permanent_warning": "ही कृती पुन्हा मागे घेता येणार नाही!"
    },
    "nl": {
        "delete_project_title": "Project verwijderen",
        "delete_project_confirm": "Dit project wordt verwijderd.",
        "delete_permanent_warning": "Deze actie kan niet ongedaan worden gemaakt!"
    },
    "pa": {
        "delete_project_title": "ਪ੍ਰੋਜੈਕਟ ਹਟਾਓ",
        "delete_project_confirm": "ਇਹ ਪ੍ਰੋਜੈਕਟ ਹਟਾ ਦਿੱਤਾ ਜਾਵੇਗਾ।",
        "delete_permanent_warning": "ਇਹ ਕਾਰਵਾਈ ਵਾਪਸ ਨਹੀਂ ਲਈ ਜਾ ਸਕਦੀ!"
    },
    "pl": {
        "delete_project_title": "Usuń projekt",
        "delete_project_confirm": "Ten projekt zostanie usunięty.",
        "delete_permanent_warning": "Tej operacji ne można cofnąć!"
    },
    "pt": {
        "delete_project_title": "Excluir projeto",
        "delete_project_confirm": "Este projeto será excluído.",
        "delete_permanent_warning": "Esta ação não pode ser desfeita!"
    },
    "ro": {
        "delete_project_title": "Ștergere proiect",
        "delete_project_confirm": "Acest proiect va fi șters.",
        "delete_permanent_warning": "Această acțiune nu poate fi anulată!"
    },
    "ru": {
        "delete_project_title": "Удалить проект",
        "delete_project_confirm": "Этот проект будет удален.",
        "delete_permanent_warning": "Это действие нельзя отменить!"
    },
    "sv": {
        "delete_project_title": "Ta bort projekt",
        "delete_project_confirm": "Det här projektet kommer att tas bort.",
        "delete_permanent_warning": "Denna åtgärd kan inte ångras!"
    },
    "ta": {
        "delete_project_title": "திட்டத்தை நீக்கு",
        "delete_project_confirm": "இந்த திட்டம் நீக்கப்படும்.",
        "delete_permanent_warning": "இந்தச் செயலை மாற்ற முடியாது!"
    },
    "te": {
        "delete_project_title": "ప్రాజెక్ట్‌ను తొలగించు",
        "delete_project_confirm": "ఈ ప్రాజెక్ట్ తొలగించబడుతుంది.",
        "delete_permanent_warning": "ఈ చర్యను వెనక్కి తీసుకోలేము!"
    },
    "th": {
        "delete_project_title": "ลบโปรเจกต์",
        "delete_project_confirm": "โปรเจกต์นี้จะถูกลบ",
        "delete_permanent_warning": "การดำเนินการนี้ไม่สามารถย้อนคืนได้!"
    },
    "tr": {
        "delete_project_title": "Projeyi Sil",
        "delete_project_confirm": "Bu proje silinecek.",
        "delete_permanent_warning": "Bu işlem geri alınamaz!"
    },
    "uk": {
        "delete_project_title": "Видалити проект",
        "delete_project_confirm": "Цей проект буде видалено.",
        "delete_permanent_warning": "Цю дію неможливо скасувати!"
    },
    "vi": {
        "delete_project_title": "Xóa dự án",
        "delete_project_confirm": "Dự án này sẽ bị xóa.",
        "delete_permanent_warning": "Hành động này không thể hoàn tác!"
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

        # Find the end of the Map
        match = re.search(r"};\s*$", content)
        if match:
            new_entries = ""
            for k, v in translations[lang_code].items():
                # Check if key already exists to avoid duplicates
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
        else:
            print(f"Could not find end of Map in {filename}")
