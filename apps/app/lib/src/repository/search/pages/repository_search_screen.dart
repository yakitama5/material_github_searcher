import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/strings.g.dart';
import '../widgets/repository_list_item_open_container.dart';
import '../widgets/repository_list_skeleton.dart';
import '../widgets/repository_search_bar.dart';
import '../widgets/repository_search_empty.dart';
import '../widgets/repository_search_initial.dart';
import '../widgets/repository_search_message_view.dart';
import '../widgets/search_history_suggestions.dart';

/// 一覧末尾からこの距離（論理px）以内へスクロールしたら次ページを先読みする。
///
/// Repository一覧行は1行あたり概ね70〜80px前後のため、本値は2〜3行分の
/// 「見えかけている」余白に相当する。
const _loadMoreThresholdExtent = 240.0;

/// 追加取得失敗時に末尾へ表示するRetryボタンのkey。
///
/// Widget Testから参照するため、`repositorySearchFieldKey`等と同じく
/// 実装とテストで同一のリテラルを再定義せず本constを共有する。
const repositoryAppendErrorRetryButtonKey = Key(
  'repositoryAppendErrorRetryButton',
);

/// 送信式SearchBarとSliver検索結果一覧を持つRepository検索画面。
///
/// [repositorySearchControllerProvider]のみをSingle Source of Truthとして
/// watchし、画面固有のViewModelは持たない。入力中の文字列だけを本Widgetが
/// ローカルに保持し、送信済みqueryはApplication State側が保持する。
class RepositorySearchScreen extends ConsumerStatefulWidget {
  /// Repository検索画面を生成する。
  const RepositorySearchScreen({super.key});

  @override
  ConsumerState<RepositorySearchScreen> createState() =>
      _RepositorySearchScreenState();
}

