import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_settings.dart';
import 'managers/theme_manager.dart';
import 'widgets/adaptive_text.dart';

/// Sol panel butonları için hover gölgesi + arka plan animasyonu sağlar.
class SideRailHoverButton extends StatefulWidget {
  const SideRailHoverButton({
    super.key,
    required this.onTap,
    required this.child,
    this.isSelected = false,
    this.verticalPadding = 6.0,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool isSelected;
  final double verticalPadding;

  @override
  State<SideRailHoverButton> createState() => _SideRailHoverButtonState();
}

class _SideRailHoverButtonState extends State<SideRailHoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 80,
          padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? primary.withValues(alpha: 0.12)
                : _hovered
                    ? primary.withValues(alpha: 0.07)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

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
        ? SideRailHoverButton(
            onTap: () => _showSettingsSheet(context),
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
    return SideRailHoverButton(
      onTap: () => _showFeaturesSheet(context),
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
    );
  }
}

void _showSettingsSheet(BuildContext context) {
  final trans = context.read<ThemeManager>().trans;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 24,
          shadowColor: Colors.black38,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
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
          elevation: 24,
          shadowColor: Colors.black38,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
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
                        (code) {
                          final name = languageNames[code] ?? code;
                          final label = languageNames.containsKey(code)
                              ? '$code - $name'
                              : code;
                          return DropdownMenuItem(
                            value: code,
                            child: AdaptiveText(
                              label,
                              maxLines: 1,
                              minFontSize: 10,
                            ),
                          );
                        },
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
                trans["settings_hide_info"] ?? "Bilgilendirmeleri Gizle",
                maxLines: 1,
                minFontSize: 12,
              ),
              value: settings.hideInfoButtons,
              onChanged: (val) => settings.setHideInfoButtons(val),
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.delete_outline),
              title: AdaptiveText(
                trans["settings_confirm_deletes"] ?? "Silmeden önce onay iste",
                maxLines: 1,
                minFontSize: 12,
              ),
              value: settings.confirmDeletes,
              onChanged: (val) => settings.setConfirmDeletes(val),
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined),
              title: AdaptiveText(
                trans["settings_show_crash_warnings"] ?? "Açılışta çökme uyarılarını göster",
                maxLines: 2,
                minFontSize: 12,
              ),
              value: settings.showCrashWarnings,
              onChanged: (val) => settings.setShowCrashWarnings(val),
            ),
          ]),

          if (isDesktop) ...[
            buildSectionHeader(trans['desktop_settings'] ?? 'Desktop Settings'),
            buildCard([
              SwitchListTile(
                secondary: const Icon(Icons.move_to_inbox_outlined),
                title: AdaptiveText(
                  trans['desktop_minimize_to_tray'] ?? 'Minimize To System Tray',
                  maxLines: 1,
                  minFontSize: 12,
                ),
                subtitle: AdaptiveText(
                  trans['desktop_minimize_to_tray_desc'] ?? 'Hide Window To Tray Instead Of Closing',
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
                  trans['desktop_always_on_top'] ?? 'Always On Top',
                  maxLines: 1,
                  minFontSize: 12,
                ),
                subtitle: AdaptiveText(
                  trans['desktop_always_on_top_desc'] ?? 'Keep This Window Above Other Windows',
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
              leading: const Icon(Icons.bug_report_outlined),
              title: AdaptiveText(
                trans['report_error_title'] ?? 'Hataları Geliştiriciye Bildir',
                maxLines: 1,
                minFontSize: 12,
              ),
              trailing: const Icon(Icons.mail_outline, size: 20, color: Colors.grey),
              onTap: () async {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'deepnodestudios@gmail.com',
                  query:
                      'subject=${Uri.encodeComponent(trans['report_error_subject'] ?? 'Hata Bildirimi - Altyazı Editörü')}',
                );
                try {
                  if (!await launchUrl(emailLaunchUri)) {
                    // ignore: use_build_context_synchronously
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(trans['email_app_open_failed'] ?? 'Could not open email app.')),
                    );
                  }
                } catch (_) {}
              },
            ),
            const Divider(height: 1, indent: 56),
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

  final target = update.downloadUrl;
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
