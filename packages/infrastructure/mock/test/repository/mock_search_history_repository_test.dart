import 'package:domain/domain.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('MockSearchHistoryRepository', () {
    test('初期履歴を指定しない場合、loadは空の履歴を返す', () async {
      final repository = MockSearchHistoryRepository();

      final history = await repository.load();

      expect(history, SearchHistory());
    });

    test('初期履歴を指定した場合、loadはその履歴を返す', () async {
      final initial = SearchHistory().recordSubmittedKeyword('flutter');
      final repository = MockSearchHistoryRepository(initialHistory: initial);

      final history = await repository.load();

      expect(history, initial);
    });

    test('saveした履歴を後続のloadで取得できる', () async {
      final repository = MockSearchHistoryRepository();
      final history = SearchHistory().recordSubmittedKeyword('dart');

      await repository.save(history);
      final reloaded = await repository.load();

      expect(reloaded, history);
    });
  });
}
