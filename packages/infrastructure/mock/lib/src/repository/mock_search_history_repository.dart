import 'package:domain/domain.dart';

/// [SearchHistoryRepository]の決定的なテスト用実装。
///
/// メモリ上の[SearchHistory]をそのまま保持するだけの単純なFakeであり、
/// Widget Test・Patrolが実ストレージへ書き込まずに検索履歴機能を検証できる
/// ようにする。永続化失敗のシナリオ再現は現時点で不要なため提供しない。
final class MockSearchHistoryRepository implements SearchHistoryRepository {
  /// 初期履歴[initialHistory]でMock Repositoryを生成する。
  MockSearchHistoryRepository({SearchHistory? initialHistory})
    : _history = initialHistory ?? SearchHistory();

  SearchHistory _history;

  @override
  Future<SearchHistory> load() async => _history;

  @override
  Future<void> save(SearchHistory history) async {
    _history = history;
  }
}
