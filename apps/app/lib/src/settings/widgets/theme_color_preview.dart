import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../theme/dynamic_color_scope.dart';

/// Theme Color選択肢とSettings一覧に表示する色preview。
///
/// 固定色は対応するSeed、Dynamicは取得済みSchemeのprimaryを使う。
/// Dynamic Colorを取得できない場合は、実効Themeと同じApp seedへfallbackする。
/// previewは装飾であり、選択肢名とRadioのSemanticsが意味を伝えるため、
/// preview自身はSemanticsから除外する。
class ThemeColorPreview extends StatelessWidget {
  /// Theme Color previewを生成する。
  const ThemeColorPreview({required this.themeColor, super.key});

  /// preview対象のTheme Color。
  final AppThemeColor themeColor;

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(context);
    return ExcludeSemantics(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  Color _resolveColor(BuildContext context) {
    final seed = themeColor.seed;
    if (seed != null) {
      return seed;
    }
    final scheme = DynamicColorScope.maybeOf(
      context,
    )?.schemeFor(Theme.of(context).brightness);
    return scheme?.primary ?? AppThemeColor.app.seed!;
  }
}
