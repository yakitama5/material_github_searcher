import '../../async/cancellation_token.dart';
import '../../error/app_exception.dart';
import 'repository_search_page.dart';
import 'repository_search_query.dart';

/// GitHub Repository検索を行うリポジトリの抽象。
///
/// 実装は`packages/infrastructure/*`が担い、`domain`はHTTPやGitHub APIの
/// 詳細に依存しない。検索に失敗した場合は[RepositorySearchException]
/// （通信キャンセルの場合は[RequestCancelledException]）を投げる契約とし、
/// Applicationはこれらの型で失敗を分類する。
// 検索の抽象は現時点でsearchのみのため、one_member_abstractsが指摘するが、
// 公開契約（Issue #73）どおりの単一メソッド抽象として意図的に維持する。
// ignore: one_member_abstracts
abstract interface class RepositorySearchRepository {
  /// [query]に一致するRepositoryを[page]・[perPage]で取得する。
  ///
  /// 1ページあたりの既定件数はApplication側で決定し、本抽象は[perPage]を
  /// 必須パラメータとして受け取るだけで既定値を持たない。[cancellationToken]
  /// がキャンセルされた場合は[RequestCancelledException]を投げる。
  Future<RepositorySearchPage> search({
    required RepositorySearchQuery query,
    required int page,
    required int perPage,
    required CancellationToken cancellationToken,
  });
}
