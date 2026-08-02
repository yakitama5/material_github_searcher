import 'package:domain/domain.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';

/// Patrolで送信する代表的な検索query。
final patrolSearchQuery = RepositorySearchQuery('flutter');

/// Patrolで0件検索に使うquery。
final patrolEmptyQuery = RepositorySearchQuery('no matching repositories');

/// 検索結果一覧でDetailへ遷移するRepository Identity。
const patrolPrimaryRepositoryIdentity = RepositoryIdentity(
  owner: 'flutter',
  name: 'flutter',
);

/// 検索結果一覧でDetailへ遷移する代表Repository。
const patrolPrimaryRepository = RepositorySummary(
  identity: patrolPrimaryRepositoryIdentity,
  ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
  language: 'Dart',
  stargazersCount: 160000,
  forksCount: 27000,
  openIssuesCount: 12000,
);

/// 追加取得完了後にだけ表示されるRepository。
const patrolPageTwoRepository = RepositorySummary(
  identity: RepositoryIdentity(owner: 'flutter', name: 'page-two'),
  ownerAvatarUrl: 'https://example.invalid/avatars/page-two.png',
  language: 'Dart',
  stargazersCount: 42,
  forksCount: 7,
  openIssuesCount: 1,
);

/// Pull to Refresh完了後に表示されるRepository。
const patrolRefreshedRepository = RepositorySummary(
  identity: RepositoryIdentity(owner: 'octocat', name: 'refreshed-repository'),
  ownerAvatarUrl: 'https://example.invalid/avatars/refreshed.png',
  language: 'Dart',
  stargazersCount: 8,
  forksCount: 2,
  openIssuesCount: 0,
);

/// Detail APIが返す実Watcher数。検索結果の値とは別のfixtureであることを
/// 明確にするため、検索結果に存在しない値を使う。
const patrolSubscribersCount = 321;

/// 検索結果の30件ページ。実機の画面高さに依存せず、末尾到達で追加取得を
/// 発火できる件数を確保する。
final patrolInitialSearchPage = RepositorySearchPage(
  items: [
    patrolPrimaryRepository,
    ...List.generate(
      29,
      (index) => RepositorySummary(
        identity: RepositoryIdentity(
          owner: 'flutter',
          name: 'page-one-${(index + 1).toString().padLeft(2, '0')}',
        ),
        ownerAvatarUrl: 'https://example.invalid/avatars/page-one-$index.png',
        language: 'Dart',
        stargazersCount: index + 1,
        forksCount: index,
        openIssuesCount: index * 2,
      ),
    ),
  ],
  totalCount: 35,
  nextPage: 2,
  hasMore: true,
);

/// 追加取得用の2ページ目。
final patrolSecondSearchPage = RepositorySearchPage(
  items: [
    patrolPageTwoRepository,
    ...List.generate(
      4,
      (index) => RepositorySummary(
        identity: RepositoryIdentity(
          owner: 'flutter',
          name: 'page-two-${(index + 1).toString().padLeft(2, '0')}',
        ),
        ownerAvatarUrl: 'https://example.invalid/avatars/page-two-$index.png',
        language: 'Dart',
        stargazersCount: index + 10,
        forksCount: index + 2,
        openIssuesCount: index + 1,
      ),
    ),
  ],
  totalCount: 35,
  nextPage: null,
  hasMore: false,
);

/// Pull to Refresh完了後の1ページ目。
final patrolRefreshSearchPage = RepositorySearchPage(
  items: const [patrolRefreshedRepository],
  totalCount: 1,
  nextPage: null,
  hasMore: false,
);

/// 0件検索の応答。
final patrolEmptySearchPage = RepositorySearchPage(
  items: const [],
  totalCount: 0,
  nextPage: null,
  hasMore: false,
);

/// Detail画面へ渡す追加情報。
const patrolDetailSupplement = RepositoryDetailSupplement(
  identity: patrolPrimaryRepositoryIdentity,
  subscribersCount: patrolSubscribersCount,
);

/// 日本語localeでRepository一覧行を識別するSemantics label。
String patrolRepositorySemanticsLabel(RepositorySummary summary) {
  final i18n = AppLocale.ja.translations.repositorySearch;
  return '${summary.identity.fullName}, ${i18n.languageLabel}: '
      '${summary.language ?? i18n.languageUnset}';
}
