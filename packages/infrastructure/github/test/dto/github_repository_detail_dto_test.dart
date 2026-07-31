import 'package:domain/domain.dart';
import 'package:infrastructure_github/src/dto/github_repository_detail_dto.dart';
import 'package:test/test.dart';

Map<String, dynamic> _validJson({Object? subscribersCount = 42}) => {
  'subscribers_count': subscribersCount,
  // watchers_countはDetail DTOが読まないことを確認するため、意図的に
  // subscribers_countと異なる値を含めておく。
  'watchers_count': 999999,
};

void main() {
  group('GithubRepositoryDetailDto.fromJson', () {
    test('正常なJSONからDTOを生成できる', () {
      final dto = GithubRepositoryDetailDto.fromJson(_validJson());

      expect(dto.subscribersCount, 42);
    });

    test('subscribers_countが0でも生成できる', () {
      final dto = GithubRepositoryDetailDto.fromJson(
        _validJson(subscribersCount: 0),
      );

      expect(dto.subscribersCount, 0);
    });

    test('subscribers_countが欠落している場合はFormatExceptionを投げる', () {
      final json = _validJson()..remove('subscribers_count');

      expect(
        () => GithubRepositoryDetailDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('subscribers_countがnullの場合はFormatExceptionを投げる', () {
      final json = _validJson(subscribersCount: null);

      expect(
        () => GithubRepositoryDetailDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('subscribers_countが文字列型の場合はFormatExceptionを投げる', () {
      final json = _validJson(subscribersCount: 'not-a-number');

      expect(
        () => GithubRepositoryDetailDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('watchers_countが含まれていても無視される', () {
      final dto = GithubRepositoryDetailDto.fromJson(_validJson());

      expect(dto.subscribersCount, isNot(999999));
      expect(dto.subscribersCount, 42);
    });

    test('toDomainでRepositoryDetailSupplementへ変換できる', () {
      const identity = RepositoryIdentity(owner: 'flutter', name: 'flutter');
      final dto = GithubRepositoryDetailDto.fromJson(_validJson());

      final supplement = dto.toDomain(identity);

      expect(supplement.identity, identity);
      expect(supplement.subscribersCount, 42);
    });
  });
}
