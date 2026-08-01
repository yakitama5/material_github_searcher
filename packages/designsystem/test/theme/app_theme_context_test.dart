import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context.colorSchemeはTheme.of(context).colorSchemeと一致する', (
    tester,
  ) async {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colorScheme),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(capturedContext.colorScheme, colorScheme);
    expect(capturedContext.textTheme, Theme.of(capturedContext).textTheme);
  });
}
