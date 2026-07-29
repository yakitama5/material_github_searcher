import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 画面幅に応じてナビゲーションを切り替えるアプリケーションシェル。
class AdaptiveAppShell extends StatelessWidget {
  /// [navigationShell] が管理する各ブランチの状態を保ったまま表示する。
  const AdaptiveAppShell({required this.navigationShell, super.key});

  /// 各ブランチのNavigatorを保持し、ブランチ切り替えを行うシェル。
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final windowSizeClass = WindowSizeClass.fromWidth(
      MediaQuery.widthOf(context),
    );

    return switch (windowSizeClass) {
      WindowSizeClass.compact => Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: _navigationDestinations,
        ),
      ),
      WindowSizeClass.medium || WindowSizeClass.expanded => Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: windowSizeClass == WindowSizeClass.expanded,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: _navigationRailDestinations,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    };
  }

  void _onDestinationSelected(int index) {
    final isCurrentBranch = index == navigationShell.currentIndex;
    if (isCurrentBranch) {
      navigationShell.route.branches[index].navigatorKey.currentState?.popUntil(
        (route) => route.isFirst,
      );
    }
    navigationShell.goBranch(
      index,
      initialLocation: isCurrentBranch,
    );
  }
}

const _navigationDestinations = [
  NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
  NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

const _navigationRailDestinations = [
  NavigationRailDestination(icon: Icon(Icons.search), label: Text('Search')),
  NavigationRailDestination(
    icon: Icon(Icons.settings),
    label: Text('Settings'),
  ),
];
