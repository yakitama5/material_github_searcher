import 'package:designsystem/designsystem.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppThemeColorSeed', () {
    final expectedSeeds = {
      AppThemeColor.app: const Color(0xFF0969DA),
      AppThemeColor.blue: const Color(0xFF2196F3),
      AppThemeColor.purple: const Color(0xFF9C27B0),
      AppThemeColor.pink: const Color(0xFFE91E63),
      AppThemeColor.red: const Color(0xFFF44336),
      AppThemeColor.orange: const Color(0xFFFF9800),
      AppThemeColor.yellow: const Color(0xFFFFEB3B),
      AppThemeColor.green: const Color(0xFF4CAF50),
    };

    for (final entry in expectedSeeds.entries) {
      test('${entry.key}は固定Seed ${entry.value}を返す', () {
        expect(entry.key.seed, entry.value);
      });
    }

    test('dynamicは固定Seedを持たずnullを返す', () {
      expect(AppThemeColor.dynamic.seed, isNull);
    });
  });
}
