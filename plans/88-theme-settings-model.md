# Issue #88 ThemeSettingsモデルとRiverpod SSOTを定義する

Issue: <https://github.com/yakitama5/material_github_searcher/issues/88>

## 目的

UI Style・ThemeMode・ThemeColorを1つの`ThemeSettings`として表現し、手書き
Riverpod Providerを唯一の状態源（SSOT）として管理する。永続化実装・設定画面・
root themeの購読は後続Issueに引き継ぐ。

## 前提・依存

`#68`（手書きRiverpod ProviderとComposition Root基盤）はmerge済み。
`docs/technical-decisions.md`は編集しない。ViewModel・Riverpod generatorは
使用しない。

## 方針

### Domain（`packages/domain`）

```text
lib/src/theme_settings/
├── app_ui_style.dart
├── app_theme_mode.dart
├── app_theme_color.dart
├── theme_settings.dart
└── theme_settings_repository.dart
```

enumは`RepositorySearchStatus`と同様、各値へ日本語docコメントを付す。

```dart
enum AppUiStyle { system, android, ios }
enum AppThemeMode { system, light, dark }
enum AppThemeColor { app, dynamic, blue, purple, pink, red, orange, yellow, green }
```

`ThemeSettings`は値オブジェクトのため、状態遷移classである
`SearchHistoryState`（named constructorで遷移を表現）ではなく、
`RepositoryIdentity`同様の`@immutable final class` + 手書き`==`/`hashCode`と
する。ただしIssueのテスト要件が`copyWith`を明示するため、値の一部だけを
差し替える`copyWith`を追加する（既存Domainモデルに前例はないが、値
オブジェクトとしては素直な操作であり、`SearchHistoryState`のような多重の
状態遷移契約は持たないため導入して問題ない）。

```dart
@immutable
final class ThemeSettings {
  const ThemeSettings({
    this.uiStyle = AppUiStyle.system,
    this.themeMode = AppThemeMode.system,
    this.themeColor = AppThemeColor.app,
  });

  final AppUiStyle uiStyle;
  final AppThemeMode themeMode;
  final AppThemeColor themeColor;

  ThemeSettings copyWith({
    AppUiStyle? uiStyle,
    AppThemeMode? themeMode,
    AppThemeColor? themeColor,
  }) => ThemeSettings(
    uiStyle: uiStyle ?? this.uiStyle,
    themeMode: themeMode ?? this.themeMode,
    themeColor: themeColor ?? this.themeColor,
  );

  // == / hashCode は3フィールドの比較
}
```

`ThemeSettingsRepository`は`SearchHistoryRepository`と同型（load/save）。
永続化失敗は既存の`AppException`サブタイプとして`ThemeSettingsPersistenceException`
を追加する（`SearchHistoryPersistenceException`と同じ理由づけ：要因分類は
Infrastructure実装の詳細であり本Issue対象外）。

```dart
abstract interface class ThemeSettingsRepository {
  Future<ThemeSettings> load();
  Future<void> save(ThemeSettings settings);
}
```

`domain.dart`へ5ファイル分のexportを追加する。

### Application（`packages/application`）

```text
lib/src/theme_settings/
├── theme_settings_repository_provider.dart  # 注入Provider（未結線でthrow）
└── theme_settings_provider.dart             # AsyncNotifierProvider
```

注入Providerは`repositoryDetailRepositoryProvider`と同型。

```dart
final themeSettingsRepositoryProvider = Provider<ThemeSettingsRepository>(
  (ref) => throw UnimplementedError(
    'themeSettingsRepositoryProvider must be overridden. '
    'Apply createProductionOverrides() or createMockOverrides().',
  ),
);
```

Issueの「初期化はloading→dataまたはloading→error」という文言は`AsyncValue`の
意味論そのものであり、`ThemeSettings`は複数の部分状態（追加取得・エラー種別の
同時保持等）を必要としないため、`SearchHistoryState`型の独自Status enumでは
なく素の`AsyncNotifier<ThemeSettings>`を採用する。アプリ全体のSSOTのため
`autoDispose`は使わない（`searchHistoryControllerProvider`と同じ理由）。

```dart
final themeSettingsProvider =
    AsyncNotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
      ThemeSettingsNotifier.new,
      retry: (_, _) => null,
    );

final class ThemeSettingsNotifier extends AsyncNotifier<ThemeSettings> {
  @override
  Future<ThemeSettings> build() =>
      ref.read(themeSettingsRepositoryProvider).load();
```

