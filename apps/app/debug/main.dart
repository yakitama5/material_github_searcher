import 'package:dependency_override/dependency_override.dart';
import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_github_searcher/i18n/strings.g.dart';
import 'package:material_github_searcher/main.dart';
import 'package:material_github_searcher/src/config/app_build_config.dart';
import 'package:material_github_searcher/src/config/device_preview_guard.dart';

/// Device Preview専用のDev Web entrypoint。
///
/// 端末サイズ・画面向き・Text Scale・Light/Darkの確認に用途を限定し、
/// 通常起動・Widget Test・Patrolでは利用しない
/// （[docs/development.md](../../../docs/development.md)参照）。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleSettings.useDeviceLocale();

  final config = AppBuildConfig.current;
  assertDevicePreviewAllowed(config, isReleaseMode: kReleaseMode);

  runApp(
    DevicePreview(
      tools: const [
        DeviceSection(frameVisibility: false, virtualKeyboard: false),
        AccessibilitySection(
          accessibleNavigation: false,
          invertColors: false,
          boldText: false,
        ),
        SystemSection(locale: false),
      ],
      builder: (context) => createApp(
        config: config,
        overrides: createProductionOverrides(),
        builder: DevicePreview.appBuilder,
      ),
    ),
  );
}
