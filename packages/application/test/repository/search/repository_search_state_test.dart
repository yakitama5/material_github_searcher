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
  });
}
