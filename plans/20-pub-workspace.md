# Issue #20 Pub Workspace によるマルチパッケージ化

<!-- cspell:words designsystem lockfile pubspecs -->

## 目的

`docs/ARCHITECTURE.md` で定義した依存方向を、Dart 標準の Pub Workspace と
複数パッケージの `pubspec.yaml` で表現する。既存の Flutter アプリは
`apps/app` へ移し、挙動を変えずに実行可能な状態を維持する。

Issue: <https://github.com/yakitama5/material_github_searcher/issues/20>

## 調査結果

- `main` と `origin/main` は `384781e` で一致し、調査開始時の作業ツリーは
  クリーンだった。
- 現在はルート直下に単一の Flutter アプリがあり、`lib/main.dart`、
  `test/widget_test.dart`、6 プラットフォームのプロジェクトが存在する。
- 現在のパッケージ名は `material_github_searcher` であり、移動後も
  `apps/app` がこの名前を維持する。
- Flutter `3.44.8` と Dart `3.12.2` は `mise.toml` で固定されている。
- 変更前の `flutter pub get`、`flutter analyze --fatal-infos`、
  `flutter test` は成功する。
- ルートの `analysis_options.yaml` はネストしたパッケージにも適用でき、
  `build` と `.dart_tool` の除外設定も階層を問わない。
- CI の解析処理はルートで依存解決と `dart analyze --fatal-infos` を実行して
  おり、Pub Workspace 化後も同じ実行位置を利用できる。
- 参考リポジトリは Melos による依存統一を前提としている。その構成や
  `any`、`null` の依存指定は持ち込まない。

## 実装方針

### Workspace ルート

ルート `pubspec.yaml` はアプリ用から Workspace 集約用へ変更する。Pub 上は
ルート自身にも一意な名前が必要なため、`material_github_searcher_workspace`
とする。

ルートには次だけを置く。

- `publish_to: none`
- `environment.sdk: 3.12.2`
- 7 個の Workspace メンバーを明示列挙した `workspace:`
- 共有する解析設定の解決に必要な `altive_lints: 4.0.0`
- SDK 同期ツールのテストに必要な `test` の固定バージョン

アプリの `version`、Flutter SDK 依存、`flutter:` セクションは
`apps/app/pubspec.yaml` へ移す。ルート自身には `resolution: workspace` を
指定せず、各 Workspace メンバーに指定する。Melos の依存や `melos:`
セクションは追加しない。

`pubspec.lock` と `.dart_tool/package_config.json` はルートに一つだけ生成する。
Workspace メンバー配下には lockfile や個別の package config を残さない。

### Workspace メンバー

| パス | パッケージ名 | 直接依存 |
| --- | --- | --- |
| `apps/app` | `material_github_searcher` | `designsystem`、`application`、`dependency_override`、Flutter |
| `packages/designsystem` | `designsystem` | `application`、Flutter |
| `packages/application` | `application` | `domain`、`foundation` |
| `packages/dependency_override` | `dependency_override` | `application`、`infrastructure_mock` |
| `packages/infrastructure/mock` | `infrastructure_mock` | `domain` |
| `packages/domain` | `domain` | `foundation` |
| `packages/foundation` | `foundation` | なし |

各メンバーに `publish_to: none`、`environment.sdk: 3.12.2`、
`resolution: workspace` を指定する。`apps/app` は既存の build version
`1.0.0+1` と `lib/main.dart` を維持する。新設する6パッケージには固定した
初期バージョン `0.1.0` と、パッケージ名に一致する最小の公開ライブラリ
`lib/<package_name>.dart` を用意する。Flutter を使う `apps/app` と
`designsystem` には `environment.flutter: 3.44.8` と Flutter SDK 依存も
指定する。判定はディレクトリ名や依存名ではなく、`dependencies` または
`dev_dependencies` に値 `sdk: flutter` の依存記述を持つかで行う。
今後 Flutter を利用する Workspace メンバーを追加した場合も、
`environment.flutter` に `mise.toml` と同じ完全一致バージョンを必須とする。

