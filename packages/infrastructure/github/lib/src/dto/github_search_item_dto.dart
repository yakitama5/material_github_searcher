import 'package:domain/domain.dart';

import 'dto_field_reader.dart';

/// GitHub Search APIのレスポンス内、`items`の1要素分のDTO。
final class GithubSearchItemDto {
  /// Item DTOを生成する。
  const GithubSearchItemDto({
    required this.owner,
    required this.name,
    required this.ownerAvatarUrl,
    required this.language,
    required this.stargazersCount,
    required this.forksCount,
    required this.openIssuesCount,
  });

  /// `json`は`items`配列の1要素分のMap。
  ///
  /// 必須フィールドの欠落・型不正、`full_name`が`owner/name`形式でない場合は
  /// [FormatException]を投げる。`watchers_count`は読み取らない
  /// ([RepositorySummary]がWatcher数を保持しないため)。
  factory GithubSearchItemDto.fromJson(Map<String, dynamic> json) {
    final fullName = requireField<String>(json, 'full_name');
    final separatorIndex = fullName.indexOf('/');
    if (separatorIndex <= 0 || separatorIndex == fullName.length - 1) {
      throw FormatException(
        'GitHub search response has an invalid "full_name" field: '
        '"$fullName"',
      );
    }

    final ownerJson = requireField<Map<String, dynamic>>(json, 'owner');

    return GithubSearchItemDto(
      owner: fullName.substring(0, separatorIndex),
      name: fullName.substring(separatorIndex + 1),
      ownerAvatarUrl: requireField<String>(ownerJson, 'avatar_url'),
      language: requireField<String?>(json, 'language'),
      stargazersCount: requireField<int>(json, 'stargazers_count'),
      forksCount: requireField<int>(json, 'forks_count'),
      openIssuesCount: requireField<int>(json, 'open_issues_count'),
    );
  }

  /// Repositoryを所有するuser・organizationのlogin名。
  final String owner;

  /// Repository名。
  final String name;

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

  /// domainの[RepositorySummary]へ変換する。
  RepositorySummary toDomain() => RepositorySummary(
    identity: RepositoryIdentity(owner: owner, name: name),
    ownerAvatarUrl: ownerAvatarUrl,
    language: language,
    stargazersCount: stargazersCount,
    forksCount: forksCount,
    openIssuesCount: openIssuesCount,
  );
}
