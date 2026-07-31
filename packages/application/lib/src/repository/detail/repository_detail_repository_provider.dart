import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

/// [RepositoryDetailRepository]を注入するProvider。
///
/// Application層はInfrastructureを直接importせず、この抽象だけに依存する。
/// 既定では未結線のため参照すると[UnimplementedError]になる。実装の結線は
/// `dependency_override`が本番用（GitHub API）・テスト用（Mock）それぞれの
/// overrideで行い、Composition Rootが適用する。
final repositoryDetailRepositoryProvider = Provider<RepositoryDetailRepository>(
  (ref) => throw UnimplementedError(
    'repositoryDetailRepositoryProvider must be overridden. '
    'Apply createProductionOverrides() or createMockOverrides().',
  ),
);
