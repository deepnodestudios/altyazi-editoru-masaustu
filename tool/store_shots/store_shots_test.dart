// Web sitesi / mağaza tanıtım görselleri için masaüstü ekran görüntüsü üretici.
// Normal `flutter test` koşusuna dahil değildir (test/ dışında).
//
// Çalıştırma:
//   flutter test tool/store_shots/store_shots_test.dart --dart-define=SHOT_LANG=TR
//
// Çıktılar: build/store_shots/<LANG>/<sahne>.png

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:altyazi_editoru/app_settings.dart';
import 'package:altyazi_editoru/controllers/translation_controller.dart';
import 'package:altyazi_editoru/main.dart';
import 'package:altyazi_editoru/managers/theme_manager.dart';

import 'demo_data.dart';

const String kLang = String.fromEnvironment('SHOT_LANG', defaultValue: 'TR');
const Size kLogicalSize = Size(1280, 800);
const double kPixelRatio = 2.0;

final GlobalKey _shotKey = GlobalKey();

/// Dile göre Segoe UI ailesi olarak yüklenecek Windows fontları.
List<String> _uiFontFiles(String lang) {
  const win = r'C:\Windows\Fonts';
  switch (lang) {
    case 'JA':
      return ['$win\\YuGothR.ttc', '$win\\YuGothM.ttc', '$win\\YuGothB.ttc'];
    case 'KO':
      return ['$win\\malgun.ttf', '$win\\malgunbd.ttf'];
    case 'CN':
      return ['$win\\msyh.ttc', '$win\\msyhbd.ttc'];
    case 'TH':
      return ['$win\\LeelawUI.ttf', '$win\\LeelaUIb.ttf'];
    default:
      return [
        '$win\\segoeui.ttf',
        '$win\\seguisb.ttf',
        '$win\\segoeuib.ttf',
      ];
  }
}

Future<void> _loadFonts() async {
  for (final family in ['Segoe UI', 'Roboto', 'FlutterTest', 'Ahem', 'Courier']) {
    final uiLoader = FontLoader(family);
    final files = family == 'Courier'
        ? [r'C:\Windows\Fonts\consola.ttf']
        : _uiFontFiles(kLang);
    for (final path in files) {
      final f = File(path);
      if (f.existsSync()) {
        final bytes = f.readAsBytesSync();
        uiLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await uiLoader.load();
  }

  // Uygulamanın kendi/paket fontları (MaterialIcons, FontAwesome ...)
  final manifestJson = await rootBundle.loadString('FontManifest.json');
  final List<dynamic> manifest = json.decode(manifestJson) as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family.replaceFirst(RegExp(r'^packages/[^/]+/'), ''));
    final loaderPkg = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      final asset = (font as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
      loaderPkg.addFont(rootBundle.load(asset));
    }
    await loader.load();
    await loaderPkg.load();
  }
}

