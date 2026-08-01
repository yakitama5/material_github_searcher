import 'package:flutter/material.dart';

/// [BuildContext]から現在の[ColorScheme]・[TextTheme]へ簡潔にアクセスする拡張。
///
/// `Theme.of(context).colorScheme`の繰り返しを避け、画面への色直書きを
/// 避ける方針（`docs/design.md`参照）に沿ったAPIを提供する。
extension AppThemeContext on BuildContext {
  /// `Theme.of(this).colorScheme`のショートハンド。
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// `Theme.of(this).textTheme`のショートハンド。
  TextTheme get textTheme => Theme.of(this).textTheme;
}
