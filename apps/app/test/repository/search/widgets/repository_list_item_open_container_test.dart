import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/repository/detail/pages/repository_detail_page.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_list_skeleton.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_bar.dart';

import '../../../support/fake_search_history_repository.dart';
import '../../detail/support/fake_repository_detail_repository.dart';
import '../support/fake_repository_search_repository.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

const _flutterIdentity = RepositoryIdentity(owner: 'flutter', name: 'flutter');

const _flutterRepo = RepositorySummary(
  identity: _flutterIdentity,
  ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
  language: 'Dart',
  stargazersCount: 160000,
  forksCount: 27000,
  openIssuesCount: 12000,
);

const _supplement = RepositoryDetailSupplement(
  identity: _flutterIdentity,
  subscribersCount: 9999,
);

/// OpenContainerの遷移animationを進めるのに十分な、既定transition durationを
/// 超える固定durationのpump。Detail初回buildがWatcher行を`SkeletonScope`で
/// 無限repeatするため、`pumpAndSettle`は使えない
/// （`repository_search_screen_test.dart`の`_settleWithoutLoopingAnimation`と
/// 同じ理由）。
const _transitionSettleDuration = Duration(milliseconds: 400);

RepositorySearchPage _singlePage(RepositorySummary item) =>
    RepositorySearchPage(
      items: [item],
      totalCount: 1,
      nextPage: null,
      hasMore: false,
    );

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

/// 現在pumpされているAppのRoot [ProviderContainer]を取得する。
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeRepositorySearchRepository searchRepository,
  required FakeRepositoryDetailRepository detailRepository,
  double width = 402,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    createApp(
      config: _config,
      overrides: [
        repositorySearchRepositoryProvider.overrideWith(
          (ref) => searchRepository,
        ),
        repositoryDetailRepositoryProvider.overrideWith(
          (ref) => detailRepository,
        ),
        searchHistoryTestOverride(),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(repositorySearchFieldKey), query);
  await tester.tap(find.byKey(repositorySearchSubmitButtonKey));
  await tester.pumpAndSettle();
}

/// [rowFinder]で見つけた行をtapし、OpenContainerの開き遷移を進める。
Future<void> _openDetailByTap(WidgetTester tester, Finder rowFinder) async {
  await tester.tap(rowFinder);
  await tester.pump();
  await tester.pump(_transitionSettleDuration);
}

/// Detail画面のback（戻る）矢印をtapし、閉じ遷移とautoDisposeの破棄
/// scheduler（`Timer(Duration.zero)`）をどちらも進める。
Future<void> _closeDetailByBackButton(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pump();
  await tester.pump(_transitionSettleDuration);
  // RiverpodのautoDispose判定はTimer(Duration.zero)経由のため、
  // 遷移完了後にさらに1frame分進めてdispose・cancelを確定させる。
  await tester.pump(Duration.zero);
  await tester.pump(Duration.zero);
}

