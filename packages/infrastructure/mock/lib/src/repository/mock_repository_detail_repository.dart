import 'package:domain/domain.dart';

import 'mock_repository_detail_response.dart';

/// [RepositoryDetailRepository]の決定的なテスト用実装。
///
/// [RepositoryIdentity]ごとに[setResponse]で応答を設定し、Widget Test・
/// Provider Test・Patrolが実APIへ接続せず同じシナリオ（成功・失敗・遅延・
/// cancel）を再現できるようにする。実時間の待機・実ネットワーク・乱数には
/// 依存しない。cancelはゲート待機中・呼出時点で既にキャンセル済みの両方で
/// 必ず優先されるため、実装（dio等）のcancel伝播タイミングに依存する実API
/// アダプターより強い「cancelは常に勝つ」保証を持つ点に留意する。
final class MockRepositoryDetailRepository
    implements RepositoryDetailRepository {
  /// Mock Repositoryを生成する。
  MockRepositoryDetailRepository();

  final Map<RepositoryIdentity, MockRepositoryDetailResponse> _responses = {};

  final List<RepositoryIdentity> _calls = [];

  /// これまでの`fetch`呼出履歴（呼び出された順）。
  List<RepositoryIdentity> get calls => List.unmodifiable(_calls);

  /// これまでの`fetch`呼出回数。
  int get callCount => _calls.length;

  /// [identity]に対する応答を設定する。
  ///
  /// 同じ[identity]へ再度設定した場合は後勝ちで上書きする（FIFOキューでは
  /// ない）。
  void setResponse({
    required RepositoryIdentity identity,
    required MockRepositoryDetailResponse response,
  }) {
    _responses[identity] = response;
  }

  @override
  Future<RepositoryDetailSupplement> fetch(
    RepositoryIdentity identity, {
    required CancellationToken cancellationToken,
  }) async {
    _calls.add(identity);

    cancellationToken.throwIfCancelled();

    final response = _responses[identity];
    if (response == null) {
      throw StateError(
        'MockRepositoryDetailRepository: no response configured for '
        'identity="${identity.fullName}". Call setResponse() first.',
      );
    }

    final gate = response.gate;
    if (gate != null) {
      await Future.any([gate.future, cancellationToken.whenCancelled]);
    }
    cancellationToken.throwIfCancelled();

    return switch (response) {
      MockRepositoryDetailSuccess(:final supplement) => supplement,
      MockRepositoryDetailFailure(:final exception) => throw exception,
    };
  }
}
