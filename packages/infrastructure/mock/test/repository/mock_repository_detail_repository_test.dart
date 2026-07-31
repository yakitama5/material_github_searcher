import 'dart:async';

import 'package:domain/domain.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('MockRepositoryDetailRepository.fetch', () {
    const flutterIdentity = RepositoryIdentity(
      owner: 'flutter',
      name: 'flutter',
    );
    const sdkIdentity = RepositoryIdentity(owner: 'dart-lang', name: 'sdk');
    const flutterSupplement42 = RepositoryDetailSupplement(
      identity: flutterIdentity,
      subscribersCount: 42,
    );

    late MockRepositoryDetailRepository repository;

    setUp(() {
      repository = MockRepositoryDetailRepository();
    });

    Future<RepositoryDetailSupplement> fetch({
      RepositoryIdentity identity = flutterIdentity,
      CancellationToken? cancellationToken,
    }) {
      return repository.fetch(
        identity,
        cancellationToken: cancellationToken ?? CancellationController().token,
      );
    }

    test('設定したidentityに一致する成功応答を返す', () async {
      repository.setResponse(
        identity: flutterIdentity,
        response: const MockRepositoryDetailSuccess(flutterSupplement42),
      );

      final result = await fetch();

      expect(result, same(flutterSupplement42));
    });

    test('identityが異なれば別の応答を返す', () async {
      const sdkSupplement = RepositoryDetailSupplement(
        identity: sdkIdentity,
        subscribersCount: 10,
      );
      repository
        ..setResponse(
          identity: flutterIdentity,
          response: const MockRepositoryDetailSuccess(flutterSupplement42),
        )
        ..setResponse(
          identity: sdkIdentity,
          response: const MockRepositoryDetailSuccess(sdkSupplement),
        );

      expect(await fetch(), same(flutterSupplement42));
      expect(await fetch(identity: sdkIdentity), same(sdkSupplement));
    });

    test('未設定のidentityを呼ぶとStateErrorになる', () async {
      await expectLater(fetch(), throwsA(isA<StateError>()));

      expect(repository.callCount, 1);
    });

    test('後から設定した応答が上書きされる', () async {
      repository
        ..setResponse(
          identity: flutterIdentity,
          response: const MockRepositoryDetailSuccess(
            RepositoryDetailSupplement(
              identity: flutterIdentity,
              subscribersCount: 1,
            ),
          ),
        )
        ..setResponse(
          identity: flutterIdentity,
          response: const MockRepositoryDetailSuccess(
            RepositoryDetailSupplement(
              identity: flutterIdentity,
              subscribersCount: 2,
            ),
          ),
        );

      final result = await fetch();

      expect(result.subscribersCount, 2);
    });

    test('失敗応答を設定すると例外を投げる', () async {
      const exception = RepositoryDetailException(message: 'rate limited');
      repository.setResponse(
        identity: flutterIdentity,
        response: MockRepositoryDetailFailure(exception),
      );

      await expectLater(fetch(), throwsA(same(exception)));
    });

    test('ゲートをcompleteするまで成功応答は完了しない', () async {
      final gate = Completer<void>();
      repository.setResponse(
        identity: flutterIdentity,
        response: MockRepositoryDetailSuccess(flutterSupplement42, gate: gate),
      );

      var completed = false;
      final future = fetch().then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      gate.complete();
      await future;

      expect(completed, isTrue);
    });

    test('ゲートをcompleteするまで失敗応答も完了しない', () async {
      final gate = Completer<void>();
      const exception = RepositoryDetailException(message: 'delayed error');
      repository.setResponse(
        identity: flutterIdentity,
        response: MockRepositoryDetailFailure(exception, gate: gate),
      );

      var settled = false;
      final future = fetch().then(
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
        identity: flutterIdentity,
        response: MockRepositoryDetailSuccess(flutterSupplement42, gate: gate),
      );

      final future = fetch(cancellationToken: controller.token);
      controller.cancel();

      await expectLater(future, throwsA(isA<RequestCancelledException>()));
      // cancel後にgateをcompleteしても影響しないことを確認する。
      gate.complete();
    });

    test('呼び出し時点で既にキャンセル済みならRequestCancelledExceptionを投げる', () async {
      final controller = CancellationController()..cancel();
      repository.setResponse(
        identity: flutterIdentity,
        response: const MockRepositoryDetailSuccess(flutterSupplement42),
      );

      await expectLater(
        fetch(cancellationToken: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );
    });

    test('既にキャンセル済みでも呼出履歴には記録される', () async {
      final controller = CancellationController()..cancel();
      repository.setResponse(
        identity: flutterIdentity,
        response: const MockRepositoryDetailSuccess(flutterSupplement42),
      );

      await expectLater(
        fetch(cancellationToken: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );

      expect(repository.callCount, 1);
    });

    test('呼出履歴と呼出回数を検証できる', () async {
      repository
        ..setResponse(
          identity: flutterIdentity,
          response: const MockRepositoryDetailSuccess(flutterSupplement42),
        )
        ..setResponse(
          identity: sdkIdentity,
          response: const MockRepositoryDetailSuccess(
            RepositoryDetailSupplement(
              identity: sdkIdentity,
              subscribersCount: 10,
            ),
          ),
        );

      await fetch();
      await fetch(identity: sdkIdentity);

      expect(repository.callCount, 2);
      expect(repository.calls, equals([flutterIdentity, sdkIdentity]));
    });

    test('callsは呼出後の外部変更から保護されている', () async {
      repository.setResponse(
        identity: flutterIdentity,
        response: const MockRepositoryDetailSuccess(flutterSupplement42),
      );

      await fetch();

      expect(
        () => repository.calls.add(flutterIdentity),
        throwsUnsupportedError,
      );
    });
  });
}
