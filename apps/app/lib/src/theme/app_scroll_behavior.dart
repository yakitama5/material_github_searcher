import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// マウスドラッグでもスクロールできるようにする[ScrollBehavior]。
///
/// 既定の[MaterialScrollBehavior]はタッチ・スタイラス・トラックパッドのみを
/// ドラッグスクロール対象とし、マウスは含めない
/// （テキスト選択との競合を避けるための上流の既定挙動）。本アプリはWebを
/// モバイルアプリ相当のスワイプ操作感で確認できるようにする方針のため、
/// マウスもドラッグ対象へ追加する。
class AppScrollBehavior extends MaterialScrollBehavior {
  /// [AppScrollBehavior] を生成する。
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
