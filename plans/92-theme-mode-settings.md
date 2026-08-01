# Issue #92 設定画面でThemeModeを切り替えられるようにする

Issue: <https://github.com/yakitama5/material_github_searcher/issues/92>

## 前提・依存

`#91`（`#128`でmerge済み: 設定画面とOS UI Style切り替え）と同型のUIを、
`ThemeMode`（System/Light/Dark）向けに追加する。

調査の結果、下記は`#125`〜`#127`で既に実装済みであり、本Issueでは**変更しない**。

- `packages/domain`: `AppThemeMode { system, light, dark }`・
  `ThemeSettings.themeMode`・`copyWith`。
- `packages/application`: `ThemeSettingsNotifier.updateThemeMode`
  （楽観的更新→保存失敗時rollback→rethrow。`_update`は呼出し元の直列化が前提）。
- `packages/infrastructure/shared_preferences`: `theme_settings.theme_mode`
  キーでの個別永続化・不正値時fallback。
- `packages/designsystem`: `AppTheme.resolve`が`AppThemeMode`→`ThemeMode`へ
  1対1変換済み。
- `apps/app/lib/main.dart`: `MaterialApp.router(theme:, darkTheme:,
  themeMode:)`で`themeSettingsProvider`をwatchしrootへ即時反映済み。
  `ThemeMode.system`はFlutter標準機構が端末brightnessへ自動追従するため、
  追加の`MediaQuery.platformBrightnessOf`監視コードは不要。

したがって本Issueのスコープは`#91`と同じく**UI（画面・route・i18n・ラベル変換・
テスト）のみ**。`docs/technical-decisions.md`は編集しない。

## 対応内容

### route（`apps/app/lib/src/router/`）

- `app_routes.dart`: `settingsThemeModeRelativePath = 'theme-mode'`・
  `settingsThemeModeRouteName = 'settingsThemeMode'`を追加。
- `go_router_provider.dart`: `settingsPath`配下の`routes`に、
  `settingsUiStyleRelativePath`の`GoRoute`と兄弟として
  `SettingsThemeModeScreen`への`GoRoute`を追加。

### 画面（`apps/app/lib/src/settings/`）

- `theme_mode_label.dart`（新規）: `ui_style_label.dart`と同型で
  `String themeModeLabel(AppThemeMode mode, Translations i18n)`。
- `pages/settings_screen.dart`: ThemeMode行の`ListTile`を追加。
  現在値は`ref.watch(themeSettingsProvider).value?.themeMode ??
  AppThemeMode.system`、`onTap`で`context.pushNamed(settingsThemeModeRouteName)`。
  Widget Test用に`settingsThemeModeListTileKey`を追加。
- `pages/settings_theme_mode_screen.dart`（新規）:
  `settings_ui_style_screen.dart`をそのまま踏襲。
  `ConsumerStatefulWidget` + `PresentationMixin`、`RadioGroup<AppThemeMode>` +
  `RadioListTile`、`_saving`フラグで多重tap防止、
  `ref.read(themeSettingsProvider.notifier).updateThemeMode(mode)`を
  `executePresentationAction`経由で呼び出し、失敗時は`i18n.settings.saveError`
  （既存共通キー、新規キー不要）をSnackbar表示。

### i18n（`apps/app/assets/i18n/settings_{ja,en}.i18n.yaml`）

```yaml
themeModeTitle: テーマモード / Theme Mode
themeModeSystem: システム / System
themeModeLight: ライト / Light
themeModeDark: ダーク / Dark
```

`build_runner`でslang生成物（`strings.g.dart`等）を再生成する。

## テスト

- `apps/app/test/settings/pages/settings_theme_mode_screen_test.dart`（新規、
  `settings_ui_style_screen_test.dart`を踏襲）:
  - 3候補+現在値表示、Semanticsでの選択状態判別。
  - 選択操作で`themeSettingsProvider`へ反映され、`Theme.of(context).brightness`
    が即時に切り替わること（`app_theme_root_test.dart`の即時反映patternを参考）。
  - Systemを選択した状態で`tester.platformDispatcher.platformBrightnessTestValue`
    を切り替え、`Theme.of(context).brightness`が追従すること
    （実装コード変更なしでFlutter標準機構により満たされる想定。テストで契約化）。
  - 保存失敗時のrollback + Snackbar（`FakeThemeSettingsRepository.saveError`）。
  - 選択後もUiStyle/ThemeColorが保持されること（`copyWith`経由の確認）。
  - 日本語・英語、402/744/1024幅。
- `apps/app/test/settings/pages/settings_screen_test.dart`: ThemeMode行の
  現在値表示・遷移・戻るを追加。
- `apps/app/test/router/go_router_provider_test.dart`:
  `/settings/theme-mode`直アクセスを追加。

## 実装手順

1. i18n（ja/en）追加 → slang再生成。
2. route定数・`GoRoute`追加。
3. `theme_mode_label.dart`追加。
4. `SettingsThemeModeScreen`実装（`SettingsUiStyleScreen`を複製・置換）。
5. `SettingsScreen`へThemeMode行追加。
6. テスト追加（上記4ファイル）。
7. `code-review`スキルでセルフレビュー→修正。
8. 全体検証（下記コマンド）。
9. Android実機・iOS Simulatorで目視確認（System brightness追従含む）。

## テスト観点（全体検証）

```sh
cd apps/app
mise exec -- flutter analyze
mise exec -- flutter test --exclude-tags=golden
mise exec -- dart format --output=none --set-exit-if-changed .
```

リポジトリルートで`dart tools/check_package_dependencies.dart`・
`dart tools/sync_sdk_versions.dart --check`も実行する。

## 対象外

- ThemeColor。
- Dynamic Color解決の再実装。
- OS自体の外観設定変更。
- `docs/technical-decisions.md`の編集。
- ドメイン・アプリケーション・永続化層・`AppTheme.resolve`・`MyApp`の変更
  （既存実装をそのまま利用）。
