import 'package:flutter/material.dart';
import 'package:material3_indicators/material3_indicators.dart';

/// pull量を[0, 1]へ正規化する際の分母。
///
/// `RefreshIndicator`内部の`_kDragContainerExtentPercentage`（release時に
/// `onRefresh`が発火する閾値）と同じ値を使い、本Widgetが計算する`_pullFraction`
/// が`1.0`に達するタイミングを、実際に発火する閾値へ一致させる。
const _dragContainerExtentPercentage = 0.25;

/// pull量（displayFraction）のうち、Indicatorの拡大アニメーションが完了
/// するまでの割合。この値未満はscaleが`0`→`1`へ線形に広がり、以降は
/// 実寸のまま位置移動（slide）だけが続く。
const _scaleFractionThreshold = 0.5;

/// `_M3RefreshIndicatorGlyph`の直径（Material円の外周）。
///
/// 内側の[Icon]・[M3LoadingIndicator]のsize（24）と、周囲のPadding（8）2つ分の
/// 合計。pull量`0`のときにIndicatorがこの分だけ[M3RefreshIndicator.offset]
/// より上へ隠れる移動距離として使う。
const _glyphExtent = 40.0;

/// [M3RefreshIndicator]が表示するIndicator本体を指すKey。
///
/// Widget Testから参照するため、実装とテストで同一のリテラルを再定義せず
/// 本constを共有する。
const m3RefreshIndicatorGlyphKey = Key('m3RefreshIndicatorGlyph');

/// [M3RefreshIndicator.enabled]が`false`の間、`RefreshIndicator.noSpinner`
/// のdrag検出自体を無効化するためのpredicate。常に`false`を返す。
bool _neverPredicate(ScrollNotification notification) => false;

/// Material 3のPull to Refresh表示を提供する共通Widget。
///
/// `material3_indicators`パッケージへの依存を本Widget内に閉じ込め、画面側は
/// 本Widgetだけを利用する。[RefreshIndicator.noSpinner]の`onStatusChange`と、
/// 自前で監視する[ScrollNotification]からpull量を追跡し、指で引いている途中
/// から[offset]位置の下端を起点にIndicatorがSlideしながら現れる。`refresh`
/// 状態へ遷移した後だけ[M3LoadingIndicator]をアニメーションさせ、それ以外
/// （drag中・armed中・snap中）は`M3LoadingIndicator`のモーフィング開始形状
/// （丸みを帯びた五角形）で静止させる。
///
/// 外部から渡される[refreshing]は、SnackbarのRetryなどgestureを伴わない
/// programmatic refreshの表示に使う。gestureに連動した進行状態
/// （`RefreshIndicatorStatus`とpull量）は本Widgetのローカル状態としてのみ持ち、
/// 呼び出し側のApplication State・ViewModelには公開しない。
class M3RefreshIndicator extends StatefulWidget {
  /// [onRefresh]・[refreshing]・[child]を指定して生成する。
  const M3RefreshIndicator({
    required this.onRefresh,
    required this.refreshing,
    required this.child,
    this.enabled = true,
    this.offset = 16,
    this.semanticsLabel,
    this.pullSemanticsLabel,
    super.key,
  });

  /// Pull to Refreshが実行されたときに呼ばれるcallback。
  final RefreshCallback onRefresh;

  /// refresh実行中かどうか。`true`の間はgestureの有無に関わらずIndicatorを
  /// 表示する（programmatic refresh向け）。
  final bool refreshing;

  /// Pull to Refresh対象のScrollableを含む子Widget。
  final Widget child;

  /// Pull to Refresh gesture自体の有効・無効を切り替える。
  ///
  /// `false`の間は[child]をそのまま表示し、drag検出・Indicator表示を一切
  /// 行わない。未検索・初回loading・初回errorなど、[onRefresh]を呼んでも
  /// 意味を持たない画面状態で、指を引いた分だけIndicatorだけが反応する
  /// ちぐはぐな見た目を避けるために使う。既定値は`true`。
  final bool enabled;

