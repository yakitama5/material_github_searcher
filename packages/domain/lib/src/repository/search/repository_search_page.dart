import 'repository_summary.dart';

/// Repository検索結果の1ページ分。
final class RepositorySearchPage {
  /// 検索結果ページを生成する。
  const RepositorySearchPage({
    required this.items,
    required this.totalCount,
    required this.nextPage,
    required this.hasMore,
  });

  /// このページに含まれる検索結果。
  final List<RepositorySummary> items;

  /// 検索条件に一致した総件数。
  final int totalCount;

  /// 次ページの番号。次ページが無い場合は`null`。
  final int? nextPage;

  /// 次ページが存在するか。
  final bool hasMore;
}
