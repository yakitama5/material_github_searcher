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

  /// メモリ上の履歴（[SearchHistoryState.history]）が永続化済み実体を反映
  /// している、またはそれ以降の変更がメモリ側の意図を優先してよいと確定
  /// していれば`true`。
  ///
  /// falseの間に[recordSubmittedKeyword]がメモリ上の履歴を基点にそのまま
  /// save()すると、実体を空/不完全な履歴で上書きして失う（load未完了・
  /// 未実行・失敗時の競合）。staleと判定され[SearchHistoryState]へ反映され
  /// なかった読込結果でtrueにしてはならない（反映されなかった実体を
  /// 「確認済み」と誤認する）。
  bool _loaded = false;

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
    try {
      final history = await _readFromDisk();
      if (_isStale(generation)) {
        return;
      }
      _loaded = true;
      state = SearchHistoryState.ready(history);
    } on AppException catch (error) {
      if (_isStale(generation)) {
        return;
      }
      _toPersistenceError(error);
    }
  }

  /// [rawKeyword]をtrimして送信済みkeywordとして記録する。
  ///
  /// GitHub検索APIの成功・失敗・0件に関係なく、送信時に無条件で呼び出す
  /// 契約とする（呼び出しの順序制御はSearchBar側の責務）。trim後に空文字と
  /// なる場合は履歴を変更しない。非空の場合はメモリを楽観更新してから
  /// 永続化する。永続化に失敗しても、この楽観更新した履歴はロールバック
  /// せず維持する。
  ///
  /// [_loaded]がfalseの場合（loadが未完了・未実行・失敗のいずれか）は、
  /// 楽観更新した履歴をそのまま永続化しない。実体を確認できていない状態で
  /// save()すると、メモリ上の空/不完全な履歴で実体を上書きして失うため、
  /// 先にdiskを読み直し、その結果へ楽観更新分を積み直してから永続化する。
  /// 再試行しても実体を確認できない場合は、メモリ上の楽観更新のみ維持し
  /// 永続化は行わない。
  Future<void> recordSubmittedKeyword(String rawKeyword) async {
    final next = state.history.recordSubmittedKeyword(rawKeyword);
    if (identical(next, state.history)) {
      return;
    }
    final generation = ++_generation;
    state = SearchHistoryState.ready(next);

    if (_loaded) {
      await _persist(next, generation);
      return;
    }

    try {
      final disk = await _readFromDisk();
      if (_isStale(generation)) {
        return;
      }
      _loaded = true;
      final rebased = _rebase(disk, onto: state.history);
      state = SearchHistoryState.ready(rebased);
      await _persist(rebased, generation);
    } on AppException catch (error) {
      if (_isStale(generation)) {
        return;
      }
      _toPersistenceError(error);
    }
  }

  /// 全履歴を削除する。
  ///
  /// 個別のkeyword単位の削除APIは提供しない。[recordSubmittedKeyword]と同様
  /// メモリを楽観更新してから永続化し、失敗してもメモリ上は空の履歴のまま
  /// 維持する。
  ///
  /// 結果（空の履歴）は基点に依存しないため、[_loaded]の状態に関わらず
  /// そのまま永続化してよい。呼び出し後は「メモリ＝空」がそのまま実体の
  /// 意図となるため、[_loaded]をtrueにして以降の[recordSubmittedKeyword]が
  /// disk再読込による積み直しを行わないようにする（積み直すと、削除した
  /// はずの実体が復元されてしまう）。
  Future<void> clearAll() async {
    final next = state.history.clearAll();
    final generation = ++_generation;
    _loaded = true;
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
      _toPersistenceError(error);
    }
  }

  /// [SearchHistoryRepository.load]を呼ぶ。
  ///
  /// [_generation]・[_loaded]には触れない。呼び出し元がgenerationの検証・
  /// [_loaded]の更新・Stateの反映を責務として持つ（staleと判定された読込の
  /// 結果を[_loaded]へ反映してしまうと、反映されなかった実体を「確認済み」
  /// と誤認する）。
  Future<SearchHistory> _readFromDisk() {
    final repository = ref.read(searchHistoryRepositoryProvider);
    return repository.load();
  }

  /// [onto]（メモリ上の履歴）の各entryを最も古いものから順に[disk]（実体）へ
  /// 再適用し、実体を基点とした履歴を返す。
  ///
  /// [onto]は最近順（先頭が最新）で並ぶため、逆順に適用することで元の相対
  /// 順序を保ったまま実体の上に積み直せる。
  SearchHistory _rebase(SearchHistory disk, {required SearchHistory onto}) =>
      disk.recordAll(onto.entries.reversed.map((entry) => entry.keyword));

  /// [state]を[error]を伴う[SearchHistoryStatus.persistenceError]へ遷移する。
  ///
  /// 履歴は現在の[SearchHistoryState.history]をそのまま維持する。
  void _toPersistenceError(AppException error) {
    state = SearchHistoryState.persistenceError(
      history: state.history,
      error: error,
    );
  }

  /// [generation]が最新の呼び出しでなければ`true`。
  ///
  /// load・record・clearAllのいずれかが後発で呼ばれ、既に世代が進んでいる
  /// 場合、先発の完了は破棄対象になる。
  bool _isStale(int generation) => generation != _generation;
}
