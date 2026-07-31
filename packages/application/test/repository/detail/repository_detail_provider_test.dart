import 'dart:async';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:fake_async/fake_async.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// [_FakeRepositoryDetailRepository]へ設定する`fetch`1回分の応答。
///
/// `infrastructure_mock`の`MockRepositoryDetailResponse`と同じ形をここへ
/// 再実装する。`application`は`infrastructure_mock`へ依存できないため
/// （`docs/ARCHITECTURE.md`の依存性逆転）、テストファイル内に閉じて定義する。
sealed class _FakeResponse {
  const _FakeResponse({this.gate});

  /// 応答を完了させるタイミングを制御するゲート。`null`なら即座に応答する。
  final Completer<void>? gate;
}

final class _FakeSuccess extends _FakeResponse {
  const _FakeSuccess(this.supplement, {super.gate});

  final RepositoryDetailSupplement supplement;
}

final class _FakeFailure extends _FakeResponse {
  const _FakeFailure(this.exception);

  final AppException exception;
}

/// [RepositoryDetailRepository]のテスト用Fake。
///
/// `gate`による決定的遅延・`cancellationToken`優先の打ち切りを
/// `infrastructure_mock`の`MockRepositoryDetailRepository`と同じ挙動で再現する。
/// 直近の呼出しで渡された[CancellationToken]を[lastToken]で公開し、
/// Provider dispose時に実際にキャンセルされたかをテストから検証できるようにする。
final class _FakeRepositoryDetailRepository
    implements RepositoryDetailRepository {
  final List<RepositoryIdentity> calls = [];
  final Map<RepositoryIdentity, _FakeResponse> _responses = {};

  /// 直近の`fetch`呼出しで渡された[CancellationToken]。
  CancellationToken? lastToken;

  void setResponse(RepositoryIdentity identity, _FakeResponse response) {
    _responses[identity] = response;
  }

  @override
  Future<RepositoryDetailSupplement> fetch(
    RepositoryIdentity identity, {
    required CancellationToken cancellationToken,
  }) async {
    calls.add(identity);
    lastToken = cancellationToken;
    cancellationToken.throwIfCancelled();

    final response = _responses[identity];
    if (response == null) {
      throw StateError(
        '_FakeRepositoryDetailRepository: no response configured for '
        'identity="${identity.fullName}".',
      );
    }

    final gate = response.gate;
    if (gate != null) {
      await Future.any([gate.future, cancellationToken.whenCancelled]);
    }
    cancellationToken.throwIfCancelled();

    return switch (response) {
      _FakeSuccess(:final supplement) => supplement,
      _FakeFailure(:final exception) => throw exception,
    };
  }
}

