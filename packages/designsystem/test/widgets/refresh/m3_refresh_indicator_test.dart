import 'dart:async';

import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material3_indicators/material3_indicators.dart';

/// テスト用viewportの論理高さ。
///
/// `RefreshIndicator`の発火閾値は`viewportDimension * 0.25`のため、本値では
/// `_kThresholdOffset`（150px）で1.0（発火可能）に達する。
const _testViewportHeight = 600.0;
const _kThresholdOffset = _testViewportHeight * 0.25;

void main() {
  group('M3RefreshIndicator', () {
    testWidgets('下方向へのdragでonRefreshを呼び出す', (tester) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {
              refreshCount++;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: 1,
              itemBuilder: (context, index) =>
                  const SizedBox(height: 2000, child: Text('content')),
            ),
          ),
        ),
      );

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    });

    testWidgets('refreshingがtrueの間だけM3LoadingIndicatorを表示する', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {},
            child: const _ScrollableContent(),
          ),
        ),
      );
      expect(find.byType(M3LoadingIndicator), findsNothing);

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: true,
            onRefresh: () async {},
            child: const _ScrollableContent(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(M3LoadingIndicator), findsOneWidget);
    });

    testWidgets('Reduce Motionでは静止したアイコンへフォールバックする', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          disableAnimations: true,
          child: M3RefreshIndicator(
            refreshing: true,
            onRefresh: () async {},
            child: const _ScrollableContent(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(M3LoadingIndicator), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('semanticsLabelを渡すとインジケーターへ反映する', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: true,
            onRefresh: () async {},
            semanticsLabel: '更新中',
            child: const _ScrollableContent(),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(M3LoadingIndicator)),
        matchesSemantics(label: '更新中'),
      );
      handle.dispose();
    });

    testWidgets('短いdragより長いdragの方がIndicatorが明瞭に表示される', (tester) async {
      _setViewportHeight(tester);

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {},
            child: const _ScrollableContent(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset / 3));
      await tester.pump();
      final shortOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();
      final longOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

      expect(shortOpacity, greaterThan(0));
      expect(shortOpacity, lessThan(1));
      expect(longOpacity, greaterThan(shortOpacity));
      expect(longOpacity, closeTo(1, 0.01));

      // pending gestureを後続テストへ持ち越さないよう解放する。
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'release前のdrag・armed・snapではM3LoadingIndicatorがアニメーションしない',
      (tester) async {
        _setViewportHeight(tester);

        await tester.pumpWidget(
          _TestApp(
            child: M3RefreshIndicator(
              refreshing: false,
              onRefresh: () async {},
              child: const _ScrollableContent(),
            ),
          ),
        );

        final gesture = await tester.startGesture(const Offset(200, 300));
        await gesture.moveBy(const Offset(0, _kThresholdOffset));
        await tester.pump();

        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byType(M3LoadingIndicator), findsNothing);

        await gesture.up();
        await tester.pump();
        // snap中(_kIndicatorSnapDuration未満)もアニメーションしない。
        expect(find.byType(M3LoadingIndicator), findsNothing);

        await tester.pumpAndSettle();
      },
    );

    testWidgets('drag→armed→refresh→doneでrefresh発火後だけアニメーションする', (
      tester,
    ) async {
      _setViewportHeight(tester);

      var refreshCount = 0;
      final refreshCompleter = Completer<void>();
      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {
              refreshCount++;
              await refreshCompleter.future;
            },
            child: const _ScrollableContent(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();
      await gesture.up();

      // snapアニメーション（150ms）が終わるとrefreshが発火する。1回目の
      // `pump()`（durationなし）でsnap animationのTickerを開始させてから
      // 時間を進めないと、Tickerの起点時刻がずれてアニメーションが完了した
      // 判定にならない。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(refreshCount, 1);
      expect(find.byType(M3LoadingIndicator), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);

      refreshCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.byType(M3LoadingIndicator), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('threshold未満で離すとonRefreshを呼ばずIndicatorが収納される', (
      tester,
    ) async {
      _setViewportHeight(tester);

      var refreshCount = 0;
      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {
              refreshCount++;
            },
            child: const _ScrollableContent(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset / 5));
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshCount, 0);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byType(M3LoadingIndicator), findsNothing);
    });

    testWidgets('1回のdrag操作でonRefreshは1回だけ呼ばれる', (tester) async {
      _setViewportHeight(tester);

      var refreshCount = 0;
      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {
              refreshCount++;
            },
            child: const _ScrollableContent(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset * 1.4));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    });

    testWidgets('Reduce Motionでもrefresh中は静止したアイコンで表示する', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          disableAnimations: true,
          child: M3RefreshIndicator(
            refreshing: true,
            onRefresh: () async {},
            child: const _ScrollableContent(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(M3LoadingIndicator), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('pull中はpullSemanticsLabelを、refresh中はsemanticsLabelを読み上げる', (
      tester,
    ) async {
      _setViewportHeight(tester);
      final handle = tester.ensureSemantics();

      final refreshCompleter = Completer<void>();
      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async => refreshCompleter.future,
            semanticsLabel: '更新中',
            pullSemanticsLabel: '引いています',
            child: const _ScrollableContent(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();

      expect(find.bySemanticsLabel('引いています'), findsOneWidget);
      expect(find.bySemanticsLabel('更新中'), findsNothing);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsLabel('引いています'), findsNothing);
      expect(find.bySemanticsLabel('更新中'), findsOneWidget);

      refreshCompleter.complete();
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('IgnorePointerでオーバーレイ表示中もタップ操作を遮らない', (tester) async {
      _setViewportHeight(tester);
      var tapCount = 0;

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {},
            offset: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => tapCount++,
                  child: const SizedBox(
                    key: Key('tapTarget'),
                    height: 40,
                    width: double.infinity,
                    child: Text('tap target'),
                  ),
                ),
                const Expanded(child: _ScrollableContent()),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();

      await tester.tap(find.byKey(const Key('tapTarget')));
      await tester.pump();

      expect(tapCount, 1);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('内側のScrollNotificationを消費せずpagination判定まで伝播させる', (
      tester,
    ) async {
      _setViewportHeight(tester);
      final notifications = <ScrollNotification>[];

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {},
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                notifications.add(notification);
                return false;
              },
              child: const _ScrollableContent(),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(notifications, isNotEmpty);
    });

    testWidgets('画面より短い一覧でもpull量が徐々に上昇する', (tester) async {
      _setViewportHeight(tester);

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 10, child: Text('content'))],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset / 3));
      await tester.pump();
      final shortOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();
      final longOpacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

      expect(shortOpacity, greaterThan(0));
      expect(longOpacity, greaterThan(shortOpacity));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}

/// テスト用viewportの論理サイズを固定する。
///
/// pull量の正規化は`viewportDimension`に依存するため、テスト実行環境の
/// 既定サイズに依存せず`_kThresholdOffset`が意図通りの値になるようにする。
void _setViewportHeight(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, _testViewportHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 1,
      itemBuilder: (context, index) =>
          const SizedBox(height: 2000, child: Text('content')),
    );
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.disableAnimations = false});

  final Widget child;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Material(child: child),
      ),
    );
  }
}
