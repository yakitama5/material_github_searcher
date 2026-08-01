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

Rect _glyphRect(WidgetTester tester) =>
    tester.getRect(find.byKey(m3RefreshIndicatorGlyphKey));

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

    testWidgets('Reduce Motionでは静止した図形へフォールバックする', (tester) async {
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
      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsOneWidget);
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

    testWidgets('pull量に応じてIndicatorのtopが単調増加する(slide)', (tester) async {
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
      await gesture.moveBy(const Offset(0, _kThresholdOffset / 5));
      await tester.pump();
      final earlyTop = _glyphRect(tester).top;

      await gesture.moveBy(const Offset(0, _kThresholdOffset * 0.4));
      await tester.pump();
      final midTop = _glyphRect(tester).top;

      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();
      final lateTop = _glyphRect(tester).top;

      expect(midTop, greaterThan(earlyTop));
      expect(lateTop, greaterThan(midTop));

      // pending gestureを後続テストへ持ち越さないよう解放する。
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('pull量0〜0.5でIndicatorが拡大し、0.5以降はサイズが変化しない(scale)', (
      tester,
    ) async {
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
      // displayFraction ≈ 0.2（scale閾値0.5未満）
      await gesture.moveBy(const Offset(0, _kThresholdOffset / 5));
      await tester.pump();
      final smallHeight = _glyphRect(tester).height;

      // 累計displayFraction ≈ 0.5（scale閾値ちょうど）
      await gesture.moveBy(const Offset(0, _kThresholdOffset * 0.3));
      await tester.pump();
      final thresholdHeight = _glyphRect(tester).height;

      // 累計displayFraction ≈ 1.0（閾値超え、scaleは1.0で頭打ち）
      await gesture.moveBy(const Offset(0, _kThresholdOffset * 0.5));
      await tester.pump();
      final fullHeight = _glyphRect(tester).height;

      expect(thresholdHeight, greaterThan(smallHeight));
      expect(fullHeight, closeTo(thresholdHeight, 0.5));

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

        expect(find.byKey(m3RefreshIndicatorGlyphKey), findsOneWidget);
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

      refreshCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.byType(M3LoadingIndicator), findsNothing);
      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsNothing);
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

      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshCount, 0);
      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsNothing);
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

      // `isNotEmpty`だけでは対象種別が実際に届いたことを保証できない。
      // 一覧先頭からのdragは常にoverscroll（既にoffset 0のためスクロール
      // 自体は動かない）として扱われるため、`OverscrollNotification`が
      // 実際に伝播していることを確認する。
      expect(notifications.whereType<OverscrollNotification>(), isNotEmpty);
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
      await gesture.moveBy(const Offset(0, _kThresholdOffset / 5));
      await tester.pump();
      final shortHeight = _glyphRect(tester).height;

      await gesture.moveBy(const Offset(0, _kThresholdOffset));
      await tester.pump();
      final longHeight = _glyphRect(tester).height;

      expect(shortHeight, greaterThan(0));
      expect(longHeight, greaterThan(shortHeight));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('enabledがfalseの間はdragしてもIndicatorが表示されずonRefreshも呼ばれない', (
      tester,
    ) async {
      _setViewportHeight(tester);
      var refreshCount = 0;

      await tester.pumpWidget(
        _TestApp(
          child: M3RefreshIndicator(
            refreshing: false,
            enabled: false,
            onRefresh: () async {
              refreshCount++;
            },
            child: const _ScrollableContent(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, _kThresholdOffset * 1.5));
      await tester.pump();

      expect(find.byKey(m3RefreshIndicatorGlyphKey), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshCount, 0);
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
