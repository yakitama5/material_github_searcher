import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../navigation/adaptive_app_shell.dart';
import '../repository/search/pages/repository_search_screen.dart';
import 'app_routes.dart';
import 'router_keys.dart';

/// アプリケーションのルーティング設定を提供する。
///
/// StatefulShellRoute により、各ブランチの Navigator とその状態を独立して保持する。
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: searchPath,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveAppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: searchBranchNavigatorKey,
            routes: [
              GoRoute(
                path: searchPath,
                builder: (context, state) => const RepositorySearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: settingsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: settingsPath,
                builder: (context, state) => const _SettingsPlaceholder(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Settings')));
  }
}
