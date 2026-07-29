import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/router/router_keys.dart';

const _config = AppBuildConfig(
  flavor: Flavor.dev,
  appName: 'Dev - Material GitHub Searcher',
  appIdAndroid: 'com.example.material_github_searcher',
  appIdIos: 'com.example.materialGithubSearcher',
  appIdSuffix: '.dev',
);

void main() {
  testWidgets('402幅ではNavigationBarを表示する', (tester) async {
    await _pumpAtWidth(tester, 402);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('744幅ではextendedでないNavigationRailを表示する', (tester) async {
    await _pumpAtWidth(tester, 744);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('1024幅ではextendedのNavigationRailを表示する', (tester) async {
    await _pumpAtWidth(tester, 1024);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('NavigationBarでSettings branchを選択できる', (tester) async {
    await _pumpAtWidth(tester, 402);

    await _selectDestination(tester, 'Settings');

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('branch切替後もSearchのscroll位置を保持する', (tester) async {
    await _pumpAtWidth(tester, 402);
    final scrollable = find.byType(Scrollable);

    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;

    await _selectDestination(tester, 'Settings');
    await _selectDestination(tester, 'Search');

    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      closeTo(offset, 0.1),
    );
  });

  testWidgets('branch切替は各Navigatorのstackを保持する', (tester) async {
    await _pumpAtWidth(tester, 402);

    unawaited(
      searchBranchNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Search subpage')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _selectDestination(tester, 'Settings');
    await _selectDestination(tester, 'Search');

    expect(find.text('Search subpage'), findsOneWidget);
  });

  testWidgets('現在のbranchを再選択するとrootへ戻る', (tester) async {
    await _pumpAtWidth(tester, 402);

    unawaited(
      searchBranchNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Search subpage')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _selectDestination(tester, 'Search');

    expect(find.text('Search subpage'), findsNothing);
    expect(find.text('Search item 0'), findsOneWidget);
  });

  testWidgets('Settings branchのNavigator stackを保持する', (tester) async {
    await _pumpAtWidth(tester, 402);
    await _selectDestination(tester, 'Settings');

    unawaited(
      settingsBranchNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Settings subpage')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _selectDestination(tester, 'Search');
    await _selectDestination(tester, 'Settings');

    expect(find.text('Settings subpage'), findsOneWidget);
  });
}

Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(createApp(config: _config));
  await tester.pumpAndSettle();
}

Future<void> _selectDestination(WidgetTester tester, String label) async {
  final navigationBar = find.byType(NavigationBar);
  await tester.tap(
    find.descendant(of: navigationBar, matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
