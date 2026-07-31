import 'package:flutter/material.dart';
import 'package:material3_indicators/material3_indicators.dart';

/// Material 3のPull to Refresh表示を提供する共通Widget。
///
/// `material3_indicators`パッケージへの依存を本Widget内に閉じ込め、画面側は
/// 本Widgetだけを利用する。[RefreshIndicator.noSpinner]で標準のspinnerを
/// 非表示にし、[refreshing]が`true`の間だけ[M3LoadingIndicator]を上部へ
/// オーバーレイ表示する。表示の要否はrefresh操作を管理するアプリ状態
/// （呼び出し側がwatchする値）に委ね、本Widget自身はローカルな進行状態を
/// 持たない。
class M3RefreshIndicator extends StatelessWidget {
  /// [onRefresh]・[refreshing]・[child]を指定して生成する。
  const M3RefreshIndicator({
    required this.onRefresh,
    required this.refreshing,
    required this.child,
    this.semanticsLabel,
    super.key,
  });

  /// Pull to Refreshが実行されたときに呼ばれるcallback。
  final RefreshCallback onRefresh;

  /// refresh実行中かどうか。`true`の間だけインジケーターを表示する。
  final bool refreshing;

  /// Pull to Refresh対象のScrollableを含む子Widget。
  final Widget child;

  /// インジケーターのSemantics label。i18nはapp側の責務のため、ローカライズ
  /// 済み文言は呼び出し側から渡す。未指定時はパッケージ既定の英語文言になる。
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator.noSpinner(onRefresh: onRefresh, child: child),
        if (refreshing)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: _M3RefreshIndicatorGlyph(semanticsLabel: semanticsLabel),
            ),
          ),
      ],
    );
  }
}

/// refresh中インジケーター本体。
///
/// [M3LoadingIndicator]は`MediaQuery.disableAnimations`を考慮せず常時
/// morph・回転アニメーションを続けるため、`packages/designsystem`の
/// Skeleton実装（`SkeletonScope`）と同じ方針で、Reduce Motion時は静止した
/// アイコンへフォールバックする。
class _M3RefreshIndicatorGlyph extends StatelessWidget {
  const _M3RefreshIndicatorGlyph({required this.semanticsLabel});

  final String? semanticsLabel;

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: reduceMotion
            ? Semantics(
                label: semanticsLabel,
                child: Icon(
                  Icons.refresh,
                  color: colorScheme.primary,
                  size: _size,
                ),
              )
            : M3LoadingIndicator(size: _size, semanticsLabel: semanticsLabel),
      ),
    );
  }
}
