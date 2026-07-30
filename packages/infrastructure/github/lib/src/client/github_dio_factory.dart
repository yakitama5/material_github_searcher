import 'package:dio/dio.dart';

/// GitHub REST APIの`baseUrl`。
const githubApiBaseUrl = 'https://api.github.com';

/// `GET /search/repositories`向けの[Dio]インスタンスを生成する。
///
/// APIキーは使用しない（未認証リクエストとして動作する）。ヘッダーには
/// `Accept`・`X-GitHub-Api-Version`・識別可能な`User-Agent`を設定する。
///
/// dioは既定でタイムアウトを持たないため、接続・受信のいずれかが停止すると
/// `CancellationToken`が発火するまでFutureが完了しなくなる。検索UIとして
/// 妥当な時間で失敗させるため、接続・受信タイムアウトを明示的に設定する。
Dio createGitHubDio({String userAgent = 'material-github-searcher'}) {
  return Dio(
    BaseOptions(
      baseUrl: githubApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': userAgent,
      },
    ),
  );
}
