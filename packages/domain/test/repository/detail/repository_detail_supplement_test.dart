import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('RepositoryDetailSupplement', () {
    const identity = RepositoryIdentity(owner: 'flutter', name: 'flutter');

    test('subscribersCount 0を表現できる', () {
      const supplement = RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: 0,
      );

      expect(supplement.subscribersCount, 0);
    });

    test('大きな値を表現できる', () {
      const supplement = RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: 5000,
      );

      expect(supplement.subscribersCount, 5000);
    });

    test('全フィールドが等しければ等価である', () {
      const a = RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: 42,
      );
      const b = RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: 42,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('いずれかのフィールドが異なれば等価にならない', () {
      const otherIdentity = RepositoryIdentity(owner: 'dart-lang', name: 'sdk');
      const base = RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: 42,
      );
      const differentIdentity = RepositoryDetailSupplement(
        identity: otherIdentity,
        subscribersCount: 42,
      );
      const differentSubscribersCount = RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: 999,
      );

      expect(base, isNot(equals(differentIdentity)));
      expect(base, isNot(equals(differentSubscribersCount)));
    });
  });
}
