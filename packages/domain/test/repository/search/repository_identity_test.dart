import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('RepositoryIdentity', () {
    test('fullNameはowner/name形式になる', () {
      const identity = RepositoryIdentity(owner: 'flutter', name: 'flutter');

      expect(identity.fullName, 'flutter/flutter');
    });

    test('owner・nameが等しければ等価である', () {
      const a = RepositoryIdentity(owner: 'flutter', name: 'flutter');
      const b = RepositoryIdentity(owner: 'flutter', name: 'flutter');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ownerまたはnameが異なれば等価にならない', () {
      const a = RepositoryIdentity(owner: 'flutter', name: 'flutter');
      const b = RepositoryIdentity(owner: 'flutter', name: 'engine');
      const c = RepositoryIdentity(owner: 'dart-lang', name: 'flutter');

      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
    });
  });
}
