import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('RepositorySearchPageFixtures', () {
    test('emptyはtotalCount 0でhasMoreがfalse', () {
      final page = RepositorySearchPageFixtures.empty;

      expect(page.items, isEmpty);
      expect(page.totalCount, 0);
      expect(page.hasMore, isFalse);
      expect(page.nextPage, isNull);
    });

    test('firstPageはhasMoreがtrueでnextPageが2', () {
      final page = RepositorySearchPageFixtures.firstPage;

      expect(page.hasMore, isTrue);
      expect(page.nextPage, 2);
    });

    test('secondPageWithOverlapはhasMoreがfalseでnextPageがnull', () {
      final page = RepositorySearchPageFixtures.secondPageWithOverlap;

      expect(page.hasMore, isFalse);
      expect(page.nextPage, isNull);
    });

    test('firstPageとsecondPageWithOverlapは1件だけidentityが重なる', () {
      final firstPageIdentities = RepositorySearchPageFixtures.firstPage.items
          .map((summary) => summary.identity)
          .toSet();
      final secondPageIdentities = RepositorySearchPageFixtures
          .secondPageWithOverlap
          .items
          .map((summary) => summary.identity)
          .toSet();

      final overlap = firstPageIdentities.intersection(secondPageIdentities);

      expect(overlap, hasLength(1));
    });
  });
}
