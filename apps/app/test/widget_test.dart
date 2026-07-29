// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      TranslationProvider(child: const MyApp(config: _config)),
    );

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Displays Japanese strings for AppLocale.ja', (
    WidgetTester tester,
  ) async {
    await LocaleSettings.setLocale(AppLocale.ja);
    await tester.pumpWidget(
      TranslationProvider(child: const MyApp(config: _config)),
    );

    expect(find.text('ボタンを押した回数'), findsOneWidget);
    expect(
      find.byTooltip('追加'),
      findsOneWidget,
    );
  });

  testWidgets('Displays English strings for AppLocale.en', (
    WidgetTester tester,
  ) async {
    await LocaleSettings.setLocale(AppLocale.en);
    await tester.pumpWidget(
      TranslationProvider(child: const MyApp(config: _config)),
    );

    expect(
      find.text('You have pushed the button this many times'),
      findsOneWidget,
    );
    expect(find.byTooltip('Increment'), findsOneWidget);
  });
}
