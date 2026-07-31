import 'package:domain/domain.dart';

import 'dto_field_reader.dart';

/// `GET /repos/{owner}/{repo}`のレスポンスボディのDTO。
///
/// `subscribers_count`のみを読む。`RepositorySummary`が持つ項目
/// （`full_name`・`language`・`stargazers_count`等）は、Summaryの複製を
/// 避けるため本DTOでは読み取らない。
final class GithubRepositoryDetailDto {
  /// Detail DTOを生成する。
  const GithubRepositoryDetailDto({required this.subscribersCount});

  /// `json`は`GET /repos/{owner}/{repo}`のレスポンスボディ全体
  /// （トップレベルMap）。
  ///
  /// `subscribers_count`の欠落・型不正は[FormatException]を投げる
  /// (呼び出し側のRepository実装で`RepositoryDetailException`へ変換する)。
  factory GithubRepositoryDetailDto.fromJson(Map<String, dynamic> json) {
    return GithubRepositoryDetailDto(
      subscribersCount: requireField<int>(json, 'subscribers_count'),
    );
  }

  /// 実Watcher数。
  final int subscribersCount;

  /// domainの[RepositoryDetailSupplement]へ変換する。
  ///
  /// [identity]はレスポンスからdecodeせず、呼び出し元が持つ値をそのまま
  /// 使う（レスポンスの`full_name`等は読み取らない）。
  RepositoryDetailSupplement toDomain(RepositoryIdentity identity) =>
      RepositoryDetailSupplement(
        identity: identity,
        subscribersCount: subscribersCount,
      );
}
