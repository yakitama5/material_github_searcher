import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:infrastructure_github/src/client/github_dio_factory.dart';
import 'package:infrastructure_github/src/repository/github_repository_detail_repository.dart';
import 'package:test/test.dart';

import '../support/fake_http_client_adapter.dart';

Map<String, dynamic> _detail({
  int subscribersCount = 42,
  int watchersCount = 999999,
}) => {'subscribers_count': subscribersCount, 'watchers_count': watchersCount};

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
  group('GitHubRepositoryDetailRepository.fetch', () {
    late FakeHttpClientAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = FakeHttpClientAdapter((options, stream, cancelFuture) {
        throw StateError('unset handler');
      });
      dio = createGitHubDio()..httpClientAdapter = adapter;
    });

    Future<RepositoryDetailSupplement> fetch({
      RepositoryIdentity identity = const RepositoryIdentity(
        owner: 'flutter',
        name: 'flutter',
      ),
      CancellationToken? cancellationToken,
    }) {
      final repository = GitHubRepositoryDetailRepository(dio: dio);
      return repository.fetch(
        identity,
        cancellationToken: cancellationToken ?? CancellationController().token,
      );
    }

    test('正常なレスポンスをRepositoryDetailSupplementへ変換する', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(_detail(), 200);

      final supplement = await fetch();

      expect(
        supplement.identity,
        const RepositoryIdentity(owner: 'flutter', name: 'flutter'),
      );
      expect(supplement.subscribersCount, 42);
    });

    test('subscribers_count 0を変換できる', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(_detail(subscribersCount: 0), 200);

      final supplement = await fetch();

      expect(supplement.subscribersCount, 0);
    });

    test('watchers_countと異なるsubscribers_countを採用する', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse(
        _detail(subscribersCount: 10, watchersCount: 20000),
        200,
      );

      final supplement = await fetch();

      expect(supplement.subscribersCount, 10);
    });

    test('owner・nameがGET /repos/{owner}/{repo}のパスへ渡る', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(_detail(), 200);

      await fetch(
        identity: const RepositoryIdentity(owner: 'dart-lang', name: 'sdk'),
      );

      final request = adapter.capturedRequests.single;
      expect(request.uri.pathSegments, ['repos', 'dart-lang', 'sdk']);
    });

    test('owner・nameに"/"を含んでいてもパスセグメントとして安全に扱われる', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(_detail(), 200);

      await fetch(
        identity: const RepositoryIdentity(
          owner: 'owner',
          name: '../../search/repositories',
        ),
      );

      final request = adapter.capturedRequests.single;
      // "/"がpathSegmentの区切りとして解釈されず、name全体が単一segmentに
      // decodeされる（percent-encodingが二重にも欠落にもなっていない）ことを
      // 確認する。
      expect(request.uri.pathSegments, [
        'repos',
        'owner',
        '../../search/repositories',
      ]);
    });

    test('createGitHubDioのヘッダーが実リクエストにマージされる', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(_detail(), 200);

      await fetch();

      final request = adapter.capturedRequests.single;
      expect(request.headers['Accept'], 'application/vnd.github+json');
      expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');
    });

    test('malformed JSONはRepositoryDetailExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          ResponseBody.fromString(
            '{not-json',
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );

      await expectLater(fetch(), throwsA(isA<RepositoryDetailException>()));
    });

    test('空ボディの200レスポンスはRepositoryDetailExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          ResponseBody.fromString(
            '',
            200,
            headers: {
              'content-type': ['application/json'],
            },
          );

      await expectLater(fetch(), throwsA(isA<RepositoryDetailException>()));
    });

    test('subscribers_count欠落はRepositoryDetailExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(<String, dynamic>{}, 200);

      await expectLater(fetch(), throwsA(isA<RepositoryDetailException>()));
    });

    test('subscribers_count欠落時、元のFormatExceptionのスタックトレースを保持する', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(<String, dynamic>{}, 200);

      try {
        await fetch();
        fail('RepositoryDetailExceptionが投げられるはず');
      } on RepositoryDetailException catch (_, stackTrace) {
        expect(
          stackTrace.toString(),
          contains('github_repository_detail_dto.dart'),
        );
      }
    });

    test('403はrate limitのRepositoryDetailExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) => _jsonResponse(
        {'message': 'rate limit exceeded'},
        403,
        headers: {
          'x-ratelimit-remaining': ['0'],
        },
      );

      await expectLater(
        fetch(),
        throwsA(
          isA<RepositoryDetailException>().having(
            (e) => e.message,
            'message',
            contains('403'),
          ),
        ),
      );
    });

    test('429はrate limitのRepositoryDetailExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse({'message': 'rate limit exceeded'}, 429);

      await expectLater(fetch(), throwsA(isA<RepositoryDetailException>()));
    });

    test('404はRepositoryDetailExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse({'message': 'Not Found'}, 404);

      await expectLater(fetch(), throwsA(isA<RepositoryDetailException>()));
    });

    test('その他4xx/5xxはRepositoryDetailExceptionへ変換される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse({'message': 'server error'}, 500);

      await expectLater(fetch(), throwsA(isA<RepositoryDetailException>()));
    });

    test('response前のcancelはRequestCancelledExceptionを投げる', () async {
      final controller = CancellationController();
      adapter.handler = (options, stream, cancelFuture) async {
        await cancelFuture;
        throw StateError('should not reach here');
      };

      final future = fetch(cancellationToken: controller.token);
      controller.cancel();

      await expectLater(future, throwsA(isA<RequestCancelledException>()));
    });

    test('stream中のcancelはRequestCancelledExceptionを投げる', () async {
      final controller = CancellationController();
      adapter.handler = (options, stream, cancelFuture) async {
        final controller2 = StreamController<Uint8List>()
          ..add(Uint8List.fromList(utf8.encode('{"subscribers_count')));
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

      final future = fetch(cancellationToken: controller.token);
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
        fetch(cancellationToken: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );
      expect(called, isFalse);
    });

    test('Fake Adapter経由で1回だけ呼び出される', () async {
      adapter.handler = (options, stream, cancelFuture) =>
          _jsonResponse(_detail(), 200);

      await fetch();

      expect(adapter.capturedRequests, hasLength(1));
    });
  });
}
