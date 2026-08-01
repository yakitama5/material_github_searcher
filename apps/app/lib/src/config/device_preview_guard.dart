import 'app_build_config.dart';

/// Device Preview専用entrypoint（`debug/main.dart`）の起動可否を判定する。
///
/// 判定ロジックを`device_preview_plus`に依存しない形でここへ置くことで、
/// `debug/`配下から呼び出しつつ、Widget Testからも直接検証できるようにする。
/// Device Previewは実機・Widget Test・Golden Test・Patrolの代替にしない方針
/// のため、Dev Flavorかつ Web に限定し、Prod Flavor・Web以外のPlatformでの
/// 起動を拒否する。GitHub PagesへのDev Web Preview配信はrelease buildを
/// 要するため、Dev Flavor・Web の組み合わせに限りdebug/profile/release
/// いずれのbuild modeも許可する（Android/iOSのProd・releaseから専用
/// entrypointを利用できない制約は、Flavorおよびplatformの判定で維持する）。
void assertDevicePreviewAllowed(
  AppBuildConfig config, {
  required bool isWeb,
}) {
  if (config.flavor != Flavor.dev) {
    throw StateError(
      'Device Preview entrypoint (debug/main.dart) requires the dev '
      'flavor. Pass --dart-define-from-file=flavor/dev.json.',
    );
  }
  if (!isWeb) {
    throw StateError(
      'Device Preview entrypoint (debug/main.dart) is Web-only. Use '
      'lib/main.dart for Android/iOS.',
    );
  }
}