  /// Indicatorを表示する上端からのoffset（論理px）。
  ///
  /// 呼び出し側のScrollable先頭にSearchBar等の固定表示がある場合、それらと
  /// Indicatorが重ならないよう、呼び出し側から表示位置を指定できるようにする
  /// 最小限のAPI。既定値は従来の固定表示と同じ`16`。
  final double offset;

  /// refresh実行中に読み上げるSemantics label。
  ///
  /// i18nはapp側の責務のため、ローカライズ済み文言は呼び出し側から渡す。
  /// 未指定時はパッケージ既定の英語文言になる。
  final String? semanticsLabel;

  /// drag中・armed中・snap中（refresh発火前）に読み上げるSemantics label。
  ///
  /// [semanticsLabel]と同様、ローカライズ済み文言は呼び出し側から渡す。
  final String? pullSemanticsLabel;

  @override
  State<M3RefreshIndicator> createState() => _M3RefreshIndicatorState();
}

class _M3RefreshIndicatorState extends State<M3RefreshIndicator> {
  RefreshIndicatorStatus? _status;
  double _pullFraction = 0;
  double? _dragOffset;

  /// `onRefresh`実行中かどうか。
  ///
  /// `RefreshIndicator.noSpinner`の`onStatusChange`は`refresh`状態への遷移も
  /// アイドルへの復帰も通知しない（フレームワーク内部で`setState`のみ行い
  /// callbackを呼ばない）ため、`refresh`中かどうかは`onRefresh`を自前でラップ
  /// して判定する。
  bool _refreshingByGesture = false;

  bool get _isRefreshing => widget.refreshing || _refreshingByGesture;

