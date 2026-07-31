import 'package:flutter/material.dart';

/// 未検索案内・初回エラー等、一覧の代わりに中央表示するアイコン付き
/// メッセージ。
///
/// [retryLabel]・[onRetry]の両方が指定された場合のみretryボタンを表示する。
/// 0件時のEmpty表現は`RepositorySearchEmpty`（Lottieを使った専用Widget）を
/// 使うため、本Widgetは未検索案内・初回エラー表示にのみ使う。
class RepositorySearchMessageView extends StatelessWidget {
  /// [icon]・[message]を中央表示するメッセージ画面を生成する。
  const RepositorySearchMessageView({
    required this.icon,
    required this.message,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  /// メッセージの上に表示するアイコン。
  final IconData icon;

  /// 中央表示する説明文。
  final String message;

  /// retryボタンのラベル。[onRetry]と両方指定された場合のみ表示する。
  final String? retryLabel;

  /// retryボタンタップ時のcallback。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final retryLabel = this.retryLabel;
    final onRetry = this.onRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (retryLabel != null && onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('repositorySearchRetryButton'),
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
