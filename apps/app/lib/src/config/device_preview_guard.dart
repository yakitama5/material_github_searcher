import 'app_build_config.dart';

/// Device Preview専用entrypoint（`debug/main.dart`）の起動可否を判定する。
///
/// 判定ロジックを`device_preview_plus`に依存しない形でここへ置くことで、
/// `debug/`配下から呼び出しつつ、Widget Testからも直接検証できるようにする。
/// Device Previewは実機・Widget Test・Golden Test・Patrolの代替にしない方針
/// のため、Dev Flavorかつdebug/profile用途に限定し、Prod Flavorまたは
/// releaseでの起動を拒否する。
void assertDevicePreviewAllowed(
  AppBuildConfig config, {
  required bool isReleaseMode,
}) {
  if (isReleaseMode) {
    throw StateError(
      'Device Preview entrypoint (debug/main.dart) must not be used in '
      'release mode. Use lib/main.dart instead.',
    );
  }
  if (config.flavor != Flavor.dev) {
    throw StateError(
      'Device Preview entrypoint (debug/main.dart) requires the dev '
      'flavor. Pass --dart-define-from-file=flavor/dev.json.',
    );
  }
}
