import 'package:animations/animations.dart';
import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../detail/pages/repository_detail_page.dart';
import 'repository_list_item.dart';

/// 検索結果一覧の1行を`OpenContainer`で包み、Repository Detail画面への
/// Container Transformを行うWidget。
///
/// `closedBuilder`に既存の[RepositoryListItem]、`openBuilder`に
/// [RepositoryDetailPage]を配置する。tap時は[RepositoryDetailPage]側の
/// Future完了を待たず、同一event loop内で
/// [RepositorySearchController.cancelPendingRequest]を呼んでから
/// `openContainer`を呼ぶ。Detailはgo_router管理外の`OpenContainer`内部Route
/// として開くため、`useRootNavigator: true`でBottom Navigation/Railを覆う。
///
/// closed状態の`color`はTheme（`ColorScheme.surface`）由来にする。本アプリの
/// `ThemeData`（`main.dart`）は`CardTheme`を設定しておらず
/// `Theme.of(context).cardTheme`のelevation・shapeは常に`null`のため、
/// それらをTheme由来として扱うと実体は無条件でfallback literalが使われる
/// だけになる。closed行は元々`ListTile`の平面表示のため、
/// `closedElevation: 0`・角丸の無い`closedShape`を明示することで、遷移前後の
/// 見た目を平面のまま維持する（Card風の影・角丸を新たに持ち込まない）。
class RepositoryListItemOpenContainer extends ConsumerWidget {
  /// [summary]の1件をOpenContainerで包んだ行を生成する。
  const RepositoryListItemOpenContainer({required this.summary, super.key});

  /// 検索結果一覧から渡すRepositoryの要約情報。
  final RepositorySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return OpenContainer<void>(
      useRootNavigator: true,
      closedColor: colorScheme.surface,
      openColor: colorScheme.surface,
      closedElevation: 0,
      closedShape: const RoundedRectangleBorder(),
      openBuilder: (context, closeContainer) =>
          RepositoryDetailPage(summary: summary),
      closedBuilder: (context, openContainer) => RepositoryListItem(
        summary: summary,
        onTap: (_) {
          ref
              .read(repositorySearchControllerProvider.notifier)
              .cancelPendingRequest();
          openContainer();
        },
      ),
    );
  }
}
