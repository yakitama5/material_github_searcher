import 'package:domain/domain.dart';
import 'package:riverpod/riverpod.dart';

import 'theme_settings_repository_provider.dart';

/// テーマ設定のSingle Source of Truthを管理するProvider。
///
/// 公開状態は本Provider1つとし、UI Style・ThemeMode・ThemeColorを個別の
/// Providerへ複製しない。アプリ全体で共有するSSOTのため`autoDispose`は使わず、
/// 画面遷移で設定を失わない。
final themeSettingsProvider =
    AsyncNotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
      ThemeSettingsNotifier.new,
      // `#85`のrepositoryDetailProviderと同じ理由でRiverpod既定の自動retryを
      // 無効化する。build失敗時、既定では`ProviderContainer.defaultRetry`が
      // Errorのサブクラス以外の例外（本Providerでは
      // ThemeSettingsPersistenceException）へ指数バックオフの自動retryを行い、
      // loadingへ戻ってしまうため、安定したAsyncErrorへ遷移させるには
      // 明示的に無効化する必要がある。
      retry: (_, _) => null,
    );

/// [themeSettingsProvider]の状態を管理する[AsyncNotifier]。
final class ThemeSettingsNotifier extends AsyncNotifier<ThemeSettings> {
  @override
  Future<ThemeSettings> build() =>
      ref.read(themeSettingsRepositoryProvider).load();

  /// [uiStyle]へ更新する。
  Future<void> updateUiStyle(AppUiStyle uiStyle) =>
      _update((current) => current.copyWith(uiStyle: uiStyle));

  /// [themeMode]へ更新する。
  Future<void> updateThemeMode(AppThemeMode themeMode) =>
      _update((current) => current.copyWith(themeMode: themeMode));

  /// [themeColor]へ更新する。
  Future<void> updateThemeColor(AppThemeColor themeColor) =>
      _update((current) => current.copyWith(themeColor: themeColor));

  /// 現在値へ[transform]を適用した新しい[ThemeSettings]を楽観的にstateへ
  /// 反映してから永続化する。
  ///
  /// 永続化に失敗した場合は直前値へrollbackし、例外を呼出元へそのまま
  /// 伝播する。呼出しは[build]成功後（`state`が[AsyncData]）を前提とし、
  /// 呼出し同士の直列化（前の呼出しのawait完了を待ってから次を呼ぶこと）
  /// は呼出し元の責務とする。前提を満たさない呼出し（load未完了・失敗時の
  /// 呼出しや、rollback未完了での多重呼出し）は対象外（`SearchHistoryController`
  /// が持つ世代番号によるstale防御は本Notifierでは採用しない。設定画面は
  /// 単純な単一操作UIを想定するため、後続のUI実装がこの前提を守る）。
  Future<void> _update(
    ThemeSettings Function(ThemeSettings current) transform,
  ) async {
    final previous = state.requireValue;
    final next = transform(previous);
    state = AsyncData(next);
    try {
      await ref.read(themeSettingsRepositoryProvider).save(next);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
