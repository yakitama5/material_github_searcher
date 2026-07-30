import 'package:meta/meta.dart';

import 'repository_summary.dart';

/// Repository検索結果の1ページ分。
@immutable
final class RepositorySearchPage {
  /// 検索結果ページを生成する。
  ///
  /// [hasMore] は [nextPage] の有無と一致している必要がある。この不変条件は
  /// デバッグ・テスト時の安全網として`assert`で検査するに留め、`const`での
  /// 生成を妨げない。
  const RepositorySearchPage({
    required this.items,
    required this.totalCount,
    required this.nextPage,
    required this.hasMore,
  }) : assert(
         hasMore == (nextPage != null),
         'hasMore must be true exactly when nextPage is non-null',
       );

  /// このページに含まれる検索結果。
  final List<RepositorySummary> items;

  /// 検索条件に一致した総件数。
  final int totalCount;

  /// 次ページの番号。次ページが無い場合は`null`。
  final int? nextPage;

  /// 次ページが存在するか。
  final bool hasMore;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! RepositorySearchPage || runtimeType != other.runtimeType) {
      return false;
    }
    if (totalCount != other.totalCount ||
        nextPage != other.nextPage ||
        hasMore != other.hasMore ||
        items.length != other.items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), totalCount, nextPage, hasMore);
}
