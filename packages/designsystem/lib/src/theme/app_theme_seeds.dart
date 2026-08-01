// 本ファイルの目的そのものがIssueで固定されたSeed Colorの宣言であり、
// ColorSchemeから導出できない値のため、ファイル全体でavoid_hardcoded_colorを
// 無効化する。
// ignore_for_file: altive_lints_plugin/avoid_hardcoded_color

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

/// [AppThemeColor]に対応する固定Seed Colorを解決する拡張。
extension AppThemeColorSeed on AppThemeColor {
  /// この[AppThemeColor]の固定Seed Color。
  ///
  /// [AppThemeColor.dynamic]はOS由来の[ColorScheme]を使うため固定Seedを
  /// 持たず`null`を返す。呼び出し側（`AppTheme.resolve`）がDynamic Color
  /// 固有のフォールバックとして個別に扱う。
  Color? get seed => switch (this) {
    AppThemeColor.app => const Color(0xFF0969DA),
    AppThemeColor.blue => const Color(0xFF2196F3),
    AppThemeColor.purple => const Color(0xFF9C27B0),
    AppThemeColor.pink => const Color(0xFFE91E63),
    AppThemeColor.red => const Color(0xFFF44336),
    AppThemeColor.orange => const Color(0xFFFF9800),
    AppThemeColor.yellow => const Color(0xFFFFEB3B),
    AppThemeColor.green => const Color(0xFF4CAF50),
    AppThemeColor.dynamic => null,
  };
}
