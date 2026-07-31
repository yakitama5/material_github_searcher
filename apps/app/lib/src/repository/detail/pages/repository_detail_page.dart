import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/strings.g.dart';

/// Watcher行のRetryボタンのkey。
///
/// Widget Testから参照するため、`repositoryAppendErrorRetryButtonKey`等と
/// 同じく実装とテストで同一のリテラルを再定義せず本constを共有する。
const repositoryDetailWatcherRetryButtonKey = Key(
  'repositoryDetailWatcherRetryButton',
);

/// 検索結果一覧の要約情報を即時表示し、実Watcher数だけ非同期取得するRepository
/// Detail画面。
///
/// [summary]の6項目（名前・owner icon・言語・Star・Fork・Issue）は初回frameから
/// 実データで表示し、[repositoryDetailProvider]が返す実Watcher数
/// （`subscribers_count`）が届くまでWatcher行だけを`SkeletonText`にする。
/// `CircularProgressIndicator`のような全画面Loading・全画面Errorへは切り替えず、
/// Watcher行の状態遷移だけで表現する。route parameterや画面固有のViewModelは
/// 持たず、[repositoryDetailProvider]をSingle Source of Truthとしてwatchする。
class RepositoryDetailPage extends ConsumerWidget {
  /// [summary]から即時表示するRepository Detail画面を生成する。
  const RepositoryDetailPage({required this.summary, super.key});

  /// 検索結果一覧から渡されるRepositoryの要約情報。
  final RepositorySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = context.i18n.repositoryDetail;
    final colorScheme = Theme.of(context).colorScheme;
    final detail = ref.watch(repositoryDetailProvider(summary.identity));
    final languageLabel = summary.language ?? i18n.languageUnset;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OwnerHeader(summary: summary),
                const SizedBox(height: 24),
                MetaInfoRow(
                  icon: Icons.code,
                  iconColor: colorScheme.secondary,
                  label: i18n.languageLabel,
                  value: languageLabel,
                ),
                const SizedBox(height: 16),
                MetaInfoRow(
                  icon: Icons.star,
                  iconColor: colorScheme.tertiary,
                  label: i18n.starsLabel,
                  value: i18n.starsValue(count: summary.stargazersCount),
                ),
                const SizedBox(height: 16),
                MetaInfoRow(
                  icon: Icons.fork_right,
                  iconColor: colorScheme.primary,
                  label: i18n.forksLabel,
                  value: i18n.forksValue(count: summary.forksCount),
                ),
                const SizedBox(height: 16),
                MetaInfoRow(
                  icon: Icons.bug_report,
                  iconColor: colorScheme.error,
                  label: i18n.issuesLabel,
                  value: i18n.issuesValue(count: summary.openIssuesCount),
                ),
                const SizedBox(height: 16),
                _WatcherRow(
                  detail: detail,
                  onRetry: () => ref.invalidate(
                    repositoryDetailProvider(summary.identity),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// owner iconとRepository名を並べて表示するヘッダー。
///
/// owner iconの読み込み失敗時はfallback avatarへ切り替える。長い名前は
/// 最大2行まで折り返し、レイアウト崩れを防ぐ。
class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.summary});

  final RepositorySummary summary;

  static const _diameter = 64.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        ClipOval(
          child: Image.network(
            summary.ownerAvatarUrl,
            width: _diameter,
            height: _diameter,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: colorScheme.surfaceContainerHighest,
              child: SizedBox(
                width: _diameter,
                height: _diameter,
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            summary.identity.fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

/// 実Watcher数だけを[detail]の状態に応じて出し分ける行。
///
/// icon・labelは[MetaInfoRow]と同じ配置で固定し、値部分だけをLoading
/// （[SkeletonText]）・Data（`subscribersCount`）・Error（inline message +
/// Retry）で差し替える。これにより値部分が差し替わってもlayoutが跳ねない。
class _WatcherRow extends StatelessWidget {
  const _WatcherRow({required this.detail, required this.onRetry});

  final AsyncValue<RepositoryDetailSupplement> detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositoryDetail;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasError = !detail.isLoading && detail.hasError;

    final Widget valueWidget;
    if (detail.isLoading) {
      valueWidget = const Align(
        alignment: Alignment.centerRight,
        child: SkeletonScope(child: SkeletonText(width: 40)),
      );
    } else if (hasError) {
      valueWidget = Text(
        i18n.watcherError,
        maxLines: 2,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
      );
    } else {
      valueWidget = Text(
        i18n.watchersValue(count: detail.requireValue.subscribersCount),
        maxLines: 1,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: colorScheme.secondary,
          // iconColorに相当する背景色に対し常にコントラストを確保するため、
          // MetaInfoRowと同様に固定で白を重ねる。
          // ignore: altive_lints_plugin/avoid_hardcoded_color
          child: const Icon(Icons.visibility, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            i18n.watchersLabel,
            maxLines: 1,
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: valueWidget),
        if (hasError) ...[
          const SizedBox(width: 4),
          IconButton(
            key: repositoryDetailWatcherRetryButtonKey,
            icon: const Icon(Icons.refresh),
            tooltip: i18n.retryTooltip,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}
