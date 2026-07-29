# Issue #45 Slangによる日本語・英語の多言語化基盤

## 目的

`slang` を利用した多言語化基盤を導入し、日本語・英語の表示を切り替えられるように
する。機能実装前に文字列管理のルールを確立し、今後の画面実装でハードコード文字列が
増えない状態にする。

## slang.yaml の導入範囲

`apps/app` のみに導入する。`packages/designsystem` は現時点でパッケージ固有の
翻訳対象文字列を持たず、導入すると Issue の対象外である「空リソース作成」に該当する
ため見送る。`designsystem` が翻訳が必要な Widget を持つ段階になった時点で改めて
導入を検討する。

## 依存関係

`docs/ARCHITECTURE.md` の方針に従い、`^` を使わず個別バージョンを固定する。

- `apps/app` の `dependencies`: `slang: 4.18.0`、`slang_flutter: 4.18.0`、
  `flutter_localizations`（Flutter SDK）
- `apps/app` の `dev_dependencies`: `slang_build_runner: 4.18.0`、
  `build_runner: 2.15.1`

`build_runner` は最新の `2.15.3` ではなく `2.15.1` を採用する。Pub Workspace は
全メンバーの依存を単一解決するため、ルートの `dev_dependencies` にある
`test: 1.31.0`（`analyzer >=8.0.0 <13.0.0` を要求）と、`build_runner 2.15.2`
以降が要求する `analyzer >=13.3.0` が競合し解決不能になる。`test` 側は
Flutter SDK が固定する `test_api 0.7.11` の都合で `1.31.0` から動かせないため、
`build_runner` を `analyzer >=8.0.0 <14.0.0` を要求する `2.15.1`
（`--workspace` フラグが正式版になった `2.14.0` 以降で、`test` と両立する
最後のバージョン）に固定して解決する。ルート `pubspec.yaml` 自体には
`build_runner` を追加する必要はない。Pub Workspace は全メンバーの依存関係を
単一の `.dart_tool/package_config.json` に解決するため、`apps/app` が
`build_runner` に依存していれば、リポジトリルートで実行しても解決できる。

## build_runner のルート実行

`docs/ARCHITECTURE.md` は「複数パッケージでテストや `build_runner` によるコード
生成が必要になった時点で、Melos の導入または単純なシェルスクリプトによる代替を
再検討する」としているが、本Issueで必要になるコード生成対象は `apps/app` 単体で
あり、複数パッケージを横断する処理ではない。そのため Melos は導入せず、
`build_runner` 2.11.0 で追加され 2.14.0 で正式化された `--workspace` フラグ
（Pub Workspace 配下の全パッケージを対象にビルドする機能）を使い、リポジトリ
ルートから次のコマンドで実行できるようにする。

```sh
mise exec -- dart run build_runner build --workspace -d
```

## 生成コードの扱い

生成された `*.g.dart` を `dart format --output=none --set-exit-if-changed` に
かけて差分が出ないことを確認したうえで、リポジトリにコミットする（gitignoreしない）。
参考リポジトリ（flutter-layer-template）も生成物をコミットしており、これに揃える。
これにより CI の `analyze`/`test`/`format` ジョブへコード生成ステップを追加する
必要がなく、既存のCI構成を変更せずに済む。`analysis_options.yaml` は既に
`**/*.g.dart` を解析対象外にしている。

## 設定ファイル: slang.yaml ではなく build.yaml を採用

Issueは `apps/app/slang.yaml` の追加を挙げているが、実装時に検証した結果
`slang_build_runner`（`build_runner` 経由のコード生成）は `slang.yaml` を
読み取らず、`input_file_pattern` 等の設定が無視されて既定値
（`.i18n.json` 拡張子想定）にフォールバックすることを実機検証で確認した。
slangの公式READMEも「`build.yaml` は `build_runner` を使う場合必須」と明記して
おり、また `build.yaml` は `dart run slang`（`build_runner` を使わない単体実行）
からも解釈されるため、設定の二重管理を避けるために `apps/app/build.yaml` の
`targets.$default.builders.slang_build_runner.options` へ設定を寄せ、
`slang.yaml` は追加しない。

参考リポジトリの設定から、本プロジェクトに存在しない `domain` の型を参照する
`imports`/`contexts`（`GoodsSortKey` 等）を除いた最小構成にする。

- `base_locale: ja`（アプリの主言語）
- `fallback_strategy: base_locale`（未対応ロケール・未翻訳文字列は日本語へfallback）
- `input_directory: assets/i18n`
- `output_directory: lib/i18n`
- `input_file_pattern: .i18n.yaml`
- `namespaces: true`（機能単位でファイルを分割）

## namespace 構成

現在実装済みの画面（カウンターのサンプル画面のみ）に対応する `common` namespace
のみを作成する。未実装機能向けの空 namespace は作らない。

## main.dart への組み込み

- `TranslationProvider` でラップし、`LocaleSettings.useDeviceLocale()` で端末
  ロケールを検出する。
- `MaterialApp` に `localizationsDelegates`（`GlobalMaterialLocalizations` 等 +
  `LocaleSettings.instance.flutterLocalizations`）と `supportedLocales` を設定する。
- 既存のハードコード文字列（ボタン説明文、tooltip 等）を `common` namespace の
  翻訳キーに置き換える。

## テスト

- `apps/app/test/widget_test.dart` の `AppBuildConfig` 結線を踏襲し、日本語・
  英語それぞれのロケールでWidgetの表示文字列を検証するテストを追加する。

## ドキュメント更新

- `docs/development.md`: ルートでのコード生成コマンドを追記する。
- `docs/testing.md`: 該当があれば翻訳のWidget Testについて触れる。
- `docs/ARCHITECTURE.md`: 本Issueが `build_runner` 導入のトリガーになったこと、
  対象が単一パッケージのため Melos は引き続き見送ることを追記する。

## 検証

- `mise exec -- dart format` で変更した Dart ファイルを整形する。
- `mise exec -- dart run build_runner build --workspace -d` でコード生成する。
- `mise exec -- flutter analyze` で静的解析を実行する。
- `mise exec -- flutter test`（`apps/app`）で既存・追加のWidget Testを実行する。
- iOS シミュレータで dev flavor を起動し、日本語表示・英語表示・未対応ロケールでの
  fallback表示を目視確認する。

## 対象外

- 機能未実装画面の翻訳
- ユーザーがアプリ内で言語を選択する設定画面
- `designsystem` パッケージへのslang導入
