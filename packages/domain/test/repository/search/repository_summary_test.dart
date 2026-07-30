import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('RepositorySummary', () {
    const identity = RepositoryIdentity(owner: 'flutter', name: 'flutter');

    test('languageはnullを許容する', () {
      const summary = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: null,
        stargazersCount: 0,
        forksCount: 0,
        openIssuesCount: 0,
      );

      expect(summary.language, isNull);
    });

    test('count 0を表現できる', () {
      const summary = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 0,
        forksCount: 0,
        openIssuesCount: 0,
      );

      expect(summary.stargazersCount, 0);
      expect(summary.forksCount, 0);
      expect(summary.openIssuesCount, 0);
    });

    test('大きな値を表現できる', () {
      const summary = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 170000,
        forksCount: 28000,
        openIssuesCount: 15000,
      );

      expect(summary.stargazersCount, 170000);
      expect(summary.forksCount, 28000);
      expect(summary.openIssuesCount, 15000);
    });

    test('全フィールドが等しければ等価である', () {
      const a = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 1,
        forksCount: 2,
        openIssuesCount: 3,
      );
      const b = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 1,
        forksCount: 2,
        openIssuesCount: 3,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('いずれかのフィールドが異なれば等価にならない', () {
      const otherIdentity = RepositoryIdentity(owner: 'dart-lang', name: 'sdk');
      const base = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 1,
        forksCount: 2,
        openIssuesCount: 3,
      );
      const differentIdentity = RepositorySummary(
        identity: otherIdentity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 1,
        forksCount: 2,
        openIssuesCount: 3,
      );
      const differentOwnerAvatarUrl = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/other.png',
        language: 'Dart',
        stargazersCount: 1,
        forksCount: 2,
        openIssuesCount: 3,
      );
      const differentLanguage = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Kotlin',
        stargazersCount: 1,
        forksCount: 2,
        openIssuesCount: 3,
      );
      const differentStargazersCount = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 999,
        forksCount: 2,
        openIssuesCount: 3,
      );
      const differentForksCount = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 1,
        forksCount: 999,
        openIssuesCount: 3,
      );
      const differentOpenIssuesCount = RepositorySummary(
        identity: identity,
        ownerAvatarUrl: 'https://example.com/avatar.png',
        language: 'Dart',
        stargazersCount: 1,
        forksCount: 2,
        openIssuesCount: 999,
      );

      expect(base, isNot(equals(differentIdentity)));
      expect(base, isNot(equals(differentOwnerAvatarUrl)));
      expect(base, isNot(equals(differentLanguage)));
      expect(base, isNot(equals(differentStargazersCount)));
      expect(base, isNot(equals(differentForksCount)));
      expect(base, isNot(equals(differentOpenIssuesCount)));
    });
  });
}
