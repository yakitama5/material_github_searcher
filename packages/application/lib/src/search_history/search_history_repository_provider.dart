import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

/// [SearchHistoryRepository]を注入するProvider。
///
/// Application層はInfrastructureを直接importせず、この抽象だけに依存する。
/// 既定では未結線のため参照すると[UnimplementedError]になる。実装の結線は
/// `dependency_override`が本番用（SharedPreferences）・テスト用（Mock）それぞれの
/// overrideで行い、Composition Rootが適用する。
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => throw UnimplementedError(
    'searchHistoryRepositoryProvider must be overridden. '
    'Apply createProductionOverrides() or createMockOverrides().',
  ),
);
