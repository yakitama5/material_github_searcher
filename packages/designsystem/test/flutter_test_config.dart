import 'dart:async';

import 'package:alchemist/alchemist.dart';

/// designsystemパッケージのgoldenテスト共通設定。
///
/// `flutter_test_config.dart` はパッケージ内の全テスト実行前に読み込まれる。
/// CI環境(`--dart-define=CI=true`)ではプラットフォーム依存の描画差異を避けるため、
/// プラットフォームgolden(`goldens/<platform>/`)の生成自体を無効化し、
/// CI golden(`goldens/ci/`、Ahemフォント固定で常に生成・比較される)のみを扱う。
/// ローカル実行時はプラットフォームgoldenも生成される(alchemistのデフォルト動作)が、
/// 比較対象はCI goldenのみというデフォルト仕様は変わらない。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const isCi = bool.fromEnvironment('CI');

  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(
        // --dart-define未指定(isCi=false)時はデフォルト値(true)と一致し静的解析上
        // 冗長に見えるが、`--dart-define=CI=true`指定時にfalseへ切り替えるための
        // 実行時分岐であり削除できない。
        // ignore: avoid_redundant_argument_values
        enabled: !isCi,
      ),
    ),
    run: testMain,
  );
}
