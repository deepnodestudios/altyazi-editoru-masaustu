// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

import 'package:altyazi_editoru/app_settings.dart';
import 'package:altyazi_editoru/controllers/translation_controller.dart';
import 'package:altyazi_editoru/main.dart';
import 'package:altyazi_editoru/managers/theme_manager.dart';
import 'package:altyazi_editoru/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('App boots (smoke test)', (WidgetTester tester) async {
    final themeManager = ThemeManager();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => themeManager,
          ),
          ChangeNotifierProvider(
            create: (_) => TranslationController(),
          ),
          ChangeNotifierProvider(
            create: (_) => AppSettings(
              themeManager: themeManager,
              enablePersistence: false,
              enableNotifications: false,
              tutorialTranslationShown: true,
              tutorialEditorShown: true,
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    // Let any one-shot init timers (tutorial checks, etc.) run.
    // Avoid pumpAndSettle here because the app has ongoing animations.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // Basic sanity: app should render a MaterialApp tree and the MainScreen.
    expect(find.byType(MyApp), findsOneWidget);
    final hasMain = find.byType(MainScreen).evaluate().isNotEmpty;
    final hasOnboarding = find.byType(OnboardingScreen).evaluate().isNotEmpty;
    expect(hasMain || hasOnboarding, isTrue);
  });
}
