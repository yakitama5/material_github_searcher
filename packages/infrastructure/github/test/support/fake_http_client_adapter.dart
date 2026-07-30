import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// テスト専用の[HttpClientAdapter]実装。
///
/// 実通信を行わず、テストごとに用意した[handler]の戻り値・例外をそのまま
/// [Dio]へ返す。呼び出しごとの[RequestOptions]は[capturedRequests]に記録する。
final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  FutureOr<ResponseBody> Function(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  )
  handler;

  final List<RequestOptions> capturedRequests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedRequests.add(options);
    return handler(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
