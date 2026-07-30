import 'package:domain/domain.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('MockRepositorySearchResponse', () {
    test('MockRepositorySearchSuccessはpageを保持する', () {
      final response = MockRepositorySearchSuccess(
        RepositorySearchPageFixtures.empty,
      );

      expect(response.page, same(RepositorySearchPageFixtures.empty));
      expect(response.gate, isNull);
    });

    test('MockRepositorySearchFailureはexceptionを保持する', () {
      const exception = RepositorySearchException(message: 'failed');
      const response = MockRepositorySearchFailure(exception);

      expect(response.exception, same(exception));
      expect(response.gate, isNull);
    });

    test(
      'MockRepositorySearchFailureへRequestCancelledExceptionは指定できない',
      () {
        expect(
          () => MockRepositorySearchFailure(const RequestCancelledException()),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });
}
