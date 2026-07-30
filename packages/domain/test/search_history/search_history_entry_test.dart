import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('SearchHistoryEntry', () {
    test('前後の空白をtrimして保持する', () {
      final entry = SearchHistoryEntry('  flutter  ');
      expect(entry.keyword, 'flutter');
    });

    test('内部の空白やGitHub検索構文は保持する', () {
      final entry = SearchHistoryEntry('  language:dart flutter  ');
      expect(entry.keyword, 'language:dart flutter');
    });

    test('trim後に空文字になる場合はArgumentErrorを投げる', () {
      expect(() => SearchHistoryEntry('   '), throwsArgumentError);
    });

    test('同じkeywordは等価である', () {
      expect(SearchHistoryEntry('flutter'), SearchHistoryEntry('flutter'));
      expect(
        SearchHistoryEntry('flutter').hashCode,
        SearchHistoryEntry('flutter').hashCode,
      );
    });

    test('異なるkeywordは等価でない', () {
      expect(SearchHistoryEntry('flutter'), isNot(SearchHistoryEntry('dart')));
    });
  });
}
