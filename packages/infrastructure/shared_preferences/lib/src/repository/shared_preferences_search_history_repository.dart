import 'package:domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SearchHistoryRepository]のSharedPreferences実装。
///
/// [SharedPreferencesAsync]はkey単位で直接読み書きし、アプリ起動時に全件を
/// メモリへ読み込むキャッシュを持たない。そのため呼び出し元（Composition
/// Root）が`SharedPreferences`インスタンスをグローバルに保持する必要がなく、
/// 本コンストラクタで都度受け取ったpreferencesFactoryをそのまま利用する。
///
/// preferencesFactoryは[load]・[save]の呼び出しごとに実行し、
/// コンストラクタでは実行しない。`SharedPreferencesAsync()`はplatform未登録
/// （例: platform channelを持たないテスト環境）だと生成時に例外を投げるため、
/// ここで先に生成してしまうと[load]・[save]のtry節の外で失敗し、
/// [SearchHistoryPersistenceException]へ変換されずに素通りしてしまう。
final class SharedPreferencesSearchHistoryRepository
    implements SearchHistoryRepository {
  /// preferencesFactoryを使って検索履歴を永続化するRepositoryを生成する。
  const SharedPreferencesSearchHistoryRepository({
    required SharedPreferencesAsync Function() preferencesFactory,
  })
    // 名前付きinitializing formal（`required this._preferencesFactory`）は
    // ラベルがprivateになり別ライブラリ（テスト等）から呼び出せなくなるため、
    // 公開名の引数を明示的にprivateフィールドへ代入する。
    // ignore: prefer_initializing_formals
    : _preferencesFactory = preferencesFactory;

  /// 検索履歴を保存するkey。
  ///
  /// 将来保存形式を変更する場合は末尾の世代（`v1`）を上げ、旧keyのデータは
  /// 読み込まず空履歴として扱う（[load]の不正・旧形式データの扱いを参照）。
  static const _keywordsKey = 'search_history.keywords.v1';

  final SharedPreferencesAsync Function() _preferencesFactory;

  @override
  Future<SearchHistory> load() async {
    final Object? stored;
    try {
      final preferences = _preferencesFactory();
      final all = await preferences.getAll(allowList: {_keywordsKey});
      stored = all[_keywordsKey];
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SearchHistoryPersistenceException(message: '$error'),
        stackTrace,
      );
    }
    if (stored is! List || stored.any((element) => element is! String)) {
      // key未保存、または旧形式・不正な保存形式は永続化の失敗とは区別し、
      // 空履歴として復旧する。
      return SearchHistory();
    }
    // 保存順は最近順（先頭が最新）。recordAllは末尾（最も古い）から順に
    // 適用することで、trim・重複排除・最大件数のルールを保ったまま
    // 最近順を再現できる。
    return SearchHistory().recordAll(stored.reversed.cast<String>());
  }

  @override
  Future<void> save(SearchHistory history) async {
    final keywords = history.entries
        .map((entry) => entry.keyword)
        .toList(growable: false);
    try {
      final preferences = _preferencesFactory();
      // 全削除（空履歴の保存）も含め、常に履歴専用keyのみをsetStringListで
      // 上書きする。他設定へ影響する`clear()`は使わない。
      await preferences.setStringList(_keywordsKey, keywords);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SearchHistoryPersistenceException(message: '$error'),
        stackTrace,
      );
    }
  }
}
