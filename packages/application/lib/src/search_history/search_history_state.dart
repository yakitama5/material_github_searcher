import 'package:domain/domain.dart';
import 'package:meta/meta.dart';

/// 検索履歴の状態遷移を表す区分。
enum SearchHistoryStatus {
  /// 永続化済み履歴を未load、またはload中。
  loading,

  /// メモリ上の履歴が最新で、直近の永続化操作は成功している。
  ready,

  /// 直近の永続化操作（load・record・clearAll）が失敗した。
  ///
  /// メモリ上の履歴（[SearchHistoryState.history]）は失敗前の内容を維持し、
  /// 失敗によって履歴自体を失わせない。
  persistenceError,
}

/// 検索履歴のSingle Source of Truthとなる不変な状態。
///
/// 送信済み検索keyword最大10件の履歴（[history]）と、直近の永続化操作の
/// 成否（[status]・[error]）を1か所へ集約する。保存方式やUIからは独立して
/// おり、Repository検索のStateとは相互参照しない。
@immutable
final class SearchHistoryState {
  /// 未load・load中の状態を生成する。
  ///
  /// メモリ上の履歴はまだ無いため空の履歴を保持する。
  SearchHistoryState.loading()
    : history = SearchHistory(),
      status = SearchHistoryStatus.loading,
      error = null;

  /// [history]で直近の永続化操作に成功した状態を生成する。
  const SearchHistoryState.ready(this.history)
    : status = SearchHistoryStatus.ready,
      error = null;

  /// [history]を維持したまま、直近の永続化操作が[error]で失敗した状態を生成する。
  const SearchHistoryState.persistenceError({
    required this.history,
    required this.error,
  }) : status = SearchHistoryStatus.persistenceError;

  /// 現在メモリ上に保持している検索履歴。
  final SearchHistory history;

  /// 現在の状態区分。
  final SearchHistoryStatus status;

  /// 直近の永続化操作の失敗内容。失敗していない場合は`null`。
  final AppException? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchHistoryState &&
          runtimeType == other.runtimeType &&
          history == other.history &&
          status == other.status &&
          error == other.error;

  @override
  int get hashCode => Object.hash(history, status, error);
}
