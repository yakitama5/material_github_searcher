import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:domain/domain.dart';

import '../dto/github_search_response_dto.dart';
import '../error/github_exception_mapper.dart';

/// GitHub REST APIの`GET /search/repositories`を叩く
/// [RepositorySearchRepository]の実装。
///
/// [Dio]はコンストラクタ経由でのみ注入し、本クラス内では生成しない
/// （本番用インスタンスは`createGitHubDio`が担う）。
final class GitHubRepositorySearchRepository
    implements RepositorySearchRepository {
  /// [dio]を注入してRepositoryを生成する。
  ///
  /// 名前付きinitializing formal（`required this._dio`）はラベルがprivateになり
  /// 別ライブラリ（テスト等）から呼び出せなくなるため、公開名の引数を明示的に
  /// privateフィールドへ代入する。
  // ignore: prefer_initializing_formals
  const GitHubRepositorySearchRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _searchPath = '/search/repositories';

  /// GitHub Searchが返す検索結果の上限件数。
  static const _maxResultWindow = 1000;

  @override
  Future<RepositorySearchPage> search({
    required RepositorySearchQuery query,
    required int page,
    required int perPage,
    required CancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();

    final cancelToken = CancelToken();
    unawaited(
      cancellationToken.whenCancelled.then((_) => cancelToken.cancel()),
    );

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _searchPath,
        queryParameters: {
          'q': query.value,
          'page': page,
          'per_page': perPage,
        },
        cancelToken: cancelToken,
      );
      final dto = GithubSearchResponseDto.fromJson(response.data!);
      return _toDomainPage(dto: dto, page: page, perPage: perPage);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        mapDioExceptionToAppException(error),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RepositorySearchException(
          message: 'Malformed GitHub search response: $error',
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        UnknownException(message: '$error'),
        stackTrace,
      );
    }
  }

  RepositorySearchPage _toDomainPage({
    required GithubSearchResponseDto dto,
    required int page,
    required int perPage,
  }) {
    final items = dto.items.map((item) => item.toDomain()).toList();
    final fetchedSoFar = page * perPage;
    final effectiveLimit = min(dto.totalCount, _maxResultWindow);
    final hasMore = items.isNotEmpty && fetchedSoFar < effectiveLimit;
    return RepositorySearchPage(
      items: items,
      totalCount: dto.totalCount,
      nextPage: hasMore ? page + 1 : null,
      hasMore: hasMore,
    );
  }
}
