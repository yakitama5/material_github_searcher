import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

RepositorySearchPage _page() => RepositorySearchPage(
  items: const [
    RepositorySummary(
      identity: RepositoryIdentity(owner: 'flutter', name: 'flutter'),
      ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
      language: 'Dart',
      stargazersCount: 1,
      forksCount: 0,
      openIssuesCount: 0,
    ),
  ],
  totalCount: 1,
  nextPage: 2,
  hasMore: true,
);

void main() {
  group('RepositorySearchState', () {
    test('initialは未検索を表す', () {
      const state = RepositorySearchState.initial();
      expect(state.status, RepositorySearchStatus.initial);
      expect(state.query, isNull);
      expect(state.items, isEmpty);
      expect(state.error, isNull);
    });

    test('successはpageの値からpage・hasMore・totalCountを取り込む', () {
      final state = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      );
      expect(state.status, RepositorySearchStatus.success);
      expect(state.page, 1);
      expect(state.hasMore, isTrue);
      expect(state.totalCount, 1);
    });

    test('itemsは変更不可でコピーされる', () {
      final state = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      );
      expect(
        () => state.items.add(state.items.first),
        throwsUnsupportedError,
      );
    });

    test('同じ内容のStateは等価である', () {
      final a = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      );
      final b = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('statusが異なるStateは等価でない', () {
      const initial = RepositorySearchState.initial();
      const loadingState = RepositorySearchState.loading(null);
      expect(initial, isNot(equals(loadingState)));
    });

    test('appendErrorのみが異なるStateは等価でない', () {
      final withoutAppendError = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      );
      final withAppendError = withoutAppendError.appendFailed(
        const RepositorySearchException(message: 'failed'),
      );
      expect(withoutAppendError, isNot(equals(withAppendError)));
      expect(
        withoutAppendError.hashCode,
        isNot(equals(withAppendError.hashCode)),
      );
    });

    test('toLoadingMoreはitems・page・hasMore・totalCountを維持し、'
        'statusをloadingMoreへ、appendErrorをnullへする', () {
      final success = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      ).appendFailed(const RepositorySearchException(message: 'failed'));

      final loadingMore = success.toLoadingMore();

      expect(loadingMore.status, RepositorySearchStatus.loadingMore);
      expect(loadingMore.query, success.query);
      expect(loadingMore.items, success.items);
      expect(loadingMore.page, success.page);
      expect(loadingMore.hasMore, success.hasMore);
      expect(loadingMore.totalCount, success.totalCount);
      expect(loadingMore.appendError, isNull);
    });

    test('appendedはitems・page・hasMore・totalCountを更新し、'
        'statusをsuccessへ、appendErrorをnullへする', () {
      final loadingMore = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      ).toLoadingMore();

      const appendedItem = RepositorySummary(
        identity: RepositoryIdentity(owner: 'dart-lang', name: 'sdk'),
        ownerAvatarUrl: 'https://example.invalid/avatars/dart-lang.png',
        language: 'C++',
        stargazersCount: 2,
        forksCount: 0,
        openIssuesCount: 0,
      );
      final appended = loadingMore.appended(
        items: [...loadingMore.items, appendedItem],
        page: 2,
        hasMore: false,
        totalCount: 2,
      );

      expect(appended.status, RepositorySearchStatus.success);
      expect(appended.items, [...loadingMore.items, appendedItem]);
      expect(appended.page, 2);
      expect(appended.hasMore, isFalse);
      expect(appended.totalCount, 2);
      expect(appended.appendError, isNull);
    });

    test('appendFailedはitems・page・hasMore・totalCountを維持し、'
        'statusをsuccessへ、appendErrorを設定する', () {
      final loadingMore = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      ).toLoadingMore();
      const exception = RepositorySearchException(message: 'failed');

      final appendFailed = loadingMore.appendFailed(exception);

      expect(appendFailed.status, RepositorySearchStatus.success);
      expect(appendFailed.items, loadingMore.items);
      expect(appendFailed.page, loadingMore.page);
      expect(appendFailed.hasMore, loadingMore.hasMore);
      expect(appendFailed.totalCount, loadingMore.totalCount);
      expect(appendFailed.appendError, same(exception));
    });

    test('toRefreshingはitems・page・hasMore・totalCountを維持し、'
        'statusをrefreshingへ、appendError・refreshErrorをnullへする', () {
      final success = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      ).appendFailed(const RepositorySearchException(message: 'append failed'));

      final refreshing = success.toRefreshing();

      expect(refreshing.status, RepositorySearchStatus.refreshing);
      expect(refreshing.query, success.query);
      expect(refreshing.items, success.items);
      expect(refreshing.page, success.page);
      expect(refreshing.hasMore, success.hasMore);
      expect(refreshing.totalCount, success.totalCount);
      expect(refreshing.appendError, isNull);
      expect(refreshing.refreshError, isNull);
    });

    test('refreshFailedはitems・page・hasMore・totalCountを維持し、'
        'statusをsuccessへ、refreshErrorを設定する', () {
      final refreshing = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      ).toRefreshing();
      const exception = RepositorySearchException(message: 'refresh failed');

      final refreshFailed = refreshing.refreshFailed(exception);

      expect(refreshFailed.status, RepositorySearchStatus.success);
      expect(refreshFailed.items, refreshing.items);
      expect(refreshFailed.page, refreshing.page);
      expect(refreshFailed.hasMore, refreshing.hasMore);
      expect(refreshFailed.totalCount, refreshing.totalCount);
      expect(refreshFailed.refreshError, same(exception));
    });

    test('cancelInFlightはloadingMore・refreshingどちらもsuccessへ戻す', () {
      final success = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      );

      final fromLoadingMore = success.toLoadingMore().cancelInFlight();
      expect(fromLoadingMore.status, RepositorySearchStatus.success);
      expect(fromLoadingMore.items, success.items);

      final fromRefreshing = success.toRefreshing().cancelInFlight();
      expect(fromRefreshing.status, RepositorySearchStatus.success);
      expect(fromRefreshing.items, success.items);

      // loadingMore・refreshingでなければ何もしない。
      expect(success.cancelInFlight(), same(success));
    });

    test(
      'refreshError設定後の無関係な遷移（toLoadingMore・appended・appendFailed）は'
      'refreshErrorをnullへ戻す',
      () {
        // refreshErrorは`ref.listen`がSnackbar表示の一過性トリガーとして
        // `next.refreshError != null`だけを見る前提のため、無関係な後続遷移で
        // 持ち越すと同じ通知が誤って再発火する（Issue #82実装時の回帰）。
        final withRefreshError =
            RepositorySearchState.success(
              query: RepositorySearchQuery('flutter'),
              result: _page(),
              page: 1,
            ).toRefreshing().refreshFailed(
              const RepositorySearchException(message: 'refresh failed'),
            );
        expect(withRefreshError.refreshError, isNotNull);

        expect(withRefreshError.toLoadingMore().refreshError, isNull);
        expect(
          withRefreshError
              .toLoadingMore()
              .appended(
                items: withRefreshError.items,
                page: 2,
                hasMore: false,
                totalCount: withRefreshError.totalCount,
              )
              .refreshError,
          isNull,
        );
        expect(
          withRefreshError
              .toLoadingMore()
              .appendFailed(
                const RepositorySearchException(message: 'append failed'),
              )
              .refreshError,
          isNull,
        );
      },
    );

    test('refreshErrorのみが異なるStateは等価でない', () {
      final withoutRefreshError = RepositorySearchState.success(
        query: RepositorySearchQuery('flutter'),
        result: _page(),
        page: 1,
      );
      final withRefreshError = withoutRefreshError.toRefreshing().refreshFailed(
        const RepositorySearchException(message: 'failed'),
      );

      expect(withoutRefreshError, isNot(equals(withRefreshError)));
      expect(
        withoutRefreshError.hashCode,
        isNot(equals(withRefreshError.hashCode)),
      );
    });
  });
}
