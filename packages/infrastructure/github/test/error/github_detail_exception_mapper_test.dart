import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:infrastructure_github/src/error/github_detail_exception_mapper.dart';
import 'package:test/test.dart';

RequestOptions _options() => RequestOptions(path: '/repos/flutter/flutter');

Response<Object?> _response({
  required int statusCode,
  Map<String, List<String>> headers = const {},
}) => Response(
  requestOptions: _options(),
  statusCode: statusCode,
  headers: Headers.fromMap(headers),
);

void main() {
  group('mapDioExceptionToDetailException', () {
    test('cancelはRequestCancelledExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.cancel,
      );

      final mapped = mapDioExceptionToDetailException(error);

      expect(mapped, isA<RequestCancelledException>());
    });

    test('403はrate limitヘッダーを含むRepositoryDetailExceptionへ変換される', () {
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

      final mapped = mapDioExceptionToDetailException(error);

      expect(mapped, isA<RepositoryDetailException>());
      expect(mapped.message, contains('403'));
      expect(mapped.message, contains('remaining: 0'));
      expect(mapped.message, contains('reset: 1700000000'));
    });

    test(
      '403でもremainingが枯渇していなければrate limit文言にしない '
      '(secondary rate limit・abuse detectionの誤表示を避ける)',
      () {
        final error = DioException(
          requestOptions: _options(),
          type: DioExceptionType.badResponse,
          response: _response(
            statusCode: 403,
            headers: {
              'x-ratelimit-remaining': ['42'],
            },
          ),
        );

        final mapped = mapDioExceptionToDetailException(error);

        expect(mapped, isA<RepositoryDetailException>());
        expect(mapped.message, isNot(contains('rate limit')));
        expect(mapped.message, contains('403'));
      },
    );

    test('429はrate limitのRepositoryDetailExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.badResponse,
        response: _response(statusCode: 429),
      );

      final mapped = mapDioExceptionToDetailException(error);

      expect(mapped, isA<RepositoryDetailException>());
      expect(mapped.message, contains('429'));
      expect(mapped.message, contains('unknown'));
    });

    test('404はRepositoryDetailExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.badResponse,
        response: _response(statusCode: 404),
      );

      final mapped = mapDioExceptionToDetailException(error);

      expect(mapped, isA<RepositoryDetailException>());
      expect(mapped.message, contains('404'));
    });

    test('その他の4xx/5xxはRepositoryDetailExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.badResponse,
        response: _response(statusCode: 500),
      );

      final mapped = mapDioExceptionToDetailException(error);

      expect(mapped, isA<RepositoryDetailException>());
      expect(mapped.message, contains('500'));
    });

    test('レスポンスを受け取れない場合はRepositoryDetailExceptionへ変換される', () {
      final error = DioException(
        requestOptions: _options(),
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out',
      );

      final mapped = mapDioExceptionToDetailException(error);

      expect(mapped, isA<RepositoryDetailException>());
      expect(mapped.message, contains('Connection timed out'));
    });
  });
}
