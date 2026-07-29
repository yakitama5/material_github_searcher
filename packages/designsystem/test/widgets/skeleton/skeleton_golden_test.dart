@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:designsystem/designsystem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  await goldenTest(
    'Skeleton',
    fileName: 'skeleton',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 600)),
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'lightの固定animation位相',
          child: const _Scenario(
            brightness: Brightness.light,
            child: _SkeletonContent(),
          ),
        ),
        GoldenTestScenario(
          name: 'darkの固定animation位相',
          child: const _Scenario(
            brightness: Brightness.dark,
            child: _SkeletonContent(),
          ),
        ),
      ],
    ),
  );
}

class _Scenario extends StatelessWidget {
  const _Scenario({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

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
      home: Material(
        child: SizedBox(
          width: 240,
          height: 128,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

class _SkeletonContent extends StatelessWidget {
  const _SkeletonContent();

  @override
  Widget build(BuildContext context) {
    return const SkeletonScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonCircle(diameter: 40),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 132),
                    SizedBox(height: 8),
                    SkeletonText(width: 88),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SkeletonBox(
            width: double.infinity,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
      ),
    );
  }
}
