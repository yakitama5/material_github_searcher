import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

void main() {
  group('RequestCancelledException', () {
    test('AppException・Exceptionのサブタイプである', () {
      const exception = RequestCancelledException();

      expect(exception, isA<AppException>());
      expect(exception, isA<Exception>());
    });

    test('messageを持たない', () {
      const exception = RequestCancelledException();

      expect(exception.message, isNull);
    });
  });

  group('UnknownException', () {
    test('AppExceptionのサブタイプである', () {
      const exception = UnknownException();

      expect(exception, isA<AppException>());
    });

    test('messageを保持する', () {
      const exception = UnknownException(message: 'unexpected');

      expect(exception.message, 'unexpected');
    });
  });
}
