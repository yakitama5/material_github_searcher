import 'package:meta/meta.dart';

/// trim済みで非空であることを保証した検索履歴の1件分のkeyword。
///
/// GitHub検索構文（qualifier、引用符、内部の空白）は呼び出し側が指定した
/// とおり保持し、前後の空白だけを除去する。trim後に空文字となる入力は
/// 履歴として成立しないため、生成時に拒否する。
@immutable
final class SearchHistoryEntry {
  /// [raw] をtrimしてkeywordを生成する。
  ///
  /// trim後に空文字になる場合は [ArgumentError] を投げる。空文字を無視する
  /// 判断は呼び出し側（`SearchHistory.recordSubmittedKeyword`）が行う。
  SearchHistoryEntry(String raw) : keyword = raw.trim() {
    if (keyword.isEmpty) {
      // 開発者向けの引数検証メッセージのため日本語化の対象外とする。
      throw ArgumentError.value(
        raw,
        'raw',
        'keyword must not be empty after trimming',
      );
    }
  }

  /// trim済みの検索履歴keyword。
  final String keyword;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchHistoryEntry &&
          runtimeType == other.runtimeType &&
          keyword == other.keyword;

  @override
  int get hashCode => keyword.hashCode;
}