  Future<void> _handleRefresh() async {
    setState(() => _refreshingByGesture = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshingByGesture = false;
          _pullFraction = 0;
          _dragOffset = null;
        });
      }
    }
  }

  /// `RefreshIndicator`は`done`・アイドル復帰時に`onStatusChange`を呼ばない
  /// （フレームワーク内部のみで`_status`をリセットする）ため、`_status`は
  /// 次にdragが始まるまで`canceled`・`done`のまま残り続ける。新しいdragの
  /// 開始を「直前の状態」ではなく`status`自体の値だけで判定できるよう、
  /// `drag`遷移時は常に`_dragOffset`・`_pullFraction`を無条件でリセットする。
  void _handleStatusChange(RefreshIndicatorStatus? status) {
    setState(() {
      _status = status;
      if (status == RefreshIndicatorStatus.drag ||
          status == RefreshIndicatorStatus.canceled) {
        _dragOffset = status == RefreshIndicatorStatus.drag ? 0 : null;
        _pullFraction = 0;
      }
    });
  }

  /// `RefreshIndicator.noSpinner`の外側で同じ[ScrollNotification]を観測し、
  /// pull量を`[0, 1]`へ正規化してローカル状態へ反映する。
  ///
  /// `RefreshIndicator`は自身の内部`NotificationListener`から常に`false`を
  /// 返すため、通知はこの外側のListenerまでbubbleしてくる。ここでも`false`を
  /// 返すことで、検索画面のpagination判定（本Widgetの子として、より内側に
  /// 置かれた別のNotificationListener）まで通知を消費せず伝播させる。
  bool _handlePullNotification(ScrollNotification notification) {
    if (!defaultScrollNotificationPredicate(notification)) {
      return false;
    }
    if (_status != RefreshIndicatorStatus.drag &&
        _status != RefreshIndicatorStatus.armed) {
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      _applyDragDelta(
        notification.metrics.axisDirection,
        notification.scrollDelta ?? 0,
        notification.metrics.viewportDimension,
      );
    } else if (notification is OverscrollNotification) {
      _applyDragDelta(
        notification.metrics.axisDirection,
        notification.overscroll,
        notification.metrics.viewportDimension,
      );
    }
    return false;
  }

  void _applyDragDelta(
    AxisDirection axisDirection,
    double delta,
    double viewportDimension,
  ) {
    final dragOffset = _dragOffset ?? 0;
    final sign = axisDirection == AxisDirection.down ? -1.0 : 1.0;
    final newDragOffset = dragOffset + sign * delta;
    final rawFraction =
        newDragOffset / (viewportDimension * _dragContainerExtentPercentage);
    final fraction = rawFraction.clamp(0.0, 1.0);
    setState(() {
      _dragOffset = newDragOffset;
      _pullFraction = fraction;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final displayFraction = _isRefreshing ? 1.0 : _pullFraction;
    final showGlyph = widget.enabled && displayFraction > 0;
    final animateGlyph = _isRefreshing && !reduceMotion;
    // pull量の前半（0〜_scaleFractionThreshold）でscaleを0→1へ広げ切り、
    // 残り半分は位置移動（slide）だけを続ける。全域で拡大し続けるより、
    // 「早めに実寸へ達してからslideする」方が公式のPull to Refreshに近い
    // 見え方になる。
    final scaleFraction = (displayFraction / _scaleFractionThreshold).clamp(
      0.0,
      1.0,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: _handlePullNotification,
      child: Stack(
        children: [
          RefreshIndicator.noSpinner(
            onRefresh: _handleRefresh,
            onStatusChange: _handleStatusChange,
            // [enabled]が`false`の間はpredicateを常にfalseにし、drag検出・
            // `onStatusChange`自体を発生させない。Widgetツリーの形は
            // `enabled`の値によらず変えず、`child`側（検索画面の
            // `CustomScrollView`）のStateを保つ。
            notificationPredicate: widget.enabled
                ? defaultScrollNotificationPredicate
                : _neverPredicate,
            child: widget.child,
          ),
          if (showGlyph)
            Positioned(
              // pull量に応じて上端の位置を動かし、[offset]位置へ向かって
              // slideさせる。displayFraction`0`で`_glyphExtent`分上（画面
              // 外寄り）、`1`で[offset]位置に到達する。SearchBar等との
              // 重なり回避よりも、途中経過の見た目の自然さを優先するため、
              // Overflowによるクリップは行わない。
              top: widget.offset - (1 - displayFraction) * _glyphExtent,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Transform.scale(
                    scale: scaleFraction,
                    child: _M3RefreshIndicatorGlyph(
                      key: m3RefreshIndicatorGlyphKey,
                      animate: animateGlyph,
                      semanticsLabel: _isRefreshing
                          ? widget.semanticsLabel
                          : widget.pullSemanticsLabel,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// refresh中インジケーター本体。
///
/// [M3LoadingIndicator]は`MediaQuery.disableAnimations`を考慮せず常時
/// morph・回転アニメーションを続けるため、`packages/designsystem`の
/// Skeleton実装（`SkeletonScope`）と同じ方針で、[animate]が`false`の間
/// （Reduce Motion時、またはrefresh発火前のpull中）は静止した図形へ
/// フォールバックする。この図形には汎用の矢印アイコンではなく、
/// `M3LoadingIndicator`が最初に描く形状（`M3Shapes.defaultCycle`の先頭、
/// 丸みを帯びた五角形・回転角度0）そのものを使い、アニメーション開始前の
/// 一場面であることを視覚的に示す。
class _M3RefreshIndicatorGlyph extends StatelessWidget {
  const _M3RefreshIndicatorGlyph({
    required this.animate,
    required this.semanticsLabel,
    super.key,
  });

  /// `true`の間だけ[M3LoadingIndicator]をアニメーションさせる。
  final bool animate;

  final String? semanticsLabel;

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: animate
            ? M3LoadingIndicator(size: _size, semanticsLabel: semanticsLabel)
            : Semantics(
                label: semanticsLabel,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: ShapeDecoration(
                    shape: M3Shapes.pentagon(),
                    color: colorScheme.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
