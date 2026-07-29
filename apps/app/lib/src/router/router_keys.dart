import 'package:flutter/widgets.dart';

/// アプリケーション全体のNavigatorを識別するキー。
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// 検索ブランチのNavigatorを識別するキー。
final searchBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'searchBranch',
);

/// 設定ブランチのNavigatorを識別するキー。
final settingsBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'settingsBranch',
);
