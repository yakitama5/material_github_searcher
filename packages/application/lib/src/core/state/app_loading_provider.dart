import 'package:riverpod/riverpod.dart';

/// アプリ全体で共通するローディング表示を管理する。
///
/// `state` は同時に実行中の [AppLoadingNotifier.wrap] 呼び出し数を表す
/// カウンタであり、ローディング中かどうかは `state > 0` で判定する。
/// 並行して複数の処理が実行された場合、一方が完了しても残処理があれば
/// カウントが `0` に戻らないため、ローディング表示を維持できる。
final appLoadingProvider = NotifierProvider<AppLoadingNotifier, int>(
  AppLoadingNotifier.new,
);

/// [appLoadingProvider] の状態を管理する [Notifier]。
class AppLoadingNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// [future] の実行前後で参照カウントを増減させる。
  ///
  /// 実行開始でカウントを `+1` し、成功・失敗いずれの場合も `finally` で
  /// `-1` へ戻す。これによりカウントが負数になることはなく、成功・失敗の
  /// 双方でローディング状態が確実に解除される。
  Future<T> wrap<T>(Future<T> future) async {
    state = state + 1;
    try {
      return await future;
    } finally {
      state = state - 1;
    }
  }
}
