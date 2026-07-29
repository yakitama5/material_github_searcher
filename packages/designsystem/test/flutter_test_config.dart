import 'dart:async';

import 'package:alchemist/alchemist.dart';

/// designsystemパッケージのgoldenテスト共通設定。
///
/// `flutter_test_config.dart` はパッケージ内の全テスト実行前に読み込まれる。
/// Golden TestはCIでは実行せず、コミット前にローカルで実行して見た目の変化に
/// 気づくための開発者向けチェックと位置付ける(`docs/testing.md` 参照)。
/// そのため、プラットフォーム間の描画差を吸収する目的だったCI golden
/// (Ahemフォント固定・文字が読めないブロック表示)は使わず、実フォント・実アイコンで
/// 描画され人が読めるプラットフォームgoldenのみを比較対象にする。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      ciGoldensConfig: CiGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
