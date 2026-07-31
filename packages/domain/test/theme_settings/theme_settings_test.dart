import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ThemeSettings', () {
    test('既定値はuiStyle=system, themeMode=system, themeColor=appになる', () {
      const settings = ThemeSettings();

      expect(settings.uiStyle, AppUiStyle.system);
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.themeColor, AppThemeColor.app);
    });

    test('全項目が等しければ等価である', () {
      const a = ThemeSettings(
        uiStyle: AppUiStyle.android,
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.blue,
      );
      const b = ThemeSettings(
        uiStyle: AppUiStyle.android,
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.blue,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('いずれかの項目が異なれば等価にならない', () {
      const base = ThemeSettings(
        uiStyle: AppUiStyle.android,
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.blue,
      );

      expect(base, isNot(equals(base.copyWith(uiStyle: AppUiStyle.ios))));
      expect(base, isNot(equals(base.copyWith(themeMode: AppThemeMode.light))));
      expect(
        base,
        isNot(equals(base.copyWith(themeColor: AppThemeColor.purple))),
      );
    });

    test('copyWithは指定した項目だけを差し替える', () {
      const base = ThemeSettings();

      final updated = base.copyWith(themeMode: AppThemeMode.dark);

      expect(updated.uiStyle, base.uiStyle);
      expect(updated.themeMode, AppThemeMode.dark);
      expect(updated.themeColor, base.themeColor);
    });

    test('copyWithを無指定で呼ぶと元の値を維持した別インスタンスを返す', () {
      const base = ThemeSettings(
        uiStyle: AppUiStyle.ios,
        themeMode: AppThemeMode.light,
        themeColor: AppThemeColor.green,
      );

      final copied = base.copyWith();

      expect(copied, equals(base));
      expect(identical(copied, base), isFalse);
    });

    test('AppUiStyleは3種類の候補を持つ', () {
      expect(AppUiStyle.values, [
        AppUiStyle.system,
        AppUiStyle.android,
        AppUiStyle.ios,
      ]);
    });

    test('AppThemeModeは3種類の候補を持つ', () {
      expect(AppThemeMode.values, [
        AppThemeMode.system,
        AppThemeMode.light,
        AppThemeMode.dark,
      ]);
    });

    test('AppThemeColorは9種類の候補を持つ', () {
      expect(AppThemeColor.values, [
        AppThemeColor.app,
        AppThemeColor.dynamic,
        AppThemeColor.blue,
        AppThemeColor.purple,
        AppThemeColor.pink,
        AppThemeColor.red,
        AppThemeColor.orange,
        AppThemeColor.yellow,
        AppThemeColor.green,
      ]);
    });
  });
}
