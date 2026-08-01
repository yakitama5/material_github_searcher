import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../i18n/strings.g.dart';
import 'repository_search_lottie_message.dart';

/// Repository検索をまだ実行していない初期状態の案内表示。
class RepositorySearchInitial extends StatelessWidget {
  /// 初期状態の案内を生成する。
  const RepositorySearchInitial({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n.repositorySearch;
    return RepositorySearchLottieMessage(
      assetPath: 'assets/lottie/search_initialize.json',
      title: i18n.initialTitle,
      description: i18n.initialHint,
      reducedMotionProgress: 1,
      // search_initializeは約11秒のアニメーションのため、全フレームを
      // rasterizeして保持するより描画コマンドのキャッシュを使う。
      renderCache: RenderCache.drawingCommands,
    );
  }
}