Workspace 内の依存は、上表の方向だけを相対 `path:` で明示する。`path:` と
SDK 依存は Pub の形式上バージョン文字列を併記できないため、固定バージョンの
規則は hosted パッケージに適用する。既存の `cupertino_icons` は移行と無関係な
削除を避け、現在の lockfile で解決済みの `1.0.9` に固定する。
`altive_lints` もキャレットを外して `4.0.0` に固定する。

### SDK バージョン同期ツール

`mise.toml` を SDK バージョンの唯一の正とし、`tools/sync_sdk_versions.dart` で
ルートと各 Workspace メンバーの完全一致制約を同期する。Melos は導入しない。

ツールは次の手順で動作する。

1. リポジトリルートの `mise.toml` から `tools.flutter` を読み取る。
   値は演算子や alias を含まない完全一致 SemVer だけを受理する。
2. `flutter --version --machine` を実行し、mise が選択した Flutter と同梱 Dart の
   バージョンを取得する。終了コード、JSON、`flutterVersion`、
   `dartSdkVersion` とそれぞれの形式を検証する。
3. 実行中の Flutter が `mise.toml` の指定と異なる場合は、ファイルを書き換えず
   `mise install` / `mise exec` が必要なことを示して失敗する。
4. ルート `pubspec.yaml` の明示的な `workspace:` から全メンバーを列挙する。
   ルート相対の文字列リストだけを受理し、glob、絶対パス、`..`、ルート外、
   正規化後の重複、対象 `pubspec.yaml` の欠落を拒否する。
5. ルートと全メンバーの `environment.sdk` を同梱 Dart の完全一致バージョンへ
   更新する。
6. Flutter SDK 依存を持つ全メンバーだけ、`environment.flutter` を
   `mise.toml` の完全一致バージョンへ更新する。Flutter SDK 依存がないルートや
   メンバーに既存の `environment.flutter` があれば削除対象とする。
7. 対象ファイル、変更前、変更後を表示し、変更がない場合も明示する。

通常実行は差分を反映し、`--check` は書き換えずに差異があれば非ゼロで終了する。
未知の `mise.toml` / `pubspec.yaml` 構造、重複キー、Workspace メンバーの欠落を
検出した場合は、推測で書き換えずエラーにする。未知のオプションや余分な引数も
拒否する。`--check` は全対象の差分をまとめて表示し、いかなる場合も書き込まない。

通常実行では、全対象の読み取り、構造検証、変更後内容の生成を完了するまで
一切書き込まない。検証成功後に同一ディレクトリの一時ファイルへ出力し、ファイル単位の
置換を行う。置換エラー時は保持した元内容から復元し、部分更新を残さない。

Flutter アップグレード直後は既存 `pubspec.yaml` の完全一致制約が古いため、
ツール本体は外部パッケージに依存させない。`dart run` による Pub の依存解決を
避け、SDK ライブラリだけで実装したスクリプトを次のように直接実行する。

```sh
mise exec -- dart tools/sync_sdk_versions.dart
mise exec -- dart tools/sync_sdk_versions.dart --check
```

行単位の更新処理は、対象となる `environment` と `workspace` の構造を厳密に検証し、
コメントや無関係な YAML を保持する。コメント内の偽キー、引用符付きの値、CRLF、
末尾改行、重複キー、異常なインデント、キーの追加、inline 形式の拒否を
一時ディレクトリの fixture でテストする。

さらに、古い完全一致 SDK 制約を持ち、`.dart_tool/package_config.json` がない
fixture に対して、テストプロセスの `Platform.resolvedExecutable` から同期スクリプトを
直接起動し、Pub の依存解決なしで更新できることを確認する。fake Flutter コマンドで
mise との一致・不一致、コマンド失敗、不正 JSON、Flutter/Dart バージョン欠落を再現する。
全件検証の後半で失敗した場合に全ファイルが未変更であること、`--check` と不正引数の
終了コードもテストする。

