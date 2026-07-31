import 'package:meta/meta.dart';

import '../search/repository_identity.dart';

/// Repository検索結果一覧だけでは取得できないDetail追加情報。
///
/// 実Watcher数は検索結果の`watchers_count`ではなくDetail APIの
/// `subscribers_count`が返す値である。本型は[subscribersCount]のみを持ち、
/// [RepositoryIdentity]で識別される検索結果一覧の項目（名前・画像・言語・
/// Star・Fork・Issue）は複製しない。Presentationが検索結果一覧の要約情報と
/// 本型を合成して画面へ表示する。
@immutable
final class RepositoryDetailSupplement {
  /// Repository Detail追加情報を生成する。
  const RepositoryDetailSupplement({
    required this.identity,
    required this.subscribersCount,
  });

  /// Repositoryの識別子。
  final RepositoryIdentity identity;

  /// 実Watcher数（GitHub APIの`subscribers_count`）。
  final int subscribersCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositoryDetailSupplement &&
          runtimeType == other.runtimeType &&
          identity == other.identity &&
          subscribersCount == other.subscribersCount;

  @override
  int get hashCode => Object.hash(identity, subscribersCount);
}
