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

import '../../support/fake_search_history_repository.dart';
import '../../support/fake_theme_settings_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

final _appLicenseEntry = LicenseEntryWithLineBreaks(
  [_config.appName],
  ['MIT License', for (var i = 0; i < 60; i++) '本文行 $i.'].join('\n\n'),
);

void main() {
  setUp(() {
    addTearDown(LicenseRegistry.reset);
  });

  testWidgets('アプリ名で識別できる項目を一覧に表示する', (tester) async {
    await _pump(tester);

    expect(find.widgetWithText(ListTile, _config.appName), findsOneWidget);
  });

  testWidgets('登録したFake packageのライセンスも一覧に表示する', (tester) async {
    await _pump(
      tester,
      additionalEntries: [
        const LicenseEntryWithLineBreaks(['Fake Package'], 'Fake License Text'),
      ],
    );

    expect(find.widgetWithText(ListTile, 'Fake Package'), findsOneWidget);
  });

  testWidgets('アプリ名の項目をタップするとMIT本文を表示し、長文をscrollできる', (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ListTile, _config.appName));
    await tester.pumpAndSettle();

    expect(find.textContaining('MIT License'), findsOneWidget);
    expect(find.text('本文行 0.'), findsOneWidget);
    expect(find.text('本文行 59.'), findsNothing);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('本文行 59.'), findsOneWidget);
  });

  testWidgets('/settings/licensesへのroute直アクセスで表示できる', (tester) async {
    await _pumpApp(tester);
    await _replaceWithFakeLicenses(const []);

    final context = tester.element(find.byType(MyApp));
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(goRouterProvider).go('/settings/licenses');
    await tester.pumpAndSettle();

    expect(find.byType(SettingsLicensesScreen), findsOneWidget);
  });

  for (final locale in [
    (appLocale: AppLocale.ja, title: 'ライセンス'),
    (appLocale: AppLocale.en, title: 'Licenses'),
  ]) {
    testWidgets('${locale.appLocale}ではAppBarタイトルをその言語で表示する', (tester) async {
      await _pump(tester, locale: locale.appLocale);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(locale.title),
        ),
        findsOneWidget,
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('$brightnessでも一覧を表示できる', (tester) async {
      await _pump(tester, brightness: brightness);

      expect(find.widgetWithText(ListTile, _config.appName), findsOneWidget);
    });
  }

  testWidgets('UI Style=iOSでも一覧を表示できる', (tester) async {
    await _pump(tester, uiStyle: AppUiStyle.ios);

    expect(find.widgetWithText(ListTile, _config.appName), findsOneWidget);
  });
}

/// [createApp]が実行時に登録する本物のcollector（`assets/LICENSE`を
/// `rootBundle`経由で読み込む）を、決定的なFakeへ差し替える。
///
/// Flutter Test環境では同一test fileの2回目以降に実際の`rootBundle`読込みが
/// 完了しない場合があるため、画面の表示・操作を検証するWidget Testでは実際の
/// asset読込みを経由させず、[_appLicenseEntry]等のFakeで差し替える。
/// `registerAppLicense`自体（実LICENSEの読込みとアプリ名での識別）は
/// `test/license/register_app_license_test.dart`のUnit Testで検証する。
Future<void> _replaceWithFakeLicenses(
  List<LicenseEntryWithLineBreaks> additionalEntries,
) async {
  LicenseRegistry.reset();
  LicenseRegistry.addLicense(
    () => Stream.fromIterable([_appLicenseEntry, ...additionalEntries]),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  AppLocale locale = AppLocale.ja,
  Brightness brightness = Brightness.light,
  AppUiStyle uiStyle = AppUiStyle.system,
}) async {
  final previousLocale = LocaleSettings.currentLocale;
  addTearDown(() => LocaleSettings.setLocale(previousLocale));
  await LocaleSettings.setLocale(locale);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(402, 900);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  await tester.pumpWidget(
    createApp(
      config: _config,
      overrides: [
        searchHistoryTestOverride(),
        themeSettingsTestOverride(
          repository: FakeThemeSettingsRepository(
            initialSettings: ThemeSettings(uiStyle: uiStyle),
          ),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

/// License画面まで遷移した状態でpumpする。
///
/// [LicensePage]はMaster-Detail Flowを持ち、compact幅（402）でのみ
/// 単一paneの標準的な戻る挙動を検証できるため、幅を明示的に固定する。
Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.ja,
  Brightness brightness = Brightness.light,
  AppUiStyle uiStyle = AppUiStyle.system,
  List<LicenseEntryWithLineBreaks> additionalEntries = const [],
}) async {
  await _pumpApp(
    tester,
    locale: locale,
    brightness: brightness,
    uiStyle: uiStyle,
  );
  await _replaceWithFakeLicenses(additionalEntries);

  final context = tester.element(find.byType(MyApp));
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(goRouterProvider).go('$settingsPath/$settingsLicensesRelativePath');
  await tester.pumpAndSettle();
}
