import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_shared_preferences/infrastructure_shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

const _keywordsKey = 'search_history.keywords.v1';

/// I/O失敗（platform channel例外等）を模すための[InMemorySharedPreferencesAsync]。
base class _ThrowingSharedPreferencesAsync
    extends InMemorySharedPreferencesAsync {
  _ThrowingSharedPreferencesAsync() : super.empty();

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) => throw StateError('simulated getPreferences I/O failure');

  @override
  Future<bool> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) => throw StateError('simulated setStringList I/O failure');
}

SharedPreferencesSearchHistoryRepository _createRepository({
  Map<String, Object> initialData = const {},
}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initialData);
  return const SharedPreferencesSearchHistoryRepository(
    preferencesFactory: SharedPreferencesAsync.new,
  );
}

void main() {
  group('SharedPreferencesSearchHistoryRepository', () {
    test('保存済みデータが無い場合、loadは空の履歴を返す', () async {
      final repository = _createRepository();

      final history = await repository.load();

      expect(history, SearchHistory());
    });

    test('保存した履歴を同じkeyから復元できる', () async {
      final repository = _createRepository();
      final history = SearchHistory().recordSubmittedKeyword('flutter');

      await repository.save(history);
      final reloaded = await repository.load();

      expect(reloaded, history);
    });

    test('別インスタンス（Repository再生成相当）でも同じ永続化先から復元できる', () async {
      final platform = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = platform;
      const writer = SharedPreferencesSearchHistoryRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );
      await writer.save(SearchHistory().recordSubmittedKeyword('dart'));

      // 同じplatform instanceを使い回し、新しいRepositoryインスタンスから
      // 読み込む（アプリ再起動後にRepositoryが再生成される状況を模す）。
      const reader = SharedPreferencesSearchHistoryRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );
      final reloaded = await reader.load();

      expect(reloaded, SearchHistory().recordSubmittedKeyword('dart'));
    });

    test('最大10件・最近順・重複排除を保った状態で復元する', () async {
      final repository = _createRepository(
        initialData: {
          _keywordsKey: [
            'k11',
            'k10',
            'k9',
            'k8',
            'k7',
            'k6',
            'k5',
            'k4',
            'k3',
            'k2',
            'k1',
          ],
        },
      );

      final history = await repository.load();

      expect(history.entries.length, 10);
      expect(history.entries.first.keyword, 'k11');
      expect(history.entries.last.keyword, 'k2');
    });

    test('前後空白・空文字・重複を含む保存データを正規化して復元する', () async {
      final repository = _createRepository(
        initialData: {
          _keywordsKey: [' flutter ', '', 'dart', 'flutter', '   '],
        },
      );

      final history = await repository.load();

      expect(
        history.entries.map((entry) => entry.keyword).toList(),
        ['flutter', 'dart'],
      );
    });

    test('不正な保存形式（List<String>以外）は空履歴として復旧する', () async {
      final repository = _createRepository(
        initialData: {_keywordsKey: 'not-a-list'},
      );

      final history = await repository.load();

      expect(history, SearchHistory());
    });

    test('全削除相当（空履歴の保存）は履歴keyだけを更新し、他keyへ影響しない', () async {
      final platform = InMemorySharedPreferencesAsync.withData({
        'other.setting': 'kept',
        _keywordsKey: ['flutter'],
      });
      SharedPreferencesAsyncPlatform.instance = platform;
      const repository = SharedPreferencesSearchHistoryRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );

      await repository.save(SearchHistory());

      final all = await SharedPreferencesAsync().getAll();
      expect(all['other.setting'], 'kept');
      expect(all[_keywordsKey], <String>[]);
    });

    test('上書き保存後は最新の内容だけが復元される', () async {
      final repository = _createRepository();
      await repository.save(SearchHistory().recordSubmittedKeyword('first'));

      await repository.save(SearchHistory().recordSubmittedKeyword('second'));
      final reloaded = await repository.load();

      expect(
        reloaded.entries.map((entry) => entry.keyword).toList(),
        ['second'],
      );
    });

    test('loadのI/O失敗はSearchHistoryPersistenceExceptionとして投げる', () async {
      SharedPreferencesAsyncPlatform.instance =
          _ThrowingSharedPreferencesAsync();
      const repository = SharedPreferencesSearchHistoryRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );

      expect(
        repository.load,
        throwsA(isA<SearchHistoryPersistenceException>()),
      );
    });

    test('saveのI/O失敗はSearchHistoryPersistenceExceptionとして投げる', () async {
      SharedPreferencesAsyncPlatform.instance =
          _ThrowingSharedPreferencesAsync();
      const repository = SharedPreferencesSearchHistoryRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );

      expect(
        () => repository.save(SearchHistory().recordSubmittedKeyword('x')),
        throwsA(isA<SearchHistoryPersistenceException>()),
      );
    });

    test(
      'platform未登録時のpreferences生成失敗もSearchHistoryPersistenceExceptionとして投げる',
      () async {
        // platform channelを持たないテスト環境等でSharedPreferencesAsyncPlatform
        // が未登録のままpreferencesFactoryが呼ばれると、SharedPreferencesAsync()
        // 自体がStateErrorを投げる。この生成をload・saveのtry節の外（コンストラクタ
        // 時点）で行うと、その場で素通りしてしまう回帰を防ぐ。
        SharedPreferencesAsyncPlatform.instance = null;
        const repository = SharedPreferencesSearchHistoryRepository(
          preferencesFactory: SharedPreferencesAsync.new,
        );

        expect(
          repository.load,
          throwsA(isA<SearchHistoryPersistenceException>()),
        );
      },
    );
  });
}
