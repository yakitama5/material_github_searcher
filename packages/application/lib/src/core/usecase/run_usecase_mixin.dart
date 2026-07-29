import 'package:riverpod/riverpod.dart';

import '../state/app_loading_provider.dart';

/// UseCase実行時の共通処理を提供するMixin。
///
/// 実行中はグローバルなローディング状態（[appLoadingProvider]）を参照カウント式で
/// 管理する。検索初回・Load More・Pull to Refresh・Repository Detail取得など、
/// 各Providerの `AsyncValue` をSSOTとして表示すべき読込は `disableLoading` を
/// `true` にしてグローバルローディングへ載せ替えない。
mixin RunUsecaseMixin {
  /// [action] を実行し、その結果を返す。
  ///
  /// [disableLoading] が `false`（既定）の場合は [appLoadingProvider] の
  /// 参照カウントを実行前後で増減させる。`true` の場合はグローバルな
  /// ローディング状態を変更せずに [action] を実行する。
  Future<T> execute<T>(
    Ref ref, {
    required Future<T> Function() action,
    bool disableLoading = false,
  }) async {
    if (disableLoading) {
      return action();
    }

    return ref.read(appLoadingProvider.notifier).wrap(action());
  }
}
