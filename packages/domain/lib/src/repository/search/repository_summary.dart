import 'package:meta/meta.dart';

import 'repository_identity.dart';

/// 検索結果一覧の1件分として表示するRepositoryの要約情報。
///
/// Watcher数（`watchers_count`・`subscribers_count`）は保持しない。Watcherが
/// 必要になった場合は、後続のRepository Detail APIが返す `subscribers_count`
/// で補う。
@immutable
final class RepositorySummary {
  /// Repositoryの要約情報を生成する。
  const RepositorySummary({
    required this.identity,
    required this.ownerAvatarUrl,
    required this.language,
    required this.stargazersCount,
    required this.forksCount,
    required this.openIssuesCount,
  });

  /// Repositoryの識別子。
  final RepositoryIdentity identity;

  /// ownerのアイコン画像URL。
  final String ownerAvatarUrl;

  /// Repositoryの主要言語。GitHub API上でnullになり得るためnullableとする。
  final String? language;

  /// Star数。
  final int stargazersCount;

  /// Fork数。
  final int forksCount;

  /// Open状態のIssue数。
  final int openIssuesCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositorySummary &&
          runtimeType == other.runtimeType &&
          identity == other.identity &&
          ownerAvatarUrl == other.ownerAvatarUrl &&
          language == other.language &&
          stargazersCount == other.stargazersCount &&
          forksCount == other.forksCount &&
          openIssuesCount == other.openIssuesCount;

  @override
  int get hashCode => Object.hash(
    identity,
    ownerAvatarUrl,
    language,
    stargazersCount,
    forksCount,
    openIssuesCount,
  );
}
