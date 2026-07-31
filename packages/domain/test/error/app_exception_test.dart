import 'package:domain/domain.dart';
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

  group('RepositorySearchException', () {
    test('AppException・Exceptionのサブタイプである', () {
      const exception = RepositorySearchException();

      expect(exception, isA<AppException>());
      expect(exception, isA<Exception>());
    });

    test('messageを保持する', () {
      const exception = RepositorySearchException(message: 'search failed');

      expect(exception.message, 'search failed');
    });
  });

  group('RepositoryDetailException', () {
    test('AppException・Exceptionのサブタイプである', () {
      const exception = RepositoryDetailException();

      expect(exception, isA<AppException>());
      expect(exception, isA<Exception>());
    });

    test('messageを保持する', () {
      const exception = RepositoryDetailException(message: 'detail failed');

      expect(exception.message, 'detail failed');
    });
  });

  group('SearchHistoryPersistenceException', () {
    test('AppException・Exceptionのサブタイプである', () {
      const exception = SearchHistoryPersistenceException();

      expect(exception, isA<AppException>());
      expect(exception, isA<Exception>());
    });

    test('messageを保持する', () {
      const exception = SearchHistoryPersistenceException(
        message: 'persistence failed',
      );

      expect(exception.message, 'persistence failed');
    });
  });
}
