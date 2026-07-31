import 'package:dio/dio.dart';
import 'package:domain/domain.dart';

/// [DioException]をRepository Detail用の[AppException]へ変換する。
///
/// `github_exception_mapper.dart`の`mapDioExceptionToAppException`
/// （Search用）と同じ分類ロジックだが、返す型が[RepositoryDetailException]
/// である点だけが異なる。動作中のSearch実装へ手を入れるリスクを避けるため
/// 共通化はせず、小さな並行実装として持つ。本関数は純粋関数であり、例外を
/// 投げずに変換結果を返すだけに留める。呼び出し側が
/// `Error.throwWithStackTrace`で元のスタックトレースを付けて投げ直すことで、
/// decode失敗等の発生箇所をログ上で追跡できるようにする。
AppException mapDioExceptionToDetailException(DioException error) {
  if (error.type == DioExceptionType.cancel) {
    return const RequestCancelledException();
  }

  final statusCode = error.response?.statusCode;
  final remaining = error.response?.headers.value('x-ratelimit-remaining');
  // 403はsecondary rate limit・abuse detectionでも返るため、remainingが
  // 明確に枯渇している場合のみrate limitの文言にする。それ以外は下の
  // 一般的なstatusCode分岐へフォールスルーし、誤ったログを避ける。
  final isRateLimited =
      statusCode == 429 || (statusCode == 403 && remaining == '0');
  if (isRateLimited) {
    final reset = error.response?.headers.value('x-ratelimit-reset');
    return RepositoryDetailException(
      message:
          'GitHub API rate limit exceeded (status: $statusCode, '
          'remaining: ${remaining ?? 'unknown'}, reset: ${reset ?? 'unknown'})',
    );
  }
  if (statusCode == 404) {
    return const RepositoryDetailException(
      message: 'GitHub repository detail endpoint returned 404',
    );
  }
  if (statusCode != null) {
    return RepositoryDetailException(
      message:
          'GitHub API request failed with status $statusCode: '
          '${error.response?.statusMessage ?? error.message}',
    );
  }

  return RepositoryDetailException(
    message: 'GitHub API request failed: ${error.message ?? error.error}',
  );
}
