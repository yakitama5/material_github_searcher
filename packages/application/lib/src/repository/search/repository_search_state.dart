import 'package:domain/domain.dart';
import 'package:meta/meta.dart';

/// Repository検索一覧の状態遷移を表す区分。
///
/// [refreshing]は後続Issue（Pull to Refresh#82）が同じStateを拡張するための
/// 予約であり、本Issueではこの状態へ遷移する通信を実装しない。0件成功は
/// [success]かつ`items`が空の状態で表し、専用の区分は設けない。追加ページ
/// 取得の失敗は[success]のまま[RepositorySearchState.appendError]で表すため、
/// 専用の区分は設けない（`success`→`loadingMore`→`success`
/// (+`appendError`)という遷移になる）。
enum RepositorySearchStatus {
  /// まだ検索が実行されていない初期状態。
  initial,

  /// 初回ページを取得中。
  loading,

  /// 取得に成功した（0件成功を含む）。
  success,

  /// 初回取得に失敗した。
  error,

  /// 追加ページを取得中。
  loadingMore,

  /// Pull to Refreshによる再取得中（#82で実装。本Issueではこの状態へ遷移しない）。
  refreshing,
}

/// Repository検索一覧のSingle Source of Truthとなる不変な状態。
///
/// 送信済みquery・items・page状態・初回取得状態を1か所へ集約し、UIは本Stateを
/// watchしてローカルにitemsを複製しない。送信済みqueryは本Stateが所有し、検索Bar
/// の入力中textはWidget側で保持する。
///
/// 初回取得の失敗（[error]）はitemsとは独立して保持する。追加page取得の失敗は
/// [appendError]で独立して保持し、[error]とは混同しない（[error]が非`null`に
/// なるのは初回取得の失敗時のみ）。
@immutable
final class RepositorySearchState {
  /// 未検索の初期状態を生成する。
  const RepositorySearchState.initial()
    : query = null,
      status = RepositorySearchStatus.initial,
      items = const [],
      page = 0,
      hasMore = false,
      totalCount = null,
      error = null,
      appendError = null;

  /// [query]の初回ページを取得中の状態を生成する。
  ///
  /// 新queryの送信・retryごとにitems・page状態を初期化するため、items等は
  /// 空へリセットする。
  const RepositorySearchState.loading(this.query)
    : status = RepositorySearchStatus.loading,
      items = const [],
      page = 0,
      hasMore = false,
      totalCount = null,
      error = null,
      appendError = null;

  /// [query]・[result]から取得成功の状態を生成する。
  ///
  /// [page]は取得済みの最新page番号であり、後続の追加取得は[hasMore]と併せて
  /// この値を起点にする。0件成功（`result.items`が空）も本状態で表す。
  RepositorySearchState.success({
    required this.query,
    required RepositorySearchPage result,
    required this.page,
  }) : status = RepositorySearchStatus.success,
       items = List.unmodifiable(result.items),
       hasMore = result.hasMore,
       totalCount = result.totalCount,
       error = null,
       appendError = null;

  /// [query]の初回取得に失敗した状態を生成する。
  const RepositorySearchState.failure({
    required this.query,
    required this.error,
  }) : status = RepositorySearchStatus.error,
       items = const [],
       page = 0,
       hasMore = false,
       totalCount = null,
       appendError = null;

  const RepositorySearchState._({
    required this.query,
    required this.status,
    required this.items,
    required this.page,
    required this.hasMore,
    required this.totalCount,
    required this.error,
    required this.appendError,
  });

  /// 送信済みの検索query。未検索の場合は`null`。
  final RepositorySearchQuery? query;

  /// 現在の状態区分。
  final RepositorySearchStatus status;

  /// 取得済みの検索結果一覧。
  final List<RepositorySummary> items;

  /// 取得済みの最新page番号。未取得の場合は`0`。
  final int page;

  /// 次ページが存在するか。
  final bool hasMore;

  /// 検索条件に一致した総件数。未取得の場合は`null`。
  final int? totalCount;

  /// 初回取得の失敗内容。失敗していない場合は`null`。
  final AppException? error;

  /// 追加page取得の失敗内容。失敗していない、または未確定の場合は`null`。
  ///
  /// [status]が[RepositorySearchStatus.success]のときのみ非`null`になりうる。
  /// 次の追加取得を開始する（[toLoadingMore]）と`null`へ戻る。
  final AppException? appendError;

  /// 直近のitems・page状態を保ったまま、追加ページ取得中の状態へ遷移する。
  ///
  /// 直前の[appendError]は次の試行を開始した時点で表示対象から外すため
  /// `null`へ戻す。[status]が[RepositorySearchStatus.success]でない状態から
  /// 呼び出さないことは呼び出し側（Controller）が保証する。
  RepositorySearchState toLoadingMore() => RepositorySearchState._(
    query: query,
    status: RepositorySearchStatus.loadingMore,
    items: items,
    page: page,
    hasMore: hasMore,
    totalCount: totalCount,
    error: error,
    appendError: null,
  );

  /// 進行中の追加ページ取得がcancelされたときに、[toLoadingMore]直前の状態へ
  /// 戻す。
  ///
  /// [status]が[RepositorySearchStatus.loadingMore]でない場合は`this`を
  /// そのまま返す（cancel時に追加取得中でなければ何もしない）。[toLoadingMore]
  /// はitems・page・hasMore・totalCountを変更せずに`status`だけを切り替えて
  /// いるため、本メソッドはその逆操作としてロスなく`success`へ戻せる。
  RepositorySearchState cancelLoadingMore() {
    if (status != RepositorySearchStatus.loadingMore) {
      return this;
    }
    return RepositorySearchState._(
      query: query,
      status: RepositorySearchStatus.success,
      items: items,
      page: page,
      hasMore: hasMore,
      totalCount: totalCount,
      error: error,
      appendError: null,
    );
  }

  /// 追加ページ取得の成功を反映した状態を生成する。
  ///
  /// [items]は既存items（重複排除済み）とマージ済みの一覧全体を渡す。
  RepositorySearchState appended({
    required List<RepositorySummary> items,
    required int page,
    required bool hasMore,
    required int? totalCount,
  }) => RepositorySearchState._(
    query: query,
    status: RepositorySearchStatus.success,
    items: List.unmodifiable(items),
    page: page,
    hasMore: hasMore,
    totalCount: totalCount,
    error: error,
    appendError: null,
  );

  /// 追加ページ取得の失敗を反映した状態を生成する。
  ///
  /// items・page・hasMore・totalCountは変更せず、直前の一覧を維持する。
  RepositorySearchState appendFailed(AppException appendError) =>
      RepositorySearchState._(
        query: query,
        status: RepositorySearchStatus.success,
        items: items,
        page: page,
        hasMore: hasMore,
        totalCount: totalCount,
        error: error,
        appendError: appendError,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! RepositorySearchState || runtimeType != other.runtimeType) {
      return false;
    }
    if (query != other.query ||
        status != other.status ||
        page != other.page ||
        hasMore != other.hasMore ||
        totalCount != other.totalCount ||
        error != other.error ||
        appendError != other.appendError ||
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
  int get hashCode => Object.hash(
    query,
    status,
    Object.hashAll(items),
    page,
    hasMore,
    totalCount,
    error,
    appendError,
  );
}
