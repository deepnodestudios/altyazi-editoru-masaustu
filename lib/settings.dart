import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'credit_history_page.dart';
import 'app_settings.dart';
import 'managers/theme_manager.dart';
import 'widgets/adaptive_text.dart';
import 'widgets/cloud_provider_logo.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.showLabel = false});

  final bool showLabel;
  static const double _sideRailIconSize = 24;
  static const double _sideRailLabelSize = 12;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final label = theme.trans["settings_title"] ?? "Ayarlar";
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;

    final childWidget = showLabel
        ? InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showSettingsSheet(context),
            child: SizedBox(
              width: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings,
                      size: _sideRailIconSize,
                      color: primary,
                    ),
                    const SizedBox(height: 4),
                    AdaptiveText(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      minFontSize: 8,
                      style: TextStyle(
                        fontSize: _sideRailLabelSize,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : IconButton.filledTonal(
            tooltip: label,
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context),
          );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 2 * 3.14159, // Açılışta bir tam tur döner
          child: child,
        );
      },
      child: childWidget,
    );
  }
}

class FeaturesButton extends StatelessWidget {
  const FeaturesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final trans = context.watch<ThemeManager>().trans;
    final label = trans['features_title'] ?? 'Features';
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFeaturesSheet(context),
      child: SizedBox(
        width: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: SettingsButton._sideRailIconSize,
                color: primary,
              ),
              const SizedBox(height: 4),
              AdaptiveText(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                minFontSize: 8,
                style: TextStyle(
                  fontSize: SettingsButton._sideRailLabelSize,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showSettingsSheet(BuildContext context) {
  final trans = context.read<ThemeManager>().trans;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            bottomLeft: Radius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            width: 400, // Masaüstü için ideal genişlik
            height: double.infinity,
            child: Column(
              children: [
                // Üst kısım: Kapatma butonu
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: trans["close"] ?? "Kapat",
                    ),
                  ),
                ),
                // İçerik
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _SettingsContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      );
    },
  );
}

void _showFeaturesSheet(BuildContext context) {
  final settings = context.read<AppSettings>();
  final trans = settings.trans;
  final screenWidth = MediaQuery.of(context).size.width;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            bottomLeft: Radius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            width: screenWidth * 0.5,
            height: double.infinity,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: trans["close"] ?? "Kapat",
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: _FeaturesContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      );
    },
  );
}

