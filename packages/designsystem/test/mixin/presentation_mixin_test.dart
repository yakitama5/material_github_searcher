import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// テスト用に [PresentationMixin] を利用するクラス。
class _TestPresenter with PresentationMixin {}

/// [SnackBarManager] のルートキーを設定した最小構成のアプリを構築する。
Widget _buildApp() {
  return MaterialApp(
    scaffoldMessengerKey: SnackBarManager.rootScaffoldMessengerKey,
    home: const Scaffold(body: SizedBox.shrink()),
  );
}

/// エラーSnackbarの文言をテスト用に固定するビルダー。
String _errorMessageBuilder(AppException exception) =>
    'エラー: ${exception.message ?? '不明'}';

void main() {
  testWidgets('成功時にsuccessMessageがあれば情報Snackbarを表示する', (tester) async {
    await tester.pumpWidget(_buildApp());
    final presenter = _TestPresenter();

    await presenter.executePresentationAction(
      action: () async {},
      errorMessageBuilder: _errorMessageBuilder,
      successMessage: '保存しました',
    );
    await tester.pump();

    expect(find.text('保存しました'), findsOneWidget);
  });

  testWidgets('成功してもsuccessMessageがなければSnackbarを表示しない', (tester) async {
    await tester.pumpWidget(_buildApp());
    final presenter = _TestPresenter();

    await presenter.executePresentationAction(
      action: () async {},
      errorMessageBuilder: _errorMessageBuilder,
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('AppException時はerrorMessageBuilderの文言をエラーSnackbarで表示する', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    final presenter = _TestPresenter();

    await presenter.executePresentationAction(
      action: () async => throw const UnknownException(message: 'boom'),
      errorMessageBuilder: _errorMessageBuilder,
    );
    await tester.pump();

    expect(find.text('エラー: boom'), findsOneWidget);
  });

  testWidgets('RequestCancelledException時はSnackbarを表示しない', (tester) async {
    await tester.pumpWidget(_buildApp());
    final presenter = _TestPresenter();

    await presenter.executePresentationAction(
      action: () async => throw const RequestCancelledException(),
      errorMessageBuilder: _errorMessageBuilder,
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('その他のException時はtoStringをエラーSnackbarで表示する', (tester) async {
    await tester.pumpWidget(_buildApp());
    final presenter = _TestPresenter();

    final exception = Exception('generic failure');
    await presenter.executePresentationAction(
      action: () async => throw exception,
      errorMessageBuilder: _errorMessageBuilder,
    );
    await tester.pump();

    expect(find.text(exception.toString()), findsOneWidget);
  });

  testWidgets('Snackbarを連続表示すると直前のSnackbarを置き換える', (tester) async {
    await tester.pumpWidget(_buildApp());
    final presenter = _TestPresenter();

    await presenter.executePresentationAction(
      action: () async {},
      errorMessageBuilder: _errorMessageBuilder,
      successMessage: '1件目',
    );
    await tester.pump();
    expect(find.text('1件目'), findsOneWidget);

    await presenter.executePresentationAction(
      action: () async {},
      errorMessageBuilder: _errorMessageBuilder,
      successMessage: '2件目',
    );
    // 置き換えアニメーションが完了するまで進める。
    await tester.pumpAndSettle();

    expect(find.text('1件目'), findsNothing);
    expect(find.text('2件目'), findsOneWidget);
  });
}
