import 'dart:async';

import 'package:flutter/material.dart';

/// 子のSkeleton Widgetでアニメーションを共有するコンテナ。
///
/// [SkeletonBox]、[SkeletonText]、[SkeletonCircle]は、同じ
/// [SkeletonScope]の中に配置する。Scopeごとに1つだけTickerを作成するため、
/// 複数行のプレースホルダーでも各WidgetがAnimationControllerを持つことはない。
class SkeletonScope extends StatelessWidget {
  /// [child]を共有アニメーションの対象にする。
  const SkeletonScope({required this.child, super.key});

  /// Skeleton Widgetを含む子Widget。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SkeletonScopeHost(child: child);
  }
}

class _SkeletonScopeHost extends StatefulWidget {
  const _SkeletonScopeHost({required this.child});

  final Widget child;

  @override
  State<_SkeletonScopeHost> createState() => _SkeletonScopeHostState();
}

class _SkeletonScopeHostState extends State<_SkeletonScopeHost>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 1200);

  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) {
      return;
    }

    _animationsDisabled = animationsDisabled;
    if (animationsDisabled) {
      _controller.value = 0;
      _controller.stop();
    } else {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScopeData(animation: _controller, child: widget.child);
  }
}

class _SkeletonScopeData extends InheritedWidget {
  const _SkeletonScopeData({required this.animation, required super.child});

  final Animation<double> animation;

  static _SkeletonScopeData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SkeletonScopeData>();
    assert(
      scope != null,
      'SkeletonBox、SkeletonText、SkeletonCircleはSkeletonScopeの子として配置してください。',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(_SkeletonScopeData oldWidget) =>
      animation != oldWidget.animation;
}

/// 指定サイズの角丸Skeletonプレースホルダー。
class SkeletonBox extends StatelessWidget {
  /// [width]、[height]、[borderRadius]を指定して生成する。
  const SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius,
    super.key,
  }) : assert(width >= 0),
       assert(height >= 0);

  /// プレースホルダーの幅。
  final double width;

  /// プレースホルダーの高さ。
  final double height;

  /// 角丸の半径。
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    return _SkeletonShape(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

/// テキスト行用のSkeletonプレースホルダー。
class SkeletonText extends StatelessWidget {
  /// [width]と任意の[height]を指定して生成する。
  const SkeletonText({required this.width, this.height, super.key})
    : assert(width >= 0),
      assert(height == null || height >= 0);

  /// プレースホルダーの幅。
  final double width;

  /// プレースホルダーの高さ。未指定時は16dp。
  final double? height;

  @override
  Widget build(BuildContext context) {
    const defaultHeight = 16.0;
    final textHeight = height ?? defaultHeight;

    return _SkeletonShape(
      width: width,
      height: textHeight,
      borderRadius: BorderRadius.circular(textHeight / 2),
    );
  }
}

/// 円形のSkeletonプレースホルダー。
class SkeletonCircle extends StatelessWidget {
  /// [diameter]を指定して生成する。
  const SkeletonCircle({required this.diameter, super.key})
    : assert(diameter >= 0);

  /// 円の直径。
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return _SkeletonShape(
      width: diameter,
      height: diameter,
      shape: BoxShape.circle,
    );
  }
}

class _SkeletonShape extends StatelessWidget {
  const _SkeletonShape({
    required this.width,
    required this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final double width;
  final double height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final animation = _SkeletonScopeData.of(context).animation;

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        child: SizedBox(width: width, height: height),
        builder: (context, child) {
          final colorScheme = Theme.of(context).colorScheme;
          final baseColor = colorScheme.surfaceContainerHighest;
          final highlightColor = Color.alphaBlend(
            colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
            baseColor,
          );
          final progress = Curves.easeInOut.transform(animation.value);
          final color = Color.lerp(baseColor, highlightColor, progress)!;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
              shape: shape,
            ),
            child: child,
          );
        },
      ),
    );
  }
}
