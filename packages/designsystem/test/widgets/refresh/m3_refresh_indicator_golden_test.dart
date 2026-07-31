@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  await goldenTest(
    'M3RefreshIndicator',
    fileName: 'm3_refresh_indicator',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 400)),
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'lightの固定animation位相',
          child: const _Scenario(brightness: Brightness.light),
        ),
        GoldenTestScenario(
          name: 'darkの固定animation位相',
          child: const _Scenario(brightness: Brightness.dark),
        ),
        GoldenTestScenario(
          name: 'Reduce Motion',
          child: const _Scenario(
            brightness: Brightness.light,
            disableAnimations: true,
          ),
        ),
      ],
    ),
  );
}

class _Scenario extends StatelessWidget {
  const _Scenario({required this.brightness, this.disableAnimations = false});

  final Brightness brightness;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: brightness,
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Material(
          child: SizedBox(
            width: 240,
            height: 160,
            child: M3RefreshIndicator(
              refreshing: true,
              onRefresh: () async {},
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: 1,
                itemBuilder: (context, index) => const SizedBox(height: 4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
