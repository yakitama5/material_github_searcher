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
  });
}