`#85`（`repositoryDetailProvider`）と同じ理由で`retry: (_, _) => null`を明示
する。RiverpodはFutureProvider/AsyncNotifierProviderのbuild失敗時、既定で
`ProviderContainer.defaultRetry`による指数バックオフの自動retryを行う
（`Error`のサブクラス以外の例外が対象）。`ThemeSettingsPersistenceException`
は`Error`ではないため無効化しないと、load失敗時に「安定したAsyncError」に
ならず自動retryで再試行し続けてしまう（`#85`で実際に踏んだ不具合と同型）。

  Future<void> updateUiStyle(AppUiStyle uiStyle) =>
      _update((current) => current.copyWith(uiStyle: uiStyle));

  Future<void> updateThemeMode(AppThemeMode themeMode) =>
      _update((current) => current.copyWith(themeMode: themeMode));

  Future<void> updateThemeColor(AppThemeColor themeColor) =>
      _update((current) => current.copyWith(themeColor: themeColor));

  Future<void> _update(ThemeSettings Function(ThemeSettings) transform) async {
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
```

- 更新は現在値から新しい`ThemeSettings`を生成し、楽観的にstateを更新してから
  保存する。保存に失敗した場合は直前値へrollbackし、例外を呼出元へ
  そのままrethrowする（Issueの契約通り）。
- enumの永続化文字列は`.name`がenum名と同じlowercase値になるため、
  Infrastructure側の実装（後続Issue）でそのまま利用できる。本Issueでの
  追加対応は不要。
- `application.dart`へ両ファイルのexportを追加する。

### dependency_override（`packages/dependency_override`）

Issueの「未結線Repository Providerは明示的に失敗し、Testでは
FakeへOverrideする」という指示通り、`themeSettingsRepositoryProvider`は
`createProductionOverrides()`・`createMockOverrides()`のどちらにも
**追加しない**。SharedPreferences実装（永続化）は本Issueの対象外であり、
かつ`themeSettingsProvider`を購読するUI・root theme連携も後続Issueのため、
現時点で結線すると実体のない仮実装を先回りして作ることになる。

## テスト

### Domain（`packages/domain/test/theme_settings/`）

- `ThemeSettings`の既定値（`uiStyle=system, themeMode=system, themeColor=app`）。
- 等価性（同じ値同士は`==`、異なる値は非`==`）。
- `copyWith`（一部フィールドのみ変更・無指定時は元の値を維持）。
- 3 enumそれぞれの全候補値が存在すること。

### Application（`packages/application/test/theme_settings/`）

`repository_detail_provider_test.dart`と同様、`ProviderContainer`+
テストファイル内Fake（`ThemeSettingsRepository implements`）で検証する。

- Fake Repositoryからの初期読込で`AsyncData(初期値)`へ遷移する。
- `load()`が失敗した場合`AsyncError`へ遷移する。
- `updateUiStyle`・`updateThemeMode`・`updateThemeColor`それぞれが値を更新し
  Repositoryへ保存されること。
- 保存失敗時に直前値へrollbackし、例外が呼出元へ伝播すること。
- `themeSettingsRepositoryProvider`のoverrideで任意のFakeへ差し替えられること。

## 実装手順

1. `packages/domain`: 3 enum→`ThemeSettings`→`ThemeSettingsRepository`→
   `ThemeSettingsPersistenceException`（`app_exception.dart`へ追加）→
   `domain.dart`のexport更新。
2. `packages/domain/test`: 上記テストケースを追加。
3. `packages/application`: 注入Provider→`themeSettingsProvider`→
   `application.dart`のexport更新。
4. `packages/application/test`: 上記テストケースを追加。
5. 全体検証（下記）を実行する。

## テスト観点（全体検証）

- `cd packages/domain && mise exec -- flutter test`が通る。
- `cd packages/application && mise exec -- flutter test`が通る。
- `mise exec -- dart run tools/check_package_dependencies.dart`が通る
  （DomainがFlutter/Riverpod/SharedPreferencesへ依存しないことの検証）。
- `mise exec -- dart format --output=none --set-exit-if-changed apps packages
  test tools`、`mise exec -- dart analyze --fatal-infos`、
  `mise exec -- dart tools/sync_sdk_versions.dart --check`が通る。

## 対象外

- SharedPreferences実装。
- ThemeData生成・Dynamic Color。
- 設定画面。
- `themeSettingsRepositoryProvider`のdependency_overrideへの結線。
- `docs/technical-decisions.md`の編集。

## 後続への引き継ぎ（追記）

セルフレビューで、`ThemeSettingsNotifier._update`が`SearchHistoryController`の
ような世代番号によるstale防御を持たないため、複数の`updateX`呼出しを
直列化せず並行実行すると、先発呼出しのrollbackが後発の成功済み保存を
巻き戻し得る点を確認した。本Issueは単一操作の契約・テストのみを要求し
現時点で`themeSettingsProvider`を購読するUIは存在しないため、意図的に
「呼出し元が直列化する」前提（`_update`のdocコメントに明記）としてスコープ外
とした。設定画面（後続Issue）の実装者は、1つの`updateX`のawait完了を待って
から次を呼ぶ、または画面側で多重送信を防止すること。
