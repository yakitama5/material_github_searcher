import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/router/app_routes.dart';
import 'package:material_github_searcher/src/router/go_router_provider.dart';
import 'package:material_github_searcher/src/settings/pages/settings_licenses_screen.dart';
import 'package:material_github_searcher/src/settings/pages/settings_screen.dart';
import 'package:material_github_searcher/src/settings/pages/settings_theme_mode_screen.dart';
import 'package:material_github_searcher/src/settings/pages/settings_ui_style_screen.dart';

import '../../support/fake_search_history_repository.dart';
import '../../support/fake_theme_settings_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

void main() {
  setUp(() {
    addTearDown(LicenseRegistry.reset);
  });

  testWidgets('既定値Systemの現在値を一覧へ表示する', (tester) async {
    await _pump(tester);

    expect(
      find.descendant(
        of: find.byKey(settingsUiStyleListTileKey),
        matching: find.text('システム'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(settingsThemeModeListTileKey),
        matching: find.text('システム'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('UI Style行をタップすると選択画面へ遷移し、戻ると一覧へ戻る', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(settingsUiStyleListTileKey));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsUiStyleScreen), findsOneWidget);

    await _popFrom<SettingsUiStyleScreen>(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(SettingsUiStyleScreen), findsNothing);
  });

  testWidgets('選択画面での変更が一覧の現在値表示へ反映される', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(settingsUiStyleListTileKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsUiStyleOptionKey(AppUiStyle.android)));
    await tester.pumpAndSettle();

    await _popFrom<SettingsUiStyleScreen>(tester);

    expect(find.text('Android'), findsOneWidget);
  });

  testWidgets('Theme Mode行をタップすると選択画面へ遷移し、戻ると一覧へ戻る', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(settingsThemeModeListTileKey));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsThemeModeScreen), findsOneWidget);

    await _popFrom<SettingsThemeModeScreen>(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(SettingsThemeModeScreen), findsNothing);
  });

  testWidgets('License行をタップすると画面へ遷移し、戻ると一覧へ戻る', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(settingsLicensesListTileKey));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsLicensesScreen), findsOneWidget);

    await _popFrom<SettingsLicensesScreen>(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(SettingsLicensesScreen), findsNothing);
  });

  testWidgets('Theme Mode選択画面での変更が一覧の現在値表示へ反映される', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(settingsThemeModeListTileKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(settingsThemeModeOptionKey(AppThemeMode.dark)),
    );
    await tester.pumpAndSettle();

    await _popFrom<SettingsThemeModeScreen>(tester);

    expect(find.text('ダーク'), findsOneWidget);
  });

  for (final locale in [
    (
      appLocale: AppLocale.ja,
      title: '設定',
      uiStyleTitle: 'UIスタイル',
      themeModeTitle: 'テーマモード',
      licensesTitle: 'ライセンス',
    ),
    (
      appLocale: AppLocale.en,
      title: 'Settings',
      uiStyleTitle: 'UI Style',
      themeModeTitle: 'Theme Mode',
      licensesTitle: 'Licenses',
    ),
  ]) {
    testWidgets('${locale.appLocale}では一覧の文言をその言語で表示する', (tester) async {
      await _pump(tester, locale: locale.appLocale);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(locale.title),
        ),
        findsOneWidget,
      );
      expect(find.text(locale.uiStyleTitle), findsOneWidget);
      expect(find.text(locale.themeModeTitle), findsOneWidget);
      expect(find.text(locale.licensesTitle), findsOneWidget);
    });
  }

  for (final width in [402.0, 744.0, 1024.0]) {
    testWidgets('$width幅でもUI Style行から選択画面を操作できる', (tester) async {
      await _pump(tester, width: width);

      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(settingsUiStyleListTileKey));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsUiStyleScreen), findsOneWidget);
    });

    testWidgets('$width幅でもTheme Mode行から選択画面を操作できる', (tester) async {
      await _pump(tester, width: width);

      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(settingsThemeModeListTileKey));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsThemeModeScreen), findsOneWidget);
    });

    testWidgets('$width幅でもLicense行からLicense画面へ遷移できる', (tester) async {
      await _pump(tester, width: width);

      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(settingsLicensesListTileKey));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsLicensesScreen), findsOneWidget);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('$brightnessでも一覧を表示できる', (tester) async {
      await _pump(tester, brightness: brightness);

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.ja,
  double width = 402,
  Brightness brightness = Brightness.light,
}) async {
  final previousLocale = LocaleSettings.currentLocale;
  addTearDown(() => LocaleSettings.setLocale(previousLocale));
  await LocaleSettings.setLocale(locale);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  await tester.pumpWidget(
    createApp(
      config: _config,
      overrides: [searchHistoryTestOverride(), themeSettingsTestOverride()],
    ),
  );
  await tester.pumpAndSettle();

  // createAppが登録する本物のcollector（`assets/LICENSE`を`rootBundle`経由で
  // 読込む）は、Flutter Test環境では同一test fileの2回目以降の読込みが完了
  // しない場合があるため、決定的なFakeへ差し替える。License画面自体の内容は
  // `settings_licenses_screen_test.dart`で検証するため、本fileではLicense画面
  // への遷移可否のみを確認すれば足りる。
  LicenseRegistry.reset();
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(['Fake Package'], 'Fake License Text'),
    ),
  );

  final context = tester.element(find.byType(MyApp));
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(goRouterProvider).go(settingsPath);
  await tester.pumpAndSettle();
}

/// 設定項目の選択画面[T]から一覧へ戻る。
///
/// AppBarの戻るボタンはlocale・UI Styleに応じてtooltip・見た目
/// （Material/Cupertino）が変わり、`tester.pageBack()`はこれらに依存して
/// 対象を特定するため、localeを問わず決定的に検証できるよう
/// `Navigator.pop`を直接呼ぶ。
Future<void> _popFrom<T extends Widget>(WidgetTester tester) async {
  final context = tester.element(find.byType(T));
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
}
