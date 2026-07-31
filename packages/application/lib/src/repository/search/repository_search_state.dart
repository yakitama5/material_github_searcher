import 'package:domain/domain.dart';
import 'package:meta/meta.dart';

/// Repository検索一覧の状態遷移を表す区分。
///
/// 0件成功は[success]かつ`items`が空の状態で表し、専用の区分は設けない。
/// 追加ページ取得の失敗は[success]のまま[RepositorySearchState.appendError]で
/// 表すため、専用の区分は設けない（`success`→`loadingMore`→`success`
/// (+`appendError`)という遷移になる）。Pull to Refreshの失敗も同様に[success]
/// のまま[RepositorySearchState.refreshError]で表す（`success`→`refreshing`→
/// `success`(+`refreshError`)という遷移になる）。
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

  /// Pull to Refreshによる再取得中。
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
      appendError = null,
      refreshError = null;

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
      appendError = null,
      refreshError = null;

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
       appendError = null,
       refreshError = null;

  /// [query]の初回取得に失敗した状態を生成する。
  const RepositorySearchState.failure({
    required this.query,
    required this.error,
  }) : status = RepositorySearchStatus.error,
       items = const [],
       page = 0,
       hasMore = false,
       totalCount = null,
       appendError = null,
       refreshError = null;

  const RepositorySearchState._({
    required this.query,
    required this.status,
    required this.items,
    required this.page,
    required this.hasMore,
    required this.totalCount,
    required this.error,
    required this.appendError,
    required this.refreshError,
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

  /// Pull to Refreshの失敗内容。失敗していない、または未確定の場合は`null`。
  ///
  /// [status]が[RepositorySearchStatus.success]のときのみ非`null`になりうる。
  /// 一覧を維持したまま通知（Snackbar等）だけで表す一過性の値であり、
  /// [refreshFailed]直後の1回の状態遷移だけで非`null`になる。それ以外の全ての
  /// 遷移（[toLoadingMore]・[toRefreshing]・[cancelInFlight]・[appended]・
  /// [appendFailed]）で`null`へ戻すため、`ref.listen`側は`next.refreshError`の
  /// 非`null`だけを見れば、無関係な後続遷移で通知が誤って再発火しない。
  final AppException? refreshError;

  /// 直近のitems・page状態を保ったまま、追加ページ取得中の状態へ遷移する。
  ///
  /// 直前の[appendError]は次の試行を開始した時点で表示対象から外すため
  /// `null`へ戻す。[refreshError]はSnackbar等での一過性通知用の値であり、
  /// [refreshFailed]直後の1回の状態遷移でだけ非`null`になるべきため、無関係な
  /// 本遷移でも持ち越さず`null`へ戻す（`ref.listen`側が`next.refreshError`の
  /// 非`null`だけを見て通知しても、無関係な後続遷移で誤発火しないようにする
  /// ため）。[status]が[RepositorySearchStatus.success]でない状態から呼び出さ
  /// ないことは呼び出し側（Controller）が保証する。
  RepositorySearchState toLoadingMore() => RepositorySearchState._(
    query: query,
    status: RepositorySearchStatus.loadingMore,
    items: items,
    page: page,
    hasMore: hasMore,
    totalCount: totalCount,
    error: error,
    appendError: null,
    refreshError: null,
  );

  /// 直近のitems・page状態を保ったまま、Pull to Refresh中の状態へ遷移する。
  ///
  /// 直前の[appendError]・[refreshError]は次の試行を開始した時点で表示対象
  /// から外すため`null`へ戻す。[status]が[RepositorySearchStatus.success]・
  /// [RepositorySearchStatus.loadingMore]・既に
  /// [RepositorySearchStatus.refreshing]以外から呼び出さないことは呼び出し側
  /// （Controller）が保証する。
  RepositorySearchState toRefreshing() => RepositorySearchState._(
    query: query,
    status: RepositorySearchStatus.refreshing,
    items: items,
    page: page,
    hasMore: hasMore,
    totalCount: totalCount,
    error: error,
    appendError: null,
    refreshError: null,
  );

  /// 進行中の追加ページ取得・Pull to Refreshがcancelされたときに、遷移前の
  /// [RepositorySearchStatus.success]へ戻す。
  ///
  /// [status]が[RepositorySearchStatus.loadingMore]・
  /// [RepositorySearchStatus.refreshing]のいずれでもない場合は`this`をそのまま
  /// 返す（cancel時にどちらでもなければ何もしない）。[toLoadingMore]・
  /// [toRefreshing]はitems・page・hasMore・totalCountを変更せずに`status`だけを
  /// 切り替えているため、本メソッドはその逆操作としてロスなく`success`へ戻せる。
  RepositorySearchState cancelInFlight() {
    if (status != RepositorySearchStatus.loadingMore &&
        status != RepositorySearchStatus.refreshing) {
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
      refreshError: null,
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
    refreshError: null,
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
        refreshError: null,
      );

  /// Pull to Refreshの失敗を反映した状態を生成する。
  ///
  /// items・page・hasMore・totalCountは変更せず、直前の一覧を維持する。
  RepositorySearchState refreshFailed(AppException refreshError) =>
      RepositorySearchState._(
        query: query,
        status: RepositorySearchStatus.success,
        items: items,
        page: page,
        hasMore: hasMore,
        totalCount: totalCount,
        error: error,
        appendError: appendError,
        refreshError: refreshError,
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
        refreshError != other.refreshError ||
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
    refreshError,
  );
}
