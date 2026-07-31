import 'dart:async';

import 'package:domain/domain.dart';

/// Widget Test専用の決定的な[RepositoryDetailRepository]。
///
/// `infrastructure_mock`は`docs/ARCHITECTURE.md`のdependency graph上
/// `apps/app`から直接参照できないため、Widget Testに閉じた最小限のFakeとして
/// 定義する（`FakeRepositorySearchRepository`と同じ理由）。
final class FakeRepositoryDetailRepository
    implements RepositoryDetailRepository {
  final _responses = <RepositoryIdentity, _Response>{};

  /// これまでの`fetch`呼出履歴（呼び出された順）。
  final calls = <RepositoryIdentity>[];

  /// `gate`未完了のまま[CancellationToken]がcancelされて終了した呼出しの
  /// identity（発生順）。
  ///
  /// Widget Testからback操作（OpenContainer close）が実際に
  /// `repositoryDetailProvider`のautoDispose経由で通信をcancelさせたことを
  /// 直接観測するために使う。`calls`はcancel有無に関わらずfetch開始時点で
  /// 記録されるため、cancelが実際に伝播したかどうかの判定には使えない。
  final cancelledIdentities = <RepositoryIdentity>[];

  /// [identity]に対する成功応答を設定する。
  ///
  /// [gate]を渡すと、[gate]の[Completer.complete]呼び出しまで応答を保留する。
  void setSuccess({
    required RepositoryIdentity identity,
    required RepositoryDetailSupplement supplement,
    Completer<void>? gate,
  }) {
    _responses[identity] = _Response(supplement: supplement, gate: gate);
  }

  /// [identity]に対する失敗応答を設定する。
  void setFailure({
    required RepositoryIdentity identity,
    required AppException exception,
  }) {
    _responses[identity] = _Response(exception: exception);
  }

  @override
  Future<RepositoryDetailSupplement> fetch(
    RepositoryIdentity identity, {
    required CancellationToken cancellationToken,
  }) async {
    calls.add(identity);
    cancellationToken.throwIfCancelled();

    final response = _responses[identity];
    if (response == null) {
      throw StateError(
        'FakeRepositoryDetailRepository: no response configured for '
        'identity="${identity.fullName}".',
      );
    }

    final gate = response.gate;
    if (gate != null) {
      await Future.any([gate.future, cancellationToken.whenCancelled]);
    }
    if (cancellationToken.isCancelled) {
      cancelledIdentities.add(identity);
    }
    cancellationToken.throwIfCancelled();

    final exception = response.exception;
    if (exception != null) {
      throw exception;
    }
    return response.supplement!;
  }
}

final class _Response {
  _Response({this.supplement, this.exception, this.gate});

  final RepositoryDetailSupplement? supplement;
  final AppException? exception;
  final Completer<void>? gate;
}
