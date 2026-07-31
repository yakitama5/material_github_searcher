import '../../async/cancellation_token.dart';
import '../../error/app_exception.dart';
import '../search/repository_identity.dart';
import 'repository_detail_supplement.dart';

/// GitHub RepositoryのDetail追加情報を取得するリポジトリの抽象。
///
/// 実装は`packages/infrastructure/*`が担い、`domain`はHTTPやGitHub APIの
/// 詳細に依存しない。取得に失敗した場合は[RepositoryDetailException]
/// （通信キャンセルの場合は[RequestCancelledException]）を投げる契約とし、
/// Applicationはこれらの型で失敗を分類する。
// 検索の抽象（RepositorySearchRepository）と同様、現時点でfetchのみのため
// one_member_abstractsが指摘するが、公開契約（Issue #84）どおりの単一
// メソッド抽象として意図的に維持する。
// ignore: one_member_abstracts
abstract interface class RepositoryDetailRepository {
  /// [identity]が示すRepositoryのDetail追加情報を取得する。
  ///
  /// [cancellationToken]がキャンセルされた場合は[RequestCancelledException]
  /// を投げる。
  Future<RepositoryDetailSupplement> fetch(
    RepositoryIdentity identity, {
    required CancellationToken cancellationToken,
  });
}
