import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/navigation/adaptive_app_shell.dart';
import 'package:material_github_searcher/src/repository/search/pages/repository_search_screen.dart';

import '../support/fake_search_history_repository.dart';
import '../support/fake_theme_settings_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

ColorScheme _defaultLightColorScheme() =>
    AppTheme.resolve(const ThemeSettings()).light.colorScheme;

void main() {
  testWidgets('テーマ設定読込中も既定Themeで表示され空白画面にならない', (tester) async {
    final repository = FakeThemeSettingsRepository()..loadGate = Completer();

    await tester.pumpWidget(
      createApp(
        config: _config,
        overrides: [
          searchHistoryTestOverride(),
          themeSettingsTestOverride(repository: repository),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(RepositorySearchScreen), findsOneWidget);
    final context = tester.element(find.byType(AdaptiveAppShell));
    expect(Theme.of(context).colorScheme, _defaultLightColorScheme());
  });

  testWidgets('テーマ設定の読込失敗時も既定Themeで表示される', (tester) async {
    final repository = FakeThemeSettingsRepository()
      ..loadError = const ThemeSettingsPersistenceException();

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

    expect(find.byType(RepositorySearchScreen), findsOneWidget);
    final context = tester.element(find.byType(AdaptiveAppShell));
    expect(Theme.of(context).colorScheme, _defaultLightColorScheme());
  });

  testWidgets('テーマ設定の変更が再起動なしでroot全体へ反映される', (tester) async {
    final repository = FakeThemeSettingsRepository();

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

    final contextBefore = tester.element(find.byType(AdaptiveAppShell));
    expect(Theme.of(contextBefore).colorScheme, _defaultLightColorScheme());

    final container = ProviderScope.containerOf(contextBefore, listen: false);
    await container
        .read(themeSettingsProvider.notifier)
        .updateThemeColor(AppThemeColor.green);
    await tester.pumpAndSettle();

    final contextAfter = tester.element(find.byType(AdaptiveAppShell));
    expect(
      Theme.of(contextAfter).colorScheme,
      AppTheme.resolve(
        const ThemeSettings(themeColor: AppThemeColor.green),
      ).light.colorScheme,
    );
  });

  testWidgets('uiStyle=androidは実行OSに関わらずAndroidのUIになる', (tester) async {
    // ホストOSをiOS相当に固定し、AppUiStyle.androidが実行OSに関わらず
    // 強制されることを検証する。`addTearDown`はFlutterのinvariantチェック
    // （`_runTestBody`内で`testBody()`完了直後に走る）より後に実行される
    // ため使えず、test body自身のfinallyで同期的にリセットする。
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final repository = FakeThemeSettingsRepository(
        initialSettings: const ThemeSettings(uiStyle: AppUiStyle.android),
      );

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

      final context = tester.element(find.byType(AdaptiveAppShell));
      expect(Theme.of(context).platform, TargetPlatform.android);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
