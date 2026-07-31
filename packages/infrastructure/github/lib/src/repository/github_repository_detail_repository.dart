import 'dart:async';

import 'package:dio/dio.dart';
import 'package:domain/domain.dart';

import '../dto/github_repository_detail_dto.dart';
import '../error/github_detail_exception_mapper.dart';

/// GitHub REST APIの`GET /repos/{owner}/{repo}`を叩く
/// [RepositoryDetailRepository]の実装。
///
/// [Dio]はコンストラクタ経由でのみ注入し、本クラス内では生成しない
/// （本番用インスタンスは`createGitHubDio`が担う）。
final class GitHubRepositoryDetailRepository
    implements RepositoryDetailRepository {
  /// [dio]を注入してRepositoryを生成する。
  ///
  /// 名前付きinitializing formal（`required this._dio`）はラベルがprivateになり
  /// 別ライブラリ（テスト等）から呼び出せなくなるため、公開名の引数を明示的に
  /// privateフィールドへ代入する。
  // ignore: prefer_initializing_formals
  const GitHubRepositoryDetailRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<RepositoryDetailSupplement> fetch(
    RepositoryIdentity identity, {
    required CancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();

    final cancelToken = CancelToken();
    unawaited(
      cancellationToken.whenCancelled.then((_) => cancelToken.cancel()),
    );

    final path =
        '/repos/${Uri.encodeComponent(identity.owner)}'
        '/${Uri.encodeComponent(identity.name)}';

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        // dioはJSON応答（responseType: ResponseType.json）の空ボディを
        // nullへ変換するため、response.data!のnull assertionはこの場合
        // TypeErrorを投げてしまい、on FormatExceptionで捕捉できず
        // UnknownExceptionになってしまう。FormatExceptionへ変換し直す
        // ことで、既存のハンドラでRepositoryDetailExceptionへ揃える。
        throw const FormatException(
          'GitHub repository detail response body is empty',
        );
      }
      final dto = GithubRepositoryDetailDto.fromJson(data);
      return dto.toDomain(identity);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        mapDioExceptionToDetailException(error),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RepositoryDetailException(
          message: 'Malformed GitHub repository detail response: $error',
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
}
