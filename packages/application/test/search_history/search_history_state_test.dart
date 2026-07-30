import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('SearchHistoryState', () {
    test('loadingは空の履歴を保持する', () {
      final state = SearchHistoryState.loading();

      expect(state.status, SearchHistoryStatus.loading);
      expect(state.history.entries, isEmpty);
      expect(state.error, isNull);
    });

    test('readyはhistoryを保持しerrorを持たない', () {
      final history = SearchHistory().recordSubmittedKeyword('flutter');
      final state = SearchHistoryState.ready(history);

      expect(state.status, SearchHistoryStatus.ready);
      expect(state.history, history);
      expect(state.error, isNull);
    });

    test('persistenceErrorはhistoryを維持したままerrorを保持する', () {
      final history = SearchHistory().recordSubmittedKeyword('flutter');
      const error = SearchHistoryPersistenceException(message: 'failed');
      final state = SearchHistoryState.persistenceError(
        history: history,
        error: error,
      );

      expect(state.status, SearchHistoryStatus.persistenceError);
      expect(state.history, history);
      expect(state.error, error);
    });

    test('同じ内容のStateは等価である', () {
      final history = SearchHistory().recordSubmittedKeyword('flutter');
      final a = SearchHistoryState.ready(history);
      final b = SearchHistoryState.ready(history);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('statusが異なるStateは等価でない', () {
      final loadingState = SearchHistoryState.loading();
      final readyState = SearchHistoryState.ready(SearchHistory());

      expect(loadingState, isNot(equals(readyState)));
    });
  });
}
