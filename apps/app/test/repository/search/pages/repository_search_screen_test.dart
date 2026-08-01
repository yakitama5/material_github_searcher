import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/repository/search/pages/repository_search_screen.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_list_item.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_list_skeleton.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_bar.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_empty.dart';
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

/// 無限スクロールの検証用に、viewportに収まらない件数のitemsを生成する。
List<RepositorySummary> _manyItems(int count, {int startIndex = 0}) =>
    List.generate(
      count,
      (i) => RepositorySummary(
        identity: RepositoryIdentity(
          owner: 'owner',
          name: 'repo-${startIndex + i}',
        ),
        ownerAvatarUrl:
            'https://example.invalid/avatars/repo-${startIndex + i}.png',
        language: 'Dart',
        stargazersCount: startIndex + i,
        forksCount: 0,
        openIssuesCount: 0,
      ),
    );

RepositorySearchPage _pageOf(
  List<RepositorySummary> items, {
  required int totalCount,
  int? nextPage,
}) => RepositorySearchPage(
  items: items,
  totalCount: totalCount,
  nextPage: nextPage,
  hasMore: nextPage != null,
);

/// 大きく上方向へdragし、その時点のスクロール可能範囲の末尾付近まで進める。
///
/// drag対象には[RepositoryListItem]ではなく[CustomScrollView]自体を使う。
/// スクロール後は先頭付近のitemがviewport外（cache extentの外）へ外れて
/// hit-testできなくなることがあるため、常にviewport全体を覆う
/// [CustomScrollView]を対象にする。末尾のSkeleton・追加item・error行は
/// 追加取得の状態変化に応じて末尾の可スクロール範囲自体が伸びるため、直前の
/// 末尾より後に描画される要素を見るには本関数を複数回呼び出す必要がある。
Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
}