/// Gerçek zamanlı (platform kanalı / dosya) işlerin bitmesini bekler.
Future<void> _settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'window_manager',
    'tray_manager',
    'screen_retriever',
    'plugins.flutter.io/path_provider',
    'dev.fluttercommunity.plus/package_info',
    'dev.fluttercommunity.plus/connectivity',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      if (call.method == 'getApplicationDocumentsDirectory' ||
          call.method == 'getApplicationSupportDirectory' ||
          call.method == 'getTemporaryDirectory') {
        return '${Directory.systemTemp.path}${Platform.pathSeparator}store_shots_appdata';
      }
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'AI Altyazi', 'packageName': 'altyazi', 'version': '1.8.5',
          'buildNumber': '1', 'buildSignature': '',
        };
      }
      if (call.method == 'check') return <String>['wifi'];
      return null;
    });
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: kPixelRatio);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/store_shots/$kLang/$name.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await _loadFonts();
    _mockChannels();
  });

  testWidgets('store shots $kLang', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = kLogicalSize * kPixelRatio;
    tester.view.devicePixelRatio = kPixelRatio;
    addTearDown(tester.view.reset);

    final isTr = kLang == 'TR';
    final target = isTr ? 'TR' : 'ES';
    final translated = isTr ? kStarlightTr : kStarlightEs;
    final sep = Platform.pathSeparator;
    final demoDir = Directory('${Directory.systemTemp.path}${sep}store_shots_demo');
    if (demoDir.existsSync()) demoDir.deleteSync(recursive: true);
    demoDir.createSync(recursive: true);
    final appData =
        Directory('${Directory.systemTemp.path}${sep}store_shots_appdata');
    if (appData.existsSync()) appData.deleteSync(recursive: true);
    String writeSrt(String name, String content) {
      final f = File('${demoDir.path}$sep$name');
      f.writeAsStringSync(content);
      return f.path;
    }

    final starlightPath = writeSrt(
        'Starlight Cartographers.srt', buildSrt(kTimes, kStarlightEn));
    final echoesPath = writeSrt(
        'Echoes of Paper Cities.srt', buildSrt(kTimes, kStarlightEn.reversed.toList()));
    final demoName = isTr ? 'Demo_Movie_TR.srt' : 'Demo_Movie.srt';
    final demoPath =
        writeSrt(demoName, buildSrt(kEditorTimes, isTr ? kEditorTr : kEditorEn));
    final neonPath = writeSrt('Neon Harvest.srt',
        buildSrt(kEditorTimes, kEditorEn));

    List<Map<String, dynamic>> blocks(List<String> lines) => [
          for (var i = 0; i < lines.length; i++)
            {'index': '${i + 1}', 'timecode': kTimes[i], 'text': lines[i]},
        ];

    final now = DateTime(2026, 11, 14, 8, 32, 57);
    final projects = <String>[
      for (var i = 0; i < kHistoryTitles.length; i++)
        jsonEncode({
          'id': 'demo_$i',
          'fileName': kHistoryTitles[i],
          'filePath': starlightPath,
          'targetLanguage': i == 1 ? (isTr ? 'EN' : 'FR') : target,
          'isCompleted': true,
          'isPartial': false,
          'isActive': false,
          'clearSdh': false,
          'totalLines': kTimes.length,
          'translatedLines': kTimes.length,
          'lastUpdated': now
              .subtract(Duration(hours: i * 9, minutes: i * 17))
              .toIso8601String()
              .substring(0, 19)
              .replaceFirst('T', ' '),
          'sourceBlocks': blocks(kStarlightEn),
          'processedBlocks': blocks(translated),
          'usedModel': 'gemini',
          'completedPlatform': 'desktop',
        }),
    ];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'language': kLang,
      'targetLanguage': target,
      'oled_mode': true,
      'is_dark_mode': true,
      'saved_projects': projects,
      'batch_files': [
        jsonEncode({'name': 'Starlight Cartographers.srt', 'path': starlightPath, 'source': 'device', 'hash': 'a1b2c3d4e5f60718'}),
        jsonEncode({'name': 'Echoes of Paper Cities.srt', 'path': echoesPath, 'source': 'device', 'hash': 'b2c3d4e5f6071829'}),
        jsonEncode({'name': 'Neon Harvest.srt', 'path': neonPath, 'source': 'device', 'hash': 'c3d4e5f60718293a'}),
      ],
      'demo_movie_path': demoPath,
    });

    final themeManager = ThemeManager();
    final controller = TranslationController();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => themeManager),
            ChangeNotifierProvider(create: (_) => controller),
            ChangeNotifierProvider(
              create: (_) => AppSettings(
                themeManager: themeManager,
                enablePersistence: true,
                enableNotifications: false,
                tutorialTranslationShown: true,
                tutorialEditorShown: true,
              ),
            ),
          ],
          child: const MyApp(),
        ),
      ),
    );
    await _settle(tester);

    controller.billingService.debugApplyUserSnapshot({
      'tokenBalance': 18095265,
      'tokenGrantBalance': 469000,
      'creditPolicy': 'token_v1',
    });
    await _settle(tester);
    final ctx = tester.element(find.byType(MainScreen));
    final settings = Provider.of<AppSettings>(ctx, listen: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_projects', projects);
    await settings.debugReloadProjectsFromPrefs();
    await _settle(tester, rounds: 2);
    settings.logs.clear();
    settings.addLog('log_editor_file_loaded', 'Starlight Cartographers.srt');
    await tester.tap(find.text('Starlight Cartographers.srt').first);
    await _settle(tester);
    await _capture(tester, '01_main');
    for (final e in find.byType(Text).evaluate()) {
      final d = (e.widget as Text).data ?? '';
      if (d.contains('.srt')) debugPrint('SRTTEXT: $d');
    }
    debugPrint('BATCH: ${(await SharedPreferences.getInstance()).getStringList('batch_files')}');

    Future<void> back() async {
      final nav = Navigator.of(tester.element(find.byType(MainScreen)));
      nav.popUntil((r) => r.isFirst);
      await _settle(tester, rounds: 2);
    }

    Future<void> shot(String name, Finder f) async {
      if (f.evaluate().isEmpty) {
        debugPrint('SHOT MISSING FINDER: $name');
        return;
      }
      await tester.tap(f.first, warnIfMissed: false);
      await _settle(tester);
      await _capture(tester, name);
      for (final e in find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)).evaluate()) {
        debugPrint('SNACK[$name]: ${(e.widget as Text).data}');
      }
      debugPrint('LOGS[$name]: ${settings.logs.take(3).map((l) => '${l.key}:${l.param}').join(' | ')}');
      debugPrint('PROJECTS[$name]: ${settings.projects.length}');
    }

    await shot('02_language', find.byIcon(Icons.expand_more));
    await back();
    await shot('03_history', find.byIcon(Icons.history));
    await shot('04_preview', find.text('Starlight Cartographers.srt').last);
    await shot('05_compare', find.byType(Tab).last);
    await back();
    await shot('06_settings', find.byIcon(Icons.settings));
    await back();
    await shot('07_features', find.byIcon(Icons.star_rounded));
    await back();

    // Editör
    settings.setEditorFile(
        demoName, buildSrt(kEditorTimes, isTr ? kEditorTr : kEditorEn));
    await tester.tap(find.byIcon(Icons.subtitles_outlined).first,
        warnIfMissed: false);
    await _settle(tester);
    await _capture(tester, '08_editor');
    debugDefaultTargetPlatformOverride = null;
  });
}
