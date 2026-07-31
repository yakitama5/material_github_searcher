/// アプリケーション全体で扱う例外の基底型。
///
/// 各レイヤーはHTTP固有例外などを本型へ変換し、Presentation層は
/// [message] を起点にユーザー向け文言を解決する。ユーザー向け文言の
/// i18n変換はapp側から注入するため、本型自体は多言語化に依存しない。
///
/// `sealed` により、基底型と全サブタイプは本ライブラリへ集約される。個別の
/// 業務・通信例外の分類はドメインの契約の一部であるため、本型系はdomainが
/// 所有する。
sealed class AppException implements Exception {
  /// 例外を生成する。
  ///
  /// [message] は開発者向けの補足情報であり、そのままユーザーへ提示する
  /// 前提を持たない。
  const AppException({this.message});

  /// 例外の補足メッセージ。持たない場合は `null`。
  final String? message;
}

/// 通信キャンセルを表す例外。
///
/// ユーザー操作や後続リクエストによるキャンセルは通常のエラーと区別し、
/// ユーザーへの通知（Snackbar等）を出さない。
final class RequestCancelledException extends AppException {
  /// 通信キャンセル例外を生成する。
  const RequestCancelledException();
}

/// 分類できない想定外のエラーを表す例外。
///
/// 具体的な例外種別が定まらない場合の受け皿として用いる。個別のAPI例外の
/// 詳細分類は後続で `AppException` のサブタイプとして追加する。
final class UnknownException extends AppException {
  /// 想定外エラー例外を生成する。
  const UnknownException({super.message});
}

/// Repository検索の失敗を表す例外。
///
/// HTTP・Rate Limitなど個別の失敗要因の分類はInfrastructure実装の詳細であり
/// 本Issueの対象外とする。Applicationが「Repository検索由来の失敗」と
/// 「その他の失敗（[UnknownException]）」を区別できるよう、まずは汎用の
/// 契約として1種類だけ用意する。要因ごとの分類が必要になった時点で、
/// `UnknownException`と同様に`AppException`の別サブタイプとして追加する。
final class RepositorySearchException extends AppException {
  /// Repository検索の失敗例外を生成する。
  const RepositorySearchException({super.message});
}

/// Repository Detail取得の失敗を表す例外。
///
/// [RepositorySearchException]と同様、要因（Rate Limit・404・その他HTTP・
/// decode等）ごとの分類はInfrastructure実装の詳細であり本Issueの対象外と
/// する。Applicationが「Repository Detail取得由来の失敗」と区別できるよう、
/// まずは汎用の契約として1種類だけ用意する。
final class RepositoryDetailException extends AppException {
  /// Repository Detail取得の失敗例外を生成する。
  const RepositoryDetailException({super.message});
}

/// 検索履歴の永続化（load・save）の失敗を表す例外。
///
/// [RepositorySearchException]と同様、要因（Storage I/Oエラー等）ごとの分類は
/// Infrastructure実装の詳細であり本Issueの対象外とする。Applicationが
/// 「検索履歴の永続化由来の失敗」と区別できるよう、まずは汎用の契約として
/// 1種類だけ用意する。
final class SearchHistoryPersistenceException extends AppException {
  /// 検索履歴の永続化失敗例外を生成する。
  const SearchHistoryPersistenceException({super.message});
}
