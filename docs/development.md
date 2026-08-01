# 開発ガイド

このリポジトリでの開発コマンドをまとめる。

## 対応プラットフォーム

Android/iOSを正式対象とする。Webは正式配布対象ではなく、Device Previewや
ローカルでの動作確認用途としてrunnerを維持する。Windows・macOS・Linux
runner（`apps/app/windows`・`apps/app/macos`・`apps/app/linux`）は対象外のため
削除した。GitHub ActionsのGolden Test生成環境やCI runnerとしての
macOS/Linux利用（[`docs/testing.md`](testing.md)参照）は、アプリの対応
platform表明とは無関係であり本項の対象外。

## セットアップ

このリポジトリでは [mise](https://mise.jdx.dev/) でFlutterのバージョンを固定管理している。
開発者間・CI間でのバージョン差異を防ぐため、`mise.toml` に記載されたバージョンを使用すること。

```sh
mise install
```

実行後、`flutter --version` で `mise.toml` の `flutter` に指定したバージョンが
解決されていることを確認する。

依存関係はリポジトリルートで一括解決する。

```sh
mise exec -- dart tools/sync_sdk_versions.dart --check
mise exec -- flutter pub get
```

## 多言語化（slang）のコード生成

`apps/app` は `slang`/`slang_flutter` で日本語・英語の文言を管理する。設定は
`apps/app/build.yaml`、翻訳リソースは `apps/app/assets/i18n/*.i18n.yaml` に置く。
`build_runner` の `--workspace` フラグにより、リポジトリルートから次のコマンドで
生成できる（`apps/app` へ `cd` する必要はない）。

```sh
mise exec -- dart run build_runner build --workspace -d
```

生成された `apps/app/lib/i18n/*.g.dart` はリポジトリにコミットする。翻訳
リソースを変更したら、コミット前に上記コマンドで再生成すること。

## アプリアイコンの生成（icons_launcher）

Android/iOSのDev・Prodランチャーアイコンは[`icons_launcher`](https://pub.dev/packages/icons_launcher)で
生成する。素材は`apps/app/assets/launcher_icon/`、Flavor別設定は
`apps/app/icons_launcher-dev.yaml` / `icons_launcher-prod.yaml`に置く。

```sh
cd apps/app
mise exec -- dart run icons_launcher:create --flavors dev,prod
```

生成先は次の通りで、いずれもコミット対象。

- Android: `android/app/src/<flavor>/res/`（Gradleのflavor source setにより
  `src/main/res`より優先されるため、`AndroidManifest.xml`のアイコン参照は
  Flavor共通のままでよい）。
- iOS: `ios/Runner/Assets.xcassets/<flavor>AppIcon.appiconset/`。

iOSは`icons_launcher`がAsset Catalogのみを生成し、`project.pbxproj`の
Build Configurationは書き換えない。`Debug-dev`/`Release-dev`/`Profile-dev`の
`ASSETCATALOG_COMPILER_APPICON_NAME`は`devAppIcon`、`-prod`側は`prodAppIcon`を
指すよう設定済みで、`icons_launcher:create`を再実行してもこの設定は変更されない。
無印の`Runner`Scheme用`Debug`/`Release`/`Profile`は既存の`AppIcon`のまま対象外。

`adaptive_monochrome_image`に指定する素材は、Android 13+ Themed Icon（Material You）が
アルファチャンネルだけを図形として使い、背景色は端末側のテーマ色で塗り替えるため、
背景を透明・図柄をアルファ不透明にした単色画像を用意する。不透明な画像を渡すと
Themed Icon適用時に塗りつぶし四角として表示される。

## アプリの実行・テスト・build

Flutterアプリの実行、テスト、buildは `apps/app` で行う。
実行時は Dev または Prod の Flavor 設定ファイルを必ず指定する。
Android/iOS では `--flavor` の指定も必須で、Dev/Prod でアプリ名・
Application ID（iOSはBundle ID）が切り替わり、同一端末または
Simulatorへ同時インストールできる。

```sh
cd apps/app

# Dev (Android)
mise exec -- flutter run --flavor dev --dart-define-from-file=flavor/dev.json

# Prod (Android)
mise exec -- flutter run --flavor prod --dart-define-from-file=flavor/prod.json

# Dev (iOS Simulator)
mise exec -- flutter run --flavor dev --dart-define-from-file=flavor/dev.json -d <Simulator ID>

# Prod (iOS Simulator)
mise exec -- flutter run --flavor prod --dart-define-from-file=flavor/prod.json -d <Simulator ID>

# Dev (Web、Device Preview・ローカル確認用)
mise exec -- flutter run --dart-define-from-file=flavor/dev.json

mise exec -- flutter test

# Dev の Web build
mise exec -- flutter build web --dart-define-from-file=flavor/dev.json

# Prod の Web build
mise exec -- flutter build web --dart-define-from-file=flavor/prod.json

# Dev の Android Debug build
mise exec -- flutter build apk --flavor dev --debug --dart-define-from-file=flavor/dev.json

# Prod の Android Debug build
mise exec -- flutter build apk --flavor prod --debug --dart-define-from-file=flavor/prod.json

# Dev の iOS Simulator build
mise exec -- flutter build ios --flavor dev --debug --simulator --dart-define-from-file=flavor/dev.json

# Prod の iOS Simulator build
mise exec -- flutter build ios --flavor prod --debug --simulator --dart-define-from-file=flavor/prod.json
```

iOSの `-d <Simulator ID>` は `xcrun simctl list devices` または `flutter devices` で
確認した起動中Simulatorの識別子に置き換える。

iOSはFlutterの `--flavor` 名（`dev`/`prod`）と同名の共有Scheme
（`ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme` / `prod.xcscheme`）で
Build Configuration（`Debug-dev`/`Release-dev`/`Profile-dev` など）を切り替えている。
Xcodeを直接開いて実行する場合も、無印の `Runner` Schemeではなく `dev`/`prod` Scheme を
選択すること（無印Schemeは Flavor の dart-define が渡らず起動時エラーになる）。

アプリ本体のBundle IDやアプリ名（`PRODUCT_BUNDLE_IDENTIFIER` / `APP_DISPLAY_NAME`）は
`apps/app/flavor/dev.json` / `prod.json` を唯一のソースとして解決される。
`ios/scripts/extract_dart_defines.sh` が `dev`/`prod` Scheme のBuild Pre-actionとして
実行され、`--dart-define-from-file` の内容（`DART_DEFINES`）をデコードして
`ios/Flutter/Environment.xcconfig`（gitignore対象、都度生成）へ書き出し、
`Debug-<flavor>`/`Release-<flavor>`/`Profile-<flavor>` の
`PRODUCT_BUNDLE_IDENTIFIER = "$(appIdIos)$(appIdSuffix)"` /
`APP_DISPLAY_NAME = "$(appName)"` がそれを参照する。Androidの
`build.gradle.kts`（`flavor/*.json` を直接読み取り）と同様、flavor設定ファイルの
値を変更するだけでiOS側にも反映され、pbxprojへの追随修正は不要。
無印の `Debug`/`Release`/`Profile`（既存の `Runner` Scheme用）はこの仕組みの
対象外で、従来どおりの固定値のまま変更していない。

Patrol CLIの`package_name` / `bundle_id`はflavor設定ファイルを参照できず、インストール済み
アプリを特定する最終IDが必要なため、`apps/app/pubspec.yaml`の`patrol`セクションにDevの値を
重複して記載する。`flavor/dev.json`のIDを変更する場合は、Androidは
`appIdAndroid + appIdSuffix`、iOSは`appIdIos + appIdSuffix`となるよう同セクションも同期する。

## Device Preview（Dev Web限定）

[`device_preview_plus`](https://pub.dev/packages/device_preview_plus)を、通常のDev/Prod起動、
Widget Test、Patrolへ影響しないDev Web専用の確認ツールとして`dev_dependencies`に導入している。
実機・Widget Test・Golden Test・Patrolの代替にはせず、端末サイズ・画面向き・Text Scale・
Safe Area・Light/Darkを素早く見た目確認する用途に限定する。

専用entrypoint `apps/app/debug/main.dart` からのみ起動する。通常起動の`lib/main.dart`は
`device_preview_plus`をimportしない。

```sh
cd apps/app
mise exec -- flutter run \
  -d chrome \
  -t debug/main.dart \
  --dart-define-from-file=flavor/dev.json
```

`debug/main.dart`はProd Flavor・releaseモード・Web以外のPlatformでの起動を`StateError`で
拒否する（判定は`lib/src/config/device_preview_guard.dart`の`assertDevicePreviewAllowed`が持ち、
`device_preview_plus`に依存しないためWidget Testからも検証できる）。Android/iOSの通常
Dev・Prod起動にはこのentrypointを使わないため、Device Previewが混入することはない。

ツールパネルは次の項目だけに絞っている。ロケール切り替えを含む他の項目は非表示にした。
Slangとのlocale二重管理を避けるため、ロケール切り替えは本ツールの対象外とし、言語切り替えは
引き続きSlangのlocale設定で行う。

- Device: 端末サイズ（Model）・画面向き（Orientation）
- Accessibility: Text scaling factor
- System: Theme（Light/Dark）

Safe Areaは専用トグルを持たず、Deviceの端末サイズ（Model）選択に連動して反映される。

`createApp`へ追加した`builder`引数（`TransitionBuilder?`、既定`null`）が
`MaterialApp.builder`へ橋渡しするhookで、`debug/main.dart`だけが`DevicePreview.appBuilder`を
渡す。通常起動・Widget Test・Patrolは`builder`を指定しないため、Composition Root
（`createApp`のProvider override経路、`MaterialApp.router`、go_router、DynamicColor、
ThemeSettings）への影響はない。

## GitHub Actionsでの手動Build

`.github/workflows/build_app.yaml`の`Build App` Workflowでは、Dev/ProdアプリのAndroid
Debug APKと署名不要のiOS Simulator Buildを任意に生成できる。このWorkflowは
`workflow_dispatch`専用であり、PRのRequired Status Checkや`main` push時の自動実行には
含まれない。

Workflowファイルがデフォルトブランチへマージされた後、GitHubのActions画面から
`Build App`を開いて`Run workflow`を選択し、次の項目を指定する。

- Branch: Build対象のBranch
- `bump_type`: `none`、`patch`、`minor`、`major`、`build`
- `flavor`: `dev`または`prod`
- `platform`: `all`、`android`、`ios`

`bump_type`が`none`以外の場合、固定版のCiderがRunner上の
`apps/app/pubspec.yaml`だけを一時的に更新する。`patch`、`minor`、`major`ではSemVerと
Build Numberを更新し、`build`ではBuild Numberだけを更新する。変更後のVersionは
Build LogとArtifact名で確認できる。Repositoryのファイル、Commit、Tagには反映されず、
WorkflowからGitへのpushも行わない。

実行完了後はWorkflow Runの`Artifacts`から次の成果物を取得できる。保持期間は7日間。

- Android: 選択FlavorのDebug APK
- iOS: 選択Flavorの`Runner.app`を格納した`.tar.gz`

iOS成果物は展開後の実行権限とシンボリックリンクを保持するため、`.app`を`tar.gz`へ
格納している。iOS Simulator向けであり、物理端末へのインストールやApp Store Connectへの
提出には利用できない。Android成果物もDebug署名されたFlavor検証用APKであり、Google
Playへ提出するRelease AABではない。

将来このWorkflowをCDへ拡張する場合は、Debug / Simulator BuildをRelease Buildへ
置き換え、署名情報とストア認証情報をGitHub Secrets等で管理する。そのうえで、生成した
成果物をCodemagic CLI Tools等から内部テストへ配布する工程をArtifact作成後に追加する。
現在のWorkflowには、署名情報の復元、Release署名、Codemagic CLI Toolsのインストール、
App Store Connect / Google Playへのアップロード処理は含めない。

## Android実機・iOS SimulatorでのE2E Test（Patrol）

PatrolによるE2E Testは、ローカルで接続したAndroid実機または起動中の
iOS Simulatorを対象に実行する。物理iOS端末は署名とProvisioning Profileの運用が
必要になるため対象外とする。GitHub ActionsやPRのRequired Status Checkでは実行しない。

### Patrolのセットアップ

Patrol package `4.8.0` と互換性のあるPatrol CLI `4.6.1`を固定して使う。
CLIをインストールし、Dartのグローバル実行ファイルを`PATH`へ追加する。
Android実機で実行する場合はAndroid SDKも環境変数へ追加する。macOSでAndroid Studioの
既定パスを使う場合は次のように設定できる。

```sh
mise exec -- dart pub global activate patrol_cli 4.6.1

export PATH="$PATH:$HOME/.pub-cache/bin"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
```

シェルを開き直しても設定を維持する場合は、利用中のシェルの設定ファイルへ
`export`行を追加する。Android SDKを別の場所へインストールしている場合は、
Android StudioのSDK Managerに表示されるパスを`ANDROID_HOME`へ設定する。

Patrolと実行対象プラットフォームの項目に問題がないことを確認する。iOS Simulatorでは
XcodeとCommand Line Toolsが必要になるため、`xcode-select -p`が利用するXcodeを
指していることも確認する。

```sh
PATROL_FLUTTER_COMMAND="mise exec -- flutter" patrol doctor
```

### Android実機の接続と実行

1. 実機の開発者向けオプションとUSBデバッグを有効にする。
2. USBで接続し、実機に表示されるデバッグ許可ダイアログを承認する。
3. 実機の画面ロックを解除した状態で、リポジトリルートから端末IDを確認する。

```sh
mise exec -- flutter devices
```

表示されたAndroid端末IDを共通タスクへ渡す。タスクはDev Flavorと
`flavor/dev.json`を必ず使用し、リポジトリで固定したFlutterからPatrolを実行する。

```sh
mise run test:e2e <Android device ID>
```

端末IDは環境固有のため、`mise.toml`やテストコードへ保存しない。

### iOS Simulatorの起動と実行

1. Xcodeで利用するiOS Simulator runtimeをインストールする。
2. Simulatorを起動し、リポジトリルートから端末IDを確認する。

```sh
xcrun simctl list devices booted
mise exec -- flutter devices
```

表示されたiOS SimulatorのIDをAndroidと共通のタスクへ渡す。タスクはDev Scheme、
DevのBundle ID `com.example.materialGithubSearcher.dev`、`flavor/dev.json`を使用する。
PatrolのiOSネイティブテストは`RunnerUITests` targetから起動し、SwiftPMが生成する
`FlutterGeneratedPluginSwiftPackage`経由でPatrolへリンクする。CocoaPodsは使用しない。
Flavor用Build ConfigurationのUI Test Bundle IDは`flavor/*.json`由来の`appIdIos`から
`$(appIdIos).RunnerUITests`として導出する。アプリ本体と異なり`appIdSuffix`を付けず、
テストランナーのIDはDev/Prod間で共通とする。

```sh
mise run test:e2e <iOS Simulator ID>
```

物理iOS端末は選択しない。Simulator IDは環境固有のため、設定ファイルへ保存しない。

### トラブルシュート

- `Patrol CLIが見つかりません`またはCLIのバージョンエラー
  - `mise exec -- dart pub global activate patrol_cli 4.6.1`を実行し、
    `$HOME/.pub-cache/bin`が`PATH`に含まれることを確認する。
- `ANDROID_HOMEが未設定です`
  - Android実機で実行する場合は、Android StudioのSDK ManagerでSDKの場所を確認し、
    そのパスを`ANDROID_HOME`へ設定する。
- `flutter devices`に実機が表示されない
  - USBケーブル、USBデバッグ、実機側の認証ダイアログを確認する。
    `adb kill-server`、`adb start-server`の順に実行してから再接続する。
- 端末が`unauthorized`と表示される
  - 実機の「USBデバッグの許可を取り消す」を実行して再接続し、認証をやり直す。
- InstrumentationまたはGradle buildが失敗する
  - `PATROL_FLUTTER_COMMAND="mise exec -- flutter" patrol doctor`で環境を確認する。
    その後`cd apps/app && mise exec -- flutter clean`、リポジトリルートで
    `mise exec -- flutter pub get`を実行して再試行する。
- Patrolがアプリの起動を待ち続ける
  - 実機の画面ロックを解除し、Devアプリ
    `com.example.material_github_searcher.dev`が対象端末へインストール可能か確認する。
    ProdアプリとはApplication IDが異なるため、Patrol設定にはDevの最終IDを使う。
- `xcodebuild`が利用するXcodeまたはSimulator runtimeを見つけられない
  - `xcode-select -p`、`xcodebuild -version`、`xcrun simctl list devices`を確認する。
    複数のXcodeがある場合は、利用するXcodeをCommand Line Toolsに設定する。
- `RunnerUITests`またはSwift Packageの解決に失敗する
  - `apps/app`で`mise exec -- flutter clean`を実行し、リポジトリルートで
    `mise exec -- flutter pub get`を再実行する。その後、起動中のSimulatorを明示して
    再試行する。Podfileや`pod install`は追加しない。
- iOSでDevアプリの起動を待ち続ける
  - 対象が物理端末ではなく起動中のSimulatorであることと、DevのBundle ID
    `com.example.materialGithubSearcher.dev`が`flavor/dev.json`とPatrol設定の両方で
    一致していることを確認する。

## Flutterのアップグレード

手順は [`flutter-upgrade.md`](flutter-upgrade.md) を参照。
