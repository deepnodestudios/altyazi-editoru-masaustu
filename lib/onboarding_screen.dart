import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_settings.dart';
import 'widgets/adaptive_text.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final trans = settings.trans;
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth >= 900;

    final List<Map<String, dynamic>> pages = [
      {
        "title": trans["onboarding_title_1"],
        "desc": trans["onboarding_desc_1"],
        "icon": Icons.auto_awesome,
        "color": Colors.deepPurple,
      },
      {
        "title": trans["onboarding_title_2"],
        "desc": trans["onboarding_desc_2"],
        "icon": Icons.sync,
        "color": Colors.teal,
      },
      {
        "title": trans["onboarding_title_3"],
        "desc": trans["onboarding_desc_3"],
        "icon": Icons.edit_note,
        "color": Colors.orange,
      },
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktopLayout ? 1100 : double.infinity,
            ),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final contentMaxWidth =
                              isDesktopLayout ? 760.0 : constraints.maxWidth;
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktopLayout ? 48.0 : 24.0,
                              vertical: isDesktopLayout ? 20.0 : 16.0,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: contentMaxWidth),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                          isDesktopLayout ? 36 : 30),
                                      decoration: BoxDecoration(
                                        color: (page["color"] as Color)
                                            .withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        page["icon"] as IconData,
                                        size: isDesktopLayout ? 116 : 100,
                                        color: page["color"] as Color,
                                      ),
                                    ),
                                    SizedBox(
                                        height: isDesktopLayout ? 48 : 40),
                                    AdaptiveText(
                                      page["title"] ?? "",
                                      style: TextStyle(
                                        fontSize: isDesktopLayout ? 30 : 24,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      minFontSize: isDesktopLayout ? 20 : 16,
                                    ),
                                    SizedBox(
                                        height: isDesktopLayout ? 24 : 20),
                                    Text(
                                      page["desc"] ?? "",
                                      style: TextStyle(
                                        fontSize: isDesktopLayout ? 18 : 16,
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktopLayout ? 32.0 : 24.0,
                    16.0,
                    isDesktopLayout ? 32.0 : 24.0,
                    isDesktopLayout ? 28.0 : 24.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(
                          pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? colorScheme.primary
                                  : colorScheme.outline.withAlpha(77),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (_currentPage < pages.length - 1)
                            TextButton(
                              onPressed: () {
                                _pageController.animateToPage(
                                  pages.length - 1,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AdaptiveText(
                                trans["onboarding_skip"] ?? "Atla",
                                maxLines: 1,
                                minFontSize: 10,
                              ),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (_currentPage < pages.length - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                _finishOnboarding(context, settings);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: AdaptiveText(
                              _currentPage == pages.length - 1
                                  ? (trans["onboarding_done"] ?? "Başla")
                                  : (trans["onboarding_next"] ?? "İleri"),
                              maxLines: 1,
                              minFontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _finishOnboarding(BuildContext context, AppSettings settings) {
    if (!settings.onboardingShown) {
      settings.completeOnboarding();
    } else {
      Navigator.pop(context);
    }
  }
}
