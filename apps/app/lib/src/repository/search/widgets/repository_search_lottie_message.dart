import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lottieイラストの表示サイズ（正方形の一辺）。
const _illustrationExtent = 160.0;

/// Repository検索の状態案内で使うLottieと文言を共通表示するWidget。
///
/// Lottieは装飾として[ExcludeSemantics]で包み、状態の意味はタイトルと補足文で
/// 伝える。アセットの読み込みに失敗してもLottieの領域だけを空にし、文言は表示
/// し続ける。`SliverFillRemaining(hasScrollBody: false)`の子にできるよう、内部は
/// intrinsic sizeを計算できる`Center`と`Column(mainAxisSize: min)`で構成する。
class RepositorySearchLottieMessage extends StatefulWidget {
  /// Lottieアセットと案内文を表示するWidgetを生成する。
  const RepositorySearchLottieMessage({
    required this.assetPath,
    required this.title,
    required this.description,
    required this.reducedMotionProgress,
    this.renderCache,
    super.key,
  }) : assert(
         reducedMotionProgress >= 0 && reducedMotionProgress <= 1,
         'reducedMotionProgress must be between 0 and 1',
       );

  /// `Lottie.asset`へ渡すアセットパス。
  final String assetPath;

  /// Lottieの下に表示する見出し。
  final String title;

  /// 見出しの下に表示する補足文。
  final String description;

  /// Reduce Motion時に静止させるアニメーションの進捗。
  final double reducedMotionProgress;

  /// アニメーションの描画キャッシュ。長いアニメーションでは
  /// [RenderCache.drawingCommands]を使い、短いアニメーションでは
  /// [RenderCache.raster]を使うなど、アセットごとに選択する。
  final RenderCache? renderCache;

  @override
  State<RepositorySearchLottieMessage> createState() =>
      _RepositorySearchLottieMessageState();
}

class _RepositorySearchLottieMessageState
    extends State<RepositorySearchLottieMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) {
      return;
    }
    _animationsDisabled = animationsDisabled;
    _applyAnimationState();
  }

  @override
  void didUpdateWidget(covariant RepositorySearchLottieMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _controller
        ..stop()
        ..duration = null
        ..value = (_animationsDisabled ?? false)
            ? widget.reducedMotionProgress
            : 0;
    } else if (oldWidget.reducedMotionProgress !=
            widget.reducedMotionProgress &&
        (_animationsDisabled ?? false)) {
      _controller.value = widget.reducedMotionProgress;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleLoaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    _applyAnimationState();
  }

  /// Reduce Motion設定と読み込み状況に応じてアニメーション状態を揃える。
  ///
  /// Composition読み込み前（[AnimationController.duration]が`null`）は
  /// [AnimationController.repeat]を呼べないため、[_handleLoaded]から再度呼び出す。
  void _applyAnimationState() {
    if (_animationsDisabled ?? false) {
      _controller
        ..stop()
        ..value = widget.reducedMotionProgress;
      return;
    }
    if (_controller.duration == null) {
      return;
    }
    unawaited(_controller.repeat());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: _illustrationExtent,
                height: _illustrationExtent,
                child: Lottie.asset(
                  widget.assetPath,
                  controller: _controller,
                  onLoaded: _handleLoaded,
                  fit: BoxFit.contain,
                  // Lottieのアセット読み込み前後でレイアウトが変わらないよう、
                  // 外側のSizedBoxで幅・高さを固定する。
                  renderCache: widget.renderCache,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
