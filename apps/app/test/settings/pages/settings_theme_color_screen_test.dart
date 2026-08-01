// Japanese fallback text is split across literals only to keep source lines
// readable.
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:dynamic_color/test_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/navigation/adaptive_app_shell.dart';
import 'package:material_github_searcher/src/router/app_routes.dart';
import 'package:material_github_searcher/src/router/go_router_provider.dart';
import 'package:material_github_searcher/src/settings/pages/settings_theme_color_screen.dart';
import 'package:material_github_searcher/src/theme/dynamic_color_scope.dart';

import '../../support/fake_search_history_repository.dart';
import '../../support/fake_theme_settings_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

const _dynamicFallbackJa =
    '現在のテーマではDynamic Colorを利用できないため、'
    'アプリの色を表示します。'
    '選択はダイナミックとして保存されます。';
const _dynamicFallbackEn =
    'Dynamic Color is unavailable for the current theme, '
    'so the app color is shown. '
    'Your choice is saved as Dynamic.';

void main() {
  setUp(DynamicColorTestingUtils.setMockDynamicColors);

  testWidgets('9候補を固定順で一度ずつ表示し、既定値Appが選択される', (tester) async {
    await _pump(tester);

    final options = tester
        .widgetList<RadioListTile<AppThemeColor>>(
          find.byType(RadioListTile<AppThemeColor>),
        )
        .map((tile) => tile.value)
        .toList();
    expect(options, const [
      AppThemeColor.app,
      AppThemeColor.dynamic,
      AppThemeColor.blue,
      AppThemeColor.purple,
      AppThemeColor.pink,
      AppThemeColor.red,
      AppThemeColor.orange,
      AppThemeColor.yellow,
      AppThemeColor.green,
    ]);
    expect(options.toSet(), hasLength(9));
    expect(_groupValue(tester), AppThemeColor.app);

    for (final color in settingsThemeColorOptions) {
      expect(find.byKey(settingsThemeColorOptionKey(color)), findsOneWidget);
      expect(find.byKey(settingsThemeColorPreviewKey(color)), findsOneWidget);
    }
    expect(find.text('アプリ'), findsOneWidget);
    expect(find.text('ダイナミック'), findsOneWidget);
    expect(find.text('青'), findsOneWidget);
    expect(find.text('紫'), findsOneWidget);
    expect(find.text('ピンク'), findsOneWidget);
    expect(find.text('赤'), findsOneWidget);
    expect(find.text('オレンジ'), findsOneWidget);
    expect(find.text('黄'), findsOneWidget);
    expect(find.text('緑'), findsOneWidget);
  });

  testWidgets('選択状態は色previewだけでなくSemanticsでも判別できる', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(
      tester.getSemantics(_radioFor(AppThemeColor.app)),
      isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true),
    );
    expect(
      tester.getSemantics(_radioFor(AppThemeColor.green)),
      isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false),
    );
    expect(
      tester.getSemantics(_radioFor(AppThemeColor.app)).label,
      contains('アプリ'),
    );
    handle.dispose();
  });

  testWidgets('9候補すべての選択がthemeSettingsProviderへ反映される', (tester) async {
    await _pump(tester);

    final context = tester.element(find.byType(AdaptiveAppShell));
    final container = ProviderScope.containerOf(context, listen: false);
    for (final color in settingsThemeColorOptions) {
      final option = find.byKey(settingsThemeColorOptionKey(color));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(
        container.read(themeSettingsProvider).value?.themeColor,
        color,
      );
      expect(_groupValue(tester), color);
    }
  });

  testWidgets('保存後にrootを再構築してもTheme Colorの選択を復元する', (tester) async {
    final repository = FakeThemeSettingsRepository();
    await _pump(tester, repository: repository);

    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.purple)),
    );
    await tester.pumpAndSettle();

    // ProviderScopeを一度ツリーから外し、次のpumpで新しいContainerを生成する。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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
        )
        .read(goRouterProvider)
        .go('$settingsPath/$settingsThemeColorRelativePath');
    await tester.pumpAndSettle();

    expect(_groupValue(tester), AppThemeColor.purple);
  });

  testWidgets('Theme Colorの変更後もThemeMode/UI Styleが保持される', (tester) async {
    final repository = FakeThemeSettingsRepository(
      initialSettings: const ThemeSettings(
        uiStyle: AppUiStyle.ios,
        themeMode: AppThemeMode.dark,
      ),
    );
    await _pump(tester, repository: repository, brightness: Brightness.dark);

    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.green)),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AdaptiveAppShell));
    final settings = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(themeSettingsProvider).value;
    expect(settings?.themeColor, AppThemeColor.green);
    expect(settings?.themeMode, AppThemeMode.dark);
    expect(settings?.uiStyle, AppUiStyle.ios);
  });

  testWidgets('選択後にLight/Dark双方の実効ColorSchemeへ即時反映される', (tester) async {
    await _pump(tester);

    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.purple)),
    );
    await tester.pumpAndSettle();

    final resolved = AppTheme.resolve(
      const ThemeSettings(themeColor: AppThemeColor.purple),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme, resolved.light.colorScheme);
    expect(app.darkTheme?.colorScheme, resolved.dark.colorScheme);
  });

  testWidgets('保存に失敗すると直前の選択へrollbackしエラーを通知する', (tester) async {
    final repository = FakeThemeSettingsRepository()
      ..saveError = const ThemeSettingsPersistenceException();
    await _pump(tester, repository: repository);

    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.blue)),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AdaptiveAppShell));
    final container = ProviderScope.containerOf(context, listen: false);
    expect(
      container.read(themeSettingsProvider).value?.themeColor,
      AppThemeColor.app,
    );
    expect(find.text('設定の保存に失敗しました'), findsOneWidget);
    expect(_groupValue(tester), AppThemeColor.app);
  });

  testWidgets('保存中は全候補を無効化し、保存完了後に再度有効化する', (tester) async {
    final repository = FakeThemeSettingsRepository()..saveGate = Completer();
    await _pump(tester, repository: repository);

    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.blue)),
    );
    await tester.pump();

    for (final color in settingsThemeColorOptions) {
      expect(
        tester
            .widget<RadioListTile<AppThemeColor>>(
              find.byKey(settingsThemeColorOptionKey(color)),
            )
            .enabled,
        isFalse,
      );
    }

    repository.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RadioListTile<AppThemeColor>>(
            find.byKey(settingsThemeColorOptionKey(AppThemeColor.blue)),
          )
          .enabled,
      isTrue,
    );
  });

  testWidgets('設定の初期読込中は全候補を無効化する', (tester) async {
    final repository = FakeThemeSettingsRepository()..loadGate = Completer();
    await _pump(tester, repository: repository, settle: false);

    for (final color in settingsThemeColorOptions) {
      expect(
        tester
            .widget<RadioListTile<AppThemeColor>>(
              find.byKey(settingsThemeColorOptionKey(color)),
            )
            .enabled,
        isFalse,
      );
    }

    repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RadioListTile<AppThemeColor>>(
            find.byKey(settingsThemeColorOptionKey(AppThemeColor.app)),
          )
          .enabled,
      isTrue,
    );
  });

  testWidgets('設定の初期読込に失敗した場合も候補を無効化する', (tester) async {
    final repository = FakeThemeSettingsRepository()
      ..loadError = const ThemeSettingsPersistenceException();
    await _pump(tester, repository: repository);

    expect(
      tester
          .widget<RadioListTile<AppThemeColor>>(
            find.byKey(settingsThemeColorOptionKey(AppThemeColor.app)),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('既存値を持つ再読込中やエラー中も全候補を無効化する', (tester) async {
    final repository = FakeThemeSettingsRepository();
    await _pump(tester, repository: repository);

    final context = tester.element(find.byType(AdaptiveAppShell));
    final container = ProviderScope.containerOf(context, listen: false);

    repository.loadGate = Completer();
    container.invalidate(themeSettingsProvider);
    await tester.pump();
    expect(container.read(themeSettingsProvider).isLoading, isTrue);
    expect(container.read(themeSettingsProvider).hasValue, isTrue);
    _expectAllOptionsDisabled(tester);

    repository.loadGate!.complete();
    repository.loadGate = null;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RadioListTile<AppThemeColor>>(
            find.byKey(settingsThemeColorOptionKey(AppThemeColor.app)),
          )
          .enabled,
      isTrue,
    );

    repository.loadError = const ThemeSettingsPersistenceException();
    container.invalidate(themeSettingsProvider);
    await tester.pumpAndSettle();
    expect(container.read(themeSettingsProvider).hasError, isTrue);
    expect(container.read(themeSettingsProvider).hasValue, isTrue);
    _expectAllOptionsDisabled(tester);

    repository.loadError = null;
    container.invalidate(themeSettingsProvider);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RadioListTile<AppThemeColor>>(
            find.byKey(settingsThemeColorOptionKey(AppThemeColor.app)),
          )
          .enabled,
      isTrue,
    );
  });

  testWidgets('Dynamic取得不可時はApp seedで表示し、選択値をdynamicのまま維持する', (
    tester,
  ) async {
    final repository = FakeThemeSettingsRepository(
      initialSettings: const ThemeSettings(themeColor: AppThemeColor.dynamic),
    );
    await _pump(tester, repository: repository);

    expect(
      find.text(_dynamicFallbackJa),
      findsOneWidget,
    );
    expect(_groupValue(tester), AppThemeColor.dynamic);

    final context = tester.element(find.byType(AdaptiveAppShell));
    expect(
      Theme.of(context).colorScheme,
      AppTheme.resolve(
        const ThemeSettings(themeColor: AppThemeColor.dynamic),
      ).light.colorScheme,
    );
    final preview = tester.widget<Container>(
      find.descendant(
        of: find.byKey(
          settingsThemeColorPreviewKey(AppThemeColor.dynamic),
        ),
        matching: find.byType(Container),
      ),
    );
    expect(
      (preview.decoration! as BoxDecoration).color,
      AppThemeColor.app.seed,
    );

    final container = ProviderScope.containerOf(context, listen: false);
    expect(
      container.read(themeSettingsProvider).value?.themeColor,
      AppThemeColor.dynamic,
    );

    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.blue)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.dynamic)),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(themeSettingsProvider).value?.themeColor,
      AppThemeColor.dynamic,
    );
  });

  testWidgets('Dynamic取得時はDynamic Schemeで表示し、fallback説明を表示しない', (
    tester,
  ) async {
    DynamicColorTestingUtils.setMockDynamicColors(accentColor: Colors.teal);
    final repository = FakeThemeSettingsRepository(
      initialSettings: const ThemeSettings(themeColor: AppThemeColor.dynamic),
    );
    await _pump(tester, repository: repository);

    final context = tester.element(find.byType(AdaptiveAppShell));
    final dynamicColorScope = DynamicColorScope.maybeOf(context)!;
    final expectedLight = dynamicColorScope.schemeFor(Brightness.light)!;
    final expectedDark = dynamicColorScope.schemeFor(Brightness.dark)!;
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(Theme.of(context).colorScheme, expectedLight);
    expect(app.theme!.colorScheme, expectedLight);
    expect(app.darkTheme?.colorScheme, expectedDark);
    expect(find.text(_dynamicFallbackJa), findsNothing);
    final preview = tester.widget<Container>(
      find.descendant(
        of: find.byKey(
          settingsThemeColorPreviewKey(AppThemeColor.dynamic),
        ),
        matching: find.byType(Container),
      ),
    );
    expect(
      (preview.decoration! as BoxDecoration).color,
      expectedLight.primary,
    );

    final container = ProviderScope.containerOf(context, listen: false);
    expect(
      container.read(themeSettingsProvider).value?.themeColor,
      AppThemeColor.dynamic,
    );

    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.blue)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(settingsThemeColorOptionKey(AppThemeColor.dynamic)),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(themeSettingsProvider).value?.themeColor,
      AppThemeColor.dynamic,
    );
  });

  testWidgets('Dynamic Colorがlightだけ取得できた場合、lightではfallbackしない', (
    tester,
  ) async {
    final light = ColorScheme.fromSeed(seedColor: Colors.teal);
    final repository = FakeThemeSettingsRepository(
      initialSettings: const ThemeSettings(themeColor: AppThemeColor.dynamic),
    );
    await _pumpPartialDynamicColor(
      tester,
      light: light,
      theme: ThemeData(colorScheme: light),
      repository: repository,
    );

    expect(find.text(_dynamicFallbackJa), findsNothing);
    final preview = tester.widget<Container>(
      find.descendant(
        of: find.byKey(
          settingsThemeColorPreviewKey(AppThemeColor.dynamic),
        ),
        matching: find.byType(Container),
      ),
    );
    expect((preview.decoration! as BoxDecoration).color, light.primary);
  });

  testWidgets('Dynamic Colorがlightだけ取得できた場合、darkではApp seedへfallbackする', (
    tester,
  ) async {
    final light = ColorScheme.fromSeed(seedColor: Colors.teal);
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    final repository = FakeThemeSettingsRepository(
      initialSettings: const ThemeSettings(themeColor: AppThemeColor.dynamic),
    );
    await _pumpPartialDynamicColor(
      tester,
      light: light,
      theme: ThemeData(colorScheme: dark),
      repository: repository,
    );

    expect(find.text(_dynamicFallbackJa), findsOneWidget);
    final preview = tester.widget<Container>(
      find.descendant(
        of: find.byKey(
          settingsThemeColorPreviewKey(AppThemeColor.dynamic),
        ),
        matching: find.byType(Container),
      ),
    );
    expect(
      (preview.decoration! as BoxDecoration).color,
      AppThemeColor.app.seed,
    );
    final context = tester.element(find.byType(SettingsThemeColorScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('Dynamic Colorがdarkだけ取得できた場合、darkではfallbackしない', (
    tester,
  ) async {
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    final repository = FakeThemeSettingsRepository(
      initialSettings: const ThemeSettings(themeColor: AppThemeColor.dynamic),
    );
    await _pumpPartialDynamicColor(
      tester,
      dark: dark,
      theme: ThemeData(colorScheme: dark),
      repository: repository,
    );

    expect(find.text(_dynamicFallbackJa), findsNothing);
    final preview = tester.widget<Container>(
      find.descendant(
        of: find.byKey(
          settingsThemeColorPreviewKey(AppThemeColor.dynamic),
        ),
        matching: find.byType(Container),
      ),
    );
    expect((preview.decoration! as BoxDecoration).color, dark.primary);
    final context = tester.element(find.byType(SettingsThemeColorScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  for (final locale in [
    (
      appLocale: AppLocale.ja,
      title: 'テーマカラー',
      labels: ['アプリ', 'ダイナミック', '青', '紫', 'ピンク', '赤', 'オレンジ', '黄', '緑'],
    ),
    (
      appLocale: AppLocale.en,
      title: 'Theme Color',
      labels: [
        'App',
        'Dynamic',
        'Blue',
        'Purple',
        'Pink',
        'Red',
        'Orange',
        'Yellow',
        'Green',
      ],
    ),
  ]) {
    testWidgets('${locale.appLocale}ではTheme Colorの文言をその言語で表示する', (
      tester,
    ) async {
      await _pump(tester, locale: locale.appLocale);

      expect(find.text(locale.title), findsOneWidget);
      for (final label in locale.labels) {
        expect(find.text(label), findsOneWidget);
      }
      if (locale.appLocale == AppLocale.en) {
        expect(find.text(_dynamicFallbackEn), findsOneWidget);
      }
    });
  }

  for (final width in [402.0, 744.0, 1024.0]) {
    testWidgets('$width幅でも9候補を操作できる', (tester) async {
      await _pump(tester, width: width);

      final option = find.byKey(
        settingsThemeColorOptionKey(AppThemeColor.green),
      );
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(_groupValue(tester), AppThemeColor.green);
    });
  }
}

Future<void> _pumpPartialDynamicColor(
  WidgetTester tester, {
  ColorScheme? light,
  ColorScheme? dark,
  required ThemeData theme,
  required FakeThemeSettingsRepository repository,
}) async {
  final previousLocale = LocaleSettings.currentLocale;
  addTearDown(() => LocaleSettings.setLocale(previousLocale));
  await LocaleSettings.setLocale(AppLocale.ja);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [themeSettingsTestOverride(repository: repository)],
      child: TranslationProvider(
        child: DynamicColorScope(
          light: light,
          dark: dark,
          child: MaterialApp(
            theme: theme,
            home: const SettingsThemeColorScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.ja,
  double width = 402,
  Brightness brightness = Brightness.light,
  FakeThemeSettingsRepository? repository,
  bool settle = true,
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
      overrides: [
        searchHistoryTestOverride(),
        themeSettingsTestOverride(repository: repository),
      ],
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  final context = tester.element(find.byType(MyApp));
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(goRouterProvider).go('$settingsPath/$settingsThemeColorRelativePath');
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Finder _radioFor(AppThemeColor color) => find.descendant(
  of: find.byKey(settingsThemeColorOptionKey(color)),
  matching: find.byType(Radio<AppThemeColor>),
);

void _expectAllOptionsDisabled(WidgetTester tester) {
  for (final color in settingsThemeColorOptions) {
    expect(
      tester
          .widget<RadioListTile<AppThemeColor>>(
            find.byKey(settingsThemeColorOptionKey(color)),
          )
          .enabled,
      isFalse,
    );
  }
}

AppThemeColor? _groupValue(WidgetTester tester) => tester
    .widget<RadioGroup<AppThemeColor>>(find.byType(RadioGroup<AppThemeColor>))
    .groupValue;
