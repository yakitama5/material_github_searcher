import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/navigation/adaptive_app_shell.dart';
import 'package:material_github_searcher/src/router/app_routes.dart';
import 'package:material_github_searcher/src/router/go_router_provider.dart';
import 'package:material_github_searcher/src/settings/pages/settings_theme_mode_screen.dart';

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
  testWidgets('System/Light/Darkの3候補を表示し、既定値Systemが選択されている', (tester) async {
    await _pump(tester);

    expect(find.text('システム'), findsOneWidget);
    expect(find.text('ライト'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);

    expect(_groupValue(tester), AppThemeMode.system);
  });

  testWidgets('選択状態は色だけでなくSemanticsでも判別できる', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(
      tester.getSemantics(_radioFor(AppThemeMode.system)),
      isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true),
    );
    expect(
      tester.getSemantics(_radioFor(AppThemeMode.dark)),
      isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false),
    );
    handle.dispose();
  });

  testWidgets('Darkを選択するとthemeSettingsProviderとrootのThemeへ即時反映される', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(settingsThemeModeOptionKey(AppThemeMode.dark)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AdaptiveAppShell));
    final container = ProviderScope.containerOf(context, listen: false);
    expect(
      container.read(themeSettingsProvider).value?.themeMode,
      AppThemeMode.dark,
    );
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('Systemを選択すると端末brightnessの変更へ追従する', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _pump(tester);

    final contextBefore = tester.element(find.byType(AdaptiveAppShell));
    expect(Theme.of(contextBefore).brightness, Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    final contextAfter = tester.element(find.byType(AdaptiveAppShell));
    expect(Theme.of(contextAfter).brightness, Brightness.dark);
  });

  testWidgets('保存に失敗すると直前の選択へrollbackしエラーを通知する', (tester) async {
    final repository = FakeThemeSettingsRepository()
      ..saveError = const ThemeSettingsPersistenceException();
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(settingsThemeModeOptionKey(AppThemeMode.dark)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AdaptiveAppShell));
    final container = ProviderScope.containerOf(context, listen: false);
    expect(
      container.read(themeSettingsProvider).value?.themeMode,
      AppThemeMode.system,
    );
    expect(find.text('設定の保存に失敗しました'), findsOneWidget);
    expect(_groupValue(tester), AppThemeMode.system);
  });

  testWidgets('ThemeModeの変更後もUiStyle/ThemeColorが保持される', (tester) async {
    final repository = FakeThemeSettingsRepository(
      initialSettings: const ThemeSettings(
        uiStyle: AppUiStyle.android,
        themeColor: AppThemeColor.green,
      ),
    );
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(settingsThemeModeOptionKey(AppThemeMode.dark)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AdaptiveAppShell));
    final settings = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(themeSettingsProvider).value;
    expect(settings?.themeMode, AppThemeMode.dark);
    expect(settings?.uiStyle, AppUiStyle.android);
    expect(settings?.themeColor, AppThemeColor.green);
  });

  for (final locale in [
    (appLocale: AppLocale.ja, system: 'システム', light: 'ライト', dark: 'ダーク'),
    (appLocale: AppLocale.en, system: 'System', light: 'Light', dark: 'Dark'),
  ]) {
    testWidgets('${locale.appLocale}では選択肢の文言をその言語で表示する', (tester) async {
      await _pump(tester, locale: locale.appLocale);

      expect(find.text(locale.system), findsOneWidget);
      expect(find.text(locale.light), findsOneWidget);
      expect(find.text(locale.dark), findsOneWidget);
    });
  }

  for (final width in [402.0, 744.0, 1024.0]) {
    testWidgets('$width幅でも3候補を選択できる', (tester) async {
      await _pump(tester, width: width);

      await tester.tap(
        find.byKey(settingsThemeModeOptionKey(AppThemeMode.light)),
      );
      await tester.pumpAndSettle();

      expect(_groupValue(tester), AppThemeMode.light);
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.ja,
  double width = 402,
  FakeThemeSettingsRepository? repository,
}) async {
  final previousLocale = LocaleSettings.currentLocale;
  addTearDown(() => LocaleSettings.setLocale(previousLocale));
  await LocaleSettings.setLocale(locale);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    createApp(
      config: _config,
      overrides: [
        searchHistoryTestOverride(),
        themeSettingsTestOverride(repository: repository),
      ],
    ),
  );
  await tester.pumpAndSettle();

  final context = tester.element(find.byType(MyApp));
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(goRouterProvider).go('$settingsPath/$settingsThemeModeRelativePath');
  await tester.pumpAndSettle();
}

Finder _radioFor(AppThemeMode mode) => find.descendant(
  of: find.byKey(settingsThemeModeOptionKey(mode)),
  matching: find.byType(Radio<AppThemeMode>),
);

AppThemeMode? _groupValue(WidgetTester tester) => tester
    .widget<RadioGroup<AppThemeMode>>(find.byType(RadioGroup<AppThemeMode>))
    .groupValue;
