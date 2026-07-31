import 'dart:async';

import 'package:domain/domain.dart';

/// `MockRepositoryDetailRepository`へ設定する`fetch`1回分の応答。
///
/// [MockRepositoryDetailSuccess]・[MockRepositoryDetailFailure]の
/// いずれかであり、`sealed`により本ライブラリ外からの新規サブタイプ追加を
/// 防いで、呼出側の`switch`が両ケースを網羅していることを型で保証する。
sealed class MockRepositoryDetailResponse {
  const MockRepositoryDetailResponse({this.gate});

  /// 応答を完了させるタイミングを制御するゲート。
  ///
  /// `null`の場合は即座に応答する。非`null`の場合、`fetch()`はこの
  /// [Completer.future]と`cancellationToken.whenCancelled`のどちらか先に
  /// 完了した方を採用する。呼び出し側が任意のタイミングで[Completer.complete]
  /// することで、実時間の待機（`Future.delayed`等）に頼らない決定的な
  /// 遅延シナリオを表現できる。
  final Completer<void>? gate;
}

/// 成功応答。`fetch()`は[supplement]をそのまま返す。
final class MockRepositoryDetailSuccess extends MockRepositoryDetailResponse {
  /// 成功応答を生成する。
  const MockRepositoryDetailSuccess(this.supplement, {super.gate});

  /// `fetch()`が返すDetail追加情報。
  final RepositoryDetailSupplement supplement;
}

/// 失敗応答。`fetch()`は[exception]を投げる。
final class MockRepositoryDetailFailure extends MockRepositoryDetailResponse {
  /// 失敗応答を生成する。
  ///
  /// [exception]に[RequestCancelledException]は指定できない。cancelは
  /// `CancellationController.cancel()`による実際のキャンセルでのみ再現する
  /// 契約とし、失敗応答経由での見せかけのcancelを防ぐ。`assert`はrelease
  /// モード等で無効化され得るため、実行モードによらず検証するために
  /// 通常のコンストラクタ本体で[ArgumentError]を投げる。
  MockRepositoryDetailFailure(this.exception, {super.gate}) {
    if (exception is RequestCancelledException) {
      throw ArgumentError.value(
        exception,
        'exception',
        'Use CancellationController.cancel() to simulate cancellation '
            'instead of '
            'MockRepositoryDetailFailure(RequestCancelledException()).',
      );
    }
  }

  /// `fetch()`が投げる例外。
  final AppException exception;
}
