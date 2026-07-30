import 'dart:async';

import 'package:application/application.dart';
import 'package:dependency_override/dependency_override.dart';
import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'i18n/strings.g.dart';
import 'src/config/app_build_config.dart';
import 'src/router/app_title_provider.dart';
import 'src/router/go_router_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleSettings.useDeviceLocale();
  runApp(
    createApp(
      config: AppBuildConfig.current,
      overrides: createProductionOverrides(),
    ),
  );
}

/// 指定されたビルド設定でアプリケーションのルートWidgetを生成する。
///
/// 通常起動とWidget Test・E2E Testで同じComposition Rootを利用するため、設定は
/// 呼び出し元が明示的に注入する。
Widget createApp({
  required AppBuildConfig config,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      appTitleProvider.overrideWithValue(config.appName),
      ...overrides,
    ],
    child: TranslationProvider(child: MyApp(config: config)),
  );
}

/// アプリケーションのルートとなるウィジェット。
class MyApp extends ConsumerStatefulWidget {
  /// ルートウィジェット [MyApp] を生成する。
  const MyApp({required this.config, super.key});

  /// 現在のビルド設定。
  final AppBuildConfig config;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 検索履歴の永続化済みloadはComposition Root起動時に一度だけ行う契約
    // （SearchHistoryControllerのdoc参照）。画面固有のViewModelを持たない
    // 方針のため、画面のinitStateではなくここで呼ぶ。
    unawaited(ref.read(searchHistoryControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: widget.config.appName,
      scaffoldMessengerKey: SnackBarManager.rootScaffoldMessengerKey,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
