import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/router/app_routes.dart';
import 'package:material_github_searcher/src/router/go_router_provider.dart';
import 'package:material_github_searcher/src/router/router_keys.dart';

import '../support/fake_search_history_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

void main() {
  testWidgets('/searchと/settingsへ遷移できる', (tester) async {
    await tester.pumpWidget(
      createApp(config: _config, overrides: [searchHistoryTestOverride()]),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MyApp));
    final router = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(goRouterProvider);

    expect(router.routeInformationProvider.value.uri.path, searchPath);

    router.go(settingsPath);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, settingsPath);
    expect(find.text('Settings'), findsWidgets);
  });

  test('rootと各branchのNavigator keyをrouterが利用する', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(goRouterProvider);
    final shellRoute = router.configuration.routes.single as StatefulShellRoute;

    expect(router.configuration.navigatorKey, same(rootNavigatorKey));
    expect(shellRoute.branches[0].navigatorKey, same(searchBranchNavigatorKey));
    expect(
      shellRoute.branches[1].navigatorKey,
      same(settingsBranchNavigatorKey),
    );
  });
}
