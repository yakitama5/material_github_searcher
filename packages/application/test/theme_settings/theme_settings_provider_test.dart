import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// [ThemeSettingsRepository]のテスト用Fake。
final class _FakeThemeSettingsRepository implements ThemeSettingsRepository {
  ThemeSettings loadResult = const ThemeSettings();
  AppException? loadError;
  AppException? saveError;

  int loadCallCount = 0;
  final List<ThemeSettings> savedSettings = [];

  @override
  Future<ThemeSettings> load() async {
    loadCallCount++;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return loadResult;
  }

  @override
  Future<void> save(ThemeSettings settings) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    savedSettings.add(settings);
  }
}

void main() {
  late _FakeThemeSettingsRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = _FakeThemeSettingsRepository();
    container = ProviderContainer(
      overrides: [themeSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  group('初期読込', () {
    test('Fake Repositoryの値でAsyncDataへ遷移する', () async {
      fake.loadResult = const ThemeSettings(
        uiStyle: AppUiStyle.android,
        themeMode: AppThemeMode.dark,
        themeColor: AppThemeColor.blue,
      );

      final result = await container.read(themeSettingsProvider.future);

      expect(result, fake.loadResult);
      expect(fake.loadCallCount, 1);
    });

    test('load失敗時はAsyncErrorへ遷移する', () async {
      fake.loadError = const ThemeSettingsPersistenceException();

      await expectLater(
        container.read(themeSettingsProvider.future),
        throwsA(isA<ThemeSettingsPersistenceException>()),
      );
      expect(
        container.read(themeSettingsProvider),
        isA<AsyncError<ThemeSettings>>(),
      );
    });
  });

  group('updateUiStyle', () {
    test('uiStyleを更新し、Repositoryへ保存する', () async {
      await container.read(themeSettingsProvider.future);

      await container
          .read(themeSettingsProvider.notifier)
          .updateUiStyle(AppUiStyle.ios);

      final state = container.read(themeSettingsProvider);
      expect(state.value!.uiStyle, AppUiStyle.ios);
      expect(fake.savedSettings, [state.value]);
    });
  });

  group('updateThemeMode', () {
    test('themeModeを更新し、Repositoryへ保存する', () async {
      await container.read(themeSettingsProvider.future);

      await container
          .read(themeSettingsProvider.notifier)
          .updateThemeMode(AppThemeMode.dark);

      final state = container.read(themeSettingsProvider);
      expect(state.value!.themeMode, AppThemeMode.dark);
      expect(fake.savedSettings, [state.value]);
    });
  });

  group('updateThemeColor', () {
    test('9候補すべてを更新し、Repositoryへ保存する', () async {
      await container.read(themeSettingsProvider.future);

      for (final themeColor in AppThemeColor.values) {
        await container
            .read(themeSettingsProvider.notifier)
            .updateThemeColor(themeColor);

        final state = container.read(themeSettingsProvider);
        expect(state.value!.themeColor, themeColor);
      }

      expect(
        fake.savedSettings.map((settings) => settings.themeColor),
        AppThemeColor.values,
      );
    });
  });

  group('保存失敗時のrollback', () {
    test('直前値へrollbackし、例外を呼出元へ伝播する', () async {
      final initial = await container.read(themeSettingsProvider.future);
      fake.saveError = const ThemeSettingsPersistenceException();

      await expectLater(
        container
            .read(themeSettingsProvider.notifier)
            .updateThemeColor(AppThemeColor.red),
        throwsA(isA<ThemeSettingsPersistenceException>()),
      );

      expect(container.read(themeSettingsProvider).value, initial);
      expect(fake.savedSettings, isEmpty);
    });
  });

  test('themeSettingsRepositoryProviderをoverrideで任意のFakeへ差し替えられる', () async {
    final other = _FakeThemeSettingsRepository()
      ..loadResult = const ThemeSettings(themeColor: AppThemeColor.yellow);
    final otherContainer = ProviderContainer(
      overrides: [themeSettingsRepositoryProvider.overrideWithValue(other)],
    );
    addTearDown(otherContainer.dispose);

    final result = await otherContainer.read(themeSettingsProvider.future);

    expect(result.themeColor, AppThemeColor.yellow);
  });
}