void main() {
  const identityA = RepositoryIdentity(owner: 'octocat', name: 'Hello-World');
  const identityB = RepositoryIdentity(owner: 'octocat', name: 'Spoon-Knife');
  const supplementA = RepositoryDetailSupplement(
    identity: identityA,
    subscribersCount: 42,
  );
  const supplementB = RepositoryDetailSupplement(
    identity: identityB,
    subscribersCount: 7,
  );

  ProviderContainer createContainer(RepositoryDetailRepository repository) =>
      ProviderContainer(
        overrides: [
          repositoryDetailRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  group('repositoryDetailProvider', () {
    test('成功時にAsyncDataへ遷移する', () async {
      final fake = _FakeRepositoryDetailRepository()
        ..setResponse(identityA, const _FakeSuccess(supplementA));
      final container = createContainer(fake);
      addTearDown(container.dispose);

      final sub = container.listen(
        repositoryDetailProvider(identityA),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        repositoryDetailProvider(identityA).future,
      );

      expect(result, supplementA);
      expect(fake.calls, [identityA]);
    });

    test('error時はAsyncErrorへ遷移する', () async {
      final fake = _FakeRepositoryDetailRepository()
        ..setResponse(
          identityA,
          const _FakeFailure(RepositoryDetailException()),
        );
      final container = createContainer(fake);
      addTearDown(container.dispose);

      final sub = container.listen(
        repositoryDetailProvider(identityA),
        (_, _) {},
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(repositoryDetailProvider(identityA).future),
        throwsA(isA<RepositoryDetailException>()),
      );
      expect(
        container.read(repositoryDetailProvider(identityA)),
        isA<AsyncError<RepositoryDetailSupplement>>(),
      );
    });

    test('error後にlistenerが外れると即座にdisposeされ、再購読で再取得する', () {
      fakeAsync((async) {
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(
            identityA,
            const _FakeFailure(RepositoryDetailException()),
          );
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final sub1 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(fake.calls, [identityA]);

        sub1.close();
        // RiverpodのdisposeスケジューラはTimer(Duration.zero)を使うため、
        // マイクロタスクだけを処理するflushMicrotasksでは検知できない。
        // elapse(Duration.zero)でそのタイマーを消化してdispose判定を進める。
        async.elapse(Duration.zero);

        final sub2 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        addTearDown(sub2.close);
        async.flushMicrotasks();

        expect(fake.calls, [identityA, identityA]);
      });
    });

    test('通信中に最後のlistenerが外れると通信をキャンセルする', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(identityA, _FakeSuccess(supplementA, gate: gate));
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final sub = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        async.flushMicrotasks();

        expect(fake.lastToken!.isCancelled, isFalse);

        sub.close();
        // Riverpodのdispose判定はTimer(Duration.zero)経由のため、
        // elapse(Duration.zero)でそのタイマーを消化する必要がある
        // （flushMicrotasksだけではonDisposeが発火しない）。
        async.elapse(Duration.zero);

        expect(fake.lastToken!.isCancelled, isTrue);
      });
    });

    test('同一identityの複数listenerでRepository呼出しが重複しない', () {
      fakeAsync((async) {
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(identityA, const _FakeSuccess(supplementA));
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final sub1 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        final sub2 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        addTearDown(sub1.close);
        addTearDown(sub2.close);
        async.flushMicrotasks();

        expect(fake.calls, [identityA]);
      });
    });

    test('異なるidentityは別々のstate・cacheになる', () {
      fakeAsync((async) {
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(identityA, const _FakeSuccess(supplementA))
          ..setResponse(identityB, const _FakeSuccess(supplementB));
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final subA = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        final subB = container.listen(
          repositoryDetailProvider(identityB),
          (_, _) {},
        );
        async.flushMicrotasks();

        expect(fake.calls, containsAllInOrder([identityA, identityB]));
        expect(
          container.read(repositoryDetailProvider(identityA)).value,
          supplementA,
        );
        expect(
          container.read(repositoryDetailProvider(identityB)).value,
          supplementB,
        );

        // Aのlistenerだけ外してcacheが切れても、Bには影響しない。
        subA.close();
        async
          ..elapse(repositoryDetailCacheDuration)
          ..flushTimers();

        final subA2 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        addTearDown(subA2.close);
        addTearDown(subB.close);
        async.flushMicrotasks();

        expect(fake.calls.where((identity) => identity == identityA), [
          identityA,
          identityA,
        ]);
        expect(fake.calls.where((identity) => identity == identityB), [
          identityB,
        ]);
      });
    });

    test('成功後、cache期間内の再購読はRepositoryを再呼出ししない', () {
      fakeAsync((async) {
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(identityA, const _FakeSuccess(supplementA));
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final sub1 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(fake.calls, [identityA]);

        sub1.close();
        async.elapse(
          repositoryDetailCacheDuration - const Duration(seconds: 1),
        );

        final sub2 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        addTearDown(sub2.close);
        async.flushMicrotasks();

        expect(fake.calls, [identityA]);
      });
    });

    test('成功後、cache期間経過後の再購読はRepositoryを再度呼び出す', () {
      fakeAsync((async) {
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(identityA, const _FakeSuccess(supplementA));
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final sub1 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(fake.calls, [identityA]);

        sub1.close();
        async
          ..elapse(repositoryDetailCacheDuration)
          ..flushTimers();

        final sub2 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        addTearDown(sub2.close);
        async.flushMicrotasks();

        expect(fake.calls, [identityA, identityA]);
      });
    });

    test('ref.invalidateで再取得し、Repository呼出し回数が増える', () {
      fakeAsync((async) {
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(identityA, const _FakeSuccess(supplementA));
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final sub = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        addTearDown(sub.close);
        async.flushMicrotasks();
        expect(fake.calls, [identityA]);

        container.invalidate(repositoryDetailProvider(identityA));
        // invalidateによる再計算もRiverpodのTimer(Duration.zero)スケジューラ
        // 経由のため、elapse(Duration.zero)で消化する必要がある。
        async.elapse(Duration.zero);

        expect(fake.calls, [identityA, identityA]);
      });
    });

    test('成功完了と最後のlistener消失が重なってもcache期限どおりにdisposeされる', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        final fake = _FakeRepositoryDetailRepository()
          ..setResponse(identityA, _FakeSuccess(supplementA, gate: gate));
        final container = createContainer(fake);
        addTearDown(container.dispose);

        final sub = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        async.flushMicrotasks();

        // 通信中に最後のlistenerが外れるのと同時にgateを解決させる。
        // buildがawait中に全listenerを失うと、Riverpodの[Ref.isPaused]の
        // doc契約により、この後の`ref.cacheFor`呼出しで登録する`onCancel`は
        // 「今まさにlistenerが0になった」イベントを取りこぼす（イベントは
        // build途中の非同期ギャップで既に発火済みのため再発火しない）。
        // cacheForがisPausedを見て直接timerを開始しないと、5分経過しても
        // 無期限にkeepAliveされ続けてしまう
        // （実装中に発覚。修正はref_extension.dartのcacheFor側）。
        sub.close();
        gate.complete();
        // まずマイクロタスクでfetchのFutureを完了させcacheForを呼ばせてから、
        // elapse(Duration.zero)でRiverpodのdisposeスケジューラ
        // （Timer(Duration.zero)）を消化する。5分のcacheタイマーには
        // 影響しない範囲で、dispose判定だけを進める。
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          // cache期間を過ぎるまで進める。「cacheDuration - 1秒」までしか
          // 進めないアサーションは、無期限keepAlive（バグ）でも
          // 正しいcache（意図した挙動）でも同じ結果になり判別できないため、
          // 必ずcacheDurationを超えて再取得されることまで確認する。
          ..elapse(repositoryDetailCacheDuration + const Duration(seconds: 1))
          ..flushTimers();
        final sub2 = container.listen(
          repositoryDetailProvider(identityA),
          (_, _) {},
        );
        addTearDown(sub2.close);
        async.flushMicrotasks();

        expect(fake.calls, [identityA, identityA]);
      });
    });
  });
}
