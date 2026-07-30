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
  });
}
