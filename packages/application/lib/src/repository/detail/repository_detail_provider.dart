import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

import '../../core/extension/ref_extension.dart';
import 'repository_detail_repository_provider.dart';

/// [repositoryDetailProvider]が成功結果を維持する期間。
///
/// 最後のlistenerが外れてからこの期間内に同じ[RepositoryIdentity]が
/// 再購読されれば、[RepositoryDetailRepository.fetch]を呼び直さずcacheした
/// 結果を再利用する。
const repositoryDetailCacheDuration = Duration(minutes: 5);

/// [RepositoryIdentity]単位でRepository Detail追加情報を取得するProvider。
///
/// 通信中に最後のlistenerが外れると
/// [CancellationRefExtension.createCancellationController]が`onDispose`で
/// 接続する`cancel()`により通信をキャンセルする。成功結果だけ
/// [repositoryDetailCacheDuration]の間cacheし、error・cancelはcacheしない。
/// Retryは呼び出し側が`ref.invalidate(repositoryDetailProvider(identity))`を
/// 呼ぶ契約とし、本Provider自身はretry用のAPIを公開しない。
///
/// Riverpodの`FutureProvider`は既定でerror時に`ProviderContainer.defaultRetry`
/// による指数バックオフの自動retryを行う。前述の「Retryは`ref.invalidate`に
/// 固定する」契約と衝突し、レート制限のあるGitHub APIへ意図せず自動再試行して
/// しまうため、`retry: (_, _) => null`で明示的に無効化する。
final repositoryDetailProvider = FutureProvider.autoDispose
    .family<RepositoryDetailSupplement, RepositoryIdentity>((
      ref,
      identity,
    ) async {
      final repository = ref.watch(repositoryDetailRepositoryProvider);
      final controller = ref.createCancellationController();
      final result = await repository.fetch(
        identity,
        cancellationToken: controller.token,
      );
      // 成功後にのみ呼ぶ。開始時に呼ぶとkeepAliveが通信中も含め常時有効になり
      // cancelできなくなる。cancel・error時に呼ぶとそれらの結果までcacheされて
      // しまう（ref_extension.dartのcacheFor doc契約）。
      ref.cacheFor(repositoryDetailCacheDuration);
      return result;
    }, retry: (_, _) => null);
