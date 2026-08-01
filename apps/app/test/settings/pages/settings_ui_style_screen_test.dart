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
  testWidgets('System/Android/iOSの3候補を表示し、既定値Systemが選択されている', (tester) async {
    await _pump(tester);

    expect(find.text('システム'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
    expect(find.text('iOS'), findsOneWidget);

    expect(_groupValue(tester), AppUiStyle.system);
  });

  testWidgets('選択状態は色だけでなくSemanticsでも判別できる', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(
      tester.getSemantics(_radioFor(AppUiStyle.system)),
      isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true),
    );
    expect(
      tester.getSemantics(_radioFor(AppUiStyle.android)),
      isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false),
    );
    handle.dispose();
  });

  testWidgets('iOSを選択するとthemeSettingsProviderとroot platformへ即時反映される', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(settingsUiStyleOptionKey(AppUiStyle.ios)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AdaptiveAppShell));
    final container = ProviderScope.containerOf(context, listen: false);
    expect(
      container.read(themeSettingsProvider).value?.uiStyle,
      AppUiStyle.ios,
    );
    expect(Theme.of(context).platform, TargetPlatform.iOS);
  });

  testWidgets('保存に失敗すると直前の選択へrollbackしエラーを通知する', (tester) async {
    final repository = FakeThemeSettingsRepository()
      ..saveError = const ThemeSettingsPersistenceException();
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(settingsUiStyleOptionKey(AppUiStyle.android)));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AdaptiveAppShell));
    final container = ProviderScope.containerOf(context, listen: false);
    expect(
      container.read(themeSettingsProvider).value?.uiStyle,
      AppUiStyle.system,
    );
    expect(find.text('設定の保存に失敗しました'), findsOneWidget);
    expect(_groupValue(tester), AppUiStyle.system);
  });

  for (final locale in [
    (
      appLocale: AppLocale.ja,
      system: 'システム',
      android: 'Android',
      ios: 'iOS',
    ),
    (
      appLocale: AppLocale.en,
      system: 'System',
      android: 'Android',
      ios: 'iOS',
    ),
  ]) {
    testWidgets('${locale.appLocale}では選択肢の文言をその言語で表示する', (tester) async {
      await _pump(tester, locale: locale.appLocale);

      expect(find.text(locale.system), findsOneWidget);
      expect(find.text(locale.android), findsOneWidget);
      expect(find.text(locale.ios), findsOneWidget);
    });
  }

  for (final width in [402.0, 744.0, 1024.0]) {
    testWidgets('$width幅でも3候補を選択できる', (tester) async {
      await _pump(tester, width: width);

      await tester.tap(
        find.byKey(settingsUiStyleOptionKey(AppUiStyle.android)),
      );
      await tester.pumpAndSettle();

      expect(_groupValue(tester), AppUiStyle.android);
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
  ).read(goRouterProvider).go('$settingsPath/$settingsUiStyleRelativePath');
  await tester.pumpAndSettle();
}

Finder _radioFor(AppUiStyle style) => find.descendant(
  of: find.byKey(settingsUiStyleOptionKey(style)),
  matching: find.byType(Radio<AppUiStyle>),
);

AppUiStyle? _groupValue(WidgetTester tester) => tester
    .widget<RadioGroup<AppUiStyle>>(find.byType(RadioGroup<AppUiStyle>))
    .groupValue;
