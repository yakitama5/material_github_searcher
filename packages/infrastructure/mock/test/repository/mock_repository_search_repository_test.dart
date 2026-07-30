import 'dart:async';

import 'package:domain/domain.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('MockRepositorySearchRepository.search', () {
    late MockRepositorySearchRepository repository;

    setUp(() {
      repository = MockRepositorySearchRepository();
    });

    Future<RepositorySearchPage> search({
      String query = 'flutter',
      int page = 1,
      int perPage = 30,
      CancellationToken? cancellationToken,
    }) {
      return repository.search(
        query: RepositorySearchQuery(query),
        page: page,
        perPage: perPage,
        cancellationToken: cancellationToken ?? CancellationController().token,
      );
    }

    test('設定したqueryとpageに一致する成功応答を返す', () async {
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchSuccess(
          RepositorySearchPageFixtures.empty,
        ),
      );

      final page = await search();

      expect(page, same(RepositorySearchPageFixtures.empty));
    });

    test('query・pageが異なれば別の応答を返す', () async {
      final page1 = RepositorySearchPageFixtures.firstPage;
      final page2 = RepositorySearchPageFixtures.secondPageWithOverlap;
      repository
        ..setResponse(
          query: RepositorySearchQuery('flutter'),
          page: 1,
          response: MockRepositorySearchSuccess(page1),
        )
        ..setResponse(
          query: RepositorySearchQuery('flutter'),
          page: 2,
          response: MockRepositorySearchSuccess(page2),
        )
        ..setResponse(
          query: RepositorySearchQuery('dart'),
          page: 1,
          response: MockRepositorySearchSuccess(
            RepositorySearchPageFixtures.empty,
          ),
        );

      expect(await search(), same(page1));
      expect(await search(page: 2), same(page2));
      expect(
        await search(query: 'dart'),
        same(RepositorySearchPageFixtures.empty),
      );
    });

    test('未設定のquery・pageを呼ぶとStateErrorになる', () async {
      await expectLater(search(), throwsA(isA<StateError>()));

      expect(repository.callCount, 1);
    });

    test('後から設定した応答が上書きされる', () async {
      repository
        ..setResponse(
          query: RepositorySearchQuery('flutter'),
          page: 1,
          response: MockRepositorySearchSuccess(
            RepositorySearchPageFixtures.empty,
          ),
        )
        ..setResponse(
          query: RepositorySearchQuery('flutter'),
          page: 1,
          response: MockRepositorySearchSuccess(
            RepositorySearchPageFixtures.firstPage,
          ),
        );

      final page = await search();

      expect(page, same(RepositorySearchPageFixtures.firstPage));
    });

    test('失敗応答を設定すると例外を投げる', () async {
      const exception = RepositorySearchException(message: 'rate limited');
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchFailure(exception),
      );

      await expectLater(search(), throwsA(same(exception)));
    });

    test('ゲートをcompleteするまで成功応答は完了しない', () async {
      final gate = Completer<void>();
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchSuccess(
          RepositorySearchPageFixtures.empty,
          gate: gate,
        ),
      );

      var completed = false;
      final future = search().then((page) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      gate.complete();
      await future;

      expect(completed, isTrue);
    });

    test('ゲートをcompleteするまで失敗応答も完了しない', () async {
      final gate = Completer<void>();
      const exception = RepositorySearchException(message: 'delayed error');
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchFailure(exception, gate: gate),
      );

      var settled = false;
      final future = search().then(
        (_) => settled = true,
        onError: (Object _, _) => settled = true,
      );

      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);

      gate.complete();
      await expectLater(future, completes);
      expect(settled, isTrue);
    });

    test('ゲート待機中にcancelされるとRequestCancelledExceptionを投げる', () async {
      final gate = Completer<void>();
      final controller = CancellationController();
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchSuccess(
          RepositorySearchPageFixtures.empty,
          gate: gate,
        ),
      );

      final future = search(cancellationToken: controller.token);
      controller.cancel();

      await expectLater(future, throwsA(isA<RequestCancelledException>()));
      // cancel後にgateをcompleteしても影響しないことを確認する。
      gate.complete();
    });

    test('呼び出し時点で既にキャンセル済みならRequestCancelledExceptionを投げる', () async {
      final controller = CancellationController()..cancel();
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchSuccess(
          RepositorySearchPageFixtures.empty,
        ),
      );

      await expectLater(
        search(cancellationToken: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );
    });

    test('既にキャンセル済みでも呼出履歴には記録される', () async {
      final controller = CancellationController()..cancel();
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchSuccess(
          RepositorySearchPageFixtures.empty,
        ),
      );

      await expectLater(
        search(cancellationToken: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );

      expect(repository.callCount, 1);
    });

    test('呼出履歴と呼出回数を検証できる', () async {
      repository
        ..setResponse(
          query: RepositorySearchQuery('flutter'),
          page: 1,
          response: MockRepositorySearchSuccess(
            RepositorySearchPageFixtures.empty,
          ),
        )
        ..setResponse(
          query: RepositorySearchQuery('flutter'),
          page: 2,
          response: MockRepositorySearchSuccess(
            RepositorySearchPageFixtures.empty,
          ),
        );

      await search();
      await search(page: 2, perPage: 10);

      expect(repository.callCount, 2);
      expect(
        repository.calls,
        equals([
          RepositorySearchCall(
            query: RepositorySearchQuery('flutter'),
            page: 1,
            perPage: 30,
          ),
          RepositorySearchCall(
            query: RepositorySearchQuery('flutter'),
            page: 2,
            perPage: 10,
          ),
        ]),
      );
    });

    test('callsは呼出後の外部変更から保護されている', () async {
      repository.setResponse(
        query: RepositorySearchQuery('flutter'),
        page: 1,
        response: MockRepositorySearchSuccess(
          RepositorySearchPageFixtures.empty,
        ),
      );

      await search();

      expect(
        () => repository.calls.add(
          RepositorySearchCall(
            query: RepositorySearchQuery('flutter'),
            page: 1,
            perPage: 30,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
