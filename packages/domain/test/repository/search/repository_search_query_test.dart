import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('RepositorySearchQuery', () {
    test('前後の空白をtrimする', () {
      final query = RepositorySearchQuery('  flutter  ');

      expect(query.value, 'flutter');
    });

    test('trim後に空文字になる入力は拒否する', () {
      expect(() => RepositorySearchQuery('   '), throwsArgumentError);
    });

    test('空文字を拒否する', () {
      expect(() => RepositorySearchQuery(''), throwsArgumentError);
    });

    test('qualifier・引用符・内部の空白は書き換えない', () {
      final query = RepositorySearchQuery(
        '  "clean architecture" language:dart stars:>100  ',
      );

      expect(query.value, '"clean architecture" language:dart stars:>100');
    });

    test('trim後の値が等しければ等価である', () {
      final a = RepositorySearchQuery('flutter');
      final b = RepositorySearchQuery('  flutter  ');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('値が異なれば等価にならない', () {
      final a = RepositorySearchQuery('flutter');
      final b = RepositorySearchQuery('dart');

      expect(a, isNot(equals(b)));
    });
  });
}
