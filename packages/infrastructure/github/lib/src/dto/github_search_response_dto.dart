import 'dto_field_reader.dart';
import 'github_search_item_dto.dart';

/// `GET /search/repositories`のレスポンスボディ全体のDTO。
final class GithubSearchResponseDto {
  /// Response DTOを生成する。
  const GithubSearchResponseDto({
    required this.totalCount,
    required this.items,
  });

  /// `json`は`GET /search/repositories`のレスポンスボディ全体
  /// （トップレベルMap）。
  ///
  /// 必須フィールドの欠落・型不正は[FormatException]を投げる
  /// (呼び出し側のRepository実装で`RepositorySearchException`へ変換する)。
  factory GithubSearchResponseDto.fromJson(Map<String, dynamic> json) {
    final totalCount = requireField<int>(json, 'total_count');
    if (totalCount < 0) {
      throw FormatException(
        'GitHub search response has a negative "total_count": $totalCount',
      );
    }

    final itemsJson = requireField<List<dynamic>>(json, 'items');
    final items = itemsJson.map((item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException(
          'GitHub search response has an invalid "items" element: '
          '${item.runtimeType}',
        );
      }
      return GithubSearchItemDto.fromJson(item);
    }).toList();

    return GithubSearchResponseDto(totalCount: totalCount, items: items);
  }

  /// 検索条件に一致した総件数。
  final int totalCount;

  /// このページに含まれる検索結果。
  final List<GithubSearchItemDto> items;
}
