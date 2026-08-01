import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:material_github_searcher/src/repository/search/widgets/repository_search_lottie_message.dart';

const _title = 'Search repositories';
const _description = 'Enter a keyword to get started.';
const _assetPath = 'assets/lottie/search_initialize.json';
const _missingAssetPath = 'assets/lottie/missing.json';

Future<void> _pumpMessage(
  WidgetTester tester, {
  bool disableAnimations = false,
  String assetPath = _assetPath,
  double reducedMotionProgress = 1,
}) async {
  if (assetPath != _missingAssetPath) {
    await tester.runAsync(() async {
      await AssetLottie(assetPath).load();
    });
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: _messageApp(
        assetPath: assetPath,
        reducedMotionProgress: reducedMotionProgress,
      ),
    ),
  );
}

Widget _messageApp({
  String assetPath = _assetPath,
  double reducedMotionProgress = 1,
}) => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: RepositorySearchLottieMessage(
            assetPath: assetPath,
            title: _title,
            description: _description,
            reducedMotionProgress: reducedMotionProgress,
          ),
        ),
      ],
    ),
  ),
);

LottieBuilder _lottie(WidgetTester tester) => tester.widget<LottieBuilder>(
  find.byType(LottieBuilder),
);

AnimationController _animationController(WidgetTester tester) =>
    _lottie(tester).controller! as AnimationController;

Future<void> _waitForComposition(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    final controller = _lottie(tester).controller;
    if (controller is AnimationController && controller.duration != null) {
      return;
    }
  }
  fail('Lottie composition was not loaded');
}

void main() {
  group('RepositorySearchLottieMessage', () {
    testWidgets('Reduce Motionでは指定したフレームで静止する', (tester) async {
      await _pumpMessage(
        tester,
        disableAnimations: true,
        reducedMotionProgress: 0.75,
      );
      await _waitForComposition(tester);

      final controller = _animationController(tester);
      expect(controller.isAnimating, isFalse);
      expect(controller.value, closeTo(0.75, 0.001));
    });

    testWidgets('Reduce Motion無効時はanimationを再生する', (tester) async {
      await _pumpMessage(tester);
      await _waitForComposition(tester);

      final controller = _animationController(tester);
      expect(controller.isAnimating, isTrue);
    });

    testWidgets('MediaQueryのReduce Motion切替に追従する', (tester) async {
      final disableAnimations = ValueNotifier(false);
      addTearDown(disableAnimations.dispose);

      await tester.runAsync(() async {
        await AssetLottie(_assetPath).load();
      });
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: disableAnimations,
          builder: (context, disabled, child) => MediaQuery(
            data: MediaQueryData(disableAnimations: disabled),
            child: child!,
          ),
          child: _messageApp(reducedMotionProgress: 0.75),
        ),
      );
      await _waitForComposition(tester);

      final controller = _animationController(tester);
      expect(controller.isAnimating, isTrue);

      disableAnimations.value = true;
      await tester.pump();
      expect(controller.isAnimating, isFalse);
      expect(controller.value, closeTo(0.75, 0.001));

      disableAnimations.value = false;
      await tester.pump();
      expect(controller.isAnimating, isTrue);
    });

    testWidgets('LottieのSemanticsを除外し、文言はSemanticsに残す', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpMessage(tester, disableAnimations: true);

      expect(find.byType(ExcludeSemantics), findsWidgets);
      expect(tester.getSemantics(find.text(_title)).label, _title);
      expect(tester.getSemantics(find.text(_description)).label, _description);
      handle.dispose();
    });

    testWidgets('Lottieの読み込みに失敗しても文言を表示する', (tester) async {
      await _pumpMessage(
        tester,
        assetPath: _missingAssetPath,
        disableAnimations: true,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_description), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
