import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_shared_preferences/infrastructure_shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

const _uiStyleKey = 'theme_settings.ui_style';
const _themeModeKey = 'theme_settings.theme_mode';
const _themeColorKey = 'theme_settings.theme_color';

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
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => throw StateError('simulated setString I/O failure');
}

SharedPreferencesThemeSettingsRepository _createRepository({
  Map<String, Object> initialData = const {},
}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initialData);
  return const SharedPreferencesThemeSettingsRepository(
    preferencesFactory: SharedPreferencesAsync.new,
  );
}

void main() {
  group('SharedPreferencesThemeSettingsRepository', () {
    test('保存済みデータが無い場合、loadは既定値（system/system/app）を返す', () async {
      final repository = _createRepository();

      final settings = await repository.load();

      expect(settings, const ThemeSettings());
    });

    for (final uiStyle in AppUiStyle.values) {
      for (final themeMode in AppThemeMode.values) {
        for (final themeColor in AppThemeColor.values) {
          test(
            '$uiStyle/$themeMode/$themeColorを保存し、同じ値をround-tripで復元できる',
            () async {
              final repository = _createRepository();
              final settings = ThemeSettings(
                uiStyle: uiStyle,
                themeMode: themeMode,
                themeColor: themeColor,
              );

              await repository.save(settings);
              final reloaded = await repository.load();

              expect(reloaded, settings);
            },
          );
        }
      }
    }

    test('別インスタンス（Repository再生成相当）でも同じ永続化先から復元できる', () async {
      final platform = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = platform;
      const writer = SharedPreferencesThemeSettingsRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );
      const saved = ThemeSettings(
        uiStyle: AppUiStyle.ios,
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.purple,
      );
      await writer.save(saved);

      const reader = SharedPreferencesThemeSettingsRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );
      final reloaded = await reader.load();

      expect(reloaded, saved);
    });

    test('一部keyだけ保存されている場合、保存済みの項目は復元し未保存の項目は既定値になる', () async {
      final repository = _createRepository(
        initialData: {_themeModeKey: 'dark'},
      );

      final settings = await repository.load();

      expect(
        settings,
        const ThemeSettings(themeMode: AppThemeMode.dark),
      );
    });

    test('未知の値（旧バージョンの廃止値等）は当該項目だけ既定値へfallbackし、他の有効値は保持する', () async {
      final repository = _createRepository(
        initialData: {
          _uiStyleKey: 'unknown_style',
          _themeModeKey: 'dark',
          _themeColorKey: 'blue',
        },
      );

      final settings = await repository.load();

      expect(
        settings,
        const ThemeSettings(
          themeMode: AppThemeMode.dark,
          themeColor: AppThemeColor.blue,
        ),
      );
    });

    test('空文字は不正値として当該項目だけ既定値へfallbackする', () async {
      final repository = _createRepository(
        initialData: {_themeColorKey: ''},
      );

      final settings = await repository.load();

      expect(settings, const ThemeSettings());
    });

    test('不正な保存形式（String以外）は当該項目だけ既定値へfallbackする', () async {
      final repository = _createRepository(
        initialData: {
          _uiStyleKey: 123,
          _themeModeKey: 'light',
        },
      );

      final settings = await repository.load();

      expect(
        settings,
        const ThemeSettings(themeMode: AppThemeMode.light),
      );
    });

    test('全削除相当の保存はテーマ設定keyだけを更新し、他keyへ影響しない', () async {
      final platform = InMemorySharedPreferencesAsync.withData({
        'search_history.keywords.v1': ['flutter'],
      });
      SharedPreferencesAsyncPlatform.instance = platform;
      const repository = SharedPreferencesThemeSettingsRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );

      await repository.save(
        const ThemeSettings(
          uiStyle: AppUiStyle.android,
          themeMode: AppThemeMode.light,
          themeColor: AppThemeColor.red,
        ),
      );

      final all = await SharedPreferencesAsync().getAll();
      expect(all['search_history.keywords.v1'], ['flutter']);
      expect(all[_uiStyleKey], 'android');
      expect(all[_themeModeKey], 'light');
      expect(all[_themeColorKey], 'red');
    });

    test('検索履歴の全削除（SearchHistoryRepositoryのsave）はテーマ設定に影響しない', () async {
      final platform = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = platform;
      const themeRepository = SharedPreferencesThemeSettingsRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );
      const historyRepository = SharedPreferencesSearchHistoryRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );
      const savedSettings = ThemeSettings(
        uiStyle: AppUiStyle.ios,
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.pink,
      );
      await themeRepository.save(savedSettings);
      await historyRepository.save(
        SearchHistory().recordSubmittedKeyword('flutter'),
      );

      // 検索履歴の全削除相当（空履歴の保存）を実行する。
      await historyRepository.save(SearchHistory());

      final reloadedSettings = await themeRepository.load();
      expect(reloadedSettings, savedSettings);
    });

    test('上書き保存後は最新の内容だけが復元される', () async {
      final repository = _createRepository();
      await repository.save(
        const ThemeSettings(themeColor: AppThemeColor.yellow),
      );

      await repository.save(
        const ThemeSettings(themeColor: AppThemeColor.green),
      );
      final reloaded = await repository.load();

      expect(reloaded, const ThemeSettings(themeColor: AppThemeColor.green));
    });

    test('loadのI/O失敗はThemeSettingsPersistenceExceptionとして投げる', () async {
      SharedPreferencesAsyncPlatform.instance =
          _ThrowingSharedPreferencesAsync();
      const repository = SharedPreferencesThemeSettingsRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );

      expect(
        repository.load,
        throwsA(isA<ThemeSettingsPersistenceException>()),
      );
    });

    test('saveのI/O失敗はThemeSettingsPersistenceExceptionとして投げる', () async {
      SharedPreferencesAsyncPlatform.instance =
          _ThrowingSharedPreferencesAsync();
      const repository = SharedPreferencesThemeSettingsRepository(
        preferencesFactory: SharedPreferencesAsync.new,
      );

      expect(
        () => repository.save(
          const ThemeSettings(themeColor: AppThemeColor.blue),
        ),
        throwsA(isA<ThemeSettingsPersistenceException>()),
      );
    });

    test(
      'platform未登録時のpreferences生成失敗もThemeSettingsPersistenceExceptionとして投げる',
      () async {
        // platform channelを持たないテスト環境等でSharedPreferencesAsyncPlatform
        // が未登録のままpreferencesFactoryが呼ばれると、SharedPreferencesAsync()
        // 自体がStateErrorを投げる。この生成をload・saveのtry節の外（コンストラクタ
        // 時点）で行うと、その場で素通りしてしまう回帰を防ぐ。
        SharedPreferencesAsyncPlatform.instance = null;
        const repository = SharedPreferencesThemeSettingsRepository(
          preferencesFactory: SharedPreferencesAsync.new,
        );

        expect(
          repository.load,
          throwsA(isA<ThemeSettingsPersistenceException>()),
        );
      },
    );
  });
}
