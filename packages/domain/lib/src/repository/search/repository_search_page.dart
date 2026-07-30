import 'package:meta/meta.dart';

import 'repository_summary.dart';

/// Repository検索結果の1ページ分。
///
/// [items] は生成時に [List.unmodifiable] でコピーする。呼び出し側が渡した
/// 元Listを後から変更しても本インスタンスへは反映されず、[items] を介した
/// 変更（`add`・`[]=`等）も例外になるため、真の意味で不変になる。この防御的
/// コピーは呼び出し側で `const` 生成できる保証と両立しないため、本コンストラクタ
/// は意図的に非`const`にしている。
@immutable
final class RepositorySearchPage {
  /// 検索結果ページを生成する。
  ///
  /// [hasMore] が [nextPage] の有無と一致しない場合は [ArgumentError] を投げる。
  RepositorySearchPage({
    required List<RepositorySummary> items,
    required this.totalCount,
    required this.nextPage,
    required this.hasMore,
  }) : items = List.unmodifiable(items) {
    if (hasMore != (nextPage != null)) {
      throw ArgumentError(
        'hasMore must be true exactly when nextPage is non-null',
      );
    }
  }

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
