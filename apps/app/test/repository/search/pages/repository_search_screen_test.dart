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
import 'package:material_github_searcher/src/repository/search/widgets/search_history_suggestions.dart';

import '../../../support/fake_search_history_repository.dart';
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

  group('検索履歴サジェスト', () {
    testWidgets('候補タップで即座に検索を実行しSearchBarへ反映する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('dart');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory()
            .recordSubmittedKeyword('dart')
            .recordSubmittedKeyword('flutter'),
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('dart'));
      await tester.pumpAndSettle();

      expect(repository.calls, [query]);
      expect(
        tester.widget<TextField>(find.byKey(_searchFieldKey)).controller?.text,
        'dart',
      );
    });

    testWidgets('フォーカス時に最近送信順で最大10件の履歴を表示する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory()
            .recordSubmittedKeyword('dart')
            .recordSubmittedKeyword('flutter'),
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      expect(find.byKey(repositorySearchHistorySuggestionsKey), findsNothing);

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();

      expect(find.byKey(repositorySearchHistorySuggestionsKey), findsOneWidget);
      expect(_suggestionKeywords(tester), ['flutter', 'dart']);
    });

    testWidgets('履歴0件時はフォーカスしてもサジェスト領域を表示しない', (tester) async {
      final repository = FakeRepositorySearchRepository();
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: FakeSearchHistoryRepository(),
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();

      expect(find.byKey(repositorySearchHistorySuggestionsKey), findsNothing);
    });

    testWidgets('入力するとtrim・大文字小文字を無視して候補を絞り込む', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory()
            .recordSubmittedKeyword('Dart')
            .recordSubmittedKeyword('flutter'),
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();
      expect(_suggestionKeywords(tester), ['flutter', 'Dart']);

      await tester.enterText(find.byKey(_searchFieldKey), '  DA  ');
      await tester.pump();

      expect(_suggestionKeywords(tester), ['Dart']);
      expect(repository.calls, isEmpty);
    });

    testWidgets('絞り込みで候補が0件になったらサジェスト領域自体を表示しない', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory()
            .recordSubmittedKeyword('dart')
            .recordSubmittedKeyword('flutter'),
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();
      expect(find.byKey(repositorySearchHistorySuggestionsKey), findsOneWidget);

      await tester.enterText(find.byKey(_searchFieldKey), 'no-such-keyword');
      await tester.pump();

      expect(find.byKey(repositorySearchHistorySuggestionsKey), findsNothing);
    });

    testWidgets('通常送信でも履歴を先頭へ記録する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory().recordSubmittedKeyword('dart'),
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      // 送信直後はSearchBarに送信済みのkeywordがそのまま残るため、絞り込み
      // を受けない状態を確認するために一度空にしてから再フォーカスする。
      await tester.enterText(find.byKey(_searchFieldKey), '');
      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();

      expect(_suggestionKeywords(tester), ['flutter', 'dart']);
    });

    testWidgets('全削除は確認Dialogを表示しキャンセルでは履歴を変更しない', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory().recordSubmittedKeyword('dart'),
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(repositorySearchHistoryClearAllButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(repositorySearchHistoryClearAllCancelKey),
        findsOneWidget,
      );
      await tester.tap(find.byKey(repositorySearchHistoryClearAllCancelKey));
      await tester.pumpAndSettle();

      expect(_suggestionKeywords(tester), ['dart']);
    });

    testWidgets('全削除は確認Dialogで確定すると履歴を削除する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory().recordSubmittedKeyword('dart'),
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(repositorySearchHistoryClearAllButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(repositorySearchHistoryClearAllConfirmKey));
      await tester.pumpAndSettle();

      expect(find.byKey(repositorySearchHistorySuggestionsKey), findsNothing);
    });

    testWidgets('load失敗時もRepository検索を継続する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      final historyRepository = FakeSearchHistoryRepository()
        ..loadError = const SearchHistoryPersistenceException(
          message: 'load failed',
        );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.calls, [query]);
      expect(find.text('flutter/flutter'), findsOneWidget);
    });

    testWidgets('save失敗時もRepository検索を継続する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      final historyRepository = FakeSearchHistoryRepository()
        ..saveError = const SearchHistoryPersistenceException(
          message: 'save failed',
        );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.calls, [query]);
      expect(find.text('flutter/flutter'), findsOneWidget);
    });

    for (final locale in [AppLocale.ja, AppLocale.en]) {
      testWidgets('$localeでは検索履歴見出し・全削除ラベルをローカライズして表示する', (tester) async {
        final repository = FakeRepositorySearchRepository();
        final historyRepository = FakeSearchHistoryRepository(
          initialHistory: SearchHistory().recordSubmittedKeyword('flutter'),
        );
        await _pumpSearchScreen(
          tester,
          repository: repository,
          historyRepository: historyRepository,
          locale: locale,
        );

        await tester.tap(find.byKey(_searchFieldKey));
        await tester.pumpAndSettle();

        final i18n = locale.translations.repositorySearch;
        expect(find.text(i18n.historySuggestionsLabel), findsOneWidget);
        expect(find.text(i18n.historyClearAllLabel), findsOneWidget);
      });
    }

    testWidgets('Semanticsに候補keywordと全削除ボタンのラベルが含まれる', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: SearchHistory().recordSubmittedKeyword('flutter'),
      );
      final handle = tester.ensureSemantics();
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();

      final suggestionSemantics = tester.getSemantics(
        find.byKey(repositorySearchHistorySuggestionItemKey('flutter')),
      );
      expect(suggestionSemantics.label, contains('flutter'));

      final clearAllSemantics = tester.getSemantics(
        find.byKey(repositorySearchHistoryClearAllButtonKey),
      );
      expect(clearAllSemantics.label, isNotEmpty);
      handle.dispose();
    });
  });
}

/// [SearchHistorySuggestions]へ渡された候補keywordを表示順で取得する。
List<String> _suggestionKeywords(WidgetTester tester) => tester
    .widget<SearchHistorySuggestions>(find.byType(SearchHistorySuggestions))
    .entries
    .map((entry) => entry.keyword)
    .toList();

Future<void> _pumpSearchScreen(
  WidgetTester tester, {
  required FakeRepositorySearchRepository repository,
  double width = 402,
  AppLocale locale = AppLocale.ja,
  FakeSearchHistoryRepository? historyRepository,
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
        searchHistoryTestOverride(repository: historyRepository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}
