import 'package:flutter/material.dart';
import 'ai_panel.dart';

class TranslationTab extends StatefulWidget {
  const TranslationTab({super.key});

  @override
  State<TranslationTab> createState() => _TranslationTabState();
}

class _TranslationTabState extends State<TranslationTab> with AutomaticKeepAliveClientMixin {
  // Sekme değiştirilse bile sayfanın durumunu (seçilen dosya vs) korur
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // KeepAlive için gerekli
    return const AITranslationPanel();
  }
}
