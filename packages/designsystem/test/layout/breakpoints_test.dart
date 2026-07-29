import 'package:designsystem/designsystem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowSizeClass.fromWidth', () {
    test('compactクラスの範囲では compact を返す', () {
      expect(WindowSizeClass.fromWidth(0), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(360), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599), WindowSizeClass.compact);
    });

    test('mediumクラスの範囲では medium を返す', () {
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(744), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
    });

    test('expandedクラスの範囲では expanded を返す', () {
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1024), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.expanded);
    });
  });
}
