import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:infrastructure_github/src/client/github_dio_factory.dart';
import 'package:infrastructure_github/src/repository/github_repository_search_repository.dart';
import 'package:test/test.dart';

import '../support/fake_http_client_adapter.dart';

Map<String, dynamic> _item({
  String fullName = 'flutter/flutter',
  Object? language = 'Dart',
}) => {
  'full_name': fullName,
  'owner': {'avatar_url': 'https://example.com/avatar.png'},
  'language': language,
  'stargazers_count': 100,
  'forks_count': 20,
  'open_issues_count': 5,
};

ResponseBody _jsonResponse(
  Map<String, dynamic> body,
  int statusCode, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    'content-type': ['application/json'],
    ...headers,
  },
);

void main() {
  group('GitHubRepositorySearchRepository.search', () {
    late FakeHttpClientAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = FakeHttpClientAdapter((options, stream, cancelFuture) {
        throw StateError('unset handler');
      });
      dio = createGitHubDio()..httpClientAdapter = adapter;
    });

    Future<RepositorySearchPage> search({
      String query = 'flutter',
      int page = 1,
      int perPage = 30,
      CancellationToken? cancellationToken,
    }) {
      final repository = GitHubRepositorySearchRepository(dio: dio);
      return repository.search(
        query: RepositorySearchQuery(query),
        page: page,
        perPage: perPage,
        cancellationToken: cancellationToken ?? CancellationController().token,
      );
    }

    test('複数件のレスポンスをRepositorySearchPageへ変換する', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 2,
        'items': [_item(), _item(fullName: 'dart-lang/sdk')],
      }, 200);

      final page = await search();

      expect(page.items, hasLength(2));
      expect(page.items[0].identity.fullName, 'flutter/flutter');
      expect(page.items[1].identity.fullName, 'dart-lang/sdk');
      expect(page.totalCount, 2);
    });

    test('0件のレスポンスをRepositorySearchPageへ変換する', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 0,
        'items': <Map<String, dynamic>>[],
      }, 200);

      final page = await search();

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextPage, isNull);
    });

    test('nullable languageを変換できる', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 1,
        'items': [_item(language: null)],
      }, 200);

      final page = await search();

      expect(page.items.single.language, isNull);
    });

    test('query・page・per_pageがリクエストへ渡る', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 0,
        'items': <Map<String, dynamic>>[],
      }, 200);

      await search(query: 'flutter searcher', page: 2);

      final request = adapter.capturedRequests.single;
      expect(request.queryParameters['q'], 'flutter searcher');
      expect(request.queryParameters['page'], 2);
      expect(request.queryParameters['per_page'], 30);
    });

    test('createGitHubDioのヘッダーが実リクエストにマージされる', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 0,
        'items': <Map<String, dynamic>>[],
      }, 200);

      await search();

      final request = adapter.capturedRequests.single;
      expect(request.headers['Accept'], 'application/vnd.github+json');
      expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');
    });

    test('malformed JSONはRepositorySearchExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          ResponseBody.fromString(
            '{not-json',
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );

      await expectLater(
        search(),
        throwsA(isA<RepositorySearchException>()),
      );
    });

    test('必須フィールド欠落はRepositorySearchExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'items': <Map<String, dynamic>>[],
      }, 200);

      await expectLater(
        search(),
        throwsA(isA<RepositorySearchException>()),
      );
    });

    test('必須フィールド欠落時、元のFormatExceptionのスタックトレースを保持する', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'items': <Map<String, dynamic>>[],
      }, 200);

      try {
        await search();
        fail('RepositorySearchExceptionが投げられるはず');
      } on RepositorySearchException catch (_, stackTrace) {
        expect(
          stackTrace.toString(),
          contains('github_search_response_dto.dart'),
        );
      }
    });

    test('403はrate limitのRepositorySearchExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse(
        {'message': 'rate limit exceeded'},
        403,
        headers: {
          'x-ratelimit-remaining': ['0'],
        },
      );

      await expectLater(
        search(),
        throwsA(
          isA<RepositorySearchException>().having(
            (e) => e.message,
            'message',
            contains('403'),
          ),
        ),
      );
    });

    test('429はrate limitのRepositorySearchExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse({'message': 'rate limit exceeded'}, 429);

      await expectLater(search(), throwsA(isA<RepositorySearchException>()));
    });

    test('その他4xx/5xxはRepositorySearchExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse({'message': 'server error'}, 500);

      await expectLater(search(), throwsA(isA<RepositorySearchException>()));
    });

    test('response前のcancelはRequestCancelledExceptionを投げる', () async {
      final controller = CancellationController();
      adapter.handler = (options, stream, cancelFuture) async {
        await cancelFuture;
        throw StateError('should not reach here');
      };

      final future = search(cancellationToken: controller.token);
      controller.cancel();

      await expectLater(future, throwsA(isA<RequestCancelledException>()));
    });

    test('stream中のcancelはRequestCancelledExceptionを投げる', () async {
      final controller = CancellationController();
      adapter.handler = (options, stream, cancelFuture) async {
        final controller2 = StreamController<Uint8List>()
          ..add(Uint8List.fromList(utf8.encode('{"total_count')));
        unawaited(
          cancelFuture!.then((_) {
            controller2.addError(StateError('aborted'));
            unawaited(controller2.close());
          }),
        );
        return ResponseBody(
          controller2.stream,
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      };

      final future = search(cancellationToken: controller.token);
      controller.cancel();

      await expectLater(future, throwsA(isA<RequestCancelledException>()));
    });

    test('既にキャンセル済みなら通信を開始せずRequestCancelledExceptionを投げる', () async {
      final controller = CancellationController()..cancel();
      var called = false;
      adapter.handler = (options, stream, cancelFuture) {
        called = true;
        throw StateError('should not be called');
      };

      await expectLater(
        search(cancellationToken: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );
      expect(called, isFalse);
    });

    test('page*perPageが1000未満ならhasMoreはtrue', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 1200,
        'items': [_item()],
      }, 200);

      final page = await search(page: 10);

      expect(page.hasMore, isTrue);
      expect(page.nextPage, 11);
    });

    test('page*perPageがちょうど1000ならhasMoreはfalse', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 1200,
        'items': [_item()],
      }, 200);

      final page = await search(page: 100, perPage: 10);

      expect(page.hasMore, isFalse);
      expect(page.nextPage, isNull);
    });

    test('totalCountが1000未満でも境界を超えたらhasMoreはfalse', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 25,
        'items': [_item()],
      }, 200);

      final page = await search();

      expect(page.hasMore, isFalse);
      expect(page.nextPage, isNull);
    });

    test('Fake Adapter経由で1回だけ呼び出される', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse({
        'total_count': 0,
        'items': <Map<String, dynamic>>[],
      }, 200);

      await search();

      expect(adapter.capturedRequests, hasLength(1));
    });
  });
}