/// 上端で下方向へfling操作し、Pull to Refreshのgestureを発生させる。
///
/// `RefreshIndicator`（`RefreshIndicatorTriggerMode.onEdge`が既定）は
/// scrollが先頭（`extentBefore == 0`）にあるときのdragだけを認識するため、
/// 呼び出し前にscroll位置が先頭にある前提とする。
Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// 非同期の検索結果反映を待つ。
///
/// [RepositorySearchEmpty]はReduce Motion無効時にLottieアニメーションを
/// 無限repeatするため、Empty表示に到達しうる操作の後で`pumpAndSettle`を
/// 使うとタイムアウトする。固定回数のpumpで代替する。
Future<void> _settleWithoutLoopingAnimation(WidgetTester tester) async {
  await tester.pump();
  // `_pullToRefresh`と同じ1秒のバッファで、低速なCI環境でもLottie
  // compositionの非同期読み込みや状態反映が確実に完了してから検証する。
  await tester.pump(const Duration(seconds: 1));
}

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
    await _settleWithoutLoopingAnimation(tester);

    expect(find.byType(RepositorySearchEmpty), findsOneWidget);
    expect(
      find.text(AppLocale.ja.translations.repositorySearch.emptyTitle),
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

  for (final locale in [AppLocale.ja, AppLocale.en]) {
    testWidgets('$localeでは0件成功時にEmptyの見出し・補助文をローカライズして表示する', (
      tester,
    ) async {
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
      await _pumpSearchScreen(tester, repository: repository, locale: locale);

      await tester.enterText(find.byKey(_searchFieldKey), 'no-such-repo');
      await tester.tap(find.byKey(_submitButtonKey));
      await _settleWithoutLoopingAnimation(tester);

      expect(
        find.text(locale.translations.repositorySearch.emptyTitle),
        findsOneWidget,
      );
      expect(
        find.text(locale.translations.repositorySearch.emptyHint),
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

  for (final width in [402.0, 744.0, 1024.0]) {
    testWidgets('幅$widthのEmpty表示でも例外を投げず表示する', (tester) async {
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
      await _pumpSearchScreen(tester, repository: repository, width: width);

      await tester.enterText(find.byKey(_searchFieldKey), 'no-such-repo');
      await tester.tap(find.byKey(_submitButtonKey));
      await _settleWithoutLoopingAnimation(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(RepositorySearchEmpty), findsOneWidget);
    });
  }

  group('無限スクロール', () {
    testWidgets('末尾までスクロールするとpage2を取得して一覧へ追加する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository
        ..setSuccess(
          query: query,
          page: _pageOf(_manyItems(30), totalCount: 35, nextPage: 2),
        )
        ..setSuccess(
          query: query,
          page: _pageOf(_manyItems(5, startIndex: 30), totalCount: 35),
          pageNumber: 2,
        );
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      await _scrollToBottom(tester);
      await tester.pumpAndSettle();

      expect(repository.pageCalls, [(query, 1), (query, 2)]);

      // page2追加直後は可スクロール範囲が伸びた分だけ再度スクロールしないと
      // 末尾の新規itemが描画範囲（cache extent）に入らない。
      await _scrollToBottom(tester);
      await tester.pumpAndSettle();

      expect(find.text('owner/repo-34'), findsOneWidget);
    });

    testWidgets('追加取得中は末尾に1行Skeletonだけ表示し既存一覧を維持する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      final gate = Completer<void>();
      repository
        ..setSuccess(
          query: query,
          page: _pageOf(_manyItems(30), totalCount: 35, nextPage: 2),
        )
        ..setSuccess(
          query: query,
          page: _pageOf(_manyItems(5, startIndex: 30), totalCount: 35),
          pageNumber: 2,
          gate: gate,
        );
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      await _scrollToBottom(tester);
      await tester.pump();
      // loadingMoreへ遷移した直後は末尾Skeleton行の分だけ可スクロール範囲が
      // 伸びるため、それを描画範囲へ収めるために再度スクロールする。
      await _scrollToBottom(tester);
      await tester.pump();

      expect(find.byType(RepositoryListItemSkeleton), findsOneWidget);
      expect(find.byType(RepositoryListSkeleton), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(RepositoryListItemSkeleton), findsNothing);

      await _scrollToBottom(tester);
      await tester.pumpAndSettle();

      expect(find.text('owner/repo-34'), findsOneWidget);
    });

    testWidgets('追加取得の失敗時は末尾にRetry行を表示し、タップで再試行できる', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository
        ..setSuccess(
          query: query,
          page: _pageOf(_manyItems(30), totalCount: 35, nextPage: 2),
        )
        ..setFailure(
          query: query,
          exception: const RepositorySearchException(
            message: 'append failed',
          ),
          pageNumber: 2,
        );
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      await _scrollToBottom(tester);
      await tester.pumpAndSettle();
      // 追加取得失敗（末尾Error/Retry行の追加）で伸びた可スクロール範囲を
      // 描画範囲へ収めるため、再度スクロールする。
      await _scrollToBottom(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocale.ja.translations.repositorySearch.errorGeneric),
        findsOneWidget,
      );
      expect(
        find.byKey(repositoryAppendErrorRetryButtonKey),
        findsOneWidget,
      );
      expect(find.text('owner/repo-34'), findsNothing);

      repository.setSuccess(
        query: query,
        page: _pageOf(
          _manyItems(5, startIndex: 30),
          totalCount: 35,
        ),
        pageNumber: 2,
      );
      await tester.tap(
        find.byKey(repositoryAppendErrorRetryButtonKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocale.ja.translations.repositorySearch.errorGeneric),
        findsNothing,
      );

      await _scrollToBottom(tester);
      await tester.pumpAndSettle();

      expect(find.text('owner/repo-34'), findsOneWidget);
    });

    testWidgets('hasMore falseでは末尾スクロールしても追加requestを呼ばない', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(
        query: query,
        page: _pageOf(_manyItems(30), totalCount: 30),
      );
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      await _scrollToBottom(tester);
      await tester.pumpAndSettle();

      expect(repository.pageCalls, [(query, 1)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SearchBar内部scroll（cursor追従）では追加requestを呼ばない', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(
        query: query,
        page: _pageOf(_manyItems(30), totalCount: 35, nextPage: 2),
      );
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      // SearchBarへ再フォーカスし、field幅を超える長文を入力する。
      // EditableText自身のScrollable（横scroll）がcursor追従のため
      // ScrollNotificationを発するが、これはCustomScrollView自身の末尾
      // scrollではないため、追加requestを誘発してはならない。
      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(_searchFieldKey),
        'a very very very very very very very long query text',
      );
      // cursor追従scrollはScrollPositionのanimateToによる複数frameの
      // アニメーションのため、1回のpumpでは進行せずpumpAndSettleが必要。
      await tester.pumpAndSettle();

      expect(repository.pageCalls, [(query, 1)]);
    });
  });

  group('Pull to Refresh', () {
    testWidgets('成功でpage1の新しい結果へ置換する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('flutter/flutter'), findsOneWidget);

      repository.setSuccess(
        query: query,
        page: _singlePage(_nullLanguageRepo),
      );
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(find.text('flutter/flutter'), findsNothing);
      expect(find.text('octocat/no-language-repo'), findsOneWidget);
      expect(repository.pageCalls.where((c) => c.$2 == 1).length, 2);
    });

    testWidgets('0件成功はEmpty表示へ置換する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      repository.setSuccess(
        query: query,
        page: RepositorySearchPage(
          items: const [],
          totalCount: 0,
          nextPage: null,
          hasMore: false,
        ),
      );
      await _pullToRefresh(tester);
      await _settleWithoutLoopingAnimation(tester);

      expect(find.text('flutter/flutter'), findsNothing);
      expect(find.byType(RepositorySearchEmpty), findsOneWidget);
      expect(
        find.text(AppLocale.ja.translations.repositorySearch.emptyTitle),
        findsOneWidget,
      );
    });

    testWidgets('失敗時は既存itemsを維持しSnackbarでRetryを提供する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      await _pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();

      repository.setFailure(
        query: query,
        exception: const RepositorySearchException(message: 'boom'),
      );
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();

      // 既存の一覧は維持し、全画面Error表示へは切り替えない。
      expect(find.text('flutter/flutter'), findsOneWidget);
      expect(
        find.text(AppLocale.ja.translations.repositorySearch.errorGeneric),
        findsOneWidget,
      );
      final retryLabel = AppLocale.ja.translations.repositorySearch.retry;
      expect(find.text(retryLabel), findsOneWidget);

      repository.setSuccess(
        query: query,
        page: _singlePage(_nullLanguageRepo),
      );
      await tester.tap(find.text(retryLabel));
      await tester.pumpAndSettle();

      expect(find.text('octocat/no-language-repo'), findsOneWidget);
    });

    testWidgets('未検索・初回error中はpull gestureを無視する', (tester) async {
      final repository = FakeRepositorySearchRepository();
      await _pumpSearchScreen(tester, repository: repository);

      // 未検索
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(repository.pageCalls, isEmpty);

      // 初回error
      final query = RepositorySearchQuery('flutter');
      repository.setFailure(
        query: query,
        exception: const RepositorySearchException(message: 'boom'),
      );
      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();
      expect(repository.pageCalls, [(query, 1)]);

      await _pullToRefresh(tester);
      await tester.pumpAndSettle();
      expect(repository.pageCalls, [(query, 1)]);
    });

    testWidgets('refreshは検索履歴へ記録しない', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      final historyRepository = FakeSearchHistoryRepository();
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
      await tester.tap(find.byKey(_submitButtonKey));
      await tester.pumpAndSettle();
      final saveCallCountAfterSubmit = historyRepository.saveCallCount;

      repository.setSuccess(
        query: query,
        page: _singlePage(_nullLanguageRepo),
      );
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(historyRepository.saveCallCount, saveCallCountAfterSubmit);
    });

    testWidgets('空一覧でもpull gestureで再取得できる', (tester) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('none');
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

      await tester.enterText(find.byKey(_searchFieldKey), 'none');
      await tester.tap(find.byKey(_submitButtonKey));
      await _settleWithoutLoopingAnimation(tester);
      expect(find.byType(RepositorySearchEmpty), findsOneWidget);
      expect(
        find.text(AppLocale.ja.translations.repositorySearch.emptyTitle),
        findsOneWidget,
      );

      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      await _pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(find.text('flutter/flutter'), findsOneWidget);
      expect(repository.pageCalls.where((c) => c.$2 == 1).length, 2);
    });

    testWidgets('Empty表示中のrefresh失敗はEmptyを維持しSnackbarでRetryを提供する', (
      tester,
    ) async {
      final repository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('none');
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

      await tester.enterText(find.byKey(_searchFieldKey), 'none');
      await tester.tap(find.byKey(_submitButtonKey));
      await _settleWithoutLoopingAnimation(tester);
      expect(find.byType(RepositorySearchEmpty), findsOneWidget);

      repository.setFailure(
        query: query,
        exception: const RepositorySearchException(message: 'boom'),
      );
      await _pullToRefresh(tester);
      await _settleWithoutLoopingAnimation(tester);

      // Emptyのままで全画面Error表示へは切り替えない。
      expect(find.byType(RepositorySearchEmpty), findsOneWidget);
      expect(
        find.text(AppLocale.ja.translations.repositorySearch.errorGeneric),
        findsOneWidget,
      );
      final retryLabel = AppLocale.ja.translations.repositorySearch.retry;
      expect(find.text(retryLabel), findsOneWidget);

      repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
      await tester.tap(find.text(retryLabel));
      await tester.pumpAndSettle();

      expect(find.text('flutter/flutter'), findsOneWidget);
    });

    for (final locale in [AppLocale.ja, AppLocale.en]) {
      testWidgets('pull中は${locale.languageCode}のpull用Semantics labelを読み上げる', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final repository = FakeRepositorySearchRepository();
        final query = RepositorySearchQuery('flutter');
        repository.setSuccess(query: query, page: _singlePage(_flutterRepo));
        await _pumpSearchScreen(
          tester,
          repository: repository,
          locale: locale,
        );

        await tester.enterText(find.byKey(_searchFieldKey), 'flutter');
        await tester.tap(find.byKey(_submitButtonKey));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CustomScrollView)),
        );
        await gesture.moveBy(const Offset(0, 200));
        await tester.pump();

        expect(
          find.bySemanticsLabel(locale.translations.repositorySearch.pulling),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            locale.translations.repositorySearch.refreshing,
          ),
          findsNothing,
        );

        await gesture.up();
        await tester.pumpAndSettle();
        handle.dispose();
      });
    }

    testWidgets('未検索中はdragしてもIndicatorが表示されない', (tester) async {
      final repository = FakeRepositorySearchRepository();
      await _pumpSearchScreen(tester, repository: repository);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();

      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('初回loading中(Skeleton表示)はdragしてもIndicatorが表示されない', (
      tester,
    ) async {
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

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();

      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsNothing);

      await gesture.up();
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('初回error中はdragしてもIndicatorが表示されない', (tester) async {
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

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();

      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

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

    testWidgets('フォーカス時に履歴を最近送信順で表示する', (tester) async {
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

    testWidgets('SearchHistoryが返す最大10件の一覧をそのまま表示する', (tester) async {
      // 最大10件への切り捨て自体はdomainの不変条件
      // （packages/domain/test/search_history/search_history_test.dart
      // 「最大10件を超える古い履歴は切り捨てる」で検証済み）。ここでは画面が
      // SearchHistory.entriesをそのまま・順序を保って描画することだけを見る。
      var history = SearchHistory();
      for (var i = 0; i < 12; i++) {
        history = history.recordSubmittedKeyword('keyword$i');
      }
      final repository = FakeRepositorySearchRepository();
      final historyRepository = FakeSearchHistoryRepository(
        initialHistory: history,
      );
      await _pumpSearchScreen(
        tester,
        repository: repository,
        historyRepository: historyRepository,
      );

      await tester.tap(find.byKey(_searchFieldKey));
      await tester.pumpAndSettle();

      expect(
        _suggestionKeywords(tester),
        history.entries.map((e) => e.keyword),
      );
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