class _FeaturesContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trans = context.watch<ThemeManager>().trans;
    final colorScheme = Theme.of(context).colorScheme;

    final features = <({String title, String desc, IconData icon})>[
      (
        title: trans['feature_ai_title'] ?? 'AI-Powered Translation',
        desc: trans['feature_ai_desc'] ??
            'Translate your subtitles with AI while preserving context. Get natural and fluent translations that consider movie plot, character names, and dialogue flow.',
        icon: Icons.auto_awesome,
      ),
      (
        title: trans['feature_editor_title'] ?? 'Advanced Subtitle Editor',
        desc: trans['feature_editor_desc'] ??
            'Edit timecodes, use Regex-powered find and replace, apply sync shifting. Line-by-line editing, case conversion, and much more.',
        icon: Icons.edit_note,
      ),
      (
        title: trans['feature_history_title'] ?? 'Translation History & Resume',
        desc: trans['feature_history_desc'] ??
            'All your translations are automatically saved. Resume incomplete translations from where you left off, or export completed ones.',
        icon: Icons.history,
      ),
      (
        title: trans['feature_sdh_title'] ?? 'SDH Tag Cleaning',
        desc: trans['feature_sdh_desc'] ??
            'Automatically cleans hearing-impaired subtitle tags. Preserves dialogue and song lyrics.',
        icon: Icons.cleaning_services,
      ),
      (
        title: trans['feature_sync_title'] ?? 'Cross-Platform Sync',
        desc: trans['feature_sync_desc'] ??
            'Your translations sync automatically between Android and Windows. Start a translation on one device and continue on another.',
        icon: Icons.sync,
      ),
      (
        title: trans['feature_credit_title'] ?? 'Credit System & History',
        desc: trans['feature_credit_desc'] ??
            'Track all your credit usage and purchases in detail. See when and for which file each credit was used.',
        icon: Icons.account_balance_wallet,
      ),
      (
        title: trans['feature_batch_title'] ?? 'Batch Translation',
        desc: trans['feature_batch_desc'] ??
            'Queue multiple subtitle files and translate them all at once. Save results individually or as a ZIP archive.',
        icon: Icons.queue,
      ),
      (
        title: trans['feature_cloud_title'] ?? 'Cloud Storage Integration',
        desc: trans['feature_cloud_desc'] ??
            'Connect with Google Drive, Dropbox, and Yandex Disk. Open files from the cloud and save translations back.',
        icon: Icons.cloud,
      ),
      (
        title: trans['feature_languages_title'] ?? '35+ Interface Languages',
        desc: trans['feature_languages_desc'] ??
            'The app interface is available in over 35 languages. The number of supported target languages for subtitle translation is even greater.',
        icon: Icons.language,
      ),
      (
        title: trans['feature_theme_title'] ?? 'Dark & Light Theme',
        desc: trans['feature_theme_desc'] ??
            'Switch between dark and light themes to reduce eye strain. Your theme preference is automatically remembered.',
        icon: Icons.dark_mode,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trans['features_title'] ?? 'Features',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: features.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = features[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(64),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(item.icon, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.desc,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = context.watch<ThemeManager>();
    final trans = theme.trans;
    final bool isDark = settings.themeMode == ThemeMode.dark;
    final bool isDesktop = settings.isDesktopPlatform;
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    String desktopText(String key) {
      const labels = {
      'EN': {
        'desktop_settings': 'Desktop Settings',
        'desktop_minimize_to_tray': 'Minimize to system tray',
        'desktop_minimize_to_tray_desc':
          'Hide window to tray instead of closing',
        'desktop_always_on_top': 'Always on top',
        'desktop_always_on_top_desc':
          'Keep this window above other windows',
      },
      'TR': {
        'desktop_settings': 'Masaüstü Ayarları',
        'desktop_minimize_to_tray': 'Sistem tepsisine küçült',
        'desktop_minimize_to_tray_desc':
          'Kapatmak yerine pencereyi tepsiye gizle',
        'desktop_always_on_top': 'Her zaman üstte',
        'desktop_always_on_top_desc':
          'Bu pencereyi diğerlerinin üstünde tut',
      },
      'FR': {
        'desktop_settings': 'Paramètres Bureau',
        'desktop_minimize_to_tray':
          'Réduire dans la zone de notification',
        'desktop_minimize_to_tray_desc':
          'Masquer la fenêtre dans la barre système au lieu de la fermer',
        'desktop_always_on_top': 'Toujours au premier plan',
        'desktop_always_on_top_desc':
          'Garder cette fenêtre au-dessus des autres',
      },
      'DE': {
        'desktop_settings': 'Desktop-Einstellungen',
        'desktop_minimize_to_tray': 'In den System-Tray minimieren',
        'desktop_minimize_to_tray_desc':
          'Fenster in den Tray ausblenden statt zu schließen',
        'desktop_always_on_top': 'Immer im Vordergrund',
        'desktop_always_on_top_desc':
          'Dieses Fenster über anderen Fenstern halten',
      },
      'IT': {
        'desktop_settings': 'Impostazioni desktop',
        'desktop_minimize_to_tray': 'Riduci nell\'area di notifica',
        'desktop_minimize_to_tray_desc':
          'Nascondi la finestra nel tray invece di chiuderla',
        'desktop_always_on_top': 'Sempre in primo piano',
        'desktop_always_on_top_desc':
          'Mantieni questa finestra sopra le altre',
      },
      'ES': {
        'desktop_settings': 'Ajustes de escritorio',
        'desktop_minimize_to_tray': 'Minimizar a la bandeja del sistema',
        'desktop_minimize_to_tray_desc':
          'Ocultar la ventana en la bandeja en lugar de cerrarla',
        'desktop_always_on_top': 'Siempre visible',
        'desktop_always_on_top_desc':
          'Mantener esta ventana sobre las demás',
      },
      'PT': {
        'desktop_settings': 'Definições de desktop',
        'desktop_minimize_to_tray':
          'Minimizar para a bandeja do sistema',
        'desktop_minimize_to_tray_desc':
          'Ocultar a janela na bandeja em vez de fechar',
        'desktop_always_on_top': 'Sempre no topo',
        'desktop_always_on_top_desc':
          'Manter esta janela acima das outras',
      },
      'RU': {
        'desktop_settings': 'Настройки рабочего стола',
        'desktop_minimize_to_tray': 'Сворачивать в системный трей',
        'desktop_minimize_to_tray_desc':
          'Скрывать окно в трее вместо закрытия',
        'desktop_always_on_top': 'Поверх всех окон',
        'desktop_always_on_top_desc':
          'Держать это окно поверх других',
      },
      'EL': {
        'desktop_settings': 'Ρυθμίσεις επιφάνειας εργασίας',
        'desktop_minimize_to_tray':
          'Ελαχιστοποίηση στο system tray',
        'desktop_minimize_to_tray_desc':
          'Απόκρυψη παραθύρου στο tray αντί για κλείσιμο',
        'desktop_always_on_top': 'Πάντα στην κορυφή',
        'desktop_always_on_top_desc':
          'Διατήρηση αυτού του παραθύρου πάνω από τα άλλα',
      },
      'AR': {
        'desktop_settings': 'إعدادات سطح المكتب',
        'desktop_minimize_to_tray': 'تصغير إلى علبة النظام',
        'desktop_minimize_to_tray_desc':
          'إخفاء النافذة في العلبة بدلًا من إغلاقها',
        'desktop_always_on_top': 'دائمًا في الأعلى',
        'desktop_always_on_top_desc':
          'إبقاء هذه النافذة فوق النوافذ الأخرى',
      },
      'IN': {
        'desktop_settings': 'डेस्कटॉप सेटिंग्स',
        'desktop_minimize_to_tray': 'सिस्टम ट्रे में मिनिमाइज़ करें',
        'desktop_minimize_to_tray_desc':
          'बंद करने के बजाय विंडो को ट्रे में छिपाएँ',
        'desktop_always_on_top': 'हमेशा सबसे ऊपर',
        'desktop_always_on_top_desc':
          'इस विंडो को अन्य विंडो के ऊपर रखें',
      },
      'ID': {
        'desktop_settings': 'Pengaturan desktop',
        'desktop_minimize_to_tray': 'Minimalkan ke baki sistem',
        'desktop_minimize_to_tray_desc':
          'Sembunyikan jendela ke baki alih-alih menutup',
        'desktop_always_on_top': 'Selalu di atas',
        'desktop_always_on_top_desc':
          'Pertahankan jendela ini di atas jendela lain',
      },
      'CN': {
        'desktop_settings': '桌面设置',
        'desktop_minimize_to_tray': '最小化到系统托盘',
        'desktop_minimize_to_tray_desc':
          '关闭时将窗口隐藏到托盘而不是退出',
        'desktop_always_on_top': '始终置顶',
        'desktop_always_on_top_desc': '让此窗口保持在其他窗口之上',
      },
      'JA': {
        'desktop_settings': 'デスクトップ設定',
        'desktop_minimize_to_tray': 'システムトレイに最小化',
        'desktop_minimize_to_tray_desc':
          '閉じる代わりにウィンドウをトレイに隠します',
        'desktop_always_on_top': '常に最前面',
        'desktop_always_on_top_desc':
          'このウィンドウを他のウィンドウより前面に保つ',
      },
      'KO': {
        'desktop_settings': '데스크톱 설정',
        'desktop_minimize_to_tray': '시스템 트레이로 최소화',
        'desktop_minimize_to_tray_desc':
          '닫는 대신 창을 트레이로 숨깁니다',
        'desktop_always_on_top': '항상 위',
        'desktop_always_on_top_desc':
          '이 창을 다른 창 위에 유지',
      },
      'NL': {
        'desktop_settings': 'Bureaubladinstellingen',
        'desktop_minimize_to_tray': 'Minimaliseren naar systeemvak',
        'desktop_minimize_to_tray_desc':
          'Verberg het venster in het systeemvak in plaats van sluiten',
        'desktop_always_on_top': 'Altijd bovenaan',
        'desktop_always_on_top_desc':
          'Houd dit venster boven andere vensters',
      },
      'SV': {
        'desktop_settings': 'Skrivbordsinställningar',
        'desktop_minimize_to_tray': 'Minimera till systemfältet',
        'desktop_minimize_to_tray_desc':
          'Dölj fönstret i systemfältet istället för att stänga',
        'desktop_always_on_top': 'Alltid överst',
        'desktop_always_on_top_desc':
          'Håll detta fönster ovanför andra fönster',
      },
      'PL': {
        'desktop_settings': 'Ustawienia pulpitu',
        'desktop_minimize_to_tray': 'Minimalizuj do zasobnika systemowego',
        'desktop_minimize_to_tray_desc':
          'Ukryj okno w zasobniku zamiast zamykać',
        'desktop_always_on_top': 'Zawsze na wierzchu',
        'desktop_always_on_top_desc':
          'Utrzymuj to okno nad innymi oknami',
      },
      'TH': {
        'desktop_settings': 'การตั้งค่าเดสก์ท็อป',
        'desktop_minimize_to_tray': 'ย่อไปยังถาดระบบ',
        'desktop_minimize_to_tray_desc':
          'ซ่อนหน้าต่างไว้ที่ถาดแทนการปิด',
        'desktop_always_on_top': 'อยู่ด้านบนเสมอ',
        'desktop_always_on_top_desc':
          'ให้หน้าต่างนี้อยู่เหนือหน้าต่างอื่น',
      },
      'VI': {
        'desktop_settings': 'Cài đặt máy tính',
        'desktop_minimize_to_tray': 'Thu nhỏ vào khay hệ thống',
        'desktop_minimize_to_tray_desc':
          'Ẩn cửa sổ vào khay thay vì đóng',
        'desktop_always_on_top': 'Luôn ở trên cùng',
        'desktop_always_on_top_desc':
          'Giữ cửa sổ này nằm trên các cửa sổ khác',
      },
      'HE': {
        'desktop_settings': 'הגדרות שולחן עבודה',
        'desktop_minimize_to_tray': 'מזער למגש המערכת',
        'desktop_minimize_to_tray_desc':
          'הסתר את החלון במגש במקום לסגור',
        'desktop_always_on_top': 'תמיד למעלה',
        'desktop_always_on_top_desc':
          'השאר חלון זה מעל חלונות אחרים',
      },
      'FA': {
        'desktop_settings': 'تنظیمات دسکتاپ',
        'desktop_minimize_to_tray': 'کوچک‌سازی به سینی سیستم',
        'desktop_minimize_to_tray_desc':
          'پنجره را به‌جای بستن در سینی مخفی کن',
        'desktop_always_on_top': 'همیشه روی همه',
        'desktop_always_on_top_desc':
          'این پنجره را بالای پنجره‌های دیگر نگه‌دار',
      },
      'TA': {
        'desktop_settings': 'டெஸ்க்டாப் அமைப்புகள்',
        'desktop_minimize_to_tray': 'சிஸ்டம் ட்ரேயிற்கு சிறிதாக்கு',
        'desktop_minimize_to_tray_desc':
          'மூடுவதற்கு பதிலாக சாளரத்தை ட்ரேவில் மறை',
        'desktop_always_on_top': 'எப்போதும் மேலே',
        'desktop_always_on_top_desc':
          'இந்த சாளரத்தை பிற சாளரங்களின் மேல் வைத்திரு',
      },
      'TE': {
        'desktop_settings': 'డెస్క్‌టాప్ సెట్టింగ్‌లు',
        'desktop_minimize_to_tray': 'సిస్టమ్ ట్రేకు చిన్నదిగా చేయి',
        'desktop_minimize_to_tray_desc':
          'మూసేయడం బదులు విండోను ట్రేలో దాచు',
        'desktop_always_on_top': 'ఎల్లప్పుడూ పైభాగంలో',
        'desktop_always_on_top_desc':
          'ఈ విండోను ఇతర విండోల కంటే పైగా ఉంచు',
      },
      'ML': {
        'desktop_settings': 'ഡെസ്ക്ടോപ്പ് ക്രമീകരണങ്ങൾ',
        'desktop_minimize_to_tray': 'സിസ്റ്റം ട്രേയിലേക്ക് മിനിമൈസ് ചെയ്യുക',
        'desktop_minimize_to_tray_desc':
          'അടയ്ക്കുന്നതിനുപകരം ജാലകം ട്രേയിൽ മറയ്ക്കുക',
        'desktop_always_on_top': 'എപ്പോഴും മുകളിൽ',
        'desktop_always_on_top_desc':
          'ഈ ജാലകം മറ്റ് ജാലകങ്ങൾക്കു മുകളിൽ സൂക്ഷിക്കുക',
      },
      'KN': {
        'desktop_settings': 'ಡೆಸ್ಕ್‌ಟಾಪ್ ಸೆಟ್ಟಿಂಗ್ಗಳು',
        'desktop_minimize_to_tray': 'ಸಿಸ್ಟಮ್ ಟ್ರೇಗೆ ಕುಗ್ಗಿಸಿ',
        'desktop_minimize_to_tray_desc':
          'ಮುಚ್ಚುವ ಬದಲು ವಿಂಡೋವನ್ನು ಟ್ರೇನಲ್ಲಿ ಅಡಗಿಸಿ',
        'desktop_always_on_top': 'ಯಾವಾಗಲೂ ಮೇಲ್ಭಾಗದಲ್ಲಿ',
        'desktop_always_on_top_desc':
          'ಈ ವಿಂಡೋವನ್ನು ಇತರ ವಿಂಡೋಗಳ ಮೇಲಿಡಿ',
      },
      'PA': {
        'desktop_settings': 'ਡੈਸਕਟਾਪ ਸੈਟਿੰਗਾਂ',
        'desktop_minimize_to_tray': 'ਸਿਸਟਮ ਟਰੇ ਵਿੱਚ ਮਿਨਿਮਾਈਜ਼ ਕਰੋ',
        'desktop_minimize_to_tray_desc':
          'ਬੰਦ ਕਰਨ ਦੀ ਬਜਾਏ ਵਿੰਡੋ ਨੂੰ ਟਰੇ ਵਿੱਚ ਲੁਕਾਓ',
        'desktop_always_on_top': 'ਹਮੇਸ਼ਾਂ ਉੱਪਰ',
        'desktop_always_on_top_desc':
          'ਇਸ ਵਿੰਡੋ ਨੂੰ ਹੋਰ ਵਿੰਡੋਜ਼ ਤੋਂ ਉੱਪਰ ਰੱਖੋ',
      },
      'GU': {
        'desktop_settings': 'ડેસ્કટોપ સેટિંગ્સ',
        'desktop_minimize_to_tray': 'સિસ્ટમ ટ્રેમાં મિનિમાઇઝ કરો',
        'desktop_minimize_to_tray_desc':
          'બંધ કરવાની બદલે વિન્ડોને ટ્રેમાં છુપાવો',
        'desktop_always_on_top': 'હંમેશા ઉપર',
        'desktop_always_on_top_desc':
          'આ વિન્ડોને અન્ય વિન્ડોઝ ઉપર રાખો',
      },
      'MR': {
        'desktop_settings': 'डेस्कटॉप सेटिंग्ज',
        'desktop_minimize_to_tray': 'सिस्टम ट्रेमध्ये मिनिमाइझ करा',
        'desktop_minimize_to_tray_desc':
          'बंद करण्याऐवजी विंडो ट्रेमध्ये लपवा',
        'desktop_always_on_top': 'नेहमी वर',
        'desktop_always_on_top_desc':
          'ही विंडो इतर विंडोंच्या वर ठेवा',
      },
      };

      final map = labels[settings.language] ?? labels['EN']!;
      return map[key] ?? labels['EN']![key] ?? key;
    }

    Widget buildSectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    Widget buildCard(List<Widget> children) {
      return Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withAlpha(77),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                trans["settings_title"] ?? "Ayarlar",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Account Section
          buildSectionHeader(trans["account_title"] ?? "Hesap"),
          buildCard([
            if (settings.isGoogleSignedIn && user != null)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child:
                      user.photoURL == null ? const Icon(Icons.person) : null,
                ),
                title: AdaptiveText(
                  user.displayName ?? 'Kullanıcı',
                  maxLines: 1,
                ),
                subtitle: AdaptiveText(
                  user.email ?? '',
                  maxLines: 1,
                  minFontSize: 10,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => settings.signOutGoogle(),
                  tooltip: trans["btn_logout"] ?? "Çıkış Yap",
                ),
              )
            else
              ListTile(
                leading: const Icon(FontAwesomeIcons.google),
                title: AdaptiveText(
                  trans["btn_google_signin"] ?? "Google ile Giriş Yap",
                  maxLines: 1,
                ),
                onTap: settings.isAuthLoading
                    ? null
                    : () async {
                        await settings.signInWithGoogle();
                      },
                trailing: settings.isProviderLoading('google_sign_in')
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: AdaptiveText(
                trans['credit_history_title'] ?? 'Kredi Geçmişi',
                maxLines: 1,
                minFontSize: 12,
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: user == null
                  ? null
                  : () {
                      final nav = Navigator.of(context, rootNavigator: true);
                      Navigator.of(context).pop();
                      Future.microtask(() {
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => const CreditHistoryPage(),
                          ),
                        );
                      });
                    },
            ),
          ]),

          // General + Additional Settings
          buildSectionHeader(trans["settings"] ?? "Ayarlar"),
          buildCard([
            ListTile(
              leading: const Icon(Icons.language),
              title: AdaptiveText(
                trans["language_title"] ?? "Dil",
                maxLines: 1,
                minFontSize: 12,
              ),
              trailing: DropdownButton<String>(
                value: settings.language,
                underline: const SizedBox(),
                onChanged: (val) {
                  if (val == null) return;
                  settings.changeLanguage(val);
                },
                items: () {
                  const languageNames = <String, String>{
                    'TR': 'Türkçe',
                    'EN': 'English',
                    'FR': 'Français',
                    'DE': 'Deutsch',
                    'IT': 'Italiano',
                    'ES': 'Español',
                    'RU': 'Русский',
                    'EL': 'Ελληνικά',
                    'PT': 'Português',
                    'AR': 'العربية',
                    'IN': 'हिन्दी',
                    'ID': 'Bahasa Indonesia',
                    'CN': '中文',
                    'CS': 'Čeština',
                    'DA': 'Dansk',
                    'JA': '日本語',
                    'KO': '한국어',
                    'NL': 'Nederlands',
                    'SV': 'Svenska',
                    'PL': 'Polski',
                    'TH': 'ไทย',
                    'VI': 'Tiếng Việt',
                    'HE': 'עברית',
                    'HU': 'Magyar',
                    'FA': 'فارسی',
                    'TA': 'தமிழ்',
                    'TE': 'తెలుగు',
                    'ML': 'മലയാളം',
                    'KN': 'ಕನ್ನಡ',
                    'PA': 'ਪੰਜਾਬੀ',
                    'GU': 'ગુજરાતી',
                    'MR': 'मराठी',
                    'RO': 'Română',
                    'UK': 'Українська',
                  };

                  const latinCodes = <String>{
                    'TR',
                    'EN',
                    'FR',
                    'DE',
                    'IT',
                    'ES',
                    'PT',
                    'CS',
                    'DA',
                    'HU',
                    'RO',
                    'ID',
                    'NL',
                    'SV',
                    'PL',
                  };

                  String latinSortKey(String input) {
                    return input
                        .toLowerCase()
                        .replaceAll('ç', 'c')
                        .replaceAll('ğ', 'g')
                        .replaceAll('ı', 'i')
                        .replaceAll('ö', 'o')
                        .replaceAll('ş', 's')
                        .replaceAll('ü', 'u')
                        .replaceAll('á', 'a')
                        .replaceAll('à', 'a')
                        .replaceAll('â', 'a')
                        .replaceAll('ã', 'a')
                        .replaceAll('ä', 'a')
                        .replaceAll('å', 'a')
                        .replaceAll('é', 'e')
                        .replaceAll('è', 'e')
                        .replaceAll('ê', 'e')
                        .replaceAll('ë', 'e')
                        .replaceAll('í', 'i')
                        .replaceAll('ì', 'i')
                        .replaceAll('î', 'i')
                        .replaceAll('ï', 'i')
                        .replaceAll('ó', 'o')
                        .replaceAll('ò', 'o')
                        .replaceAll('ô', 'o')
                        .replaceAll('õ', 'o')
                        .replaceAll('ú', 'u')
                        .replaceAll('ù', 'u')
                        .replaceAll('û', 'u')
                        .replaceAll('ñ', 'n');
                  }

                  final allCodes = languageNames.keys.toList();
                  final latinSorted = allCodes
                      .where(latinCodes.contains)
                      .toList()
                    ..sort((a, b) => latinSortKey(languageNames[a]!)
                        .compareTo(latinSortKey(languageNames[b]!)));
                    final nonLatinSorted = allCodes
                      .where((code) => !latinCodes.contains(code))
                      .toList()
                    ..sort((a, b) => (languageNames[a] ?? a)
                      .toLowerCase()
                      .compareTo((languageNames[b] ?? b).toLowerCase()));
                    final orderedCodes = [...latinSorted, ...nonLatinSorted];

                  return orderedCodes
                      .map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: AdaptiveText(
                            languageNames[code] ?? code,
                            maxLines: 1,
                            minFontSize: 10,
                          ),
                        ),
                      )
                      .toList();
                }(),
              ),
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              title: AdaptiveText(
                trans["theme_title"] ?? "Tema",
                maxLines: 1,
                minFontSize: 12,
              ),
              subtitle: AdaptiveText(
                isDark
                    ? (trans["theme_dark"] ?? "Koyu")
                    : (trans["theme_light"] ?? "Açık"),
                maxLines: 1,
                minFontSize: 10,
              ),
              value: isDark,
              onChanged: (_) => settings.toggleTheme(),
            ),
            if (isDark) ...[
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.brightness_low),
                title: AdaptiveText(
                  trans["oled_mode"] ?? "OLED Modu",
                  maxLines: 1,
                  minFontSize: 12,
                ),
                subtitle: AdaptiveText(
                  trans["oled_mode_desc"] ?? "Saf siyah arayüz",
                  maxLines: 1,
                  minFontSize: 10,
                ),
                value: settings.oledMode,
                onChanged: (val) => settings.setOledMode(val),
              ),
            ],
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.info_outline),
              title: AdaptiveText(
                trans["settings_hide_info"] ?? "Bilgi düğmelerini gizle",
                maxLines: 1,
                minFontSize: 12,
              ),
              value: settings.hideInfoButtons,
              onChanged: (val) => settings.setHideInfoButtons(val),
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.delete_forever),
              title: AdaptiveText(
                trans["settings_confirm_deletes"] ?? "Silmeden önce onay iste",
                maxLines: 1,
                minFontSize: 12,
              ),
              value: settings.confirmDeletes,
              onChanged: (val) => settings.setConfirmDeletes(val),
            ),
          ]),

          if (isDesktop) ...[
            buildSectionHeader(desktopText('desktop_settings')),
            buildCard([
              SwitchListTile(
                secondary: const Icon(Icons.move_to_inbox_outlined),
                title: AdaptiveText(
                  desktopText('desktop_minimize_to_tray'),
                  maxLines: 1,
                  minFontSize: 12,
                ),
                subtitle: AdaptiveText(
                  desktopText('desktop_minimize_to_tray_desc'),
                  maxLines: 2,
                  minFontSize: 10,
                ),
                value: settings.minimizeToTray,
                onChanged: (val) {
                  unawaited(settings.setMinimizeToTray(val));
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.push_pin_outlined),
                title: AdaptiveText(
                  desktopText('desktop_always_on_top'),
                  maxLines: 1,
                  minFontSize: 12,
                ),
                subtitle: AdaptiveText(
                  desktopText('desktop_always_on_top_desc'),
                  maxLines: 2,
                  minFontSize: 10,
                ),
                value: settings.alwaysOnTop,
                onChanged: (val) {
                  unawaited(settings.setAlwaysOnTop(val));
                },
              ),
            ]),
          ],

          // Cloud Services
          buildSectionHeader(trans["cloud_services"] ?? "Bulut Servisleri"),
          buildCard([
            _buildCloudTile(
              context,
              leading: const CloudProviderLogo(
                asset: CloudProviderAssets.googleDrive,
                size: 20,
                monochrome: false,
                semanticLabel: 'Google Drive',
              ),
              label: trans["cloud_source_drive"] ?? "Google Drive",
              isConnected: settings.isGDriveConnected,
              isLoading: settings.isProviderLoading('google_drive'),
              onTap: () => settings.toggleGDriveConnection(),
              trans: trans,
            ),
            const Divider(height: 1, indent: 56),
            _buildCloudTile(
              context,
              leading: const CloudProviderLogo(
                asset: CloudProviderAssets.dropbox,
                size: 20,
                monochrome: false,
                semanticLabel: 'Dropbox',
              ),
              label: trans["cloud_source_dropbox"] ?? "Dropbox",
              isConnected: settings.isDropboxConnected,
              isLoading: settings.isProviderLoading('dropbox'),
              onTap: () async {
                await settings.refreshCloudOAuthConfig();
                if (!context.mounted) return;
                if (settings.effectiveDropboxClientId.trim().isEmpty &&
                    !settings.isDropboxConnected) {
                    final template = trans['cloud_config_missing'] ??
                      '{provider} yapılandırılmamış. OAuth istemci kimliğini ayarlayın.';
                  final msg = template
                      .replaceAll('{provider}',
                          trans['cloud_source_dropbox'] ?? 'Dropbox')
                      .replaceAll('{redirect}', 'Dropbox OAuth redirect');
                  settings.addLog('log_error', msg);
                  return;
                }
                await settings.toggleDropboxConnection();
              },
              trans: trans,
            ),
            const Divider(height: 1, indent: 56),
            _buildCloudTile(
              context,
              leading: const CloudProviderLogo(
                asset: CloudProviderAssets.yandexDisk,
                size: 20,
                monochrome: false,
                semanticLabel: 'Yandex Disk',
              ),
              label: trans["cloud_source_yandex"] ?? "Yandex Disk",
              isConnected: settings.isYandexConnected,
              isLoading: settings.isProviderLoading('yandex'),
              onTap: () async {
                await settings.refreshCloudOAuthConfig();
                if (!context.mounted) return;
                if ((settings.effectiveYandexClientId.trim().isEmpty ||
                        settings.effectiveYandexClientSecret.trim().isEmpty) &&
                    !settings.isYandexConnected) {
                    final template = trans['cloud_config_missing'] ??
                      '{provider} yapılandırılmamış. OAuth istemci kimliği/gizlisini ayarlayın.';
                  final msg = template
                      .replaceAll('{provider}',
                          trans['cloud_source_yandex'] ?? 'Yandex Disk')
                      .replaceAll('{redirect}', 'Yandex OAuth redirect');
                  settings.addLog('log_error', msg);
                  return;
                }
                await settings.toggleYandexConnectionWithContext(context);
              },
              trans: trans,
            ),
          ]),

          buildCard([
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: AdaptiveText(
                trans["check_updates"] ?? "Güncellemeleri Kontrol Et",
                maxLines: 1,
                minFontSize: 12,
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () {
                unawaited(_checkForUpdatesFromSettings(context));
              },
            ),
          ]),

          // About
          const SizedBox(height: 16),
          buildCard([
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: AdaptiveText(
                trans["about_title"] ?? "Hakkında",
                maxLines: 1,
                minFontSize: 12,
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () async {
                Navigator.pop(context);
                await _showAboutDialog(context);
              },
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCloudTile(
    BuildContext context, {
    Widget? leading,
    IconData? icon,
    required String label,
    required bool isConnected,
    required bool isLoading,
    required VoidCallback onTap,
    required Map<String, String> trans,
    String? actionLabel,
  }) {
    return ListTile(
      leading: leading ?? FaIcon(icon ?? FontAwesomeIcons.cloud, size: 20),
      title: AdaptiveText(label, maxLines: 1, minFontSize: 12),
      subtitle: AdaptiveText(
        isConnected
          ? (trans["connected"] ?? "Bağlı")
          : (trans["not_connected"] ?? "Bağlı Değil"),
        style: TextStyle(
          color: isConnected ? Colors.green : Colors.grey,
          fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        minFontSize: 10,
      ),
      trailing: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : AdaptiveText(
                actionLabel ??
                    (isConnected
                        ? (trans["cloud_disconnect"] ?? "Bağlantıyı Kes")
                        : (trans["cloud_connect"] ?? "Bağlan")),
                maxLines: 1,
                minFontSize: 10,
              ),
      ),
    );
  }
}

Future<void> _showAboutDialog(BuildContext context) async {
  final settings = context.read<AppSettings>();
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  final version = info.version.trim();
  final buildNumber = info.buildNumber.trim();
  final displayVersion =
      buildNumber.isEmpty || buildNumber == '0' || version.contains('+')
          ? version
          : '$version+$buildNumber';
  final trans = settings.trans;
  final localizedAppName = (trans['app_name'] ?? '').trim();
  final appName = localizedAppName.isNotEmpty
      ? localizedAppName
      : 'AI Subtitle Translator & Editor';

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.translate, size: 40, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(appName, style: const TextStyle(fontSize: 16)),
                Text(
                  displayVersion,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            trans["dev_info"] ?? "Geliştirici: Mehmet Öz",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            trans["about_description"] ??
                "AI destekli altyazı çevirici ve düzenleyici.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            trans["about_legalese"] ?? "© 2024 Mehmet Öz\nMIT License",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            showLicensePage(
              context: context,
              applicationName: appName,
              applicationVersion: displayVersion,
            );
          },
          child: Text(trans['view_licenses'] ?? 'View Licenses'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(trans['close'] ?? 'Close'),
        ),
      ],
    ),
  );
}

