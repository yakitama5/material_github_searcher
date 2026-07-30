import 'dart:async';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// `search`呼出1回分の記録。
final class _FakeCall {
  const _FakeCall({
    required this.query,
    required this.page,
    required this.perPage,
  });

  final RepositorySearchQuery query;
  final int page;
  final int perPage;
}

/// `search`へ設定する応答。
///
/// [gate]が非`null`の場合、`search`は[gate]と`cancellationToken.whenCancelled`
/// のどちらか先に完了した方まで待つ。[cancelWins]が`true`のときは待機後に
/// cancel済みなら[RequestCancelledException]を投げる（Mockと同じ「cancelが常に
/// 勝つ」挙動）。`false`のときはcancel済みでも成功/失敗をそのまま返し、cancelが
/// レースに負ける実APIの挙動を模す。
final class _FakeResponse {
  _FakeResponse.success(
    this.page, {
    this.gate,
    this.cancelWins = true,
  }) : exception = null;

  _FakeResponse.failure(
    this.exception, {
    this.gate,
    this.cancelWins = true,
  }) : page = null;

  final RepositorySearchPage? page;
  final AppException? exception;
  final Completer<void>? gate;
  final bool cancelWins;
}

/// [RepositorySearchRepository]のテスト用Fake。
final class _FakeRepositorySearchRepository
    implements RepositorySearchRepository {
  final List<_FakeCall> calls = [];
  final Map<(String, int), _FakeResponse> _responses = {};

  int get callCount => calls.length;

  void setSuccess({
    required RepositorySearchQuery query,
    required RepositorySearchPage result,
    int page = 1,
    Completer<void>? gate,
    bool cancelWins = true,
  }) {
    _responses[(query.value, page)] = _FakeResponse.success(
      result,
      gate: gate,
      cancelWins: cancelWins,
    );
  }

  void setFailure({
    required RepositorySearchQuery query,
    required AppException exception,
    int page = 1,
    Completer<void>? gate,
    bool cancelWins = true,
  }) {
    _responses[(query.value, page)] = _FakeResponse.failure(
      exception,
      gate: gate,
      cancelWins: cancelWins,
    );
  }

  @override
  Future<RepositorySearchPage> search({
    required RepositorySearchQuery query,
    required int page,
    required int perPage,
    required CancellationToken cancellationToken,
  }) async {
    calls.add(_FakeCall(query: query, page: page, perPage: perPage));

    cancellationToken.throwIfCancelled();

    final response = _responses[(query.value, page)];
    if (response == null) {
      throw StateError(
        'no response configured for query="${query.value}", page=$page',
      );
    }

    final gate = response.gate;
    if (gate != null) {
      await Future.any([gate.future, cancellationToken.whenCancelled]);
    }
    if (response.cancelWins) {
      cancellationToken.throwIfCancelled();
    }

    final exception = response.exception;
    if (exception != null) {
      throw exception;
    }
    return response.page!;
  }
}

/// 成功応答用のページ。`totalCount`・`hasMore`まで区別できる代表値。
RepositorySearchPage _pageWithItems() => RepositorySearchPage(
  items: const [
    RepositorySummary(
      identity: RepositoryIdentity(owner: 'flutter', name: 'flutter'),
      ownerAvatarUrl: 'https://example.invalid/avatars/flutter.png',
      language: 'Dart',
      stargazersCount: 160000,
      forksCount: 27000,
      openIssuesCount: 12000,
    ),
  ],
  totalCount: 42,
  nextPage: 2,
  hasMore: true,
);

RepositorySearchPage _emptyPage() => RepositorySearchPage(
  items: const [],
  totalCount: 0,
  nextPage: null,
  hasMore: false,
);

/// page1と1件だけidentityが重なる（値は異なる）page2用のページ。
RepositorySearchPage _secondPageWithOverlap() => RepositorySearchPage(
  items: const [
    // page1（_pageWithItems）と同じidentityだが値が異なる。dedup後は
    // page1側の値が維持されることを確認するために使う。
    RepositorySummary(
      identity: RepositoryIdentity(owner: 'flutter', name: 'flutter'),
      ownerAvatarUrl: 'https://example.invalid/avatars/flutter-updated.png',
      language: 'Dart',
      stargazersCount: 999999,
      forksCount: 99999,
      openIssuesCount: 99999,
    ),
    RepositorySummary(
      identity: RepositoryIdentity(owner: 'dart-lang', name: 'sdk'),
      ownerAvatarUrl: 'https://example.invalid/avatars/dart-lang.png',
      language: 'C++',
      stargazersCount: 8000,
      forksCount: 1000,
      openIssuesCount: 500,
    ),
  ],
  totalCount: 42,
  nextPage: 3,
  hasMore: true,
);

