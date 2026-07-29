import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:patrol/patrol.dart';

/// 決定的な設定でE2E Test対象のアプリを起動する。
///
/// 外部サービスを利用する機能の実装後は、この関数で`dependency_override`が公開する
/// Mock向けoverride一式を必須で受け取り、[createApp]へ注入する。
Future<void> pumpTestApp(PatrolIntegrationTester $) async {
  await LocaleSettings.setLocale(AppLocale.ja);
  await $.pumpWidgetAndSettle(createApp(config: AppBuildConfig.current));
}
