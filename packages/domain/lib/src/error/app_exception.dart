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
