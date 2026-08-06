import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_settings.dart';
import '../controllers/translation_controller.dart';

class PurchaseDialog extends StatefulWidget {
  const PurchaseDialog({super.key});

  @override
  State<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<PurchaseDialog> {
  static final Uri _playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.deepnode.altyaziceviri',
  );

  StreamSubscription? _subscription;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    // Satın alma başarılı olduğunda dialogu kapat
    _subscription = context.read<TranslationController>().purchaseSuccessStream.listen((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _launchLemonSqueezyCheckout(String baseUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final separator = baseUrl.contains('?') ? '&' : '?';
    final urlWithParams = '$baseUrl${separator}checkout[custom][userId]=${user.uid}&checkout[email]=${Uri.encodeComponent(user.email ?? '')}';
    
    final uri = Uri.parse(urlWithParams);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildWebPackageCard({
    required BuildContext context,
    required String id,
    required String name,
    required int credits,
    required String priceText,
    required String url,
    bool isBestSeller = false,
    bool isBestValue = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.read<AppSettings>();
    final trans = settings.trans;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.grey.shade200;
    final titleColor = isDark ? Colors.white : colorScheme.onSurface;
    final subtitleColor = isDark ? Colors.grey[400] : colorScheme.onSurfaceVariant;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          color: cardColor,
          elevation: isDark ? 1 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: (isBestValue || isBestSeller)
                ? BorderSide(color: colorScheme.primary, width: 2)
                : BorderSide(color: colorScheme.outline.withAlpha(50)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_offer, color: colorScheme.primary),
            ),
            title: Text(
              name,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$credits ${(trans["purchase_translations_unit"] ?? "Çeviri Hakkı")}",
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () {
                if (!settings.isGoogleSignedIn) {
                  settings.signInWithGoogle();
                } else {
                  _launchLemonSqueezyCheckout(url);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.green.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                priceText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        if (isBestValue)
          Positioned(
            top: -12,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                trans["best_value"] ?? "EN AVANTAJLI",
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        if (isBestSeller)
          Positioned(
            top: -12,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                trans["best_seller"] ?? "EN ÇOK SATAN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final trans = settings.trans;
    final isGoogleSignedIn = settings.isGoogleSignedIn;
    final isWindowsDesktop = !kIsWeb && Platform.isWindows;
    
    return Consumer<TranslationController>(
      builder: (context, ctrl, _) {
        return PopScope(
          canPop: !ctrl.isPurchasing,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event.logicalKey == LogicalKeyboardKey.escape && !ctrl.isPurchasing) {
                Navigator.of(context).maybePop();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Dialog(
                  backgroundColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.primary, width: 1),
                  ),
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 40, color: colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        (trans["add_credits"] ?? "Kredi Ekle").toUpperCase(),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trans["credit_usage_info"] ?? "1 Kredi = 1 Tam Dosya Çevirisi",
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (!isGoogleSignedIn) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  trans["purchase_google_required"] ??
                                      "Mevcut kredilerinizi görmek için Google hesabınızla giriş yapın.",
                                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => settings.signInWithGoogle(),
                          icon: const Icon(Icons.login),
                          label: Text(trans["btn_google_signin"] ?? "Google ile Giriş Yap"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ],
                      if (isWindowsDesktop)
                        Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                _buildWebPackageCard(
                                  context: context,
                                  id: 'starter',
                                  name: trans['package_starter'] ?? 'Starter',
                                  credits: 10,
                                  priceText: '\$1.99',
                                  url: 'https://deepnode-studios.lemonsqueezy.com/checkout/buy/0781242d-9870-4b8e-bf7c-3f609fbff843',
                                ),
                                const SizedBox(height: 12),
                                _buildWebPackageCard(
                                  context: context,
                                  id: 'pro',
                                  name: trans['package_pro'] ?? 'Pro',
                                  credits: 50,
                                  priceText: '\$5.99',
                                  url: 'https://deepnode-studios.lemonsqueezy.com/checkout/buy/13ee56c7-8eba-4741-83b3-e0b20bb31b99',
                                  isBestSeller: true,
                                ),
                                const SizedBox(height: 12),
                                _buildWebPackageCard(
                                  context: context,
                                  id: 'expert',
                                  name: trans['package_expert'] ?? 'Expert',
                                  credits: 100,
                                  priceText: '\$9.99',
                                  url: 'https://deepnode-studios.lemonsqueezy.com/checkout/buy/38250e3a-c965-483f-858a-b7e03b57ebdb',
                                  isBestValue: true,
                                ),
                              ],
                            ),
                          )
                        else if (isGoogleSignedIn)
                          Flexible(
                            child: ctrl.isStoreLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                : ctrl.storeError != null
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.signal_wifi_bad, color: colorScheme.error, size: 40),
                                            const SizedBox(height: 12),
                                            Text(
                                              ctrl.storeError!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton(
                                              onPressed: () => ctrl.fetchPackages(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: colorScheme.primary,
                                                foregroundColor: colorScheme.onPrimary,
                                              ),
                                              child: Text(trans["btn_retry"] ?? "Tekrar Dene"),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ctrl.packages.isEmpty
                                        ? Center(
                                            child: Text(
                                              trans["purchase_no_packages"] ?? "Paket bulunamadı",
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          )
                                        : Builder(
                                            builder: (context) {
                                              final sortedPackages = List.of(ctrl.packages)
                                                ..sort((a, b) => a.credits.compareTo(b.credits));

                                              int bestValueIndex = -1;
                                              int bestSellerIndex = -1;
                                              double minUnitPrice = double.infinity;

                                              if (sortedPackages.length > 1) {
                                                for (int i = 0; i < sortedPackages.length; i++) {
                                                  final p = sortedPackages[i];
                                                  if (p.name.toLowerCase().contains('pro')) {
                                                    bestSellerIndex = i;
                                                  }
                                                  
                                                  if (p.rawPrice != null && p.credits > 0) {
                                                    final up = p.rawPrice! / p.credits;
                                                    if (up < minUnitPrice) {
                                                      minUnitPrice = up;
                                                      bestValueIndex = i;
                                                    }
                                                  }
                                                }
                                                
                                                if (bestSellerIndex == -1 && sortedPackages.length >= 3) {
                                                  bestSellerIndex = 1;
                                                }
                                              }

                                              return ListView.separated(
                                                shrinkWrap: true,
                                                itemCount: sortedPackages.length,
                                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                                itemBuilder: (context, index) {
                                                  final package = sortedPackages[index];
                                                  final isBestValue = index == bestValueIndex;
                                                  final isBestSeller = index == bestSellerIndex && !isBestValue;

                                                  final localizedName = () {
                                                    if (package.id == 'starter_pack') return trans['package_starter'] ?? package.name;
                                                    if (package.id == 'pro_pack') return trans['package_pro'] ?? package.name;
                                                    if (package.id == 'expert_pack') return trans['package_expert'] ?? package.name;
                                                    return package.name;
                                                  }();

                                                  String? unitPriceInfo;
                                                  if (package.rawPrice != null && package.credits > 0) {
                                                    final unitPrice = package.rawPrice! / package.credits;
                                                    final symbol = package.currencySymbol ?? '';
                                                    unitPriceInfo = "$symbol${unitPrice.toStringAsFixed(2)} / ${(trans['credit'] ?? 'Kredi')}";
                                                  }

                                                  return Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Card(
                                                        color: Colors.grey[900],
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          side: (isBestValue || isBestSeller)
                                                              ? BorderSide(color: colorScheme.primary, width: 2)
                                                              : BorderSide(color: colorScheme.outline.withAlpha(50)),
                                                        ),
                                                        child: ListTile(
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                          leading: Container(
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              color: colorScheme.primary.withAlpha(30),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(Icons.local_offer, color: colorScheme.primary),
                                                          ),
                                                          title: Text(
                                                            localizedName,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          subtitle: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                "${package.credits} ${(trans["purchase_translations_unit"] ?? "Çeviri Hakkı")}",
                                                                style: TextStyle(
                                                                  color: Colors.grey[400],
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                              if (unitPriceInfo != null)
                                                                Text(
                                                                  unitPriceInfo,
                                                                  style: TextStyle(
                                                                    color: colorScheme.primary.withValues(alpha: 0.8),
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          trailing: ElevatedButton(
                                                            onPressed: () => ctrl.buyCredit(package),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.green.shade600,
                                                              foregroundColor: Colors.white,
                                                              elevation: 6,
                                                              shadowColor: Colors.green.withValues(alpha: 0.4),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(24),
                                                              ),
                                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                            ),
                                                            child: Text(
                                                              package.price ?? '...',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w900,
                                                                fontSize: 15,
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      if (isBestValue)
                                                        Positioned(
                                                          top: -12,
                                                          right: 24,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: colorScheme.primary,
                                                              borderRadius: BorderRadius.circular(20),
                                                              boxShadow: const [
                                                                BoxShadow(
                                                                  color: Colors.black45,
                                                                  blurRadius: 4,
                                                                  offset: Offset(0, 2),
                                                                )
                                                              ],
                                                            ),
                                                            child: Text(
                                                              trans["best_value"] ?? "EN AVANTAJLI",
                                                              style: TextStyle(
                                                                color: colorScheme.onPrimary,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                letterSpacing: 1,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      if (isBestSeller)
                                                        Positioned(
                                                          top: -12,
                                                          right: 24,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.orange.shade700,
                                                              borderRadius: BorderRadius.circular(20),
                                                              boxShadow: const [
                                                                BoxShadow(
                                                                  color: Colors.black45,
                                                                  blurRadius: 4,
                                                                  offset: Offset(0, 2),
                                                                )
                                                              ],
                                                            ),
                                                            child: Text(
                                                              trans["best_seller"] ?? "EN ÇOK SATAN",
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                letterSpacing: 1,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                          ),
                      if (isWindowsDesktop) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                await launchUrl(
                                  _playStoreUri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withAlpha(50),
                                  border: Border.all(color: colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons.googlePlay,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      trans['install_app_cta'] ?? 'Mobil Uygulamadan Al',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                await launchUrl(
                                  Uri.parse('https://deepnodestudios.net/#shop'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withAlpha(50),
                                  border: Border.all(color: colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons.globe,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      trans['buy_from_web'] ?? 'Webden Al',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          if (!mounted || ctrl.isPurchasing) return;
                          Navigator.pop(context);
                        },
                        child: Text(
                          (trans["btn_cancel"] ?? trans["cancel"] ?? "İptal").toUpperCase(),
                          style: TextStyle(color: colorScheme.onSurface.withAlpha((0.7 * 255).round())),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              if (ctrl.isPurchasing)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            trans["purchase_processing"] ?? "İşlem yapılıyor...\nLütfen bekleyin",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
