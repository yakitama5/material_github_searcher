import 'package:meta/meta.dart';

import 'search_history_entry.dart';

/// 送信済み検索keywordの履歴を表す不変な値オブジェクト。
///
/// 保存方式やUIから独立した履歴ルールのSSOTであり、trim・重複排除・最大件数
/// を本型が決定的に表現する。[entries]は最近送信した順（先頭が最新）に並ぶ。
@immutable
final class SearchHistory {
  /// [entries]から履歴を生成する。
  ///
  /// [entries]は防御的にコピーし、呼び出し側の変更から独立させる。省略時は
  /// 空の履歴になる。
  SearchHistory({List<SearchHistoryEntry> entries = const []})
    : entries = List.unmodifiable(entries);

  /// 最大保持件数。
  static const maxEntries = 10;

  /// 最近送信した順（先頭が最新）に並ぶ履歴一覧。
  final List<SearchHistoryEntry> entries;

  /// [rawKeyword]をtrimして記録した新しい履歴を返す。
  ///
  /// trim後に空文字となる場合は記録せず自身をそのまま返す。trim後に既存と
  /// 同一keywordがあれば重複させず削除してから先頭へ移動する。結果が
  /// [maxEntries]を超える場合は古い履歴から切り捨てる。
  SearchHistory recordSubmittedKeyword(String rawKeyword) {
    final trimmed = rawKeyword.trim();
    if (trimmed.isEmpty) {
      return this;
    }
    final deduplicated = entries.where((entry) => entry.keyword != trimmed);
    final next = [SearchHistoryEntry(trimmed), ...deduplicated];
    return SearchHistory(entries: next.take(maxEntries).toList());
  }

  /// [keywords]を先頭から順に[recordSubmittedKeyword]で記録した履歴を返す。
  ///
  /// 保存/送信順が最近順（先頭が最新）の一覧をそのまま復元したい場合は、
  /// 末尾（最も古いもの）から順に渡すと、trim・重複排除・最大件数のルール
  /// を保ったまま元の順序を再現できる。
  SearchHistory recordAll(Iterable<String> keywords) {
    var history = this;
    for (final keyword in keywords) {
      history = history.recordSubmittedKeyword(keyword);
    }
    return history;
  }

  /// 全履歴を削除した空の履歴を返す。
  SearchHistory clearAll() => SearchHistory();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SearchHistory || runtimeType != other.runtimeType) {
      return false;
    }
    if (entries.length != other.entries.length) {
      return false;
    }
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != other.entries[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);
}
