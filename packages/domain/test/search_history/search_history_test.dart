import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('SearchHistory', () {
    test('生成直後は空の履歴である', () {
      final history = SearchHistory();
      expect(history.entries, isEmpty);
    });

    test('entriesは防御的にコピーされ変更不可', () {
      final source = [SearchHistoryEntry('flutter')];
      final history = SearchHistory(entries: source);
      source.add(SearchHistoryEntry('dart'));

      expect(history.entries, hasLength(1));
      expect(
        () => history.entries.add(SearchHistoryEntry('dart')),
        throwsUnsupportedError,
      );
    });

    group('recordSubmittedKeyword', () {
      test('trimして先頭へ記録する', () {
        final history = SearchHistory().recordSubmittedKeyword('  flutter  ');

        expect(history.entries, [SearchHistoryEntry('flutter')]);
      });

      test('空文字は無視して自身をそのまま返す', () {
        final history = SearchHistory();
        final result = history.recordSubmittedKeyword('   ');

        expect(identical(result, history), isTrue);
      });

      test('新しいkeywordほど先頭になる', () {
        final history = SearchHistory()
            .recordSubmittedKeyword('flutter')
            .recordSubmittedKeyword('dart');

        expect(history.entries, [
          SearchHistoryEntry('dart'),
          SearchHistoryEntry('flutter'),
        ]);
      });

      test('trim後に同一keywordがあれば重複させず先頭へ移動する', () {
        final history = SearchHistory()
            .recordSubmittedKeyword('flutter')
            .recordSubmittedKeyword('dart')
            .recordSubmittedKeyword('  flutter  ');

        expect(history.entries, [
          SearchHistoryEntry('flutter'),
          SearchHistoryEntry('dart'),
        ]);
      });

      test('最大10件を超える古い履歴は切り捨てる', () {
        var history = SearchHistory();
        for (var i = 0; i < 12; i++) {
          history = history.recordSubmittedKeyword('keyword-$i');
        }

        expect(history.entries, hasLength(SearchHistory.maxEntries));
        expect(history.entries.first, SearchHistoryEntry('keyword-11'));
        expect(history.entries.last, SearchHistoryEntry('keyword-2'));
      });
    });

    group('recordAll', () {
      test('末尾から順に適用すると元の最近順を再現する', () {
        final saved = SearchHistory()
            .recordSubmittedKeyword('flutter')
            .recordSubmittedKeyword('dart');

        final restored = SearchHistory().recordAll(
          saved.entries.reversed.map((entry) => entry.keyword),
        );

        expect(restored, saved);
      });

      test('trim・重複排除・最大件数のルールを保ったまま適用する', () {
        final history = SearchHistory().recordAll([
          '  flutter  ',
          'flutter',
          for (var i = 0; i < 12; i++) 'keyword-$i',
        ]);

        expect(history.entries, hasLength(SearchHistory.maxEntries));
        expect(history.entries.first, SearchHistoryEntry('keyword-11'));
      });
    });

    group('clearAll', () {
      test('空の履歴を返す', () {
        final history = SearchHistory()
            .recordSubmittedKeyword('flutter')
            .clearAll();

        expect(history.entries, isEmpty);
      });
    });

    test('同じ内容の履歴は等価である', () {
      final a = SearchHistory().recordSubmittedKeyword('flutter');
      final b = SearchHistory().recordSubmittedKeyword('flutter');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('内容が異なる履歴は等価でない', () {
      final a = SearchHistory().recordSubmittedKeyword('flutter');
      final b = SearchHistory().recordSubmittedKeyword('dart');

      expect(a, isNot(equals(b)));
    });
  });
}
