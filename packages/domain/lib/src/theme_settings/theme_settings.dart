import 'package:meta/meta.dart';

import 'app_theme_color.dart';
import 'app_theme_mode.dart';
import 'app_ui_style.dart';

/// UI Style・ThemeMode・ThemeColorを1つに集約したテーマ設定。
///
/// アプリ全体のSingle Source of Truthとして`themeSettingsProvider`が保持し、
/// 項目別に値を複製しない契約とする。既定値は`uiStyle=system`・
/// `themeMode=system`・`themeColor=app`で固定する。
@immutable
final class ThemeSettings {
  /// テーマ設定を生成する。
  ///
  /// 各項目省略時はOS設定へ追従する`system`・アプリ既定色の`app`になる。
  const ThemeSettings({
    this.uiStyle = AppUiStyle.system,
    this.themeMode = AppThemeMode.system,
    this.themeColor = AppThemeColor.app,
  });

  /// Material・Cupertinoの見た目切り替え区分。
  final AppUiStyle uiStyle;

  /// 明暗切り替え区分。
  final AppThemeMode themeMode;

  /// ベースとなるSeed Colorの区分。
  final AppThemeColor themeColor;

  /// 指定した項目だけを差し替えた新しい[ThemeSettings]を生成する。
  ///
  /// 未指定の項目は現在値を維持する。
  ThemeSettings copyWith({
    AppUiStyle? uiStyle,
    AppThemeMode? themeMode,
    AppThemeColor? themeColor,
  }) => ThemeSettings(
    uiStyle: uiStyle ?? this.uiStyle,
    themeMode: themeMode ?? this.themeMode,
    themeColor: themeColor ?? this.themeColor,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSettings &&
          runtimeType == other.runtimeType &&
          uiStyle == other.uiStyle &&
          themeMode == other.themeMode &&
          themeColor == other.themeColor;

  @override
  int get hashCode => Object.hash(uiStyle, themeMode, themeColor);
}
