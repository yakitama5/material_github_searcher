import 'package:flutter_riverpod/misc.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:patrol/patrol.dart';

/// 決定的な設定でE2E Test対象のアプリを起動する。
///
/// 呼び出し元が指定した[overrides]を[createApp]へ注入し、外部サービスの実装後も
/// 同じComposition Rootを利用する。
Future<void> pumpTestApp(
  PatrolIntegrationTester $, {
  required List<Override> overrides,
}) async {
  await LocaleSettings.setLocale(AppLocale.ja);
  await $.pumpWidgetAndSettle(
    createApp(
      config: AppBuildConfig.current,
      overrides: overrides,
    ),
  );
}
