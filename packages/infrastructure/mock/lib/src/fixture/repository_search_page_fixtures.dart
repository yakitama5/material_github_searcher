import 'package:domain/domain.dart';

import 'repository_summary_fixtures.dart';

/// テストで再利用する代表的な[RepositorySearchPage]群。
///
/// `RepositorySearchPage`のコンストラクタは`hasMore == (nextPage != null)`を
/// 強制し、かつ防御的コピー（`List.unmodifiable`）のため非`const`になる。
/// 本クラスの各fixtureも`static final`で保持するため、namespace用クラスの
/// 定番である「staticメンバーのみ」の形を維持する。
// ignore: avoid_classes_with_only_static_members
abstract final class RepositorySearchPageFixtures {
  /// `totalCount == 0`の空ページ。
  static final empty = RepositorySearchPage(
    items: const [],
    totalCount: 0,
    nextPage: null,
    hasMore: false,
  );

  /// page1に出現する共有Repository（page2と同一identity・微妙に異なる値）。
  ///
  /// 2回のページ取得の間に実データが変化した状況（Star数の増加等）を模して
  /// おり、identityの一致だけを保証し値までは一致させない。
  static const _sharedOnFirstPage = RepositorySummary(
    identity: RepositoryIdentity(owner: 'octocat', name: 'overlapping-repo'),
    ownerAvatarUrl: 'https://example.invalid/avatars/octocat-overlap.png',
    language: 'Go',
    stargazersCount: 500,
    forksCount: 80,
    openIssuesCount: 10,
  );

  /// page2に出現する共有Repository。[_sharedOnFirstPage]とidentityが一致する。
  static const _sharedOnSecondPage = RepositorySummary(
    identity: RepositoryIdentity(owner: 'octocat', name: 'overlapping-repo'),
    ownerAvatarUrl: 'https://example.invalid/avatars/octocat-overlap.png',
    language: 'Go',
    stargazersCount: 501,
    forksCount: 80,
    openIssuesCount: 10,
  );

  /// pagination検証用の1ページ目。[secondPageWithOverlap]と1件だけidentityが
  /// 重なる。
  static final firstPage = RepositorySearchPage(
    items: const [
      RepositorySummaryFixtures.flutter,
      RepositorySummaryFixtures.dartSdk,
      _sharedOnFirstPage,
    ],
    totalCount: 4,
    nextPage: 2,
    hasMore: true,
  );

  /// pagination検証用の2ページ目。[firstPage]と[_sharedOnFirstPage]／
  /// [_sharedOnSecondPage]の組で1件だけidentityが重なる。
  static final secondPageWithOverlap = RepositorySearchPage(
    items: const [
      _sharedOnSecondPage,
      RepositorySummaryFixtures.materialGithubSearcher,
    ],
    totalCount: 4,
    nextPage: null,
    hasMore: false,
  );
}
