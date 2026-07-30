import 'package:domain/domain.dart';
import 'package:meta/meta.dart';

/// `MockRepositorySearchRepository`が記録する`search`呼出1回分の引数。
///
/// [CancellationToken]は呼出ごとに異なるインスタンスが渡され得るため
/// 保持せず、テストで検証しやすい引数（query/page/perPage）だけを持つ。
@immutable
final class RepositorySearchCall {
  /// 呼出記録を生成する。
  const RepositorySearchCall({
    required this.query,
    required this.page,
    required this.perPage,
  });

  /// 呼出時に渡された検索クエリ。
  final RepositorySearchQuery query;

  /// 呼出時に渡されたページ番号。
  final int page;

  /// 呼出時に渡された1ページあたりの件数。
  final int perPage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositorySearchCall &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          page == other.page &&
          perPage == other.perPage;

  @override
  int get hashCode => Object.hash(query, page, perPage);

  @override
  String toString() =>
      'RepositorySearchCall(query: ${query.value}, page: $page, '
      'perPage: $perPage)';
}
