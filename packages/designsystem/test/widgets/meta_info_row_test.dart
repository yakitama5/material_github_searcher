@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  await goldenTest(
    'MetaInfoRow',
    fileName: 'meta_info_row',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: '標準的なラベルと値を表示する',
          child: const _Scenario(
            child: MetaInfoRow(
              icon: Icons.language,
              iconColor: Colors.blue,
              label: '言語',
              value: 'Dart',
            ),
          ),
        ),
        GoldenTestScenario(
          name: '異なるアイコン色のラベルと値を表示する',
          child: const _Scenario(
            child: MetaInfoRow(
              icon: Icons.star,
              iconColor: Colors.amber,
              label: 'スター',
              value: '143K',
            ),
          ),
        ),
        GoldenTestScenario(
          name: '長いラベルと値は末尾を省略して表示する',
          child: const _Scenario(
            child: MetaInfoRow(
              icon: Icons.info_outline,
              iconColor: Colors.teal,
              label: '非常に長いラベル文字列でオーバーフローの挙動を確認する行',
              value: '非常に長い値文字列でオーバーフローの挙動を確認する',
            ),
          ),
        ),
      ],
    ),
  );
}

/// Golden Testのシナリオ表示領域(幅・高さ・locale)を固定するラッパー。
class _Scenario extends StatelessWidget {
  const _Scenario({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ja')],
      home: Material(
        child: SizedBox(
          width: 300,
          height: 48,
          child: Padding(padding: const EdgeInsets.all(8), child: child),
        ),
      ),
    );
  }
}
