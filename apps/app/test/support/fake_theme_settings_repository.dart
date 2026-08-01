import 'dart:async';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/misc.dart';

/// [themeSettingsRepositoryProvider]を[FakeThemeSettingsRepository]へ結線する
/// override。
Override themeSettingsTestOverride({FakeThemeSettingsRepository? repository}) =>
    themeSettingsRepositoryProvider.overrideWith(
      (ref) => repository ?? FakeThemeSettingsRepository(),
    );

/// [ThemeSettingsRepository]のテスト用Fake。
///
/// `infrastructure_mock`の`MockThemeSettingsRepository`と異なり、
/// [loadError]・[loadGate]でload失敗・load中断（loading状態の固定）を
/// 再現できるようにし、root（`MyApp`）が読込中・失敗時も既定Themeで
/// 起動することを検証するテストから使う。
final class FakeThemeSettingsRepository implements ThemeSettingsRepository {
  /// 初期設定[initialSettings]でFake Repositoryを生成する。
  FakeThemeSettingsRepository({ThemeSettings? initialSettings})
    : _settings = initialSettings ?? const ThemeSettings();

  ThemeSettings _settings;

  /// 非`null`の場合、[load]はこの例外をthrowする。
  AppException? loadError;

  /// 非`null`の場合、[load]は本Completerが完了するまで待機する。
  ///
  /// loading状態を任意のタイミングまで固定し、その間rootが既定Themeで
  /// 表示されることを検証するテストで使う。
  Completer<void>? loadGate;

  @override
  Future<ThemeSettings> load() async {
    final gate = loadGate;
    if (gate != null) {
      await gate.future;
    }
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return _settings;
  }

  @override
  Future<void> save(ThemeSettings settings) async {
    _settings = settings;
  }
}
