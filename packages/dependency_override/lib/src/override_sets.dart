import 'package:application/application.dart';
import 'package:infrastructure_github/infrastructure_github.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:riverpod/misc.dart';

/// 本番環境向けのProvider override一式を生成する。
///
/// Repository検索は実GitHub APIを叩く[GitHubRepositorySearchRepository]へ
/// 結線する。`Dio`は`createGitHubDio`が本番向けに生成し、Providerが初めて
/// 参照された時点で遅延生成する。
List<Override> createProductionOverrides() => [
  repositorySearchRepositoryProvider.overrideWith(
    (ref) => GitHubRepositorySearchRepository(dio: createGitHubDio()),
  ),
];

/// テスト・開発環境向けのProvider override一式を生成する。
///
/// Repository検索は決定的な[MockRepositorySearchRepository]へ結線し、実APIへ
/// 接続せず同じシナリオ（成功・空・失敗・遅延・cancel）を再現できるようにする。
List<Override> createMockOverrides() => [
  repositorySearchRepositoryProvider.overrideWith(
    (ref) => MockRepositorySearchRepository(),
  ),
];
