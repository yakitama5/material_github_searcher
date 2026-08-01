import 'package:flutter/material.dart';

/// rootで取得したDynamic Colorを、アプリ内の設定画面へ伝えるScope。
///
/// Dynamic Colorの取得はComposition Rootの`DynamicColorBuilder`が一度だけ担い、
/// 子Widgetがプラグインを再呼び出ししないようにする。取得できない場合は
/// [light]または[dark]が`null`になる。
class DynamicColorScope extends InheritedWidget {
  /// Dynamic Colorの取得結果を保持するScopeを生成する。
  const DynamicColorScope({
    required this.light,
    required this.dark,
    required super.child,
    super.key,
  });

  /// Dynamic Colorのlight Scheme。未対応・未取得時は`null`。
  final ColorScheme? light;

  /// Dynamic Colorのdark Scheme。未対応・未取得時は`null`。
  final ColorScheme? dark;

  /// 現在の[brightness]に対応するDynamic Colorを返す。
  ColorScheme? schemeFor(Brightness brightness) => switch (brightness) {
    Brightness.light => light,
    Brightness.dark => dark,
  };

  /// 現在の[brightness]でDynamic Colorが利用できるか。
  bool isAvailableFor(Brightness brightness) => schemeFor(brightness) != null;

  /// [context]から最寄りのScopeを取得する。root外では`null`を返す。
  static DynamicColorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DynamicColorScope>();

  @override
  bool updateShouldNotify(DynamicColorScope oldWidget) =>
      light != oldWidget.light || dark != oldWidget.dark;
}
