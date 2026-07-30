import 'package:infrastructure_github/src/dto/github_search_item_dto.dart';
import 'package:test/test.dart';

Map<String, dynamic> _validJson({Object? language = 'Dart'}) => {
  'full_name': 'flutter/flutter',
  'owner': {'avatar_url': 'https://example.com/avatar.png'},
  'language': language,
  'stargazers_count': 100,
  'forks_count': 20,
  'open_issues_count': 5,
};

void main() {
  group('GithubSearchItemDto.fromJson', () {
    test('正常なJSONからDTOを生成できる', () {
      final dto = GithubSearchItemDto.fromJson(_validJson());

      expect(dto.owner, 'flutter');
      expect(dto.name, 'flutter');
      expect(dto.ownerAvatarUrl, 'https://example.com/avatar.png');
      expect(dto.language, 'Dart');
      expect(dto.stargazersCount, 100);
      expect(dto.forksCount, 20);
      expect(dto.openIssuesCount, 5);
    });

    test('languageがnullでも生成できる', () {
      final dto = GithubSearchItemDto.fromJson(_validJson(language: null));

      expect(dto.language, isNull);
    });

    test('languageキー自体が欠落していても生成できる', () {
      final json = _validJson()..remove('language');

      final dto = GithubSearchItemDto.fromJson(json);

      expect(dto.language, isNull);
    });

    test('languageが文字列でもnullでもない場合はFormatExceptionを投げる', () {
      final json = _validJson(language: 42);

      expect(
        () => GithubSearchItemDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('full_nameに"/"が含まれない場合はFormatExceptionを投げる', () {
      final json = _validJson()..['full_name'] = 'invalid-full-name';

      expect(
        () => GithubSearchItemDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('full_nameのowner部分が空の場合はFormatExceptionを投げる', () {
      final json = _validJson()..['full_name'] = '/flutter';

      expect(
        () => GithubSearchItemDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('full_nameのname部分が空の場合はFormatExceptionを投げる', () {
      final json = _validJson()..['full_name'] = 'flutter/';

      expect(
        () => GithubSearchItemDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('full_nameが欠落している場合はFormatExceptionを投げる', () {
      final json = _validJson()..remove('full_name');

      expect(
        () => GithubSearchItemDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('ownerがMapでない場合はFormatExceptionを投げる', () {
      final json = _validJson()..['owner'] = 'not-a-map';

      expect(
        () => GithubSearchItemDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('owner.avatar_urlが欠落している場合はFormatExceptionを投げる', () {
      final json = _validJson()..['owner'] = <String, dynamic>{};

      expect(
        () => GithubSearchItemDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    for (final field in [
      'stargazers_count',
      'forks_count',
      'open_issues_count',
    ]) {
      test('$fieldが欠落している場合はFormatExceptionを投げる', () {
        final json = _validJson()..remove(field);

        expect(
          () => GithubSearchItemDto.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('$fieldが文字列型の場合はFormatExceptionを投げる', () {
        final json = _validJson()..[field] = 'not-a-number';

        expect(
          () => GithubSearchItemDto.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('watchers_countが含まれていても無視される', () {
      final json = _validJson()..['watchers_count'] = 999;

      final dto = GithubSearchItemDto.fromJson(json);

      expect(dto.stargazersCount, 100);
    });

    test('toDomainでRepositorySummaryへ変換できる', () {
      final dto = GithubSearchItemDto.fromJson(_validJson());

      final summary = dto.toDomain();

      expect(summary.identity.owner, 'flutter');
      expect(summary.identity.name, 'flutter');
      expect(summary.ownerAvatarUrl, 'https://example.com/avatar.png');
      expect(summary.language, 'Dart');
      expect(summary.stargazersCount, 100);
      expect(summary.forksCount, 20);
      expect(summary.openIssuesCount, 5);
    });
  });
}
