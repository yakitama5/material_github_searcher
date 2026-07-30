import 'package:infrastructure_mock/infrastructure_mock.dart';
import 'package:test/test.dart';

void main() {
  group('RepositorySummaryFixtures', () {
    test('uniqueIdentitySamplesのidentityは互いに一意', () {
      final identities = RepositorySummaryFixtures.uniqueIdentitySamples
          .map((summary) => summary.identity)
          .toList();

      expect(identities.toSet(), hasLength(identities.length));
    });

    test('typicalはflutter・dartSdk・materialGithubSearcherを含む', () {
      expect(RepositorySummaryFixtures.typical, [
        RepositorySummaryFixtures.flutter,
        RepositorySummaryFixtures.dartSdk,
        RepositorySummaryFixtures.materialGithubSearcher,
      ]);
    });

    test('nullLanguageのlanguageはnull', () {
      expect(RepositorySummaryFixtures.nullLanguage.language, isNull);
    });

    test('longFullNameのfullNameは長い', () {
      expect(
        RepositorySummaryFixtures.longFullName.identity.fullName.length,
        greaterThan(80),
      );
    });

    test('brokenOwnerAvatarのownerAvatarUrlは.invalid TLDを使う', () {
      final uri = Uri.parse(
        RepositorySummaryFixtures.brokenOwnerAvatar.ownerAvatarUrl,
      );

      expect(uri.host, endsWith('.invalid'));
    });
  });
}
