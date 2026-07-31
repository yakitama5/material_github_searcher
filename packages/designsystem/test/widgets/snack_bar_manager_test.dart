import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp() {
  return MaterialApp(
    scaffoldMessengerKey: SnackBarManager.rootScaffoldMessengerKey,
    home: const Scaffold(body: SizedBox.shrink()),
  );
}

void main() {
  group('SnackBarManager', () {
    testWidgets('actionLabel・onAction未指定ではactionを表示しない', (tester) async {
      await tester.pumpWidget(_buildApp());

      SnackBarManager.showErrorSnackBar('失敗しました');
      await tester.pump();

      expect(find.text('失敗しました'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
    });

    testWidgets('actionLabel・onAction指定でactionを表示しタップで呼び出す', (tester) async {
      await tester.pumpWidget(_buildApp());
      var retried = false;

      SnackBarManager.showErrorSnackBar(
        '失敗しました',
        actionLabel: '再試行',
        onAction: () => retried = true,
      );
      await tester.pumpAndSettle();

      expect(find.text('再試行'), findsOneWidget);
      await tester.tap(find.text('再試行'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
