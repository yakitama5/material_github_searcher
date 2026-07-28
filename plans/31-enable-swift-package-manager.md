# Issue #31 iOS ネイティブ依存管理で Swift Package Manager を有効化

<!-- cspell:words deintegrate pbxproj SwiftPM xcshareddata xcodeproj xcscheme xcschemes -->

## 目的

Flutter アプリの `pubspec.yaml` で Swift Package Manager（SwiftPM）を明示的に
有効化し、開発者ごとの Flutter グローバル設定に依存せず、iOS のネイティブ依存を
SwiftPM で解決できる状態にする。SwiftPM 非対応プラグイン向けの CocoaPods
フォールバックは維持する。

Issue: <https://github.com/yakitama5/material_github_searcher/issues/31>

## 調査結果

- 依存する Issue #20 は完了済みで、Flutter アプリは `apps/app` に配置されている。
- Flutter `3.44.8` と Dart `3.12.2` は `mise.toml` で固定されている。
- ローカルの `flutter config --list` では
  `enable-swift-package-manager: false` が明示されている。
- `apps/app/pubspec.yaml` の `flutter:` セクションには、SwiftPM のプロジェクト設定が
  まだ存在しない。
- iOS の `project.pbxproj` には `FlutterGeneratedPluginSwiftPackage` の
  Package／Target 統合がなく、Runner Scheme に
  `Run Prepare Flutter Framework Script` pre-action も存在しない。
- 現在は iOS ネイティブプラグインを利用しておらず、Podfile も存在しない。
  CocoaPods 用の xcworkspace と xcconfig は既存構成のまま維持されている。
- Flutter `3.44.8` の自動移行は、SwiftPM 対応プラグインが 0 件かつ Xcode
  プロジェクトが未移行の場合、生成 Package と Xcode 移行をスキップする。
  実際に config-only build は成功したが、SwiftPM 統合の差分は生成されなかった。
- `.gitignore` は `build`、`.swiftpm`、`Flutter/ephemeral`、`Pods`、
  `.symlinks` などの生成物を除外する。
- Flutter 3.44 以降は SwiftPM が標準で有効であり、Flutter の実行時に既存 Xcode
  プロジェクトを自動移行する。SwiftPM 非対応プラグインは CocoaPods に
  フォールバックする。
- `flutter.config` は現在のアプリパッケージからのみ読み取られる。このため依存解決は
  Workspace ルートで行い、iOS の移行とビルドは `apps/app` で実行する。

## 実装方針

### プロジェクト単位の SwiftPM 設定

`apps/app/pubspec.yaml` の既存 `flutter:` セクションに次を追加する。
Workspace 集約用のルート `pubspec.yaml` には追加しない。

```yaml
flutter:
  config:
    enable-swift-package-manager: true
  uses-material-design: true
```

プロジェクト設定がグローバル設定より優先されることを利用し、グローバルの
`enable-swift-package-manager` が `false` の環境でも SwiftPM を有効にする。

### Flutter による Xcode プロジェクトの自動移行

手動で Xcode プロジェクトを先に編集せず、まず mise で固定した Flutter `3.44.8` の
自動移行を試す。iOS Simulator 向けの config-only build を実行した直後に、必須の
Package／Target 統合と pre-action が追加されたかを検証する。

```sh
mise exec -- flutter pub get
(cd apps/app && mise exec -- flutter build ios --config-only --simulator)
```

自動移行では次の追跡ファイルが変更対象になる。

- `apps/app/ios/Runner.xcodeproj/project.pbxproj`
- `apps/app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`

今回の実行では、ネイティブプラグインが存在しないため Flutter `3.44.8` の実装上
自動移行がスキップされ、Issue の受け入れ条件を満たす Xcode 差分が生成されなかった。
この自動移行を適用できない場合に限り、Flutter 公式ドキュメントと固定 SDK の
テンプレートに従って手動統合する。手動統合へ移る前に部分的な変更やバックアップが
残っていないことを確認する。

### CocoaPods フォールバック

SwiftPM 非対応プラグインが追加された場合の Flutter による CocoaPods
フォールバックを妨げない。今回の対応では Podfile を新設せず、既存の xcworkspace、
xcconfig、CocoaPods 関連設定を削除せず、`pod deintegrate` なども実行しない。

## 実装手順

1. `apps/app/pubspec.yaml` に `enable-swift-package-manager: true` を追加する。
2. Workspace ルートで、mise の Flutter を使って依存解決する。
3. `apps/app` で iOS Simulator 向け config-only build を実行し、自動移行を試す。
4. 自動移行の結果を検証する。必須統合が生成されなければ、公式手順と固定 SDK の
   テンプレートを照合して `project.pbxproj` と Runner Scheme を手動統合する。
