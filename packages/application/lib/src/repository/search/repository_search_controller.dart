import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

import 'repository_search_repository_provider.dart';
import 'repository_search_state.dart';

/// Repository検索一覧のSingle Source of Truthを管理するController。
///
/// 送信済みquery・items・初回取得状態を1つの手書きNotifierで保持し、APIから
/// PresentationへのStateの単方向データフローを確立する。autoDisposeにより画面が
/// 破棄されると自動でdisposeし、進行中requestをcancelする。
final repositorySearchControllerProvider =
    NotifierProvider.autoDispose<
      RepositorySearchController,
      RepositorySearchState
    >(RepositorySearchController.new);

/// [repositorySearchControllerProvider]の状態を管理する[Notifier]。
final class RepositorySearchController extends Notifier<RepositorySearchState> {
  /// 1ページあたりの取得件数。1ページ目は本件数で取得する。
  static const _perPage = 30;

  /// 初回取得のページ番号。
  static const _firstPage = 1;

  /// 進行中requestを識別する世代番号。
  ///
  /// 新query・retryごとに増やし、await完了時に最新世代と一致するかを検証する。
  /// 遅れて完了した旧requestが最新Stateを上書きしないための番兵。
  int _generation = 0;

  /// 進行中requestのキャンセルコントローラ。進行中でなければ`null`。
  CancellationController? _pendingController;

  @override
  RepositorySearchState build() {
    // Provider dispose時に進行中requestを中断する。
    ref.onDispose(() => _pendingController?.cancel());
    return const RepositorySearchState.initial();
  }

  /// [rawQuery]をtrimして初回検索を実行する。
  ///
  /// trim後に空となるqueryではAPIを呼ばず、Stateも変更しない。非空queryは
  /// 進行中の旧requestをcancelしてから、page1・[_perPage]件で検索する。
  Future<void> submit(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _search(RepositorySearchQuery(trimmed));
  }

  /// 直近に送信済みのqueryで初回検索を再実行する。
  ///
  /// 未検索（送信済みqueryが無い）の場合は何もしない。
  Future<void> retry() async {
    final query = state.query;
    if (query == null) {
      return;
    }
    await _search(query);
  }

  /// 進行中requestをcancelする。
  ///
  /// cancelは通知用のerror Stateへ遷移させない。Settings・OpenContainer遷移の
  /// 直前などに呼び、遅延responseによるState更新を抑止する。
  void cancelPendingRequest() {
    _pendingController?.cancel();
    _pendingController = null;
  }

  Future<void> _search(RepositorySearchQuery query) async {
    // queryごとに進行中requestは1つだけ許可する。旧requestをcancelし、世代を進める。
    _pendingController?.cancel();
    final controller = CancellationController();
    _pendingController = controller;
    final generation = ++_generation;

    state = RepositorySearchState.loading(query);

    final repository = ref.read(repositorySearchRepositoryProvider);
    try {
      final result = await repository.search(
        query: query,
        page: _firstPage,
        perPage: _perPage,
        cancellationToken: controller.token,
      );
      // 遅延responseによる最新Stateの上書きを二重のガードで防ぐ。
      // 現状の設計ではsupersessionが必ずcancelを伴うため両条件は重なるが、
      // generation検証はIssue #76の独立要件であり、将来supersessionがcancelを
      // 伴わなくなっても保護する防御的多重化として意図的に併存させる。
      if (_isStale(generation, controller)) {
        return;
      }
      state = RepositorySearchState.success(
        query: query,
        result: result,
        page: _firstPage,
      );
    } on RequestCancelledException {
      // cancelは通知用error Stateへ遷移させない。
      return;
    } on AppException catch (error) {
      // 成功パスと同じく、遅延失敗が最新Stateを上書きしないよう二重ガードする。
      if (_isStale(generation, controller)) {
        return;
      }
      state = RepositorySearchState.failure(query: query, error: error);
    }
  }

  /// requestが破棄対象なら`true`。
  ///
  /// 世代不一致は新query・retryによるsupersessionを、token cancelは
  /// [cancelPendingRequest]・Provider disposeを検出する。後者は世代を進めない
  /// ため、tokenの検証が無いとcancel後の遅延responseを取りこぼす。
  bool _isStale(int generation, CancellationController controller) =>
      generation != _generation || controller.token.isCancelled;
}