void main() {
  group('RepositoryListItemOpenContainer', () {
    testWidgets('tap直後にAPI完了を待たずtransitionが開始しSummaryが即時表示される', (
      tester,
    ) async {
      final searchRepository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      searchRepository.setSuccess(
        query: query,
        page: _singlePage(_flutterRepo),
      );
      final detailRepository = FakeRepositoryDetailRepository();
      final gate = Completer<void>();
      detailRepository.setSuccess(
        identity: _flutterIdentity,
        supplement: _supplement,
        gate: gate,
      );

      await _pumpApp(
        tester,
        searchRepository: searchRepository,
        detailRepository: detailRepository,
      );
      await _submit(tester, 'flutter');

      await _openDetailByTap(tester, find.text('flutter/flutter'));

      expect(find.byType(RepositoryDetailPage), findsOneWidget);
      // Summaryは即時表示される（Detail APIの完了を待たない）。
      expect(find.text('flutter/flutter'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      // Watcherだけが未完了のためSkeleton。
      expect(find.byType(SkeletonText), findsOneWidget);
      expect(find.text('9,999'), findsNothing);
      expect(tester.takeException(), isNull);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('9,999'), findsOneWidget);
      expect(find.byType(SkeletonText), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('戻るボタンで逆animationし、未完了のDetail requestがcancelされる', (
      tester,
    ) async {
      final searchRepository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      searchRepository.setSuccess(
        query: query,
        page: _singlePage(_flutterRepo),
      );
      final detailRepository = FakeRepositoryDetailRepository();
      final gate = Completer<void>();
      detailRepository.setSuccess(
        identity: _flutterIdentity,
        supplement: _supplement,
        gate: gate,
      );

      await _pumpApp(
        tester,
        searchRepository: searchRepository,
        detailRepository: detailRepository,
      );
      await _submit(tester, 'flutter');
      await _openDetailByTap(tester, find.text('flutter/flutter'));

      expect(detailRepository.calls, [_flutterIdentity]);
      expect(detailRepository.cancelledIdentities, isEmpty);

      await _closeDetailByBackButton(tester);

      expect(find.byType(RepositoryDetailPage), findsNothing);
      // OpenContainerのcloseから実際にrepositoryDetailProviderのautoDispose
      // （onDispose→CancellationController.cancel）が発火したことを、Widget
      // Test経由で直接観測する（申し送り: PR #123 CodeRabbitレビューの議論、
      // #85のProvider testでは検証できない実UI操作からの経路）。
      expect(detailRepository.cancelledIdentities, [_flutterIdentity]);
      // cancelは通知用のSnackbarを表示しない。
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);

      // 検証後にgateを解決してもテスト終了後にpending Futureが残らないようにする。
      gate.complete();
    });

    testWidgets('Android系の システムback（ハードウェア/ジェスチャー）でも同様にcancelされる', (
      tester,
    ) async {
      final searchRepository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      searchRepository.setSuccess(
        query: query,
        page: _singlePage(_flutterRepo),
      );
      final detailRepository = FakeRepositoryDetailRepository();
      final gate = Completer<void>();
      detailRepository.setSuccess(
        identity: _flutterIdentity,
        supplement: _supplement,
        gate: gate,
      );

      await _pumpApp(
        tester,
        searchRepository: searchRepository,
        detailRepository: detailRepository,
      );
      await _submit(tester, 'flutter');
      await _openDetailByTap(tester, find.text('flutter/flutter'));

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(_transitionSettleDuration);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);

      expect(find.byType(RepositoryDetailPage), findsNothing);
      expect(detailRepository.cancelledIdentities, [_flutterIdentity]);
      expect(tester.takeException(), isNull);

      gate.complete();
    });

    testWidgets('backで一覧のitems・query・scroll位置が維持される', (tester) async {
      final searchRepository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      final items = _manyItems(30);
      searchRepository.setSuccess(
        query: query,
        page: _pageOf(items, totalCount: 30),
      );
      final detailRepository = FakeRepositoryDetailRepository();
      for (final item in items) {
        detailRepository.setSuccess(
          identity: item.identity,
          supplement: RepositoryDetailSupplement(
            identity: item.identity,
            subscribersCount: 1,
          ),
        );
      }

      await _pumpApp(
        tester,
        searchRepository: searchRepository,
        detailRepository: detailRepository,
      );
      await _submit(tester, 'flutter');

      // hasMore falseの30件を末尾までscrollし、item数に依存せず常に画面下端に
      // 見える最終itemを対象にする。
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pump();
      final scrollOffsetBefore = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;

      await _openDetailByTap(
        tester,
        find.text('owner/repo-29').hitTestable(),
      );
      await _closeDetailByBackButton(tester);

      expect(find.byType(RepositoryDetailPage), findsNothing);
      // 送信済みqueryはSearch Controller側のStateとして保持される
      // （SliverAppBar自体はfloating・末尾scroll中は画面外へ出るため、末尾
      // scroll状態のままではTextFieldがviewport内に無くwidget lookupできない）。
      expect(
        _container(tester).read(repositorySearchControllerProvider).query,
        query,
      );
      expect(find.text('owner/repo-29'), findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        scrollOffsetBefore,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('成功後5分以内の再openはRepositoryを再呼出しせずcacheした値を表示する', (
      tester,
    ) async {
      final searchRepository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      searchRepository.setSuccess(
        query: query,
        page: _singlePage(_flutterRepo),
      );
      final detailRepository = FakeRepositoryDetailRepository()
        ..setSuccess(identity: _flutterIdentity, supplement: _supplement);

      await _pumpApp(
        tester,
        searchRepository: searchRepository,
        detailRepository: detailRepository,
      );
      await _submit(tester, 'flutter');

      await _openDetailByTap(tester, find.text('flutter/flutter'));
      await tester.pump();
      expect(find.text('9,999'), findsOneWidget);
      expect(detailRepository.calls, [_flutterIdentity]);

      await _closeDetailByBackButton(tester);

      // cache期間内に再openする。
      await tester.pump(
        repositoryDetailCacheDuration - const Duration(seconds: 1),
      );
      await _openDetailByTap(tester, find.text('flutter/flutter'));

      // cacheされた値が初回frameから表示され、Repositoryは再呼出しされない。
      expect(find.text('9,999'), findsOneWidget);
      expect(find.byType(SkeletonText), findsNothing);
      expect(detailRepository.calls, [_flutterIdentity]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('成功後5分経過後の再openはRepositoryを再取得する', (tester) async {
      final searchRepository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      searchRepository.setSuccess(
        query: query,
        page: _singlePage(_flutterRepo),
      );
      final detailRepository = FakeRepositoryDetailRepository()
        ..setSuccess(identity: _flutterIdentity, supplement: _supplement);

      await _pumpApp(
        tester,
        searchRepository: searchRepository,
        detailRepository: detailRepository,
      );
      await _submit(tester, 'flutter');

      await _openDetailByTap(tester, find.text('flutter/flutter'));
      await tester.pump();
      expect(detailRepository.calls, [_flutterIdentity]);

      await _closeDetailByBackButton(tester);

      // cache期間を超えて経過させる。
      await tester.pump(
        repositoryDetailCacheDuration + const Duration(seconds: 1),
      );

      // 再取得時の初回frameでSkeletonが見えることを決定的に検証するため、
      // 次の応答にgateを設定してタイミングを制御する。
      final gate = Completer<void>();
      detailRepository.setSuccess(
        identity: _flutterIdentity,
        supplement: _supplement,
        gate: gate,
      );
      await _openDetailByTap(tester, find.text('flutter/flutter'));

      // Watcherが再度Skeletonから始まり、Repositoryが再呼出しされる。
      expect(find.byType(SkeletonText), findsOneWidget);
      expect(detailRepository.calls, [_flutterIdentity, _flutterIdentity]);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('9,999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Load More中のtapはSearch requestをcancelしてからDetailを開く', (
      tester,
    ) async {
      final searchRepository = FakeRepositorySearchRepository();
      final query = RepositorySearchQuery('flutter');
      final firstPageItems = _manyItems(30);
      final appendGate = Completer<void>();
      searchRepository
        ..setSuccess(
          query: query,
          page: _pageOf(firstPageItems, totalCount: 35, nextPage: 2),
        )
        ..setSuccess(
          query: query,
          page: _pageOf(_manyItems(5, startIndex: 30), totalCount: 35),
          pageNumber: 2,
          gate: appendGate,
        );
      final lastItem = firstPageItems.last;
      final detailRepository = FakeRepositoryDetailRepository()
        ..setSuccess(
          identity: lastItem.identity,
          supplement: RepositoryDetailSupplement(
            identity: lastItem.identity,
            subscribersCount: 1,
          ),
        );

      await _pumpApp(
        tester,
        searchRepository: searchRepository,
        detailRepository: detailRepository,
      );
      await _submit(tester, 'flutter');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pump();

      // 追加取得中（末尾Skeleton行）であることを確認してからtapする。
      expect(find.byType(RepositoryListItemSkeleton), findsOneWidget);

      await _openDetailByTap(
        tester,
        find.text('owner/repo-29').hitTestable(),
      );

      expect(find.byType(RepositoryDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _closeDetailByBackButton(tester);

      // 追加取得中Skeletonはcancelにより消え、末尾のSkeleton行は残らない
      // （RepositorySearchController.cancelPendingRequestがloadingMoreを
      // successへ戻す契約）。
      expect(find.byType(RepositoryListItemSkeleton), findsNothing);
      expect(tester.takeException(), isNull);

      appendGate.complete();
    });

    for (final width in [402.0, 744.0, 1024.0]) {
      testWidgets('幅${width}pxでDetailがBottom Navigation/Railを覆う', (
        tester,
      ) async {
        final searchRepository = FakeRepositorySearchRepository();
        final query = RepositorySearchQuery('flutter');
        searchRepository.setSuccess(
          query: query,
          page: _singlePage(_flutterRepo),
        );
        final detailRepository = FakeRepositoryDetailRepository()
          ..setSuccess(identity: _flutterIdentity, supplement: _supplement);

        await _pumpApp(
          tester,
          searchRepository: searchRepository,
          detailRepository: detailRepository,
          width: width,
        );
        await _submit(tester, 'flutter');

        await _openDetailByTap(tester, find.text('flutter/flutter'));

        final detailSize = tester.getSize(
          find
              .descendant(
                of: find.byType(RepositoryDetailPage),
                matching: find.byType(Scaffold),
              )
              .first,
        );
        // useRootNavigator:trueによりNavigationRail/NavigationBarを含む
        // シェル全体の上へ被さるため、Detail Scaffoldの幅はブランチ内の
        // Expanded領域（Rail分だけ狭い）ではなく画面全幅と一致する。高さも
        // 画面全高（900）と一致することで、compact幅のBottom Navigationが
        // 占める高さも覆っていることを確認する（widthだけの比較では
        // Bottom Navigationは高さ方向にしか場所を占めないため検出できない）。
        expect(detailSize.width, width);
        expect(detailSize.height, 900);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
