/// Material Design 3 の Window size classes に基づく幅の分類。
///
/// デバイス種別ではなく利用可能な幅(dp)でレイアウトを判断する方針の一部として、
/// `docs/design.md` の定義をコードに反映したもの。
/// 参考: https://m3.material.io/foundations/layout/breakpoints/overview
enum WindowSizeClass {
  /// 0dp以上 [Breakpoints.medium] 未満。
  compact,

  /// [Breakpoints.medium] 以上 [Breakpoints.expanded] 未満。
  medium,

  /// [Breakpoints.expanded] 以上。
  expanded;

  /// 利用可能な幅(dp)から対応する [WindowSizeClass] を求める。
  factory WindowSizeClass.fromWidth(double width) {
    if (width >= Breakpoints.expanded) {
      return WindowSizeClass.expanded;
    }
    if (width >= Breakpoints.medium) {
      return WindowSizeClass.medium;
    }
    return WindowSizeClass.compact;
  }
}

/// Window size class の下限値(dp)と、大画面時の最大コンテンツ幅(dp)。
abstract final class Breakpoints {
  /// compactクラスの下限値。
  static const double compact = 0;

  /// mediumクラスの下限値。
  static const double medium = 600;

  /// expandedクラスの下限値。
  static const double expanded = 840;

  /// expandedクラスでコンテンツが無制限に広がらないようにする際の最大幅。
  /// expandedの下限値と同じにしているため、compact/mediumクラス
  /// (width < expanded)では常に制限が効かない。
  static const double maxContentWidth = expanded;
}
