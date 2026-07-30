import 'dart:async';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_list_skeleton.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_bar.dart';

import '../support/fake_repository_search_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

const _searchFieldKey = repositorySearchFieldKey;
const _submitButtonKey = repositorySearchSubmitButtonKey;
const _retryButtonKey = Key('repositorySearchRetryButton');

const _flutterRepo = RepositorySummary(
  identity: RepositoryIdentity(owner: 'flutter', name: 'flutter'),
  ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
  language: 'Dart',
  stargazersCount: 160000,
  forksCount: 27000,
  openIssuesCount: 12000,
);

const _nullLanguageRepo = RepositorySummary(
  identity: RepositoryIdentity(owner: 'octocat', name: 'no-language-repo'),
  ownerAvatarUrl: 'https://example.invalid/avatars/octocat.png',
  language: null,
  stargazersCount: 1,
  forksCount: 0,
  openIssuesCount: 0,
);

const _longNameRepo = RepositorySummary(
  identity: RepositoryIdentity(
    owner: 'an-organization-with-an-unusually-long-account-name',
    name: 'a-repository-with-an-equally-unusually-long-descriptive-name',
  ),
  ownerAvatarUrl: 'https://example.invalid/avatars/long-name-owner.png',
  language: 'Dart',
  stargazersCount: 42,
  forksCount: 7,
  openIssuesCount: 1,
);

const _brokenAvatarRepo = RepositorySummary(
  identity: RepositoryIdentity(owner: 'broken-avatar', name: 'sample-repo'),
  ownerAvatarUrl: 'https://owner-icon.invalid/missing-avatar.png',
  language: 'Dart',
  stargazersCount: 9,
  forksCount: 2,
  openIssuesCount: 0,
);

RepositorySearchPage _singlePage(RepositorySummary item) =>
    RepositorySearchPage(
      items: [item],
      totalCount: 1,
      nextPage: null,
      hasMore: false,
    );

void main() {
  testWidgets('未検索時は利用案内を表示する', (tester) async {
    await _pumpSearchScreen(
      tester,
      repository: FakeRepositorySearchRepository(),
    );

    expect(
      find.text(AppLocale.ja.translations.repositorySearch.guidance),
      findsOneWidget,
    );
  });

  testWidgets('keyboard submitで検索を実行する', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.calls, [query]);
    expect(find.text('flutter/flutter'), findsOneWidget);
  });

  testWidgets('search buttonタップで検索を実行する', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(repository.calls, [query]);
    expect(find.text('flutter/flutter'), findsOneWidget);
  });

  testWidgets('入力中はAPIを呼び出さない', (tester) async {
    final repository = FakeRepositorySearchRepository();
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.pump();

    expect(repository.calls, isEmpty);
  });

  testWidgets('trim後に空文字となる入力はAPIを呼び出さない', (tester) async {
    final repository = FakeRepositorySearchRepository();
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), '   ');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.byType(RepositoryListSkeleton), findsNothing);
  });

  testWidgets('初回loading中はSkeletonを表示しSearchBarを操作できる', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    final gate = Completer<void>();
    repository.setSuccess(
      query: query,
      page: _singlePage(_flutterRepo),
      gate: gate,
    );
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pump();

    expect(find.byType(RepositoryListSkeleton), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(_searchFieldKey)).enabled,
      isNot(false),
    );
    await tester.enterText(find.byKey(_searchFieldKey), 'flutter2');
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('data時に0件ならEmpty表示になる', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('no-such-repo');
    repository.setSuccess(
      query: query,
      page: RepositorySearchPage(
        items: const [],
        totalCount: 0,
        nextPage: null,
        hasMore: false,
      ),
    );
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'no-such-repo');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocale.ja.translations.repositorySearch.empty),
      findsOneWidget,
    );
  });

  testWidgets('initial error時はqueryを保持しretryできる', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    repository.setFailure(
      query: query,
      exception: const RepositorySearchException(message: 'boom'),
    );
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocale.ja.translations.repositorySearch.errorGeneric),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byKey(_searchFieldKey)).controller?.text,
      'flutter',
    );

    repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
    await tester.tap(find.byKey(_retryButtonKey));
    await tester.pumpAndSettle();

    expect(repository.calls, [query, query]);
    expect(find.text('flutter/flutter'), findsOneWidget);
  });

  testWidgets('Rate Limit時は専用文言を表示する', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    repository.setFailure(
      query: query,
      exception: const RepositorySearchException(
        message:
            'GitHub API rate limit exceeded (status: 429, '
            'remaining: 0, reset: 1700000000)',
      ),
    );
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocale.ja.translations.repositorySearch.errorRateLimited),
      findsOneWidget,
    );
    expect(
      find.text(AppLocale.ja.translations.repositorySearch.errorGeneric),
      findsNothing,
    );
  });

  testWidgets('languageがnullの場合はローカライズした未設定を表示する', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('octocat');
    repository.setSuccess(query: query, page: _singlePage(_nullLanguageRepo));
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'octocat');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocale.ja.translations.repositorySearch.languageUnset),
      findsOneWidget,
    );
  });

  testWidgets('非常に長い名前でも例外を投げずに表示する', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('long-name');
    repository.setSuccess(query: query, page: _singlePage(_longNameRepo));
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'long-name');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining(_longNameRepo.identity.name), findsOneWidget);
  });

  testWidgets('text scaleを大きくしても例外を投げずに表示する', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('flutter/flutter'), findsOneWidget);
  });

  testWidgets('owner iconの読み込み失敗時はfallback avatarを表示する', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('broken-avatar');
    repository.setSuccess(query: query, page: _singlePage(_brokenAvatarRepo));
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'broken-avatar');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('Semanticsにリポジトリ名と主要情報が含まれる', (tester) async {
    final repository = FakeRepositorySearchRepository();
    final query = RepositorySearchQuery('flutter');
    repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
    final handle = tester.ensureSemantics();
    await _pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
    await tester.tap(find.byKey(_submitButtonKey));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.text('flutter/flutter'));
    expect(semantics.label, contains('flutter/flutter'));
    expect(semantics.label, contains('Dart'));
    expect(semantics.label, contains('160000'));
    handle.dispose();
  });

  for (final locale in [AppLocale.ja, AppLocale.en]) {
    testWidgets('$localeでは未検索案内をローカライズして表示する', (tester) async {
      await _pumpSearchScreen(
        tester,
        repository: FakeRepositorySearchRepository(),
        locale: locale,
      );

      expect(
        find.text(locale.translations.repositorySearch.guidance),
        findsOneWidget,
      );
    });
  }

  for (final width in [402.0, 744.0, 1024.0]) {
    testWidgets('幅$widthでも例外を投げず表示する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      await _pumpSearchScreen(tester, repository: repository, width: width);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('flutter/flutter'), findsOneWidget);
    });
  }
}

Future<void> _pumpSearchScreen(
  WidgetTester tester, {
  required FakeRepositorySearchRepository repository,
  double width = 402,
  AppLocale locale = AppLocale.ja,
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
        repositorySearchRepositoryProvider.overrideWith((ref) => repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}
