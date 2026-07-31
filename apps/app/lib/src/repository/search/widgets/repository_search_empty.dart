import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../i18n/strings.g.dart';

/// Lottieイラストの表示サイズ（正方形の一辺）。
const _illustrationExtent = 160.0;

/// Repository検索が成功し、結果が0件のときに表示するEmpty表示。
///
/// `SkeletonScope`（`packages/designsystem`）や`M3RefreshIndicator`の
/// Reduce Motion対応と同じ方針で、[MediaQuery.disableAnimationsOf]が
/// `true`の間はLottieアニメーションを止め、最終フレームで静止させる
/// （初期フレームは箱が閉じた状態で意味を持たないため、意味のある静止画に
/// なる最終フレームを使う）。`RepositorySearchMessageView`と同じ
/// `Center` + `Column`構成にし、`SliverFillRemaining(hasScrollBody: false)`
/// の直接の子として使う前提とする（`hasScrollBody: false`はintrinsic
/// dimensionsの計算を子に要求するため、`LayoutBuilder`など計算不能な
/// Widgetを子に含めない）。
class RepositorySearchEmpty extends StatefulWidget {
  /// Empty表示を生成する。
  const RepositorySearchEmpty({super.key});

  @override
  State<RepositorySearchEmpty> createState() => _RepositorySearchEmptyState();
}

class _RepositorySearchEmptyState extends State<RepositorySearchEmpty>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleLoaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    _applyAnimationState();
  }

  /// [_animationsDisabled]と読み込み状況に応じてanimationの再生状態を揃える。
  ///
  /// Composition読み込み前（[AnimationController.duration]が`null`）は
  /// `repeat()`を呼べないため、[_handleLoaded]からの再呼び出しに委ねる。
  void _applyAnimationState() {
    if (_animationsDisabled) {
      _controller
        ..stop()
        ..value = 1;
      return;
    }
    if (_controller.duration == null) {
      return;
    }
    unawaited(_controller.repeat());
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;
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
                  'assets/lottie/woman_empty_box.json',
                  controller: _controller,
                  onLoaded: _handleLoaded,
                  fit: BoxFit.contain,
                  // 小さく反復再生するアニメーションはrenderCacheで使い回す
                  // ことをlottieパッケージ自身が推奨している（CPU/GPU負荷を
                  // メモリ使用量とtradeする）。
                  //
                  // `backgroundLoading: true`はcompute()経由の実Isolateを
                  // 使うため意図的に指定しない。Widget Testは`tester.pump`
                  // でcomposition読み込みの完了を待つ設計（`pumpAndSettle`
                  // が使えないため）だが、`tester.pump`はFakeAsyncのタイマー
                  // のみ進め実Isolateの往復は進めないため、指定すると
                  // Widget Testが本番と無関係な理由で不安定になる。
                  renderCache: RenderCache.raster,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              i18n.emptyTitle,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              i18n.emptyHint,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