5. config-only build を再実行し、生成 Package と手動統合の整合性を検証する。
6. iOS Simulator 向けの完全な build を実行し、SwiftPM の依存解決とアプリ build が
   成功することを確認する。
7. 静的解析、Widget テスト、SDK 同期チェックを実行する。
8. Git 差分と追跡ファイルを確認し、生成物やバックアップが追加されていないことを
   検証する。

## 品質ゲート

### SDK と依存解決

```sh
mise exec -- flutter --version
mise exec -- flutter config --list
mise exec -- dart tools/sync_sdk_versions.dart --check
mise exec -- flutter pub get
```

確認事項:

- Flutter は `mise.toml` で固定した `3.44.8` である。
- グローバルの `enable-swift-package-manager` が `false` のままでも、アプリの
  `pubspec.yaml` に `enable-swift-package-manager: true` が存在する。
- SDK 制約は `mise.toml` と一致している。
- 依存解決は Workspace ルートで成功し、メンバー配下に lockfile を生成しない。

### SwiftPM 統合と config-only build

```sh
(cd apps/app && mise exec -- flutter build ios --config-only --simulator)
rg -q 'enable-swift-package-manager: true' apps/app/pubspec.yaml
rg -q 'FlutterGeneratedPluginSwiftPackage in Frameworks' \
  apps/app/ios/Runner.xcodeproj/project.pbxproj
rg -q 'XCLocalSwiftPackageReference' \
  apps/app/ios/Runner.xcodeproj/project.pbxproj
rg -q 'packageProductDependencies' \
  apps/app/ios/Runner.xcodeproj/project.pbxproj
rg -q 'PreActions' \
  apps/app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
rg -q 'Run Prepare Flutter Framework Script' \
  apps/app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
rg -q 'xcode_backend.sh.*prepare' \
  apps/app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
```

`project.pbxproj` で次を確認する。

- `FlutterGeneratedPluginSwiftPackage in Frameworks` の `PBXBuildFile`
- Flutter group 内の `PBXFileReference`
- Runner の Frameworks build phase への追加
- Runner の `packageProductDependencies` への追加
- Project の `packageReferences` にある `XCLocalSwiftPackageReference`
- `XCSwiftPackageProductDependency` の product name

Runner Scheme で次を確認する。

- BuildAction の `PreActions`
- `Run Prepare Flutter Framework Script` の名称
- Runner の `BuildableReference`
- `xcode_backend.sh prepare` の実行

### iOS Simulator build

```sh
(cd apps/app && mise exec -- flutter build ios --simulator)
```

SwiftPM による依存解決を含む Simulator build が成功することを確認する。

### 回帰テスト

```sh
mise exec -- dart analyze --fatal-infos
(cd apps/app && mise exec -- flutter test)
```

### 差分と生成物

```sh
git diff --check
git status --short
test -f pubspec.lock
find apps packages \
  \( -name pubspec.lock -o -path '*/.dart_tool/package_config.json' \) -print
```

確認事項:

- 意図する追跡差分は `apps/app/pubspec.yaml`、`project.pbxproj`、Runner Scheme と
  この計画書に限定されている。
- `pubspec.lock` は依存バージョンが変わらない限り差分がなく、ルートにだけ存在する。
- `build`、`Flutter/ephemeral`、`.swiftpm`、`Pods`、`.symlinks`、移行時の
  `project.pbxproj.backup`、`Runner.xcscheme.backup` が Git 管理に追加されていない。
  `git ls-files` で対象パターンの出力が空であることを確認する。
- CocoaPods フォールバックを妨げる削除や設定変更がない。

## リスクと対応

- コマンドの実行位置を誤ると `apps/app/pubspec.yaml` の `flutter.config` が
  読み取られない。iOS の移行・build は必ず `apps/app` で実行する。
- Flutter の自動移行は標準 Xcode object ID と構造を前提とする。現在の
  `project.pbxproj` は標準 ID を保持しているが、失敗した場合は復元状態を確認してから
  公式の手動統合へ切り替える。
- build によって多数の一時ファイルが生成される。追跡済みの想定外ファイルが
  更新された場合は機械的に採用せず、変更理由を個別に確認する。
- flavor や Scheme が増えた場合は、それぞれに prepare pre-action が必要になる。
  現在は Runner の単一 Scheme のみを対象とする。

## 参考

- [Swift Package Manager for app developers](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
- [Flutter pubspec options](https://docs.flutter.dev/tools/pubspec)
