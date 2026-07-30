import 'dart:async';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/repository/search/pages/repository_search_screen.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_list_item.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_bar.dart';
import 'package:material_github_searcher/src/router/app_routes.dart';
import 'package:material_github_searcher/src/router/go_router_provider.dart';
import 'package:material_github_searcher/src/router/router_keys.dart';

import '../repository/search/support/fake_repository_search_repository.dart';
import '../support/fake_search_history_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

const _searchFieldKey = repositorySearchFieldKey;
const _submitButtonKey = repositorySearchSubmitButtonKey;

List<RepositorySummary> _manyRepositories(int count) => List.generate(
  count,
  (index) => RepositorySummary(
    identity: RepositoryIdentity(owner: 'owner$index', name: 'repo$index'),
    ownerAvatarUrl: 'https://example.invalid/avatars/owner$index.png',
    language: 'Dart',
    stargazersCount: index,
    forksCount: 0,
    openIssuesCount: 0,
  ),
);

/// Search内の縦scrollを行う本体のScrollable。SearchBar（TextField）内部の
/// 横scroll用Scrollableと区別するため、axisDirectionで絞り込む。
final _verticalScrollable = find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

void main() {
  testWidgets('402幅ではNavigationBarを表示する', (tester) async {
    await _pumpAtWidth(tester, 402);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('744幅ではextendedでないNavigationRailを表示する', (tester) async {
    await _pumpAtWidth(tester, 744);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('1024幅ではextendedのNavigationRailを表示する', (tester) async {
    await _pumpAtWidth(tester, 1024);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('NavigationBarでSettings branchを選択できる', (tester) async {
    await _pumpAtWidth(tester, 402);
    final router = _routerFor(tester);

    await _selectDestination(tester, 1);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(router.routeInformationProvider.value.uri.path, settingsPath);
  });

  testWidgets('branch切替後もSearchの検索結果とscroll位置を保持する', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    repository.setSuccess(
      query: query,
      page: RepositorySearchPage(
        items: _manyRepositories(30),
        totalCount: 30,
        nextPage: null,
        hasMore: false,
      ),
    );
    await _pumpAtWidth(tester, 402, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    await tester.drag(_verticalScrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(_verticalScrollable)
        .position
        .pixels;
    expect(offset, greaterThan(0));

    await _selectDestination(tester, 1);
    await _selectDestination(tester, 0);

    expect(find.byType(RepositoryListItem), findsWidgets);
    expect(
      tester.state<ScrollableState>(_verticalScrollable).position.pixels,
      closeTo(offset, 0.1),
    );
    // branch切替のみでは再検索が発生しない（保持であり再取得ではない）ことを
    // 呼出回数で確認する。
    expect(repository.calls, [query]);
  });

  testWidgets('Search branchから離脱すると進行中の検索をcancelする', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    final gate = Completer<void>();
    repository.setSuccess(
      query: query,
      page: RepositorySearchPage(
        items: _manyRepositories(1),
        totalCount: 1,
        nextPage: null,
        hasMore: false,
      ),
      gate: gate,
    );
    await _pumpAtWidth(tester, 402, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pump();

    final container = _containerFor(tester);
    expect(
      container.read(repositorySearchControllerProvider).status,
      RepositorySearchStatus.loading,
    );

    await _selectDestination(tester, 1);

    // cancel後に遅延応答が完了しても、cancel済みのrequestとして破棄され
    // Stateはloadingのまま変化しないことを確認する。
    gate.complete();
    await tester.pumpAndSettle();

    expect(
      container.read(repositorySearchControllerProvider).status,
      RepositorySearchStatus.loading,
    );
  });

  testWidgets('branch切替は各Navigatorのstackを保持する', (tester) async {
    await _pumpAtWidth(tester, 402);

    unawaited(
      searchBranchNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Search subpage')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _selectDestination(tester, 1);
    await _selectDestination(tester, 0);

    expect(find.text('Search subpage'), findsOneWidget);
  });

  testWidgets('現在のbranchを再選択するとrootへ戻る', (tester) async {
    await _pumpAtWidth(tester, 402);

    unawaited(
      searchBranchNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Search subpage')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _selectDestination(tester, 0);

    expect(find.text('Search subpage'), findsNothing);
    expect(find.byType(RepositorySearchScreen), findsOneWidget);
  });

  testWidgets('Settings branchのNavigator stackを保持する', (tester) async {
    await _pumpAtWidth(tester, 402);
    await _selectDestination(tester, 1);

    unawaited(
      settingsBranchNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Settings subpage')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _selectDestination(tester, 0);
    await _selectDestination(tester, 1);

    expect(find.text('Settings subpage'), findsOneWidget);
  });

  for (final locale in [
    (appLocale: AppLocale.ja, searchLabel: '検索', settingsLabel: '設定'),
    (appLocale: AppLocale.en, searchLabel: 'Search', settingsLabel: 'Settings'),
  ]) {
    testWidgets('${locale.appLocale}ではNavigationBarのラベルを表示する', (
      tester,
    ) async {
      await _pumpAtWidth(tester, 402, locale: locale.appLocale);

      final navigationBar = find.byType(NavigationBar);
      expect(
        find.descendant(
          of: navigationBar,
          matching: find.text(locale.searchLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: navigationBar,
          matching: find.text(locale.settingsLabel),
        ),
        findsOneWidget,
      );
    });

    testWidgets('${locale.appLocale}ではNavigationRailのラベルを表示する', (
      tester,
    ) async {
      await _pumpAtWidth(tester, 1024, locale: locale.appLocale);

      final navigationRail = find.byType(NavigationRail);
      expect(
        find.descendant(
          of: navigationRail,
          matching: find.text(locale.searchLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: navigationRail,
          matching: find.text(locale.settingsLabel),
        ),
        findsOneWidget,
      );
    });
  }
}

Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width, {
  AppLocale locale = AppLocale.ja,
  FakeRepositorySearchRepository? repository,
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
        if (repository != null)
          repositorySearchRepositoryProvider.overrideWith(
            (ref) => repository,
          ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _routerFor(WidgetTester tester) {
  return _containerFor(tester).read(goRouterProvider);
}

ProviderContainer _containerFor(WidgetTester tester) {
  final context = tester.element(find.byType(MyApp));
  return ProviderScope.containerOf(context, listen: false);
}

Future<void> _selectDestination(WidgetTester tester, int index) async {
  final navigationBar = find.byType(NavigationBar);
  await tester.tap(
    find.descendant(
      of: navigationBar,
      matching: find.byType(NavigationDestination).at(index),
    ),
  );
  await tester.pumpAndSettle();
}
