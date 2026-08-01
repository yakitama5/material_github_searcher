import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../navigation/adaptive_app_shell.dart';
import '../repository/search/pages/repository_search_screen.dart';
import '../settings/pages/settings_screen.dart';
import '../settings/pages/settings_ui_style_screen.dart';
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
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: settingsUiStyleRelativePath,
                    name: settingsUiStyleRouteName,
                    builder: (context, state) => const SettingsUiStyleScreen(),
                  ),
                ],
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
