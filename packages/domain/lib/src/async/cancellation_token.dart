import 'dart:async';

import '../error/app_exception.dart';

/// 非同期処理のキャンセルを購読するための読み取り専用トークン。
///
/// キャンセルの指示は [CancellationController.cancel] のみが行い、トークンの
/// 保持者は状態の参照とキャンセル完了の待受けだけを行う。HTTPやRiverpodなどの
/// 特定技術には依存せず、「キャンセルは [RequestCancelledException] で表す」という
/// ドメインの決定に基づく契約としてdomainが所有する。後続のGitHub API adapterは
/// [whenCancelled] をHTTPのabortへ接続し、本契約を再実装しない。
abstract interface class CancellationToken {
  /// 既にキャンセル済みなら `true`。
  bool get isCancelled;

  /// キャンセルされたときに完了する [Future]。
  ///
  /// 既にキャンセル済みの場合も完了済みの [Future] を返すため、購読タイミングに
  /// よらずキャンセルを検出できる。逆に [CancellationController.cancel] が
  /// 呼ばれない限り完了しないため、`whenCancelled.then(...)` で登録した後始末
  /// （通信のabort等）はキャンセル時だけ実行される。正常完了時のリソース解放は
  /// 通信実装側で別途行う。Provider経由の場合は `createCancellationController`
  /// が `Ref.onDispose` でcancelを保証する。
  Future<void> get whenCancelled;

  /// 既にキャンセル済みなら [RequestCancelledException] を投げる。
  ///
  /// 処理の要所で呼び出し、キャンセル後に処理を継続しないための番兵として使う。
  void throwIfCancelled();
}

/// [CancellationToken] を生成し、キャンセルを指示するコントローラ。
///
/// 生成側（Providerやユースケース）が本体を保持してキャンセルを制御し、処理の
/// 実行側へは [token] だけを渡す。
final class CancellationController {
  /// キャンセルコントローラを生成する。
  CancellationController();

  final Completer<void> _completer = Completer<void>();

  late final CancellationToken _token = _CancellationToken(this);

  /// 実行側へ渡す読み取り専用トークン。
  CancellationToken get token => _token;

  bool get _isCancelled => _completer.isCompleted;

  /// キャンセルを指示する。
  ///
  /// 冪等であり、複数回呼び出しても2回目以降は何もしない。二重cancelや
  /// dispose後の再cancelでも例外にならない。
  void cancel() {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete();
  }
}

/// [CancellationController] に紐づく [CancellationToken] の実装。
final class _CancellationToken implements CancellationToken {
  _CancellationToken(this._controller);

  final CancellationController _controller;

  @override
  bool get isCancelled => _controller._isCancelled;

  @override
  Future<void> get whenCancelled => _controller._completer.future;

  @override
  void throwIfCancelled() {
    if (isCancelled) {
      throw const RequestCancelledException();
    }
  }
}
