import 'package:domain/domain.dart';
import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('MockRepositoryDetailResponse', () {
    const identity = RepositoryIdentity(owner: 'flutter', name: 'flutter');

    test('MockRepositoryDetailSuccessはsupplementを保持する', () {
      const supplement = RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: 42,
      );
      const response = MockRepositoryDetailSuccess(supplement);

      expect(response.supplement, same(supplement));
      expect(response.gate, isNull);
    });

    test('MockRepositoryDetailFailureはexceptionを保持する', () {
      const exception = RepositoryDetailException(message: 'failed');
      final response = MockRepositoryDetailFailure(exception);

      expect(response.exception, same(exception));
      expect(response.gate, isNull);
    });

    test('MockRepositoryDetailFailureへRequestCancelledExceptionは指定できない', () {
      expect(
        () => MockRepositoryDetailFailure(const RequestCancelledException()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