void main() {
  late _FakeRepositorySearchRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = _FakeRepositorySearchRepository();
    container = ProviderContainer(
      overrides: [
        repositorySearchRepositoryProvider.overrideWithValue(fake),
      ],
    );
    // autoDispose Providerをテスト中に維持するためlistenerを張る。
    final sub = container.listen(
      repositorySearchControllerProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    addTearDown(container.dispose);
  });

  RepositorySearchController controller() =>
      container.read(repositorySearchControllerProvider.notifier);

  RepositorySearchState state() =>
      container.read(repositorySearchControllerProvider);

  group('初期状態', () {
    test('未検索の初期状態である', () {
      final current = state();
      expect(current.status, RepositorySearchStatus.initial);
      expect(current.query, isNull);
      expect(current.items, isEmpty);
      expect(current.page, 0);
      expect(current.hasMore, isFalse);
      expect(current.totalCount, isNull);
      expect(current.error, isNull);
    });
  });

  group('submit', () {
    test('成功で結果・page・hasMore・totalCountを保持する', () async {
      final result = _pageWithItems();
      fake.setSuccess(query: RepositorySearchQuery('flutter'), result: result);

      await controller().submit('flutter');

      final current = state();
      expect(current.status, RepositorySearchStatus.success);
      expect(current.query, RepositorySearchQuery('flutter'));
      expect(current.items, result.items);
      expect(current.page, 1);
      expect(current.hasMore, isTrue);
      expect(current.totalCount, 42);
      expect(current.error, isNull);
    });

    test('0件成功はitems空のsuccessで、初回errorと区別する', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('none'),
        result: _emptyPage(),
      );

      await controller().submit('none');

      final current = state();
      expect(current.status, RepositorySearchStatus.success);
      expect(current.items, isEmpty);
      expect(current.totalCount, 0);
      expect(current.error, isNull);
    });

    test('初回errorをitemsと独立して保持する', () async {
      const exception = RepositorySearchException(message: 'failed');
      fake.setFailure(
        query: RepositorySearchQuery('boom'),
        exception: exception,
      );

      await controller().submit('boom');

      final current = state();
      expect(current.status, RepositorySearchStatus.error);
      expect(current.error, same(exception));
      expect(current.items, isEmpty);
      expect(current.query, RepositorySearchQuery('boom'));
    });

    test('Rate Limit等の検索失敗もerror stateへ遷移する', () async {
      const exception = RepositorySearchException(message: 'rate limited');
      fake.setFailure(
        query: RepositorySearchQuery('rate'),
        exception: exception,
      );

      await controller().submit('rate');

      expect(state().status, RepositorySearchStatus.error);
      expect(state().error, same(exception));
    });

    test('trim後に空のqueryではAPIを呼ばずStateも変更しない', () async {
      await controller().submit('   ');

      expect(fake.callCount, 0);
      expect(state().status, RepositorySearchStatus.initial);
    });

    test('page1・perPage30・trim済みqueryで1回だけ呼び出す', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
      );

      await controller().submit('  flutter  ');

      expect(fake.callCount, 1);
      expect(fake.calls.single.query, RepositorySearchQuery('flutter'));
      expect(fake.calls.single.page, 1);
      expect(fake.calls.single.perPage, 30);
    });

    test('新queryで旧items・page状態を切り替える', () async {
      fake
        ..setSuccess(
          query: RepositorySearchQuery('flutter'),
          result: _pageWithItems(),
        )
        ..setSuccess(
          query: RepositorySearchQuery('none'),
          result: _emptyPage(),
        );

      await controller().submit('flutter');
      expect(state().items, isNotEmpty);

      await controller().submit('none');
      final current = state();
      expect(current.query, RepositorySearchQuery('none'));
      expect(current.items, isEmpty);
      expect(current.page, 1);
      expect(current.hasMore, isFalse);
      expect(current.totalCount, 0);
    });
  });

  group('retry', () {
    test('未検索では何もしない', () async {
      await controller().retry();

      expect(fake.callCount, 0);
      expect(state().status, RepositorySearchStatus.initial);
    });

    test('直近の送信済みqueryで再検索する', () async {
      final query = RepositorySearchQuery('flutter');
      fake.setFailure(
        query: query,
        exception: const RepositorySearchException(message: 'failed'),
      );

      await controller().submit('flutter');
      expect(state().status, RepositorySearchStatus.error);

      fake.setSuccess(query: query, result: _pageWithItems());
      await controller().retry();

      expect(state().status, RepositorySearchStatus.success);
      expect(fake.callCount, 2);
      expect(fake.calls.map((c) => c.query), everyElement(equals(query)));
    });
  });

  group('loadNextPage', () {
    test('成功でpage2をマージし、page・hasMore・totalCountを更新する', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
      );
      await controller().submit('flutter');
      final firstPageItem = state().items.single;

      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _secondPageWithOverlap(),
        page: 2,
      );
      await controller().loadNextPage();

      final current = state();
      expect(current.status, RepositorySearchStatus.success);
      expect(current.page, 2);
      expect(current.hasMore, isTrue);
      expect(current.totalCount, 42);
      expect(current.appendError, isNull);
      // 重複排除: page1・page2に共通するidentity（flutter/flutter）は1件だけ
      // 残り、page1側の値が維持される（page2の更新値を採用しない）。
      expect(current.items, hasLength(2));
      expect(current.items.first, same(firstPageItem));
      expect(
        current.items.last.identity,
        const RepositoryIdentity(owner: 'dart-lang', name: 'sdk'),
      );
      expect(fake.calls.map((c) => c.page), [1, 2]);
    });

    test('未検索・初回取得中・初回error・hasMore falseでは何もしない', () async {
      // 未検索
      await controller().loadNextPage();
      expect(fake.callCount, 0);

      // 初回error
      const exception = RepositorySearchException(message: 'failed');
      fake.setFailure(
        query: RepositorySearchQuery('boom'),
        exception: exception,
      );
      await controller().submit('boom');
      await controller().loadNextPage();
      expect(fake.callCount, 1);

      // hasMore false（0件成功）
      fake.setSuccess(
        query: RepositorySearchQuery('none'),
        result: _emptyPage(),
      );
      await controller().submit('none');
      await controller().loadNextPage();
      expect(fake.callCount, 2);
    });

    test('loadingMore中の重複呼出しはpage2を1回しか呼ばない', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
      );
      await controller().submit('flutter');

      final gate = Completer<void>();
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _secondPageWithOverlap(),
        page: 2,
        gate: gate,
      );

      final future1 = controller().loadNextPage();
      expect(state().status, RepositorySearchStatus.loadingMore);
      // statusが同期的にloadingMoreへ遷移済みのため、後続呼出しはガードされる。
      final future2 = controller().loadNextPage();

      gate.complete();
      await Future.wait([future1, future2]);

      expect(fake.calls.where((c) => c.page == 2).length, 1);
      expect(state().status, RepositorySearchStatus.success);
    });

    test('失敗時は既存items・page・hasMoreを維持し、appendErrorを設定する', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
      );
      await controller().submit('flutter');
      final before = state();

      const exception = RepositorySearchException(message: 'append failed');
      fake.setFailure(
        query: RepositorySearchQuery('flutter'),
        exception: exception,
        page: 2,
      );
      await controller().loadNextPage();

      final current = state();
      expect(current.status, RepositorySearchStatus.success);
      expect(current.items, before.items);
      expect(current.page, before.page);
      expect(current.hasMore, before.hasMore);
      expect(current.appendError, same(exception));
    });

    test('append失敗後の再試行は同じpageを呼び直し、成功でappendErrorを消す', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
      );
      await controller().submit('flutter');

      fake.setFailure(
        query: RepositorySearchQuery('flutter'),
        exception: const RepositorySearchException(message: 'append failed'),
        page: 2,
      );
      await controller().loadNextPage();
      expect(state().appendError, isNotNull);

      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _secondPageWithOverlap(),
        page: 2,
      );
      await controller().loadNextPage();

      final current = state();
      expect(current.status, RepositorySearchStatus.success);
      expect(current.appendError, isNull);
      expect(current.page, 2);
      expect(fake.calls.where((c) => c.page == 2).length, 2);
    });

    test('新queryのsubmitは進行中の追加requestをcancelしpage1へ戻す', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
      );
      await controller().submit('flutter');

      final gate = Completer<void>();
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _secondPageWithOverlap(),
        page: 2,
        gate: gate,
      );
      final loadMoreFuture = controller().loadNextPage();
      expect(state().status, RepositorySearchStatus.loadingMore);

      fake.setSuccess(
        query: RepositorySearchQuery('dart'),
        result: _emptyPage(),
      );
      final submitFuture = controller().submit('dart');
      expect(state().status, RepositorySearchStatus.loading);
      expect(state().query, RepositorySearchQuery('dart'));

      gate.complete();
      await Future.wait([loadMoreFuture, submitFuture]);

      final current = state();
      expect(current.query, RepositorySearchQuery('dart'));
      expect(current.status, RepositorySearchStatus.success);
      expect(current.page, 1);
      expect(current.items, isEmpty);
      expect(current.appendError, isNull);
    });

    test('進行中にcancelPendingRequestが呼ばれるとloadingMoreからsuccessへ戻る', () async {
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
      );
      await controller().submit('flutter');
      final before = state();

      final gate = Completer<void>();
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _secondPageWithOverlap(),
        page: 2,
        gate: gate,
      );
      final future = controller().loadNextPage();
      expect(state().status, RepositorySearchStatus.loadingMore);

      controller().cancelPendingRequest();
      // cancel直後に末尾Skeletonが残り続けず、直前のsuccess状態へ戻っている。
      expect(state().status, RepositorySearchStatus.success);
      expect(state().items, before.items);
      expect(state().page, before.page);
      expect(state().hasMore, before.hasMore);
      expect(state().appendError, isNull);

      // cancel後に遅延応答が完了しても、cancel済みのrequestとして破棄され
      // 戻したsuccess状態を上書きしない。
      gate.complete();
      await future;
      expect(state().status, RepositorySearchStatus.success);
      expect(state().items, before.items);
    });
  });

  group('cancel・supersession', () {
    test('別query送信で旧requestをcancelし、最新queryを反映する', () async {
      final gateA = Completer<void>();
      final gateB = Completer<void>();
      fake
        ..setSuccess(
          query: RepositorySearchQuery('flutter'),
          result: _pageWithItems(),
          gate: gateA,
        )
        ..setSuccess(
          query: RepositorySearchQuery('dart'),
          result: _emptyPage(),
          gate: gateB,
        );

      final futureA = controller().submit('flutter');
      expect(state().status, RepositorySearchStatus.loading);
      expect(state().query, RepositorySearchQuery('flutter'));

      final futureB = controller().submit('dart');
      expect(state().query, RepositorySearchQuery('dart'));

      // 旧request(A)はcancelされ、RequestCancelledExceptionで畳まれる。
      await futureA;
      // 旧requestの完了ではStateが上書きされない。
      expect(state().query, RepositorySearchQuery('dart'));

      gateB.complete();
      await futureB;

      expect(state().status, RepositorySearchStatus.success);
      expect(state().query, RepositorySearchQuery('dart'));
      expect(fake.callCount, 2);
    });

    test('cancel後の遅延成功responseは最新Stateを上書きしない', () async {
      final gateB = Completer<void>();
      fake
        ..setSuccess(
          // cancelがレースに負け成功が返る実APIを模す。
          query: RepositorySearchQuery('flutter'),
          result: _pageWithItems(),
          cancelWins: false,
        )
        ..setSuccess(
          query: RepositorySearchQuery('dart'),
          result: _emptyPage(),
          gate: gateB,
        );

      final futureA = controller().submit('flutter');
      final futureB = controller().submit('dart');

      // Aはcancel済みだが成功を返す。世代検証で破棄されB(loading)を保つ。
      await futureA;
      expect(state().query, RepositorySearchQuery('dart'));
      expect(state().status, RepositorySearchStatus.loading);

      gateB.complete();
      await futureB;
      expect(state().status, RepositorySearchStatus.success);
      expect(state().query, RepositorySearchQuery('dart'));
    });

    test('cancelPendingRequestは通知用error Stateへ遷移させない', () async {
      final gate = Completer<void>();
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
        gate: gate,
      );

      final future = controller().submit('flutter');
      expect(state().status, RepositorySearchStatus.loading);

      controller().cancelPendingRequest();
      gate.complete();
      await future;

      // loadingのまま。errorへは遷移しない。
      expect(state().status, RepositorySearchStatus.loading);
      expect(state().error, isNull);
    });

    test('dispose中の進行中requestはcancelされ、遅延完了で例外を起こさない', () async {
      final gate = Completer<void>();
      fake.setSuccess(
        query: RepositorySearchQuery('flutter'),
        result: _pageWithItems(),
        gate: gate,
      );

      final future = controller().submit('flutter');
      expect(state().status, RepositorySearchStatus.loading);

      container.dispose();
      gate.complete();

      await expectLater(future, completes);
    });
  });
}
