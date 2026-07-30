import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

import 'search_history_repository_provider.dart';
import 'search_history_state.dart';

/// 検索履歴のSingle Source of Truthを管理するController。
///
/// Repository検索のStateとは相互参照させず、独立して送信済みkeywordを管理
/// する。アプリ全体で共有するSSOTのため`autoDispose`は使わず、画面遷移で
/// 履歴を失わない。
final searchHistoryControllerProvider =
    NotifierProvider<SearchHistoryController, SearchHistoryState>(
      SearchHistoryController.new,
    );

/// [searchHistoryControllerProvider]の状態を管理する[Notifier]。
final class SearchHistoryController extends Notifier<SearchHistoryState> {
  /// load・record・clearAllの呼び出しを識別する世代番号。
  ///
  /// 各操作の開始時に増やし、永続化完了（成功・失敗）時に呼び出し時点の
  /// 世代と現在の世代が一致するかを検証する。後発の呼び出しが既に新しい
  /// 履歴へ進んでいる場合、先発の遅延失敗が最新Stateを古いスナップショット
  /// で上書きしないための番兵。
  int _generation = 0;

  @override
  SearchHistoryState build() => SearchHistoryState.loading();

  /// 永続化済みの検索履歴を読み込み、メモリ上の履歴を置き換える。
  ///
  /// 呼び出しタイミング（アプリ起動時等）はComposition Root側の責務であり、
  /// 本Controllerは自動loadを行わない。失敗時はメモリ上の履歴（loadを呼ぶ前
  /// の内容。通常は空）を維持したまま[SearchHistoryStatus.persistenceError]
  /// へ遷移する。
  Future<void> load() async {
    final generation = ++_generation;
    final repository = ref.read(searchHistoryRepositoryProvider);
    try {
      final history = await repository.load();
      if (_isStale(generation)) {
        return;
      }
      state = SearchHistoryState.ready(history);
    } on AppException catch (error) {
      if (_isStale(generation)) {
        return;
      }
      state = SearchHistoryState.persistenceError(
        history: state.history,
        error: error,
      );
    }
  }

  /// [rawKeyword]をtrimして送信済みkeywordとして記録する。
  ///
  /// GitHub検索APIの成功・失敗・0件に関係なく、送信時に無条件で呼び出す
  /// 契約とする（呼び出しの順序制御はSearchBar側の責務）。trim後に空文字と
  /// なる場合は履歴を変更しない。非空の場合はメモリを楽観更新してから
  /// 永続化する。永続化に失敗しても、この楽観更新した履歴はロールバック
  /// せず維持する。
  Future<void> recordSubmittedKeyword(String rawKeyword) async {
    final next = state.history.recordSubmittedKeyword(rawKeyword);
    if (identical(next, state.history)) {
      return;
    }
    final generation = ++_generation;
    state = SearchHistoryState.ready(next);
    await _persist(next, generation);
  }

  /// 全履歴を削除する。
  ///
  /// 個別のkeyword単位の削除APIは提供しない。[recordSubmittedKeyword]と同様
  /// メモリを楽観更新してから永続化し、失敗してもメモリ上は空の履歴のまま
  /// 維持する。
  Future<void> clearAll() async {
    final next = state.history.clearAll();
    final generation = ++_generation;
    state = SearchHistoryState.ready(next);
    await _persist(next, generation);
  }

  Future<void> _persist(SearchHistory history, int generation) async {
    final repository = ref.read(searchHistoryRepositoryProvider);
    try {
      await repository.save(history);
    } on AppException catch (error) {
      if (_isStale(generation)) {
        return;
      }
      state = SearchHistoryState.persistenceError(
        history: history,
        error: error,
      );
    }
  }

  /// [generation]が最新の呼び出しでなければ`true`。
  ///
  /// load・record・clearAllのいずれかが後発で呼ばれ、既に世代が進んでいる
  /// 場合、先発の完了は破棄対象になる。
  bool _isStale(int generation) => generation != _generation;
}
