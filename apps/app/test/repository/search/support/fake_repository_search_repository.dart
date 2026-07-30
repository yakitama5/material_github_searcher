import 'dart:async';

import 'package:domain/domain.dart';

/// Widget Test専用の決定的な[RepositorySearchRepository]。
///
/// `infrastructure_mock`は`docs/ARCHITECTURE.md`のdependency graph上
/// `apps/app`から直接参照できないため、Widget Testに閉じた最小限のFakeとして
/// 定義する（`packages/infrastructure/mock`の`MockRepositorySearchRepository`
/// と役割は同じだが、layer間の依存制約により共有できない）。
final class FakeRepositorySearchRepository
    implements RepositorySearchRepository {
  final _responses = <(String, int), _Response>{};

  /// これまでの`search`呼出履歴（呼び出された順）。
  final calls = <RepositorySearchQuery>[];

  /// これまでの`search`呼出履歴（query・page、呼び出された順）。
  ///
  /// [calls]は既存テストとの互換のためqueryのみを保持するため、page単位の
  /// 検証（無限スクロールのpagination等）にはこちらを使う。
  final pageCalls = <(RepositorySearchQuery query, int page)>[];

  /// [query]・[page]の組に対する成功応答を設定する。
  ///
  /// [gate]を渡すと、[gate]の[Completer.complete]呼び出しまで応答を保留する。
  void setSuccess({
    required RepositorySearchQuery query,
    required RepositorySearchPage page,
    int pageNumber = 1,
    Completer<void>? gate,
  }) {
    _responses[(query.value, pageNumber)] = _Response(
      page: page,
      gate: gate,
    );
  }

  /// [query]・[pageNumber]の組に対する失敗応答を設定する。
  void setFailure({
    required RepositorySearchQuery query,
    required AppException exception,
    int pageNumber = 1,
  }) {
    _responses[(query.value, pageNumber)] = _Response(exception: exception);
  }

  @override
  Future<RepositorySearchPage> search({
    required RepositorySearchQuery query,
    required int page,
    required int perPage,
    required CancellationToken cancellationToken,
  }) async {
    calls.add(query);
    pageCalls.add((query, page));
    cancellationToken.throwIfCancelled();

    final response = _responses[(query.value, page)];
    if (response == null) {
      throw StateError(
        'FakeRepositorySearchRepository: no response configured for '
        'query="${query.value}", page=$page.',
      );
    }

    final gate = response.gate;
    if (gate != null) {
      await Future.any([gate.future, cancellationToken.whenCancelled]);
    }
    cancellationToken.throwIfCancelled();

    final exception = response.exception;
    if (exception != null) {
      throw exception;
    }
    return response.page!;
  }
}

final class _Response {
  _Response({this.page, this.exception, this.gate});

  final RepositorySearchPage? page;
  final AppException? exception;
  final Completer<void>? gate;
}
