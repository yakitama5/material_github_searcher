import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

/// [ThemeSettingsRepository]を注入するProvider。
///
/// Application層はInfrastructureを直接importせず、この抽象だけに依存する。
/// 既定では未結線のため参照すると[UnimplementedError]になる。実装の結線は
/// `dependency_override`が本番用（SharedPreferences等）・テスト用（Mock）
/// それぞれのoverrideで行い、Composition Rootが適用する。
final themeSettingsRepositoryProvider = Provider<ThemeSettingsRepository>(
  (ref) => throw UnimplementedError(
    'themeSettingsRepositoryProvider must be overridden. '
    'Apply createProductionOverrides() or createMockOverrides().',
  ),
);
