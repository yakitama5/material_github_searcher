import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:infrastructure_github/src/error/github_exception_mapper.dart';
import 'package:test/test.dart';

RequestOptions _options() => RequestOptions(path: '/search/repositories');

Response<Object?> _response({
  required int statusCode,
  Map<String, List<String>> headers = const {},
}) => Response(
  requestOptions: _options(),
  statusCode: statusCode,
  headers: Headers.fromMap(headers),
);

void main() {
  group('mapDioExceptionToAppException', () {
    test('cancelはRequestCancelledExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.cancel,
      );

      final mapped = mapDioExceptionToAppException(error);

      expect(mapped, isA<RequestCancelledException>());
    });

    test('403はrate limitヘッダーを含むRepositorySearchExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.badResponse,
        response: _response(
          statusCode: 403,
          headers: {
            'x-ratelimit-remaining': ['0'],
            'x-ratelimit-reset': ['1700000000'],
          },
        ),
      );

      final mapped = mapDioExceptionToAppException(error);

      expect(mapped, isA<RepositorySearchException>());
      expect(mapped.message, contains('403'));
      expect(mapped.message, contains('remaining: 0'));
      expect(mapped.message, contains('reset: 1700000000'));
    });

    test('429はrate limitのRepositorySearchExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.badResponse,
        response: _response(statusCode: 429),
      );

      final mapped = mapDioExceptionToAppException(error);

      expect(mapped, isA<RepositorySearchException>());
      expect(mapped.message, contains('429'));
      expect(mapped.message, contains('unknown'));
    });

    test('404はRepositorySearchExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.badResponse,
        response: _response(statusCode: 404),
      );

      final mapped = mapDioExceptionToAppException(error);

      expect(mapped, isA<RepositorySearchException>());
      expect(mapped.message, contains('404'));
    });

    test('その他の4xx/5xxはRepositorySearchExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.badResponse,
        response: _response(statusCode: 500),
      );

      final mapped = mapDioExceptionToAppException(error);

      expect(mapped, isA<RepositorySearchException>());
      expect(mapped.message, contains('500'));
    });

    test('レスポンスを受け取れない場合はRepositorySearchExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out',
      );

      final mapped = mapDioExceptionToAppException(error);

      expect(mapped, isA<RepositorySearchException>());
      expect(mapped.message, contains('Connection timed out'));
    });
  });
}
