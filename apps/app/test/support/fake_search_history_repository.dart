import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/misc.dart';

/// [searchHistoryRepositoryProvider]を[FakeSearchHistoryRepository]へ結線する
/// override。
///
/// `MyApp.initState`が`searchHistoryControllerProvider.notifier.load()`を
/// 無条件で呼ぶため、`createApp()`を叩く全Widget Testが本Providerの結線を
/// 要求する。呼び出し元ごとに同じ3行を書く代わりに本helperへ集約する。
Override searchHistoryTestOverride({FakeSearchHistoryRepository? repository}) =>
    searchHistoryRepositoryProvider.overrideWith(
      (ref) => repository ?? FakeSearchHistoryRepository(),
    );

/// [SearchHistoryRepository]のテスト用Fake。
///
/// `infrastructure_mock`の`MockSearchHistoryRepository`相当の単純な
/// in-memory実装を`apps/app`のテストからも使えるように用意する
/// （`apps/app`は`infrastructure_mock`へ依存しないため個別に定義する）。
/// [loadError]・[saveError]を設定すると、load/save失敗時にRepository検索が
/// 継続することを検証するテストで永続化失敗を再現できる。
final class FakeSearchHistoryRepository implements SearchHistoryRepository {
  /// 初期履歴[initialHistory]でFake Repositoryを生成する。
  FakeSearchHistoryRepository({SearchHistory? initialHistory})
    : _history = initialHistory ?? SearchHistory();

  SearchHistory _history;

  /// 非`null`の場合、[load]はこの例外をthrowする。
  AppException? loadError;

  /// 非`null`の場合、[save]はこの例外をthrowする。
  AppException? saveError;

  @override
  Future<SearchHistory> load() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return _history;
  }

  @override
  Future<void> save(SearchHistory history) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    _history = history;
  }
}
