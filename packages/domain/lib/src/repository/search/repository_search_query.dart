import 'package:meta/meta.dart';

/// trim済みで非空であることを保証したRepository検索キーワード。
///
/// 前後の空白だけを除去し、GitHub検索構文（qualifier、引用符、内部の空白）は
/// 呼び出し側が指定したとおり保持する。trim後に空文字となる入力は検索対象と
/// して成立しないため、生成時に拒否する。
@immutable
final class RepositorySearchQuery {
  /// [raw] をtrimしてqueryを生成する。
  ///
  /// trim後に空文字になる場合は [ArgumentError] を投げる。
  RepositorySearchQuery(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      // 開発者向けの引数検証メッセージのため日本語化の対象外とする。
      throw ArgumentError.value(
        raw,
        'raw',
        'query must not be empty after trimming',
      );
    }
  }

  /// trim済みのクエリ文字列。
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositorySearchQuery &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
