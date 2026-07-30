import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('RepositorySearchPage', () {
    const identity = RepositoryIdentity(owner: 'flutter', name: 'flutter');
    const summary = RepositorySummary(
      identity: identity,
      ownerAvatarUrl: 'https://example.com/avatar.png',
      language: 'Dart',
      stargazersCount: 1,
      forksCount: 2,
      openIssuesCount: 3,
    );

    test('次ページが存在する場合はhasMoreがtrue・nextPageが非null', () {
      const page = RepositorySearchPage(
        items: [summary],
        totalCount: 100,
        nextPage: 2,
        hasMore: true,
      );

      expect(page.hasMore, isTrue);
      expect(page.nextPage, 2);
    });

    test('最終ページの場合はhasMoreがfalse・nextPageがnull', () {
      const page = RepositorySearchPage(
        items: [summary],
        totalCount: 1,
        nextPage: null,
        hasMore: false,
      );

      expect(page.hasMore, isFalse);
      expect(page.nextPage, isNull);
    });

    test('該当0件のページを表現できる', () {
      const page = RepositorySearchPage(
        items: [],
        totalCount: 0,
        nextPage: null,
        hasMore: false,
      );

      expect(page.items, isEmpty);
      expect(page.totalCount, 0);
    });

    test('hasMoreとnextPageが矛盾する場合はAssertionErrorを投げる', () {
      expect(
        () => RepositorySearchPage(
          items: const [],
          totalCount: 0,
          nextPage: 2,
          hasMore: false,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RepositorySearchPage(
          items: const [],
          totalCount: 0,
          nextPage: null,
          hasMore: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('items・totalCount・nextPage・hasMoreが等しければ等価である', () {
      const a = RepositorySearchPage(
        items: [summary],
        totalCount: 100,
        nextPage: 2,
        hasMore: true,
      );
      const b = RepositorySearchPage(
        items: [summary],
        totalCount: 100,
        nextPage: 2,
        hasMore: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('itemsの並び順が異なれば等価にならない', () {
      const identity2 = RepositoryIdentity(owner: 'flutter', name: 'engine');
      const summary2 = RepositorySummary(
        identity: identity2,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'C++',
        stargazersCount: 4,
        forksCount: 5,
        openIssuesCount: 6,
      );
      const a = RepositorySearchPage(
        items: [summary, summary2],
        totalCount: 2,
        nextPage: null,
        hasMore: false,
      );
      const b = RepositorySearchPage(
        items: [summary2, summary],
        totalCount: 2,
        nextPage: null,
        hasMore: false,
      );

      expect(a, isNot(equals(b)));
    });

    test(
      'totalCountが異なる、または(nextPage・hasMore)の組が異なれば等価にならない',
      () {
        // hasMoreとnextPageはassertで連動するため独立には変えられず、
        // ページング状態の組として差分を検証する。
        const base = RepositorySearchPage(
          items: [summary],
          totalCount: 100,
          nextPage: 2,
          hasMore: true,
        );
        const differentTotalCount = RepositorySearchPage(
          items: [summary],
          totalCount: 999,
          nextPage: 2,
          hasMore: true,
        );
        const differentNextPageValue = RepositorySearchPage(
          items: [summary],
          totalCount: 100,
          nextPage: 3,
          hasMore: true,
        );
        const finalPageState = RepositorySearchPage(
          items: [summary],
          totalCount: 100,
          nextPage: null,
          hasMore: false,
        );

        expect(base, isNot(equals(differentTotalCount)));
        expect(base, isNot(equals(differentNextPageValue)));
        expect(base, isNot(equals(finalPageState)));
      },
    );
  });
}
