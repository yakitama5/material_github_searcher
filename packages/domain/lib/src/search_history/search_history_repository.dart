import '../error/app_exception.dart';
import 'search_history.dart';

/// 検索履歴の永続化を行うリポジトリの抽象。
///
/// 実装は`packages/infrastructure/*`が担い、`domain`は保存先（SharedPreferences
/// 等）の詳細に依存しない。永続化に失敗した場合は
/// [SearchHistoryPersistenceException]を投げる契約とし、Applicationは
/// メモリ上の履歴を維持したままこの型で失敗を扱う。
abstract interface class SearchHistoryRepository {
  /// 永続化済みの検索履歴を読み込む。
  ///
  /// 永続化されたデータが存在しない場合は空の[SearchHistory]を返す。
  Future<SearchHistory> load();

  /// [history]を永続化する。
  ///
  /// 個別のkeyword単位のAPIは提供せず、常に履歴全体を上書き保存する契約と
  /// する（全削除は空の[SearchHistory]を渡すことで表現する）。
  Future<void> save(SearchHistory history);
}
