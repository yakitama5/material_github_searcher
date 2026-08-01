# Issue #95 icons_launcherでDev・ProdアプリアイコンとAndroid monochrome iconを整備する

Issue: <https://github.com/yakitama5/material_github_searcher/issues/95>

## 前提・依存

`#90`merge後の対応。Flavor名（`dev`/`prod`）、Application ID / Bundle IDは
`apps/app/flavor/*.json`のまま変更しない。提供済みDev/Prod素材
（`apps/app/assets/launcher_icon/*.png`）を利用し、別デザインは生成しない。
`docs/technical-decisions.md`は編集しない。依存追加を伴うため、最新mainから
`feat/95-icons-launcher`ブランチを作成して着手する。

## 調査結果

- `icons_launcher`（pub.dev最新版 `3.1.0`）は `--flavor <name>` /
  `--flavors a,b` オプションと `icons_launcher-<flavor>.yaml` という
  設定ファイル名規則でflavor別生成に対応する。
  - Android: `android/app/src/<flavor>/res/` へ出力される（Gradleの
    flavor source set機構でmainより優先されるため、Manifest等は共通のままでよい）。
  - iOS: `ios/Runner/Assets.xcassets/<flavor>AppIcon.appiconset/` という
    flavorをprefixにしたAsset Catalogが作られる。`project.pbxproj`側の
    `ASSETCATALOG_COMPILER_APPICON_NAME`をBuild Configurationごとに
    書き換える必要があり、ツールはpbxprojを編集しない。

## 提供素材の検証結果と対応方針

`apps/app/assets/launcher_icon/`配下の6ファイルは全て512x512、
アルファ値は全面255（完全不透明）の黒背景＋白文字（"Dev"/"Prod"）画像で、
`icon_adaptive_{dev,prod}.png`と`icon_adaptive_monochrome_{dev,prod}.png`は
バイト単位で同一ファイルだった。Issueの生成契約は
「monochromeは単色・透明背景」を求めており素材のままでは矛盾するため、
ユーザー確認の上で次の方針とした。

- **monochrome**: 黒背景をアルファ0、白文字部分をアルファ有りの
  白マスクへ変換する前処理を行う（色相・文字デザイン自体は変更しない）。
- **adaptive background**: 背景専用素材がないため`adaptive_background_color: '#000000'`
  （提供素材の背景色と同一）を使う。
- **adaptive round**: round専用素材がないため`icon_<flavor>.png`を流用する。

## 対応内容

1. `apps/app/pubspec.yaml`へ`icons_launcher: 3.1.0`を固定devDependencyとして追加。
2. `apps/app/assets/launcher_icon/`の素材を整理し、monochrome用素材に透過処理を適用。
3. `apps/app/icons_launcher-dev.yaml` / `icons_launcher-prod.yaml`を追加
   （android/iosのみ`enable: true`、web/macos/windows/linuxは`enable: false`）。
4. `dart run icons_launcher:create --flavors dev,prod`を実行し、
   Android（legacy/adaptive/round/monochrome）・iOS Asset Catalogを生成。
5. `android/app/src/main/res/mipmap-*/ic_launcher.png`（flavor別res配下に
   隠れて未使用になる旧アイコン）を削除。
6. `ios/Runner.xcodeproj/project.pbxproj`のflavor別Build Configuration
   （`PRODUCT_BUNDLE_IDENTIFIER = "$(appIdIos)$(appIdSuffix)"`を持つ
   `Debug-dev`/`Release-dev`/`Profile-dev`と`-prod`側）の
   `ASSETCATALOG_COMPILER_APPICON_NAME`をそれぞれ`devAppIcon`/`prodAppIcon`に変更。
   無印`Runner`Scheme用の`Debug`/`Release`/`Profile`は対象外のまま変更しない。
7. `docs/development.md`へ再生成コマンドと前提を追記。
8. Android実機Dev/Prod同時install、Android 13+ Themed Icon、
   iOS Simulator各SchemeのIcon Set反映を目視確認しPRへ記録。

## 対象外

Splash screen、Store listing画像、Notification icon、
アプリ内ThemeColorとの動的連動、web/macos/windows/linuxのアイコン。
