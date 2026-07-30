import 'package:application/application.dart';
import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/strings.g.dart';

/// Search branchのStatefulShellBranch内でのindex。
///
/// branch定義順（`go_router_provider.dart`）と対応させ、Search branchから
/// 離脱するタイミングの判定に使う。
const _searchBranchIndex = 0;

/// 画面幅に応じてナビゲーションを切り替えるアプリケーションシェル。
class AdaptiveAppShell extends ConsumerWidget {
  /// [navigationShell] が管理する各ブランチの状態を保ったまま表示する。
  const AdaptiveAppShell({required this.navigationShell, super.key});

  /// 各ブランチのNavigatorを保持し、ブランチ切り替えを行うシェル。
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowSizeClass = WindowSizeClass.fromWidth(
      MediaQuery.widthOf(context),
    );
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.search),
        label: context.i18n.common.navigation.search,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings),
        label: context.i18n.common.navigation.settings,
      ),
    ];
    final railDestinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.search),
        label: Text(context.i18n.common.navigation.search),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings),
        label: Text(context.i18n.common.navigation.settings),
      ),
    ];

    return switch (windowSizeClass) {
      WindowSizeClass.compact => Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => _onDestinationSelected(ref, index),
          destinations: destinations,
        ),
      ),
      WindowSizeClass.medium || WindowSizeClass.expanded => Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: windowSizeClass == WindowSizeClass.expanded,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(ref, index),
              destinations: railDestinations,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    };
  }

  void _onDestinationSelected(WidgetRef ref, int index) {
    final isCurrentBranch = index == navigationShell.currentIndex;
    if (isCurrentBranch) {
      navigationShell.route.branches[index].navigatorKey.currentState?.popUntil(
        (route) => route.isFirst,
      );
    } else if (navigationShell.currentIndex == _searchBranchIndex) {
      // Search branchから離脱する遷移時は、indexedStackがWidget状態を保持し
      // 続けるため`autoDispose`のcancel（`ref.onDispose`）が発火しない。
      // 遷移直前に明示的にcancelし、遅延responseによるState更新を防ぐ。
      ref
          .read(repositorySearchControllerProvider.notifier)
          .cancelPendingRequest();
    }
    navigationShell.goBranch(
      index,
      initialLocation: isCurrentBranch,
    );
  }
}
