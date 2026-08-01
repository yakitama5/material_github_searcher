import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../i18n/strings.g.dart';
import 'repository_search_lottie_message.dart';

/// Repository検索が成功し、結果が0件のときに表示するEmpty表示。
///
/// `SliverFillRemaining(hasScrollBody: false)`の直接の子として使う。
class RepositorySearchEmpty extends StatelessWidget {
  /// Empty表示を生成する。
  const RepositorySearchEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;
    return RepositorySearchLottieMessage(
      assetPath: 'assets/lottie/woman_empty_box.json',
      title: i18n.emptyTitle,
      description: i18n.emptyHint,
      reducedMotionProgress: 1,
      // 小さく反復再生するアニメーションはraster cacheで使い回すことを
      // lottieパッケージ自身が推奨している。Emptyの既存挙動を維持する。
      renderCache: RenderCache.raster,
    );
  }
}
