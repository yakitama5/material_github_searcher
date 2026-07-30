import 'dart:async';

import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/strings.g.dart';
import '../widgets/repository_list_item.dart';
import '../widgets/repository_list_skeleton.dart';
import '../widgets/repository_search_bar.dart';
import '../widgets/repository_search_message_view.dart';

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

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _submit(String rawQuery) {
    unawaited(
      ref.read(repositorySearchControllerProvider.notifier).submit(rawQuery),
    );
  }

  void _retry() {
    unawaited(ref.read(repositorySearchControllerProvider.notifier).retry());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repositorySearchControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: CustomScrollView(
              key: const PageStorageKey<String>('repository-search-scroll'),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  automaticallyImplyLeading: false,
                  titleSpacing: 16,
                  title: RepositorySearchBar(
                    controller: _queryController,
                    onSubmit: _submit,
                  ),
                ),
                _RepositorySearchBody(state: state, onRetry: _retry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepositorySearchBody extends StatelessWidget {
  const _RepositorySearchBody({required this.state, required this.onRetry});

  final RepositorySearchState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;

    return switch (state.status) {
      RepositorySearchStatus.initial => SliverFillRemaining(
        hasScrollBody: false,
        child: RepositorySearchMessageView(
          icon: Icons.search,
          message: i18n.guidance,
        ),
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
      // loadingMore・refreshingは後続Issue（#81・#82）が専用UIを追加するまでの
      // 暫定として、直近取得済みのitemsをsuccessと同じ表示のまま維持する。
      // 本Issueのcontrollerはこれらの状態へ遷移しないが、enumの網羅性のため
      // 分岐上はここへ含める。
      RepositorySearchStatus.success ||
      RepositorySearchStatus.loadingMore ||
      RepositorySearchStatus.refreshing =>
        state.items.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: RepositorySearchMessageView(
                  icon: Icons.inbox_outlined,
                  message: i18n.empty,
                ),
              )
            : SliverList.builder(
                itemCount: state.items.length,
                itemBuilder: (context, index) =>
                    RepositoryListItem(summary: state.items[index]),
              ),
    };
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
