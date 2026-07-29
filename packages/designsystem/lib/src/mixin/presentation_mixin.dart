import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import '../widgets/snack_bar_manager.dart';

/// [AppException] からユーザー向け文言を組み立てるコールバック。
///
/// i18n変換はapp側の責務であるため、Presentation層は文言解決を本コールバックへ
/// 委譲し、designsystemはappへ依存しない。
typedef AppExceptionMessageBuilder = String Function(AppException exception);

/// Presentation層の操作に共通する成功・エラー通知処理を提供するMixin。
mixin PresentationMixin {
  /// [action] を実行し、結果に応じてSnackbarで通知する。
  ///
  /// - 成功し [successMessage] が指定されていれば情報Snackbarを表示する。
  /// - [RequestCancelledException] は通信キャンセルとしてユーザー通知しない。
  /// - その他の [AppException] は [errorMessageBuilder] で解決した文言を
  ///   エラーSnackbarで表示する。
  /// - 上記以外の [Exception] は `toString()` をエラーSnackbarで表示する。
  Future<void> executePresentationAction({
    required AsyncCallback action,
    required AppExceptionMessageBuilder errorMessageBuilder,
    String? successMessage,
  }) async {
    try {
      await action();
      if (successMessage != null) {
        SnackBarManager.showInfoSnackBar(successMessage);
      }
    } on RequestCancelledException {
      // 通信キャンセルは通常エラーと区別し、ユーザー通知を出さない。
    } on AppException catch (e) {
      SnackBarManager.showErrorSnackBar(errorMessageBuilder(e));
    } on Exception catch (e) {
      // AppExceptionへ変換されていない想定外の例外に対する安全網。
      // 本来はAPI層がHTTP固有例外を AppException 系へ変換する想定であり、
      // ここへ到達するのは例外的なケースのため toString() を最終手段とする。
      SnackBarManager.showErrorSnackBar(e.toString());
    }
  }
}
