import 'package:domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ThemeSettingsRepository]のSharedPreferences実装。
///
/// [SearchHistory]用の`SharedPreferencesSearchHistoryRepository`と同じ理由で、
/// `preferencesFactory`は[load]・[save]呼び出しごとに実行し、コンストラクタでは
/// 実行しない（platform未登録時の生成失敗をtry節の外で素通りさせないため）。
final class SharedPreferencesThemeSettingsRepository
    implements ThemeSettingsRepository {
  /// preferencesFactoryを使ってテーマ設定を永続化するRepositoryを生成する。
  const SharedPreferencesThemeSettingsRepository({
    required SharedPreferencesAsync Function() preferencesFactory,
  })
    // 名前付きinitializing formal（`required this._preferencesFactory`）は
    // ラベルがprivateになり別ライブラリ（テスト等）から呼び出せなくなるため、
    // 公開名の引数を明示的にprivateフィールドへ代入する。
    // ignore: prefer_initializing_formals
    : _preferencesFactory = preferencesFactory;

  /// UI Styleを保存するkey。
  static const _uiStyleKey = 'theme_settings.ui_style';

  /// ThemeModeを保存するkey。
  static const _themeModeKey = 'theme_settings.theme_mode';

  /// ThemeColorを保存するkey。
  static const _themeColorKey = 'theme_settings.theme_color';

  final SharedPreferencesAsync Function() _preferencesFactory;

  @override
  Future<ThemeSettings> load() async {
    final Map<String, Object?> stored;
    try {
      final preferences = _preferencesFactory();
      stored = await preferences.getAll(
        allowList: {_uiStyleKey, _themeModeKey, _themeColorKey},
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ThemeSettingsPersistenceException(message: '$error'),
        stackTrace,
      );
    }
    // key未保存・不正値・未知の値（旧バージョンが保存した廃止値等）は項目単位で
    // 既定値へfallbackする。他の項目が保存済みであれば、その有効値は保持する
    // （1項目の破損で他の有効な設定まで初期化しない）。既定値は
    // `ThemeSettings`のコンストラクタ既定値（uiStyle/themeMode=system,
    // themeColor=app）と一致させる。
    const defaults = ThemeSettings();
    return ThemeSettings(
      uiStyle: _resolve(
        stored[_uiStyleKey],
        AppUiStyle.values,
        defaults.uiStyle,
      ),
      themeMode: _resolve(
        stored[_themeModeKey],
        AppThemeMode.values,
        defaults.themeMode,
      ),
      themeColor: _resolve(
        stored[_themeColorKey],
        AppThemeColor.values,
        defaults.themeColor,
      ),
    );
  }

  T _resolve<T extends Enum>(Object? stored, List<T> values, T fallback) {
    if (stored is! String) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == stored) {
        return value;
      }
    }
    return fallback;
  }

  @override
  Future<void> save(ThemeSettings settings) async {
    try {
      final preferences = _preferencesFactory();
      // 3項目を個別keyへ書き込む。SharedPreferencesAsyncには複数keyを
      // 単一トランザクションで書き込むAPIが無いため、途中の書き込みが
      // 失敗すると一部の項目だけが更新された状態になり得る。その場合も
      // 例外はそのまま呼出元（Applicationのrollback）へ伝播し、次回の
      // [load]は未更新・破損した項目を個別にfallbackで補うため、
      // 呼出し元が手動で復元し直す必要はない。
      await preferences.setString(_uiStyleKey, settings.uiStyle.name);
      await preferences.setString(_themeModeKey, settings.themeMode.name);
      await preferences.setString(_themeColorKey, settings.themeColor.name);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ThemeSettingsPersistenceException(message: '$error'),
        stackTrace,
      );
    }
  }
}
