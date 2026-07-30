import 'package:domain/domain.dart';

import 'mock_repository_search_response.dart';
import 'repository_search_call.dart';

/// [RepositorySearchRepository]の決定的なテスト用実装。
///
/// `query`・`page`の組ごとに[setResponse]で応答を設定し、Widget Test・
/// Provider Test・Patrolが実APIへ接続せず同じシナリオ（成功・空・失敗・
/// 遅延・cancel・pagination）を再現できるようにする。実時間の待機・実
/// ネットワーク・乱数には依存しない。cancelはゲート待機中・呼出時点で
/// 既にキャンセル済みの両方で必ず優先されるため、実装（dio等）のcancel
/// 伝播タイミングに依存する実APIアダプターより強い「cancelは常に勝つ」
/// 保証を持つ点に留意する。
final class MockRepositorySearchRepository
    implements RepositorySearchRepository {
  /// Mock Repositoryを生成する。
  MockRepositorySearchRepository();

  final Map<(RepositorySearchQuery, int), MockRepositorySearchResponse>
  _responses = {};

  final List<RepositorySearchCall> _calls = [];

  /// これまでの`search`呼出履歴（呼び出された順）。
  List<RepositorySearchCall> get calls => List.unmodifiable(_calls);

  /// これまでの`search`呼出回数。
  int get callCount => _calls.length;

  /// [query]・[page]の組に対する応答を設定する。
  ///
  /// 同じ組へ再度設定した場合は後勝ちで上書きする（FIFOキューではない）。
  void setResponse({
    required RepositorySearchQuery query,
    required int page,
    required MockRepositorySearchResponse response,
  }) {
    _responses[(query, page)] = response;
  }

  @override
  Future<RepositorySearchPage> search({
    required RepositorySearchQuery query,
    required int page,
    required int perPage,
    required CancellationToken cancellationToken,
  }) async {
    _calls.add(
      RepositorySearchCall(query: query, page: page, perPage: perPage),
    );

    cancellationToken.throwIfCancelled();

    final response = _responses[(query, page)];
    if (response == null) {
      throw StateError(
        'MockRepositorySearchRepository: no response configured for '
        'query="${query.value}", page=$page. Call setResponse() first.',
      );
    }

    final gate = response.gate;
    if (gate != null) {
      await Future.any([gate.future, cancellationToken.whenCancelled]);
    }
    cancellationToken.throwIfCancelled();

    return switch (response) {
      MockRepositorySearchSuccess(page: final resultPage) => resultPage,
      MockRepositorySearchFailure(:final exception) => throw exception,
    };
  }
}
