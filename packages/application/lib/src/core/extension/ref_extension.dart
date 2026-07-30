import 'dart:async';

import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

/// autoDispose Providerの結果を一定時間だけ保持するための [Ref] 拡張。
extension CacheForExtension on Ref {
  /// 最後のlistenerが外れてから [duration] の間だけProviderを維持する。
  ///
  /// listenerが存在する間は [keepAlive] によりdisposeを抑止し、全listenerが
  /// 外れた（[onCancel]）時点で [duration] のtimerを開始する。期限内にlistenerが
  /// 戻れば（[onResume]）timerを取り消して維持を継続し、期限が満了すると
  /// `KeepAliveLink.close` で維持を解除してProviderをdispose可能にする。
  /// Providerがdisposeされる際（[onDispose]）はtimerを取り消してresourceを解放する。
  ///
  /// 呼び出すタイミングは利用Provider側の責務とする。たとえばRepository Detailは
  /// API成功後にのみ呼び、通信開始時やerror・cancel時には呼ばない。
  ///
  /// 本メソッドは呼び出し時点で [keepAlive] を確保するため、UIがwatchして
  /// listenerが付き外れするautoDispose Providerで使うことを前提とする。listenerが
  /// 一度も付かない（`read` のみで参照する）Providerでは [onCancel] が発火せず期限が
  /// 開始しないため、破棄されず維持され続ける点に注意する。
  void cacheFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;

    onCancel(() {
      timer?.cancel();
      timer = Timer(duration, link.close);
    });
    onResume(() {
      timer?.cancel();
      timer = null;
    });
    onDispose(() {
      timer?.cancel();
      timer = null;
    });
  }
}

/// Provider内でキャンセルを扱うための [Ref] 拡張。
extension CancellationRefExtension on Ref {
  /// Providerのライフサイクルに紐づく [CancellationController] を生成する。
  ///
  /// [Ref.onDispose] へ [CancellationController.cancel] を接続するため、Providerが
  /// dispose・再計算されると進行中の処理へキャンセルが伝わる。RiverpodやHTTP固有の
  /// 型をInfrastructureへ漏らさずに通信を停止できる。
  CancellationController createCancellationController() {
    final controller = CancellationController();
    onDispose(controller.cancel);
    return controller;
  }
}
