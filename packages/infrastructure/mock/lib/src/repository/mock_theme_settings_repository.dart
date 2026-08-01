import 'package:domain/domain.dart';

/// [ThemeSettingsRepository]の決定的なテスト用実装。
///
/// メモリ上の[ThemeSettings]をそのまま保持するだけの単純なFakeであり、
/// Widget Test・Patrolが実ストレージへ書き込まずにテーマ設定機能を検証できる
/// ようにする。永続化失敗のシナリオ再現は現時点で不要なため提供しない。
final class MockThemeSettingsRepository implements ThemeSettingsRepository {
  /// 初期設定[initialSettings]でMock Repositoryを生成する。
  MockThemeSettingsRepository({ThemeSettings? initialSettings})
    : _settings = initialSettings ?? const ThemeSettings();

  ThemeSettings _settings;

  @override
  Future<ThemeSettings> load() async => _settings;

  @override
  Future<void> save(ThemeSettings settings) async {
    _settings = settings;
  }
}
