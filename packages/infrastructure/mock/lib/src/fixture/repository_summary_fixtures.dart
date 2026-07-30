import 'package:domain/domain.dart';

/// テストで再利用する代表的な[RepositorySummary]群。
///
/// `flutter/flutter`等の実在名を模した固定値のみを使い、乱数・現在時刻には
/// 依存しない。[uniqueIdentitySamples]に含まれるfixtureのidentityは互いに
/// 一意であり、`RepositorySearchPageFixtures`のpagination fixtureが持つ
/// 意図的な重複とは独立している。
abstract final class RepositorySummaryFixtures {
  /// 代表的な複数件のRepository（Star・Fork等が異なる典型例）。
  static const typical = [flutter, dartSdk, materialGithubSearcher];

  /// `flutter/flutter`相当の代表的な1件。
  static const flutter = RepositorySummary(
    identity: RepositoryIdentity(owner: 'flutter', name: 'flutter'),
    ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
    language: 'Dart',
    stargazersCount: 160000,
    forksCount: 27000,
    openIssuesCount: 12000,
  );

  /// `dart-lang/sdk`相当の1件。
  static const dartSdk = RepositorySummary(
    identity: RepositoryIdentity(owner: 'dart-lang', name: 'sdk'),
    ownerAvatarUrl: 'https://example.invalid/avatars/dart-lang.png',
    language: 'C++',
    stargazersCount: 10500,
    forksCount: 1700,
    openIssuesCount: 3200,
  );

  /// 本アプリ自身を模した1件。
  static const materialGithubSearcher = RepositorySummary(
    identity: RepositoryIdentity(
      owner: 'yakitama5',
      name: 'material_github_searcher',
    ),
    ownerAvatarUrl: 'https://example.invalid/avatars/yakitama5.png',
    language: 'Dart',
    stargazersCount: 3,
    forksCount: 0,
    openIssuesCount: 5,
  );

  /// [RepositorySummary.language]が`null`になるケース。
  static const nullLanguage = RepositorySummary(
    identity: RepositoryIdentity(owner: 'octocat', name: 'no-language-repo'),
    ownerAvatarUrl: 'https://example.invalid/avatars/octocat.png',
    language: null,
    stargazersCount: 1,
    forksCount: 0,
    openIssuesCount: 0,
  );

  /// 非常に長い`fullName`になるケース（owner・name双方を長くする）。
  static const longFullName = RepositorySummary(
    identity: RepositoryIdentity(
      owner: 'an-organization-with-an-unusually-long-account-name',
      name: 'a-repository-with-an-equally-unusually-long-descriptive-name',
    ),
    ownerAvatarUrl: 'https://example.invalid/avatars/long-name-owner.png',
    language: 'Dart',
    stargazersCount: 42,
    forksCount: 7,
    openIssuesCount: 1,
  );

  /// owner iconの読み込み失敗確認用の1件。
  ///
  /// `ownerAvatarUrl`は`.invalid` TLD（RFC 2606で名前解決不能と予約された
  /// 非実在ドメイン）を使うため、Widget Test等で実際に画像取得を試みても
  /// 決定的に失敗する。本fixture自体はI/Oを行わない。
  static const brokenOwnerAvatar = RepositorySummary(
    identity: RepositoryIdentity(owner: 'broken-avatar', name: 'sample-repo'),
    ownerAvatarUrl: 'https://owner-icon.invalid/missing-avatar.png',
    language: 'Dart',
    stargazersCount: 9,
    forksCount: 2,
    openIssuesCount: 0,
  );

  /// identityが互いに一意であることを検証する対象の全fixture。
  ///
  /// `RepositorySearchPageFixtures`が持つpage1/page2間の意図的な重複は
  /// 含まない。
  static const uniqueIdentitySamples = [
    flutter,
    dartSdk,
    materialGithubSearcher,
    nullLanguage,
    longFullName,
    brokenOwnerAvatar,
  ];
}
