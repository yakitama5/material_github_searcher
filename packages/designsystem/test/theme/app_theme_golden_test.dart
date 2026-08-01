@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  await goldenTest(
    'AppTheme',
    fileName: 'app_theme',
    builder: () => GoldenTestGroup(
      children: [
        for (final themeColor in [AppThemeColor.app, AppThemeColor.green])
          for (final brightness in Brightness.values)
            GoldenTestScenario(
              name: '$themeColor / $brightness',
              child: _Scenario(themeColor: themeColor, brightness: brightness),
            ),
      ],
    ),
  );
}

/// Light/Dark・代表色それぞれで主要Widgetの可読性を確認するシナリオ。
class _Scenario extends StatelessWidget {
  const _Scenario({required this.themeColor, required this.brightness});

  final AppThemeColor themeColor;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final settings = ThemeSettings(themeColor: themeColor);
    final resolved = AppTheme.resolve(settings);
    final theme = brightness == Brightness.light
        ? resolved.light
        : resolved.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Material(
        color: theme.colorScheme.surface,
        child: const _MainWidgets(),
      ),
    );
  }
}

class _MainWidgets extends StatelessWidget {
  const _MainWidgets();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 320,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repository', style: context.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'yakitama5/material_github_searcher',
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () {}, child: const Text('Star')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              color: context.colorScheme.primaryContainer,
              child: Text(
                'primaryContainer上のテキスト',
                style: TextStyle(color: context.colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
