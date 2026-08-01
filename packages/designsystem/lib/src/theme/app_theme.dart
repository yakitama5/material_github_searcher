import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme_seeds.dart';

/// [AppThemeMode]をFlutterの[ThemeMode]へ一対一変換する拡張。
extension AppThemeModeMapping on AppThemeMode {
  /// 対応する[ThemeMode]。
  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// [AppUiStyle]を強制する[TargetPlatform]へ変換する拡張。
extension AppUiStyleMapping on AppUiStyle {
  /// 強制する[TargetPlatform]。
  ///
  /// [AppUiStyle.system]は実行OSへ追従させるため`null`を返し、
  /// 呼び出し側は`null`の場合`defaultTargetPlatform`をそのまま使う契約とする。
  TargetPlatform? get targetPlatform => switch (this) {
    AppUiStyle.system => null,
    AppUiStyle.android => TargetPlatform.android,
    AppUiStyle.ios => TargetPlatform.iOS,
  };
}

/// [ThemeSettings]から実際に描画するTheme一式を解決する。
///
/// `designsystem`はRiverpodへ依存しないため、`ThemeSettings`のSSOTを
/// 監視する責務はapp側（Composition Root）が担い、本クラスは値を受け取って
/// [ThemeData]・[ThemeMode]へ変換する純粋な関数のみを提供する。
final class AppTheme {
  const AppTheme._();

  /// [settings]と、OSから取得したDynamic Color（[dynamicLight]・
  /// [dynamicDark]）からLight/Dark[ThemeData]と[ThemeMode]を解決する。
  ///
  /// [ThemeSettings.themeColor]が[AppThemeColor.dynamic]の場合、
  /// [dynamicLight]・[dynamicDark]を使う。Dynamic Color非対応やOS未応答で
  /// 片方または双方が`null`の場合、不足している側だけを
  /// [AppThemeColor.app]のSeedから生成する（`ThemeSettings`の保存値
  /// `dynamic`自体は変更しない）。
  ///
  /// [ThemeSettings.uiStyle]は[ThemeData.platform]へ反映し、`system`は
  /// `defaultTargetPlatform`（実行OS）へ追従させる。
  static ({ThemeData light, ThemeData dark, ThemeMode themeMode}) resolve(
    ThemeSettings settings, {
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
  }) {
    final platform = settings.uiStyle.targetPlatform ?? defaultTargetPlatform;
    return (
      light: ThemeData(
        colorScheme: _resolveColorScheme(
          settings.themeColor,
          Brightness.light,
          dynamicScheme: dynamicLight,
        ),
        platform: platform,
      ),
      dark: ThemeData(
        colorScheme: _resolveColorScheme(
          settings.themeColor,
          Brightness.dark,
          dynamicScheme: dynamicDark,
        ),
        platform: platform,
      ),
      themeMode: settings.themeMode.themeMode,
    );
  }

  static ColorScheme _resolveColorScheme(
    AppThemeColor themeColor,
    Brightness brightness, {
    required ColorScheme? dynamicScheme,
  }) {
    final seed = themeColor.seed;
    if (seed == null) {
      // [AppThemeColor.dynamic]は固定Seedを持たない
      // （[AppThemeColorSeed.seed]参照）。
      return dynamicScheme ??
          ColorScheme.fromSeed(
            // AppThemeColor.appは固定Seedを持つため非nullが保証される。
            seedColor: AppThemeColor.app.seed!,
            brightness: brightness,
          );
    }
    return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  }
}
