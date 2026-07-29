import 'package:flutter/material.dart';

enum _SnackBarType { info, error }

/// ルートの `ScaffoldMessenger` を介してSnackbarを表示する管理クラス。
///
/// `MaterialApp.router` の `scaffoldMessengerKey` に [rootScaffoldMessengerKey]
/// を設定することで、画面のBuildContextに依存せずどこからでもSnackbarを表示できる。
sealed class SnackBarManager {
  SnackBarManager._();

  /// アプリのルートに設定する `ScaffoldMessenger` のキー。
  ///
  /// `MaterialApp.router` の `scaffoldMessengerKey` へ渡して利用する。
  static final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 情報通知用のSnackbarを表示する。
  static void showInfoSnackBar(String message) =>
      _showSnackBar(message, _SnackBarType.info);

  /// エラー通知用のSnackbarを表示する。
  static void showErrorSnackBar(String message) =>
      _showSnackBar(message, _SnackBarType.error);

  static void _showSnackBar(String message, _SnackBarType type) {
    final state = rootScaffoldMessengerKey.currentState;
    final context = rootScaffoldMessengerKey.currentContext;
    if (state == null || context == null) {
      return;
    }

    final cs = Theme.of(context).colorScheme;

    state
      ..hideCurrentSnackBar()
      ..showSnackBar(switch (type) {
        _SnackBarType.info => SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          showCloseIcon: true,
        ),
        _SnackBarType.error => SnackBar(
          content: Text(message, style: TextStyle(color: cs.onError)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: cs.error,
          closeIconColor: cs.onError,
          showCloseIcon: true,
        ),
      });
  }
}