class _RepositorySearchScreenState
    extends ConsumerState<RepositorySearchScreen> {
  final _queryController = TextEditingController();
  final _searchFieldFocusNode = FocusNode(
    debugLabel: 'repositorySearchField',
  );

  /// SearchBarがフォーカスを得てから、送信・候補選択・全削除確定まで`true`。
  ///
  /// 候補タップ時にSearchBarがFocusを失ってもこのフラグは変化しないため、
  /// タップの完了前に候補一覧が消えてタップを取りこぼす競合を避ける。
  /// 一方でフォーカス喪失に反応させないため、SearchBar外へのタップでは
  /// 閉じない（送信・候補選択・全削除確定という明示的な操作でのみ閉じる）。
  bool _suggestionsVisible = false;

  @override
  void initState() {
    super.initState();
    _searchFieldFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _searchFieldFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_searchFieldFocusNode.hasFocus) {
      setState(() => _suggestionsVisible = true);
    }
  }

  void _submit(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(searchHistoryControllerProvider.notifier)
          .recordSubmittedKeyword(trimmed),
    );
    unawaited(
      ref.read(repositorySearchControllerProvider.notifier).submit(trimmed),
    );
    setState(() => _suggestionsVisible = false);
    _searchFieldFocusNode.unfocus();
  }

  void _selectSuggestion(String keyword) {
    _queryController.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
    _submit(keyword);
  }

  void _clearAllHistory() {
    unawaited(ref.read(searchHistoryControllerProvider.notifier).clearAll());
  }

  void _retry() {
    unawaited(ref.read(repositorySearchControllerProvider.notifier).retry());
  }

  void _loadNextPage() {
    unawaited(
      ref.read(repositorySearchControllerProvider.notifier).loadNextPage(),
    );
  }

  Future<void> _refresh() =>
      ref.read(repositorySearchControllerProvider.notifier).refresh();

  /// 一覧末尾付近までスクロールされたら次ページを先読みする。
  ///
  /// [CustomScrollView]自身が発するNotification（`depth == 0`）だけを対象と
  /// する。SearchBar内部の`TextField`（`EditableText`）も独自の横scroll用
  /// Scrollableを持ち、そのNotificationは`depth`を1以上に増やしながら本
  /// Widgetまでbubbleしてくるため、`depth`を見ないと入力中のcursor追従scroll
  /// だけで誤発火する。
  ///
  /// 追加取得失敗時（[RepositorySearchState.appendError]が非`null`）は、
  /// スクロールのたびに再試行を発火させず、末尾のRetryボタンでの明示的な
  /// 再試行だけを許可する。`hasMore`・進行中判定自体はController側の
  /// [RepositorySearchController.loadNextPage]が同期的にガードするため、
  /// ここでは重複呼出しを気にせず呼んでよい。
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    if (notification.metrics.extentAfter > _loadMoreThresholdExtent) {
      return false;
    }
    final state = ref.read(repositorySearchControllerProvider);
    if (state.status != RepositorySearchStatus.success ||
        !state.hasMore ||
        state.appendError != null) {
      return false;
    }
    _loadNextPage();
    return false;
  }

  List<SearchHistoryEntry> _filterSuggestions(
    List<SearchHistoryEntry> entries,
  ) {
    final trimmed = _queryController.text.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return entries;
    }
    return entries
        .where((entry) => entry.keyword.toLowerCase().contains(trimmed))
        .toList();
  }

  /// Pull to Refresh失敗を非破壊的なSnackbar（Retry付き）で通知する。
  ///
  /// 既存itemsは維持したままなので、全画面Error表示や末尾Error行のような
  /// 破壊的な表示へは切り替えない。
  void _handleSearchStateChange(
    RepositorySearchState? previous,
    RepositorySearchState next,
  ) {
    final refreshError = next.refreshError;
    if (refreshError == null) {
      return;
    }
    final i18n = context.i18n.repositorySearch;
    SnackBarManager.showErrorSnackBar(
      _resolveErrorMessage(context, refreshError),
      actionLabel: i18n.retry,
      onAction: () => unawaited(_refresh()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RepositorySearchState>(
      repositorySearchControllerProvider,
      _handleSearchStateChange,
    );
    final state = ref.watch(repositorySearchControllerProvider);
    final historyState = ref.watch(searchHistoryControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: M3RefreshIndicator(
              refreshing: state.status == RepositorySearchStatus.refreshing,
              onRefresh: _refresh,
              // 未検索・初回loading（Skeleton表示）・初回errorはrefresh()
              // 自体が何もしないため、指を引いてもIndicatorだけが反応する
              // 見た目のちぐはぐさを避けるためgesture自体を無効化する。
              // `RepositorySearchController.refresh`のガード条件と揃える。
              enabled:
                  state.status == RepositorySearchStatus.success ||
                  state.status == RepositorySearchStatus.loadingMore ||
                  state.status == RepositorySearchStatus.refreshing,
              // SliverAppBar内のSearchBar（既定のtoolbarHeight）の下あたりに
              // 表示位置を合わせるため、既定の16よりも下へIndicatorをずらす
              // （pull量が少ない間はSearchBarと重なる場合があるが、途中経過
              // の見た目の自然さを優先し許容する）。
              offset: kToolbarHeight + 16,
              semanticsLabel: context.i18n.repositorySearch.refreshing,
              pullSemanticsLabel: context.i18n.repositorySearch.pulling,
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: CustomScrollView(
                  key: const PageStorageKey<String>(
                    'repository-search-scroll',
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      automaticallyImplyLeading: false,
                      titleSpacing: 16,
                      title: RepositorySearchBar(
                        controller: _queryController,
                        focusNode: _searchFieldFocusNode,
                        onSubmit: _submit,
                      ),
                    ),
                    // 絞り込みは1文字入力ごとに発生するため、検索結果一覧を
                    // 含む画面全体ではなく本sliverだけを`_queryController`の
                    // 変更に反応させ、再構築範囲を最小化する。
                    SliverToBoxAdapter(
                      child: ListenableBuilder(
                        listenable: _queryController,
                        builder: (context, _) {
                          if (!_suggestionsVisible) {
                            return const SizedBox.shrink();
                          }
                          final suggestions = _filterSuggestions(
                            historyState.history.entries,
                          );
                          if (suggestions.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return SearchHistorySuggestions(
                            entries: suggestions,
                            onSelect: _selectSuggestion,
                            onClearAllConfirmed: _clearAllHistory,
                          );
                        },
                      ),
                    ),
                    _RepositorySearchBody(
                      state: state,
                      onRetry: _retry,
                      onRetryAppend: _loadNextPage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RepositorySearchBody extends StatelessWidget {
  const _RepositorySearchBody({
    required this.state,
    required this.onRetry,
    required this.onRetryAppend,
  });

  final RepositorySearchState state;
  final VoidCallback onRetry;
  final VoidCallback onRetryAppend;

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;

    return switch (state.status) {
      RepositorySearchStatus.initial => const SliverFillRemaining(
        hasScrollBody: false,
        child: RepositorySearchInitial(),
      ),
      RepositorySearchStatus.loading => const SliverToBoxAdapter(
        child: RepositoryListSkeleton(),
      ),
      RepositorySearchStatus.error => SliverFillRemaining(
        hasScrollBody: false,
        child: RepositorySearchMessageView(
          icon: Icons.error_outline,
          message: _resolveErrorMessage(context, state.error!),
          retryLabel: i18n.retry,
          onRetry: onRetry,
        ),
      ),
      // refreshing中はPull to Refreshの進捗を`M3RefreshIndicator`の
      // オーバーレイ（build内）だけで表す。一覧自体はsuccessと同じ表示を
      // 維持し、既存itemsを隠さない。
      RepositorySearchStatus.success ||
      RepositorySearchStatus.loadingMore ||
      RepositorySearchStatus.refreshing => _buildResults(context),
    };
  }

  Widget _buildResults(BuildContext context) {
    if (state.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: RepositorySearchEmpty(),
      );
    }

    final appendError = state.appendError;
    final trailingWidget = switch (state.status) {
      RepositorySearchStatus.loadingMore => const RepositoryListItemSkeleton(),
      _ when appendError != null => _AppendErrorRow(
        message: _resolveErrorMessage(context, appendError),
        onRetry: onRetryAppend,
      ),
      _ => null,
    };

    return SliverList.builder(
      itemCount: state.items.length + (trailingWidget == null ? 0 : 1),
      itemBuilder: (context, index) => index < state.items.length
          ? RepositoryListItemOpenContainer(summary: state.items[index])
          : trailingWidget!,
    );
  }
}

/// 追加ページ取得失敗時に一覧末尾へ表示するError/Retry行。
///
/// 全画面表示の[RepositorySearchMessageView]と異なり、既存の一覧を維持した
/// まま末尾1行分だけに収める。
class _AppendErrorRow extends StatelessWidget {
  const _AppendErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(
            key: repositoryAppendErrorRetryButtonKey,
            onPressed: onRetry,
            child: Text(i18n.retry),
          ),
        ],
      ),
    );
  }
}

/// [error]をユーザー向け文言へ変換する。
///
/// `AppException`階層はRate Limit専用のサブタイプをまだ持たず
/// （`packages/domain/lib/src/error/app_exception.dart`参照）、GitHub側の
/// Rate Limit判定はinfrastructure層（`github_exception_mapper.dart`）が
/// 組み立てた開発者向け`message`文字列にのみ残っている。専用サブタイプが
/// 追加されるまでの暫定として、本アプリ層でその文字列を検査してRate Limit
/// 専用文言を出し分ける。
String _resolveErrorMessage(BuildContext context, AppException error) {
  final i18n = context.i18n.repositorySearch;
  final message = error.message;
  final isRateLimited =
      error is RepositorySearchException &&
      message != null &&
      message.contains('rate limit exceeded');
  return isRateLimited ? i18n.errorRateLimited : i18n.errorGeneric;
}
