import 'package:infrastructure_github/src/dto/github_search_response_dto.dart';
import 'package:test/test.dart';

Map<String, dynamic> _item({String fullName = 'flutter/flutter'}) => {
  'full_name': fullName,
  'owner': {'avatar_url': 'https://example.com/avatar.png'},
  'language': 'Dart',
  'stargazers_count': 100,
  'forks_count': 20,
  'open_issues_count': 5,
};

void main() {
  group('GithubSearchResponseDto.fromJson', () {
    test('0件のレスポンスを変換できる', () {
      final dto = GithubSearchResponseDto.fromJson({
        'total_count': 0,
        'items': <Map<String, dynamic>>[],
      });

      expect(dto.totalCount, 0);
      expect(dto.items, isEmpty);
    });

    test('複数件のレスポンスを変換できる', () {
      final dto = GithubSearchResponseDto.fromJson({
        'total_count': 2,
        'items': [
          _item(),
          _item(fullName: 'dart-lang/sdk'),
        ],
      });

      expect(dto.totalCount, 2);
      expect(dto.items, hasLength(2));
      expect(dto.items[0].name, 'flutter');
      expect(dto.items[1].name, 'sdk');
    });

    test('total_countが欠落している場合はFormatExceptionを投げる', () {
      expect(
        () => GithubSearchResponseDto.fromJson({
          'items': <Map<String, dynamic>>[],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('total_countが文字列型の場合はFormatExceptionを投げる', () {
      expect(
        () => GithubSearchResponseDto.fromJson({
          'total_count': '0',
          'items': <Map<String, dynamic>>[],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('total_countが負値の場合はFormatExceptionを投げる', () {
      expect(
        () => GithubSearchResponseDto.fromJson({
          'total_count': -1,
          'items': <Map<String, dynamic>>[],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('itemsが配列でない場合はFormatExceptionを投げる', () {
      expect(
        () => GithubSearchResponseDto.fromJson({
          'total_count': 0,
          'items': 'not-a-list',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('itemsが欠落している場合はFormatExceptionを投げる', () {
      expect(
        () => GithubSearchResponseDto.fromJson({'total_count': 0}),
        throwsA(isA<FormatException>()),
      );
    });

    test('items内の要素がMapでない場合はFormatExceptionを投げる', () {
      expect(
        () => GithubSearchResponseDto.fromJson({
          'total_count': 1,
          'items': ['not-a-map'],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
