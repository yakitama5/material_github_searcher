import 'package:domain/domain.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('MockThemeSettingsRepository', () {
    test('初期設定を指定しない場合、loadは既定値を返す', () async {
      final repository = MockThemeSettingsRepository();

      final settings = await repository.load();

      expect(settings, const ThemeSettings());
    });

    test('初期設定を指定した場合、loadはその設定を返す', () async {
      const initial = ThemeSettings(
        uiStyle: AppUiStyle.android,
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.blue,
      );
      final repository = MockThemeSettingsRepository(initialSettings: initial);

      final settings = await repository.load();

      expect(settings, initial);
    });

    test('saveした設定を後続のloadで取得できる', () async {
      final repository = MockThemeSettingsRepository();
      const settings = ThemeSettings(themeColor: AppThemeColor.purple);

      await repository.save(settings);
      final reloaded = await repository.load();

      expect(reloaded, settings);
    });
  });
}
