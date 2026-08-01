import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme.resolve - Seed解決', () {
    for (final themeColor in AppThemeColor.values.where(
      (color) => color != AppThemeColor.dynamic,
    )) {
      test('themeColor=$themeColorはfromSeed(${themeColor.seed})を使う', () {
        final result = AppTheme.resolve(
          ThemeSettings(themeColor: themeColor),
        );

        expect(
          result.light.colorScheme,
          ColorScheme.fromSeed(seedColor: themeColor.seed!),
        );
        expect(
          result.dark.colorScheme,
          ColorScheme.fromSeed(
            seedColor: themeColor.seed!,
            brightness: Brightness.dark,
          ),
        );
      });
    }
  });

  group('AppTheme.resolve - Dynamic Colorのフォールバック', () {
    final dynamicLight = ColorScheme.fromSeed(seedColor: Colors.teal);
    final dynamicDark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );

    test('Light/Dark双方取得できた場合はそのまま使う', () {
      final result = AppTheme.resolve(
        const ThemeSettings(themeColor: AppThemeColor.dynamic),
        dynamicLight: dynamicLight,
        dynamicDark: dynamicDark,
      );

      expect(result.light.colorScheme, dynamicLight);
      expect(result.dark.colorScheme, dynamicDark);
    });

    test('Darkのみ取得できた場合、LightだけAppのSeedから生成する', () {
      final result = AppTheme.resolve(
        const ThemeSettings(themeColor: AppThemeColor.dynamic),
        dynamicDark: dynamicDark,
      );

      expect(
        result.light.colorScheme,
        ColorScheme.fromSeed(seedColor: AppThemeColor.app.seed!),
      );
      expect(result.dark.colorScheme, dynamicDark);
    });

    test('Lightのみ取得できた場合、DarkだけAppのSeedから生成する', () {
      final result = AppTheme.resolve(
        const ThemeSettings(themeColor: AppThemeColor.dynamic),
        dynamicLight: dynamicLight,
      );

      expect(result.light.colorScheme, dynamicLight);
      expect(
        result.dark.colorScheme,
        ColorScheme.fromSeed(
          seedColor: AppThemeColor.app.seed!,
          brightness: Brightness.dark,
        ),
      );
    });

    test('双方取得できない場合、Light/Dark双方をAppのSeedから生成する', () {
      final result = AppTheme.resolve(
        const ThemeSettings(themeColor: AppThemeColor.dynamic),
      );

      expect(
        result.light.colorScheme,
        ColorScheme.fromSeed(seedColor: AppThemeColor.app.seed!),
      );
      expect(
        result.dark.colorScheme,
        ColorScheme.fromSeed(
          seedColor: AppThemeColor.app.seed!,
          brightness: Brightness.dark,
        ),
      );
    });
  });

  group('AppThemeModeMapping', () {
    final expectedModes = {
      AppThemeMode.system: ThemeMode.system,
      AppThemeMode.light: ThemeMode.light,
      AppThemeMode.dark: ThemeMode.dark,
    };

    for (final entry in expectedModes.entries) {
      test('themeMode=${entry.key}はThemeMode.${entry.value.name}へ変換される', () {
        final result = AppTheme.resolve(
          ThemeSettings(themeMode: entry.key),
        );

        expect(result.themeMode, entry.value);
      });
    }
  });

  group('AppUiStyleMapping - ThemeData.platform', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('uiStyle=systemはdefaultTargetPlatform（実行OS）へ追従する', () {
      final result = AppTheme.resolve(const ThemeSettings());

      expect(result.light.platform, TargetPlatform.fuchsia);
      expect(result.dark.platform, TargetPlatform.fuchsia);
    });

    test('uiStyle=androidは実行OSに関わらずandroidを強制する', () {
      final result = AppTheme.resolve(
        const ThemeSettings(uiStyle: AppUiStyle.android),
      );

      expect(result.light.platform, TargetPlatform.android);
      expect(result.dark.platform, TargetPlatform.android);
    });

    test('uiStyle=iosは実行OSに関わらずiOSを強制する', () {
      final result = AppTheme.resolve(
        const ThemeSettings(uiStyle: AppUiStyle.ios),
      );

      expect(result.light.platform, TargetPlatform.iOS);
      expect(result.dark.platform, TargetPlatform.iOS);
    });
  });
}
