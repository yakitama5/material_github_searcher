import 'package:dependency_override/dependency_override.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/navigation/adaptive_app_shell.dart';
import 'package:material_github_searcher/src/repository/search/pages/repository_search_screen.dart';

import 'support/fake_search_history_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

final _messageProvider = Provider<String>((ref) => 'default');

void main() {
  testWidgets('アプリは検索ブランチから起動する', (tester) async {
    await tester.pumpWidget(
      createApp(config: _config, overrides: [searchHistoryTestOverride()]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RepositorySearchScreen), findsOneWidget);
  });

  testWidgets('createAppへ渡したProvider overrideを参照できる', (tester) async {
    await tester.pumpWidget(
      createApp(
        config: _config,
        overrides: [
          _messageProvider.overrideWithValue('injected'),
          searchHistoryTestOverride(),
        ],
      ),
    );

    final context = tester.element(find.byType(MyApp));
    final container = ProviderScope.containerOf(context, listen: false);

    expect(container.read(_messageProvider), 'injected');
  });

  testWidgets('Production overrideで起動できる', (tester) async {
    await tester.pumpWidget(
      createApp(config: _config, overrides: createProductionOverrides()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RepositorySearchScreen), findsOneWidget);
  });

  testWidgets('Mock overrideで起動できる', (tester) async {
    await tester.pumpWidget(
      createApp(config: _config, overrides: createMockOverrides()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RepositorySearchScreen), findsOneWidget);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'ThemeData.platformは$platformに追従する',
      (tester) async {
        await tester.pumpWidget(
          createApp(
            config: _config,
            overrides: [searchHistoryTestOverride()],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(AdaptiveAppShell));
        expect(Theme.of(context).platform, platform);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
