import 'dart:async';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationController / CancellationToken', () {
    test('cancel前のTokenはisCancelledがfalseである', () {
      final controller = CancellationController();

      expect(controller.token.isCancelled, isFalse);
    });

    test('cancel後のTokenはisCancelledがtrueになる', () {
      final controller = CancellationController()..cancel();

      expect(controller.token.isCancelled, isTrue);
    });

    test('cancelを複数回呼んでも例外にならず状態を保つ', () {
      final controller = CancellationController()..cancel();

      expect(controller.cancel, returnsNormally);
      expect(controller.token.isCancelled, isTrue);
    });

    test('whenCancelledはcancel時に完了する', () async {
      final controller = CancellationController();
      var completed = false;

      unawaited(controller.token.whenCancelled.then((_) => completed = true));
      expect(completed, isFalse);

      controller.cancel();
      await controller.token.whenCancelled;

      expect(completed, isTrue);
    });

    test('cancel済みのTokenを後から参照してもwhenCancelledは完了済みである', () async {
      final controller = CancellationController()..cancel();

      // cancel後に取得した購読でも完了を検出できる。
      await expectLater(controller.token.whenCancelled, completes);
    });

    test('throwIfCancelledはcancel前は何も投げない', () {
      final controller = CancellationController();

      expect(controller.token.throwIfCancelled, returnsNormally);
    });

    test('throwIfCancelledはcancel後にRequestCancelledExceptionを投げる', () {
      final controller = CancellationController()..cancel();

      expect(
        controller.token.throwIfCancelled,
        throwsA(isA<RequestCancelledException>()),
      );
    });
  });
}
