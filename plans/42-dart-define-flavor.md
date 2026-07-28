# Issue #42 Dev/Prod の dart-define 設定基盤

## 目的

`--dart-define-from-file` を利用して Dev/Prod のアプリ設定を切り替えられるようにし、
Dart コード、CLI、VS Code、IntelliJ のいずれからも同じ設定ファイルを参照できる
基盤を追加する。

## 実装方針

1. `apps/app/flavor/dev.json` と `prod.json` に、`flavor`、`appName`、
   `appIdAndroid`、`appIdIos`、`appIdSuffix` を定義する。
2. `apps/app` の composition root 配下に `Flavor` と `AppBuildConfig` を追加する。
   `String.fromEnvironment` による取得と値の検証を分離し、実行時は
   `AppBuildConfig.fromEnvironment()`、Unit Test では `fromValues()` を利用する。
3. `main()` の開始時に設定モデルを生成し、Flavor 未指定・不正値、および必須設定の
   空値をアプリ起動前に分かりやすい例外として検出する。画面タイトルにも
   `appName` を渡し、Dart コードから設定を利用できることを示す。
4. `.vscode/launch.json` と `.run/*.run.xml` に Dev/Prod の共有起動設定を追加する。
5. README に Dev/Prod の CLI 起動コマンドと IDE での起動方法を追記する。
6. Flavor の Dev/Prod 判定、未指定、不正値、全設定値の読み取り、必須値の空文字を
   Unit Test で確認する。

## 検証

- `mise exec -- dart format` で変更した Dart ファイルを整形する。
- `mise exec -- flutter test` で既存 Widget Test と追加 Unit Test を実行する。
- `mise exec -- flutter analyze` で静的解析を実行する。
- JSON と IntelliJ の XML が構文として読み取れることを確認する。

## 対象外

- Android の productFlavors
- iOS の Build Configuration / Scheme
- Flavor 別アイコン、署名、デプロイ設定
