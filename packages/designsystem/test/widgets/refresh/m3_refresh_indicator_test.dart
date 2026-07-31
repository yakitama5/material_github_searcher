import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material3_indicators/material3_indicators.dart';

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
  });
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
