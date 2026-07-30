import 'package:dio/dio.dart';
import 'package:domain/domain.dart';

/// [DioException]をアプリ共通の[AppException]へ変換する。
///
/// 本関数は純粋関数であり、例外を投げずに変換結果を返すだけに留める。
/// 呼び出し側が`Error.throwWithStackTrace`で元のスタックトレースを付けて
/// 投げ直すことで、decode失敗等の発生箇所をログ上で追跡できるようにする。
AppException mapDioExceptionToAppException(DioException error) {
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
    return RepositorySearchException(
      message:
          'GitHub API rate limit exceeded (status: $statusCode, '
          'remaining: ${remaining ?? 'unknown'}, reset: ${reset ?? 'unknown'})',
    );
  }
  if (statusCode == 404) {
    return const RepositorySearchException(
      message: 'GitHub search endpoint returned 404',
    );
  }
  if (statusCode != null) {
    return RepositorySearchException(
      message:
          'GitHub API request failed with status $statusCode: '
          '${error.response?.statusMessage ?? error.message}',
    );
  }

  return RepositorySearchException(
    message: 'GitHub API request failed: ${error.message ?? error.error}',
  );
}
