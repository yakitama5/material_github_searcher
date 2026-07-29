import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Skeleton', () {
    testWidgets('Box、Text、Circleを指定したサイズで表示する', (tester) async {
      await tester.pumpWidget(
        const _TestApp(
          child: SkeletonScope(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(key: Key('box'), width: 120, height: 24),
                SkeletonText(key: Key('text'), width: 96, height: 18),
                SkeletonCircle(key: Key('circle'), diameter: 32),
              ],
            ),
          ),
        ),
      );

      expect(_sizeOf(tester, const Key('box')), const Size(120, 24));
      expect(_sizeOf(tester, const Key('text')), const Size(96, 18));
      expect(_sizeOf(tester, const Key('circle')), const Size(32, 32));
    });

    testWidgets('Textは高さ未指定時に16dpで表示する', (tester) async {
      await tester.pumpWidget(
        const _TestApp(
          child: SkeletonScope(
            child: SkeletonText(key: Key('text'), width: 80),
          ),
        ),
      );

      expect(_sizeOf(tester, const Key('text')), const Size(80, 16));
    });

    testWidgets('ThemeのLight/Dark ColorSchemeから色を導出する', (tester) async {
      final lightScheme = ColorScheme.fromSeed(seedColor: Colors.teal);
      final darkScheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      );

      await tester.pumpWidget(
        _TestApp(
          colorScheme: lightScheme,
          child: const SkeletonScope(
            child: SkeletonBox(key: Key('skeleton'), width: 80, height: 16),
          ),
        ),
      );
      expect(_skeletonColor(tester), lightScheme.surfaceContainerHighest);

      await tester.pumpWidget(
        _TestApp(
          colorScheme: darkScheme,
          child: const SkeletonScope(
            child: SkeletonBox(key: Key('skeleton'), width: 80, height: 16),
          ),
        ),
      );
      expect(_skeletonColor(tester), darkScheme.surfaceContainerHighest);
    });

    testWidgets('任意のColorScheme値に追従する', (tester) async {
      const expectedColor = Color(0xff123456);
      final colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
      ).copyWith(surfaceContainerHighest: expectedColor);

      await tester.pumpWidget(
        _TestApp(
          colorScheme: colorScheme,
          child: const SkeletonScope(
            child: SkeletonBox(key: Key('skeleton'), width: 80, height: 16),
          ),
        ),
      );

      expect(_skeletonColor(tester), expectedColor);
    });

    testWidgets('Reduce Motionでは静止し、時間を進めても色が変化しない', (tester) async {
      await tester.pumpWidget(
        const _TestApp(
          disableAnimations: true,
          child: SkeletonScope(
            child: SkeletonBox(key: Key('skeleton'), width: 80, height: 16),
          ),
        ),
      );
      final initialColor = _skeletonColor(tester);

      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.hasRunningAnimations, isFalse);
      expect(_skeletonColor(tester), initialColor);
    });

    testWidgets('各primitiveだけをSemantics treeから除外する', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const _TestApp(
          child: SkeletonScope(
            child: Column(
              children: [
                Text('読み込み中'),
                SkeletonBox(width: 80, height: 16),
                SkeletonText(width: 64),
                SkeletonCircle(diameter: 24),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('読み込み中')),
        matchesSemantics(label: '読み込み中'),
      );
      expect(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SkeletonText),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SkeletonCircle),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('複数primitiveは1つのTickerを共有し、Scope破棄時に停止する', (tester) async {
      await tester.pumpWidget(
        const _TestApp(
          child: SkeletonScope(
            child: Column(
              children: [
                SkeletonBox(width: 80, height: 16),
                SkeletonText(width: 64),
                SkeletonCircle(diameter: 24),
              ],
            ),
          ),
        ),
      );

      expect(tester.binding.transientCallbackCount, 1);

      await tester.pumpWidget(const _TestApp(child: SizedBox()));
      await tester.pump();

      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

Color? _skeletonColor(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
  return (decoratedBox.decoration as BoxDecoration).color;
}

Size _sizeOf(WidgetTester tester, Key key) {
  return tester.getSize(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(ExcludeSemantics),
    ),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.child,
    this.colorScheme,
    this.disableAnimations = false,
  });

  final Widget child;
  final ColorScheme? colorScheme;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final scheme = colorScheme ?? ColorScheme.fromSeed(seedColor: Colors.blue);

    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Theme(
          data: ThemeData(colorScheme: scheme),
          child: Material(child: Center(child: child)),
        ),
      ),
    );
  }
}
