import '../error/app_exception.dart';
import 'theme_settings.dart';

/// テーマ設定の永続化を行うリポジトリの抽象。
///
/// 実装は`packages/infrastructure/*`が担い、`domain`は保存先
/// （SharedPreferences等）の詳細に依存しない。永続化に失敗した場合は
/// [ThemeSettingsPersistenceException]を投げる契約とし、Applicationは
/// メモリ上の設定を維持したままこの型で失敗を扱う。
abstract interface class ThemeSettingsRepository {
  /// 永続化済みのテーマ設定を読み込む。
  ///
  /// 永続化されたデータが存在しない場合は既定値の[ThemeSettings]を返す。
  Future<ThemeSettings> load();

  /// [settings]を永続化する。
  ///
  /// 項目単位の部分保存APIは提供せず、常に[ThemeSettings]全体を上書き
  /// 保存する契約とする。
  Future<void> save(ThemeSettings settings);
}
