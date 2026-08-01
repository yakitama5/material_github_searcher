import 'dart:async';

import 'package:application/application.dart';
import 'package:dependency_override/dependency_override.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'i18n/strings.g.dart';
import 'src/config/app_build_config.dart';
import 'src/license/register_app_license.dart';
import 'src/router/app_title_provider.dart';
import 'src/router/go_router_provider.dart';
import 'src/theme/dynamic_color_scope.dart';

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
  TransitionBuilder? builder,
}) {
  registerAppLicense(config.appName);
  return ProviderScope(
    overrides: [
      appTitleProvider.overrideWithValue(config.appName),
      ...overrides,
    ],
    child: TranslationProvider(
      child: MyApp(config: config, builder: builder),
    ),
  );
}

/// アプリケーションのルートとなるウィジェット。
class MyApp extends ConsumerStatefulWidget {
  /// ルートウィジェット [MyApp] を生成する。
  const MyApp({required this.config, this.builder, super.key});

  /// 現在のビルド設定。
  final AppBuildConfig config;

  /// [MaterialApp.builder] へ注入する任意のラッパー。
  ///
  /// Device Preview専用entrypoint（`debug/main.dart`）が
  /// `DevicePreview.appBuilder` を渡すためのhookで、通常起動やTestでは
  /// 指定しない。
  final TransitionBuilder? builder;

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
    // 読込中・失敗時も既定Themeで起動し、空白画面にしない契約
    // （`ThemeSettingsNotifier`のdoc参照）。永続化失敗時はThemeSettingsを
    // メモリ上の既定値のまま扱うApplication層の方針に合わせ、root側も
    // AsyncLoading・AsyncError双方で`ThemeSettings()`の既定値へ揃える。
    final themeSettings =
        ref.watch(themeSettingsProvider).value ?? const ThemeSettings();
    final routerConfig = ref.watch(goRouterProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final resolvedTheme = AppTheme.resolve(
          themeSettings,
          dynamicLight: lightDynamic,
          dynamicDark: darkDynamic,
        );
        return DynamicColorScope(
          light: lightDynamic,
          dark: darkDynamic,
          child: MaterialApp.router(
            title: widget.config.appName,
            scaffoldMessengerKey: SnackBarManager.rootScaffoldMessengerKey,
            locale: TranslationProvider.of(context).flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: resolvedTheme.light,
            darkTheme: resolvedTheme.dark,
            themeMode: resolvedTheme.themeMode,
            routerConfig: routerConfig,
            builder: widget.builder,
          ),
        );
      },
    );
  }
}