Future<void> _checkForUpdatesFromSettings(BuildContext context) async {
  final settings = context.read<AppSettings>();
  final trans = settings.trans;

  final update = await settings.checkDesktopUpdateFromGoogleDrive(
    minimumCheckInterval: Duration.zero,
  );

  if (!context.mounted) return;

  if (update == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          trans['update_not_found'] ?? 'Yeni sürüm bulunamadı.',
        ),
      ),
    );
    return;
  }

  final newVersionLabel = trans['update_new_version'] ?? 'New version';
  final currentVersionLabel =
      trans['update_current_version'] ?? 'Current version';

  final openNow = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(trans['update_title'] ?? 'Yeni sürüm bulundu'),
      content: Text(
        '$newVersionLabel: ${update.latestVersion}\n'
        '$currentVersionLabel: ${update.currentVersion}\n\n'
        '${update.fileName}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(trans['update_later'] ?? 'Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(trans['update_action'] ?? 'Güncelle'),
        ),
      ],
    ),
  );

  if (openNow != true || !context.mounted) return;

  final target = update.folderUrl ?? update.downloadUrl;
  final uri = Uri.tryParse(target);
  if (uri == null) return;

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          trans['log_error'] ?? 'Bağlantı açılamadı.',
        ),
      ),
    );
  }
}
