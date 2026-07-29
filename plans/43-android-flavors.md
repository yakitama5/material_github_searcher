# Issue #43 Android の Dev/Prod Flavor

## 目的

`apps/app/flavor/dev.json` / `prod.json`（#42 で導入した dart-define 基盤）を単一の
ソースとして、Android ネイティブ側にも Dev/Prod の productFlavors を追加する。
アプリ名・Application ID を Gradle と Dart の両方で二重管理せず、同一端末への
Dev/Prod 同時インストールを可能にする。

## 実装方針

1. `apps/app/android/app/build.gradle.kts` に `flavorDimensions("environment")` と
   `productFlavors { dev, prod }` を追加する。
2. 各 flavor の値は Gradle スクリプトから `flavor/<flavor>.json` を直接読み取って
   反映し、値の二重管理を避ける。
   - JSON パースには Gradle のクラスパスに含まれる `groovy.json.JsonSlurper` を
     Kotlin DSL から利用する（追加の依存を増やさない）。
   - `appIdAndroid` を `defaultConfig.applicationId` に設定する。
   - `appIdSuffix` が空文字でなければ `applicationIdSuffix` に設定する
     （prod は空文字のため未設定のままとなり、既存の Application ID を維持する）。
   - `appName` を `resValue("string", "app_name", ...)` として各 flavor に生成する。
3. `AndroidManifest.xml` の `android:label` を固定文字列から `@string/app_name` に
   変更し、flavor ごとに生成した文字列リソースを参照させる。
4. `docs/development.md` の Android 起動コマンドに `--flavor dev` / `--flavor prod`
   を追加する（productFlavors 追加により Android では flavor 指定が必須になるため）。

## 検証

- `mise exec -- flutter build apk --flavor dev --debug --dart-define-from-file=flavor/dev.json`
- `mise exec -- flutter build apk --flavor prod --debug --dart-define-from-file=flavor/prod.json`
- 生成された各 APK に対して `aapt dump badging` 等で `applicationId` と表示ラベルが
  flavor ごとに異なることを確認する（実機への同時インストール確認は本エージェントの
  実行環境では行えないため、Application ID が異なることをもって代替確認とする）。
- 既存の Dart テスト（`mise exec -- flutter test`）に影響がないことを確認する。

## 対象外

- iOS Flavor
- Flavor 別アイコン
- Release 署名
- Google Play へのデプロイ
