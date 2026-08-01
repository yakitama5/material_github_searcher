# Issue #93 設定画面でThemeColorを切り替えられるようにする

Issue: <https://github.com/yakitama5/material_github_searcher/issues/93>

## 前提・依存

`#92`（`#129`でmerge済み）のThemeMode設定画面と同型のUIを、既存の
`AppThemeColor`・`themeSettingsProvider`・`AppTheme.resolve`へ接続する。
既存のDynamic Color解決やThemeMode/UI Styleの責務は再実装せず、
`docs/technical-decisions.md`も編集しない。

## 対応方針

- `/settings/theme-color`を名前付きrouteとして追加する。
- Settings一覧へ現在値とpreviewを持つTheme Color行を追加する。
- 画面側で候補を明示した定数リストにし、App / Dynamic / Blue / Purple /
  Pink / Red / Orange / Yellow / Greenの順序を固定する。
- `themeColorLabel`で表示文言をi18nへ分離し、`RadioListTile`のラベル・選択Semantics・
  previewを別々に提供する。
- `ThemeSettingsNotifier.updateThemeColor`へ選択を委譲し、既存の楽観的更新、
  保存失敗時rollback、Snackbar通知を再利用する。
- rootの`DynamicColorBuilder`が取得したlight/dark Schemeを
  `DynamicColorScope`で設定画面へ渡す。現在表示しているbrightnessのSchemeが
  取得できない場合だけ画面にfallback説明を表示し、previewと実効ThemeはApp seedへ
  fallbackする。もう一方のbrightnessが欠けていても、取得できている側ではDynamic
  Schemeを使う。保存値とRadioの選択値は常に`AppThemeColor.dynamic`のまま保持する。
- `AppTheme.resolve`のDynamic fallbackは既存実装を利用し、ThemeMode/UI Styleへは
  変更を加えない。

## 変更対象

- `apps/app/assets/i18n/settings_{ja,en}.i18n.yaml`とslang生成物
- `apps/app/lib/src/router/app_routes.dart`
- `apps/app/lib/src/router/go_router_provider.dart`
- `apps/app/lib/src/settings/pages/settings_screen.dart`
- `apps/app/lib/src/settings/pages/settings_theme_color_screen.dart`
- `apps/app/lib/src/settings/theme_color_label.dart`
- `apps/app/lib/src/theme/dynamic_color_scope.dart`
- `apps/app/lib/main.dart`
- Settings、router、root themeのWidget Test

## テスト観点

- 9候補が固定順で一度ずつ表示され、ラベル・選択状態・previewが表示される。
- radioのSemanticsで選択状態を判定できる。
- 全候補の選択が`themeSettingsProvider`へ反映される。
- Dynamic対応時は選択値を維持し、実効ColorSchemeとpreviewにDynamic Schemeを使う。
- Dynamic非対応時は選択値を`dynamic`のまま維持し、App seedの実効ColorSchemeと
  fallback説明を表示する。
- 選択後もThemeMode/UI Styleが保持され、保存失敗時はrollbackとSnackbarになる。
- 日本語・英語、Light/Dark、402/744/1024幅、一覧遷移、route直アクセスを検証する。
- 既存の永続化round-tripは`AppThemeColor.values`で既に検証されているため、
  UIからの更新経路を中心に確認する。