### Flutter アプリの移動

`apps/app` を Flutter ツールから見たアプリルートにする。次を履歴が追える形で
移動する。

- `.metadata`
- `lib/`
- `test/`
- `android/`
- `ios/`
- `linux/`
- `macos/`
- `web/`
- `windows/`

プラットフォームのディレクトリ構造は一式を保ち、内部の相対パスを先回りして
変更しない。移動後に build と起動で検証し、実際に不整合が出た箇所だけを直す。
`lib/main.dart` の UI と `test/widget_test.dart` のテスト内容は変更しない。
現在の `main.dart` は Flutter 以外を import していないため、利用していない新設
パッケージの import は追加しない。初期構築の依存境界は `pubspec.yaml` の
`path:` 依存と各パッケージの公開ライブラリで表現する。

### リポジトリ設定とドキュメント

- ルート `.gitignore` をネスト後の `apps/app/build`、`coverage`、Android の
  build 出力も除外できるパターンへ変更する。
- `README.md` に、依存解決はルート、アプリの実行・テスト・build は
  `apps/app` で行うことと、SDK 同期ツールの利用方法を記載する。
- `docs/flutter-upgrade.md` を、`mise.toml` の更新後に同期ツールを実行し、
  ルートの lockfile を再生成する手順へ更新する。
- `docs/ARCHITECTURE.md` に、完全一致 SDK 制約は同期ツールで `mise.toml` から
  反映し、`--check` で不一致を検出する方針を追記する。
- `analysis_options.yaml` と `mise.toml` はルートに維持する。
- `.github/workflows/analyze.yaml` は
  `checkout` → `setup-flutter`（mise install と PATH 設定）→ 同期ツールの
  `--check` → `flutter pub get` → `dart analyze` の順にする。新しい SDK と古い
  制約の組み合わせでも、Pub の解決エラーより先に原因を明示する。
- SDK 同期は解析の前提条件として既存 Analyze ワークフローで検査し、このためだけの
  CI ワークフローや Melos 設定は追加しない。

## 実装手順

1. ルート `pubspec.yaml` を Workspace 集約用に変更し、アプリ用の内容を
   `apps/app/pubspec.yaml` へ分離する。
2. Flutter アプリ一式を `apps/app` へ移し、ルートにアプリ固有ファイルが
   残っていないことを確認する。
3. `foundation`、`domain`、`application`、`infrastructure_mock`、
   `designsystem`、`dependency_override` の最小パッケージを作成する。
4. 各 `pubspec.yaml` に `resolution: workspace`、固定 SDK 制約、上表の
   `path:` 依存だけを設定する。
5. `tools/sync_sdk_versions.dart` とそのテストを追加し、適用・検査の両モードを
   実装する。
6. `.gitignore`、`README.md`、`docs/ARCHITECTURE.md`、
   `docs/flutter-upgrade.md`、Analyze ワークフローを新しい運用に合わせる。
7. 同期ツールを適用した後、ルートで依存を解決して `pubspec.lock` を更新し、
   Workspace 一覧と依存関係を確認する。
8. 下記の品質ゲートを実行する。
9. 実装コンテキストを持たないサブエージェントに、Issue、アーキテクチャ、差分を
   渡してレビューを依頼する。指摘を反映後、品質ゲートを再実行する。
10. Draft PR 作成後、`pr-review-report` スキルで詳細レビューを行う。

## 品質ゲート

### 構成と依存解決

```sh
mise exec -- flutter --version
mise exec -- dart --version
mise exec -- dart tools/sync_sdk_versions.dart --check
mise exec -- flutter pub get
mise exec -- dart pub workspace list
mise exec -- dart pub deps
```

確認事項:

