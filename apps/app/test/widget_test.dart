// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:dependency_override/dependency_override.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final _messageProvider = Provider<String>((ref) => 'default');

void main() {
  // LocaleSettings は static singleton のため、各テストが変更した locale が
  // 後続テストへ残らないよう、テストごとに基準となる ja へ戻す。
  setUp(() async {
    await LocaleSettings.setLocale(AppLocale.ja);
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(createApp(config: _config));

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

  testWidgets('createAppへ渡したProvider overrideを参照できる', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createApp(
        config: _config,
        overrides: [_messageProvider.overrideWithValue('injected')],
      ),
    );

    final context = tester.element(find.byType(MyApp));
    final container = ProviderScope.containerOf(context, listen: false);

    expect(container.read(_messageProvider), 'injected');
  });

  testWidgets('Production overrideで起動できる', (WidgetTester tester) async {
    await tester.pumpWidget(
      createApp(
        config: _config,
        overrides: createProductionOverrides(),
      ),
    );

    expect(find.text(_config.appName), findsOneWidget);
  });

  testWidgets('Mock overrideで起動できる', (WidgetTester tester) async {
    await tester.pumpWidget(
      createApp(config: _config, overrides: createMockOverrides()),
    );

    expect(find.text(_config.appName), findsOneWidget);
  });

  testWidgets('Displays Japanese strings for AppLocale.ja', (
    WidgetTester tester,
  ) async {
    await LocaleSettings.setLocale(AppLocale.ja);
    await tester.pumpWidget(createApp(config: _config));

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
    await tester.pumpWidget(createApp(config: _config));

    expect(
      find.text('You have pushed the button this many times'),
      findsOneWidget,
    );
    expect(find.byTooltip('Increment'), findsOneWidget);
  });
}