- ルートと7メンバーが重複しない名前で一覧に現れる。
- `pubspec.lock` はルートにだけ存在する。
- `altive_lints: 4.0.0` はルートの `dev_dependencies` にだけ存在する。
- ルートと全メンバーの `environment.sdk` が、mise で選択した Flutter 同梱 Dart と
  完全一致する。
- Flutter SDK 依存を持つ全メンバーの `environment.flutter` が
  `mise.toml` と完全一致し、Flutter SDK 依存がないルートとメンバーには
  `environment.flutter` がない。
- 同期ツールの適用後に `--check` を実行すると差分なしで成功する。
- 全 `pubspec.yaml` の hosted dependency と hosted dev dependency に、`any`、
  `null`、キャレット付きバージョンが存在しない。
- `melos` 依存と `melos:` セクションが存在しない。
- 上表の10本の Workspace 内依存が過不足なく存在し、
  `docs/ARCHITECTURE.md` にない依存が存在しない。

### 静的解析とテスト

```sh
mise exec -- dart test test/tools
mise exec -- dart analyze --fatal-infos
(cd apps/app && mise exec -- flutter test)
```

同期ツールの単体テスト、ルートからの全メンバー解析、移動後の既存 Widget テストが
すべて成功することを確認する。

### build と起動

```sh
(cd apps/app && mise exec -- flutter build web)
(cd apps/app && mise exec -- flutter devices)
(cd apps/app && mise exec -- flutter run -d <device-id> --no-resident)
```

Web build でアプリパッケージとしての成立を再現可能に確認した上で、利用可能な
シミュレータまたはデスクトップ端末で実際に起動する。既存のカウンター画面が表示され、
ボタン操作で値が増えることを確認する。

### 差分と生成物

```sh
git status --short
git diff --check
find apps packages -name pubspec.lock -o -path '*/.dart_tool/package_config.json'
```

意図しない生成物、メンバー配下の lockfile、個別 package config、無関係な変更が
含まれていないことを確認する。`find` の出力は空であることを必須とする。

## リスクと対策

- ルートとアプリのパッケージ名が重複すると依存解決に失敗するため、ルートを
  `material_github_searcher_workspace` に分離する。
- `lib` だけを移すと Flutter ツールの実行単位が分裂するため、`.metadata` と全
  プラットフォームを含むアプリ一式を移す。
- ネスト後の build 出力が Git の未追跡ファイルとして現れないよう、実行前に
  `.gitignore` を修正し、実行後にも ignored 状態を確認する。
- 固定 SDK 制約は patch バージョン差でも解決を拒否する。全メンバーを
  `mise.toml` と同期するツールと CI の `--check` により、手作業の更新漏れを防ぐ。
- Flutter 更新直後は古い SDK 制約で Pub の依存解決が失敗し得る。同期ツールを
  SDK ライブラリだけで実装して直接実行し、`flutter pub get` より先に同期する。
- YAML を行単位で更新するため、想定外の構造を黙って破壊しないよう、対応構造を
  限定して曖昧な入力では失敗させ、fixture テストで書式保持を確認する。
- 最小パッケージにはまだ業務 API がないため、依存境界は `pubspec.yaml` と公開
  ライブラリの構造で確認する。Issue #20 では機能や抽象を先行実装しない。
- `flutter run` は端末状態に依存するため、再現可能な Web build と Widget テストを
  先に通し、その後に利用可能な端末で起動確認する。

## 完了条件

- Issue #20 の受け入れ条件をすべて満たす。
- `docs/ARCHITECTURE.md` の依存方向とパッケージ名に一致する。
- 既存アプリの表示と Widget テストの挙動が維持される。
- ルートから Pub Workspace 全体を依存解決・解析できる。
- `mise.toml` を変更して同期ツールを実行すると、全 SDK 制約が完全一致で更新される。
- 同期ツールの `--check` がローカルと CI で SDK 制約の不一致を検出できる。
- Melos に関する依存・設定・実行コマンドが追加されていない。
- サブエージェントのレビュー指摘が解消され、全品質ゲートが再実行済みである。
