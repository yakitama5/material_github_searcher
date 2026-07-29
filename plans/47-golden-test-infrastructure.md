# Issue #47 Golden Testの実行基盤と代表テストを追加

## 目的

Design Systemの見た目の意図しない変更を検出するため、`packages/designsystem` に
Golden Test の実行基盤を追加する。本 Issue では基盤と代表的な1コンポーネントの
テストまでを対象とし、全画面・全コンポーネントの Golden 化は行わない。

Issue: <https://github.com/yakitama5/material_github_searcher/issues/47>

## 調査結果

- `packages/designsystem` には現状 `lib/src/layout/breakpoints.dart`
  （`WindowSizeClass`/`Breakpoints`）しか存在せず、UI Widget は1つもない。
  「代表的な Design System コンポーネントを1件 Golden Test 化する」という完了条件を
  満たすには、本 Issue の中で最小限の新規 Widget を1つ作成する必要がある。
- `docs/testing.md` は「Golden Test・Patrol とも、本ドキュメント執筆時点では基盤を
  導入していない。基盤導入は別 Issue で行い、導入後に実行コマンドとディレクトリ構成を
  本ドキュメントへ追記する」としており、本 Issue がその「別 Issue」にあたる。
- 参考リポジトリ `yakitama5/flutter-layer-template` の `packages/designsystem` を調査した。
  - Golden Test ライブラリは **alchemist**（`^0.14.0`）を採用している。
  - `test/flutter_test_config.dart` で
    `AlchemistConfig(platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi))`
    を設定し、`--dart-define=CI=true` の有無でプラットフォーム Golden の生成有無を
    切り替えている（`isCi` は `bool.fromEnvironment('CI')` で判定）。
  - CI 実行コマンドは `flutter test --dart-define=CI=true`（`melos.yaml` の
    `test:ci:flutter`）。
  - Golden Test 専用 Tag は `@Tags(['golden'])` をテストファイル先頭に付与。
  - `.gitignore` で `test/**/goldens/**/*.*` と `test/**/failures/**/*.*` を除外しつつ
    `!test/**/goldens/ci/*.*` で CI Golden のみ Git 管理対象に戻している。
  - 代表コンポーネント（`ErrorView`）は `goldenTest` + `GoldenTestGroup` +
    `GoldenTestScenario` で複数シナリオを1ファイルにまとめている。
  - 本リポジトリは Melos 不採用（`docs/ARCHITECTURE.md`）のため、`melos run` 前提の
    コマンド体系はそのまま転用せず、`flutter test` を直接実行する形に置き換える。
- alchemist 本体の実装（`AlchemistConfig` のドキュメントコメント）を確認したところ、
  仕様は次のとおり。
  - CI Golden（`goldens/ci/` に生成される方）は **デフォルトで常に生成・比較され**、
    プラットフォーム間の描画差を避けるため **Ahem フォント固定・テキストは色付き
    ブロック表示**になる。
  - プラットフォーム Golden（`goldens/<platform>/`）は人が読める実際のレンダリングだが
    **デフォルトでは生成のみで比較はされない**。
    **【訂正・実装後追記】この記述は誤り。`enabled: true`（デフォルト）の
    `GoldensConfig` は生成だけでなく通常どおり比較まで行われることを、
    alchemist本体のソース（`goldenTest`/`GoldenTestRunner.run`）で確認した。
    後述の「CI実行方針の転換」で採用した最終方針（プラットフォームGoldenのみを
    比較対象にする）は、この訂正後の理解を前提にしても実際に見た目の回帰を
    検出できる設計になっている。**
  - つまり `PlatformGoldensConfig(enabled: !isCi)` は「比較の有無」ではなく
    「CI環境でプラットフォーム Golden を無駄に生成しない」ための最適化であり、
    決定性そのものは CI Golden のデフォルト仕様（Ahem 固定）が担保する。
    （この段落は導入検討時点の設計意図の記録。最終的にはCI Golden自体を
    使わない方針に転換したため、下記「CI実行方針の転換」を参照。）
  - この標準仕様（CI で比較する PNG は文字が読めないブロック表示になる）は
    ユーザー確認済み。実フォントロードは行わない。
- CI（`.github/workflows/check_pr.yaml`）の `test` ジョブは現状
  `working-directory: packages/designsystem` で単に `flutter test` を実行している
  （`--dart-define=CI=true` なし）。このままでは CI 上でも `isCi` が `false` になり、
  プラットフォーム Golden まで生成・評価対象になり得るため、「CI環境で決定的に比較
  できる」という完了条件を満たすには **この行の変更が必須**。
- `packages/domain`・`packages/application` は現状 export のみの空パッケージで、
  例外型などの共通型は存在しない。代表コンポーネントを外部型に依存させると
  この Issue の対象外である「検索機能固有」実装に踏み込みかねないため、
  外部型に依存しないコンポーネントを選ぶ。

## 実装方針

### スコープの線引き（意図的な判断）

添付いただいたイメージ（リポジトリ詳細画面の「言語 / スター / ウォッチ / フォーク /
イシュー」の行）は GitHub リポジトリの統計表示そのものだが、これを
「検索機能固有」の Widget にしてしまうと Issue の対象外に抵触する。そのため、
代表コンポーネントは次の設計にすることで **designsystem の汎用 UI 部品** として
スコープ内に収める。

- 受け取るのは `IconData`・`Color`・`String` の**プリミティブのみ**。リポジトリや
  スター数などのドメイン知識を一切持たない。
- 数値のフォーマット（`143K` のような整形）は行わない。値は呼び出し側が完成済みの
  `String` として渡す。
- 名前は用途（リポジトリ統計）ではなく形状（アイコン + ラベル + 値の1行）で付ける。
  仮称 `MetaInfoRow`（プラン確定時に最終決定。他候補: `IconLabelValueRow`）。

この線引きを行った理由をコード上にも一言コメントで残す想定（実装フェーズで対応）。

### 採用ライブラリ: alchemist

- `packages/designsystem` の `dev_dependencies` に `alchemist: 0.14.0` を追加する
  （`docs/ARCHITECTURE.md` の方針に従いキャレット等は付けず完全固定バージョンにする）。
- SDK制約は `sdk: '>=3.8.0 <4.0.0'` / `flutter: '>=3.32.0'` で、本リポジトリの
  `sdk: 3.12.2` / `flutter: 3.44.8` を満たす。

### 代表コンポーネント: `MetaInfoRow`（仮称）

- 配置: `packages/designsystem/lib/src/widgets/meta_info_row.dart`
- API 案:

  ```dart
  class MetaInfoRow extends StatelessWidget {
    const MetaInfoRow({
      required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      super.key,
    });

    final IconData icon;
    final Color iconColor;
    final String label;
    final String value;

    @override
    Widget build(BuildContext context) { ... }
  }
  ```

  見た目は添付イメージに合わせ、色付きの円形アイコン + ラベル（左寄せ）+
  値（右寄せ）の1行とする。詳細な余白・タイポグラフィは実装時に調整可。
- `packages/designsystem/lib/designsystem.dart` に export を追加する。

### Golden Test シナリオ（最小限）

基盤の疎通確認が目的のため、シナリオ数は絞る。

1. 標準ケース（例: 「言語」「Dart」、globe アイコン）
2. 長いラベル・値でのテキスト折り返し/オーバーフロー確認
3. 異なるアイコン色（例: 「スター」「143K」、星アイコン・黄色）

`goldenTest` + `GoldenTestGroup` + `GoldenTestScenario` で1ファイルにまとめ、
各シナリオは `SizedBox` で幅・高さを固定して包む（`docs/testing.md` の
「画面幅に応じた Widget Test」と同様に、テスト対象の表示領域を明示的に固定する
考え方を踏襲）。

### 完了条件・対応内容とのトレーサビリティ

**【実装後注記】以下の表はプラン確定時点（実装方針）の対応内容であり、
「CI環境で決定的に比較できる」を含む一部はDraft PR作成後に方針転換した。
最終的な対応内容は後述の「CI実行方針の転換（Draft PR作成後）」を参照。**

| Issue記載 | 対応 |
| --- | --- |
| Golden Test用ライブラリを導入する | `packages/designsystem/pubspec.yaml` に `alchemist: 0.14.0` を追加 |
| designsystemパッケージへ共通テスト設定を追加する | `packages/designsystem/test/flutter_test_config.dart` を新規作成 |
| CIとローカルの描画差を吸収できる構成にする | alchemist標準のCI Golden（Ahemフォント固定）を採用。加えて `flutter_test_config.dart` で `PlatformGoldensConfig(enabled: !isCi)` によりCI環境でのプラットフォームGolden生成を止める |
| Golden Testへ専用Tagを付与する | テストファイルに `@Tags(['golden'])`、`test/dart_test.yaml` にタグ定義を追加 |
| Golden Test実行・更新コマンドを追加する | `docs/testing.md` に実行/更新/除外コマンドを追記（下記コマンド体系参照） |
| フォント、locale、画面サイズを固定する | フォント: alchemistのCI Golden既定（Ahem）を採用。画面サイズ: 各シナリオを`SizedBox`で固定。locale: alchemistのシナリオラッパーに準拠して固定指定する（実装時に具体的な注入方法を確認） |
| 代表的なDesign Systemコンポーネントを1件Golden Test化する | `MetaInfoRow`（仮称）を新規作成し、3シナリオでGolden Test化 |
| Golden画像の更新ルールを文書化する | `docs/testing.md` の「Golden Test と Patrol の位置付け」を更新 |
| ✅ Golden Testを共通コマンドで実行できる | `flutter test --tags=golden` |
| ✅ Golden画像を共通コマンドで更新できる | `flutter test --tags=golden --update-goldens` |
| ✅ 代表コンポーネントのGolden Testが追加されている | `MetaInfoRow` の Golden Test |
| ✅ CI環境で決定的に比較できる | `check_pr.yaml` の designsystem テストステップに `--dart-define=CI=true` を追加 |
| ✅ Golden画像のレビュー・更新ルールが記載されている | `docs/testing.md` に追記 |
| ✅ 通常テストとGolden TestをTagで区別できる | `--tags=golden` / `--exclude-tags=golden` |

### ディレクトリ構成

**【実装後注記】下記構成図もプラン確定時点のもの。最終的には `goldens/ci/` は
使わず `goldens/macos/`（生成環境固有、Git管理）のみになった。詳細は
「CI実行方針の転換（Draft PR作成後）」を参照。**

```text
packages/designsystem/
  .gitignore                          # 新規: platform golden を除外、ci goldenのみ管理
  pubspec.yaml                        # 更新: alchemist追加
  lib/
    designsystem.dart                 # 更新: MetaInfoRow を export
    src/
      widgets/
        meta_info_row.dart            # 新規
  test/
    dart_test.yaml                    # 新規: golden タグ定義
    flutter_test_config.dart          # 新規: AlchemistConfig 設定
    widgets/
      meta_info_row_test.dart         # 新規: @Tags(['golden'])
      goldens/
        ci/
          meta_info_row.png           # 新規: alchemistが生成、Git管理対象
```

### `.gitignore`（新規、参考実装を踏襲）

```gitignore
# alchemistのプラットフォームgoldenは環境依存のため管理対象外とする。
# CI golden(goldens/ci/)のみgit管理する。
test/**/goldens/**/*.*
test/**/failures/**/*.*
!test/**/goldens/ci/*.*
```

### `test/dart_test.yaml`（原則作成しない）

参考実装（`flutter-layer-template`）には存在しないファイルであり、まずは
`dart_test.yaml` なしで `@Tags(['golden'])` のみ実装する。`flutter test` 実行時に
未定義タグの警告が実際に出た場合のみ、後追いで `golden` タグを宣言する
`dart_test.yaml` を追加する。

### `test/flutter_test_config.dart`（新規）

参考実装と同じ考え方を採用する。

```dart
import 'dart:async';

import 'package:alchemist/alchemist.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // ignore: do_not_use_environment
  const isCi = bool.fromEnvironment('CI');

  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi),
    ),
    run: testMain,
  );
}
```

### CIワークフローの変更

`.github/workflows/check_pr.yaml` の `test` ジョブ内、designsystem を実行する
ステップのみ変更する（Golden Testを持つのは designsystem のみのため、他パッケージ・
`apps/app` への追加は行わない）。

```diff
       - name: Test designsystem package
         working-directory: packages/designsystem
-        run: flutter test
+        run: flutter test --dart-define=CI=true
```

### コマンド体系（`docs/testing.md` に追記）

```sh
cd packages/designsystem

# 通常のWidget Test・Unit Testのみ実行（Golden Testを除外）
flutter test --exclude-tags=golden

# Golden Testのみ実行
flutter test --tags=golden

# Golden画像を更新
flutter test --tags=golden --update-goldens

# 全テスト実行（CI相当、決定的に比較する場合）
flutter test --dart-define=CI=true
```

### ドキュメント更新

`docs/testing.md` の「Golden Test と Patrol の位置付け」節を更新し、次を追記する。

- 採用ライブラリ（alchemist 0.14.0）
- ディレクトリ構成（`test/**/goldens/ci/` のみGit管理、他は `.gitignore` 対象）
- 実行・更新・除外コマンド（上記コマンド体系）
- CI Golden の既定仕様（Ahemフォント固定・テキストは色付きブロック表示になり、
  人が目視でレビューする対象ではあるが読める文字にはならない旨）の明記
- Golden画像の更新ルール: 意図した見た目の変更であることをPR説明で明記した上で
  `--update-goldens` を実行し、差分画像を確認してからコミットする
- `@Tags(['golden'])` の付与ルールと `--exclude-tags=golden` / `--tags=golden` の
  使い分け

新規英単語（`alchemist`、`goldens` 等）は `.cspell/project-term.txt` に追加する
（現状未登録であることを確認済み）。

## 実装手順

1. `packages/designsystem/pubspec.yaml` に `alchemist: 0.14.0` を追加し、
   `flutter pub get` で解決を確認する。
2. `packages/designsystem/lib/src/widgets/meta_info_row.dart` を作成し、
   `lib/designsystem.dart` から export する。
3. `packages/designsystem/test/dart_test.yaml` と `flutter_test_config.dart` を作成する。
4. `packages/designsystem/test/widgets/meta_info_row_test.dart` を
   `@Tags(['golden'])` 付きで作成し、3シナリオを実装する。
5. `packages/designsystem/.gitignore` を作成する。
6. `flutter test --tags=golden --update-goldens` を実行し、
   `test/widgets/goldens/ci/*.png` を生成する。生成された画像を目視確認する。
7. `flutter test`（designsystem 全体）・`flutter test --dart-define=CI=true` の
   両方がローカルで成功することを確認する。
8. `.github/workflows/check_pr.yaml` の designsystem テストステップに
   `--dart-define=CI=true` を追加する。
9. `docs/testing.md` を更新する。
10. 新規英単語を `.cspell/project-term.txt` に追加する。
11. `dart analyze --fatal-infos`、`dart format --output=none --set-exit-if-changed`、
    `npx markdownlint-cli2`、`npx cspell` を実行し通過を確認する。
12. Draft PR を作成し、CI（`check_pr.yaml`）が実際に Golden Test込みで
    決定的にグリーンになることを確認する。

## 品質ゲート

- `packages/designsystem` で `flutter test` が成功する。
- `flutter test --tags=golden` で Golden Test のみが実行される。
- `flutter test --exclude-tags=golden` で Golden Test がスキップされ、他のテストのみ
  実行される。
- `flutter test --dart-define=CI=true` をローカルで実行した結果と、CI上の実行結果が
  一致する（同じ Golden 画像で差分が出ない）。
- `dart analyze --fatal-infos` が通る。
- `dart format --output=none --set-exit-if-changed` が通る。
- `dart tools/check_package_dependencies.dart` が通る
  （`designsystem` → `alchemist` は dev_dependency のため依存関係図に影響しないことを
  確認する）。
- `npx markdownlint-cli2`・`npx cspell` が更新した Markdown に対して成功する。
- Issueの完了条件6項目すべてに対応済み（上記トレーサビリティ表を参照）。

## 実装時の差分（実装後の追記）

計画段階では判明していなかった、実装中に確認・修正した点を記録する。

- **アイコンはCI Goldenでブロック化されない**: `obscureText` はテーマの
  `TextStyle.fontFamily` を `Ahem` に置き換える実装のため、`Icon(IconData)`
  は影響を受けず実際のアイコングリフのまま描画されることを実測で確認した。
  「見た目の回帰検出」という目的は当初の想定どおり成立する。
- **`test/dart_test.yaml` では効かない**: `dart_test.yaml` は `test/` 配下ではなく
  パッケージルート（`packages/designsystem/dart_test.yaml`）に置く必要があった。
  また、`flutter test`（`--tags`/`--exclude-tags` を付けない全件実行）で実際に
  「未定義タグ」警告が発生したため、当初の合意どおり追加した。
- **シナリオラッパーは `Scaffold` ではなく `Material` を使う**: `Scaffold` を
  `SizedBox` で固定した領域の中に置くと、`Scaffold` 内部の `Overlay` が unbounded
  height を要求してレイアウト例外になった。参考実装と同様、`Material` に留める。
- **altive_lints（4.0.0）のカスタムルールの ignore 構文は `altive_lints_plugin/`
  接頭辞が必要**: README記載の `altive_lints/{rule_name}` は導入バージョンでは
  古い表記で、実際には `// ignore: altive_lints_plugin/avoid_hardcoded_color`
  が必要だった。
- **プラットフォーム Golden 未生成時の初回失敗**: プラットフォーム Golden は
  Git 管理しないため、初回や削除直後は `--dart-define=CI=true` なしの
  `flutter test` が失敗する。`docs/testing.md` に対応（`--update-goldens` を
  一度実行する）を追記した。

## フレッシュエージェントによるレビューと対応

実装完了後、新規コンテキストのエージェントに差分レビューを依頼し、指摘2件に
実装で対応した。

- **バグ**: `MetaInfoRow` の `value` の `Text` が `Expanded`/`Flexible` で
  幅制約されておらず、`overflow: TextOverflow.ellipsis` が機能していなかった
  （長い `value` で `RenderFlex overflowed` 例外が発生することをレビュー側が実測）。
  `Flexible` で包んで修正し、あわせてシナリオ3の `value` を短い数値文字列から
  実際にオーバーフローする長さの文字列に変更し、Golden Testがこの不備を
  検出できるようにした。
- **ドキュメント不整合**: `docs/testing.md` に「`MaterialApp` の `locale:` で
  固定する」と書いたが、`supportedLocales` 未指定では既定の `en_US` に
  フォールバックし実際には `ja` が反映されていなかった（レビュー側が
  `Localizations.maybeLocaleOf` で実測）。`flutter_localizations` を
  designsystemの `dev_dependencies` に追加し、`GlobalMaterialLocalizations.delegates`
  と `supportedLocales: [Locale('ja')]` を明示することで実際に `ja` が
  解決されることを確認し、`docs/testing.md` の記述も補足した。

## CI実行方針の転換（Draft PR作成後）

Draft PR作成後、CI（`check_pr.yaml`）の `Test` ジョブが実際に失敗した
（「初回のGolden画像がCIで一致しない可能性」として下記リスク欄に記載していた
懸念が的中した）。

- **事象**: ローカル(macOS)で生成しコミットした CI Golden
  (`goldens/ci/meta_info_row.png`) と、GitHub Actions runner(Linux)上で
  実際に描画した結果が0.52%(562px)一致しなかった。alchemist の CI Golden は
  文字列を `Ahem` フォント固定のブロック表示にしてプラットフォーム間の描画差を
  吸収する仕組みだが、`MetaInfoRow` の見た目の主な検証対象である
  `CircleAvatar`（円形）と `Icon`（グリフ）はテキストではないためこの吸収の
  対象外で、アンチエイリアシングの描画差が macOS と Linux の間でそのまま
  残ってしまうことが原因だった。
- **さらに判明した設計上の不備**: `flutter_test_config.dart` は
  `platformGoldensConfig` のみ上書きしており `ciGoldensConfig` は常に
  `enabled: true`（既定値）のままだった。そのため CI Golden はローカル(macOS)と
  CI(Linux)の両方で比較される状態になっており、どちらか一方の環境で生成した
  画像をコミットしても、もう一方の環境では必ず失敗する構造的な欠陥があった。
- **検討した選択肢**: (a) Docker で Linux 環境を用意し CI Golden をそこで生成、
  (b) GitHub Actions 上で一時的に `--update-goldens` を実行しartifactとして
  取得、(c) CI runner を `macos-latest` に変更、(d) `diffThreshold` で微小差を
  許容、(e) CI での Golden Test 実行自体をやめ、ローカルでの事前確認のみに
  限定する。(a)(c)は継続的な運用コスト（Docker管理、GitHub Actionsのmacosランナー
  課金レートの高さ）が今回の規模に見合わない。(d)は実測ベースで「アイコン1個が
  丸ごと変色する規模の回帰」と「今回のノイズ」がほぼ同じ大きさ（画像全体の
  0.4〜0.5%程度）であり、検出力を保てないと判断した。
- **決定**: (e) を採用。個人開発で PR 作成者がそのままレビューも行う運用のため、
  「コミット前にローカルで Golden Test を実行して見た目の変化に気づく」運用で
  実用上十分と判断し、ユーザーが明示的にこの判断を承認した。
  - `flutter_test_config.dart`: `ciGoldensConfig: CiGoldensConfig(enabled: false)`
    とし、CI Golden(Ahem)自体を使わない。プラットフォーム Golden（実フォント・
    実アイコン、人が読める画像）のみを比較対象にする。
  - `check_pr.yaml`: `--dart-define=CI=true` を削除し、
    `flutter test --exclude-tags=golden` として Golden Test を CI から除外する。
  - `.gitignore`: プラットフォーム Golden を Git 管理対象に変更する（従来の
    「CI Goldenのみ管理」から「プラットフォームGoldenを管理し、生成環境に依存する
    ことを許容する」方針に転換）。
  - `docs/testing.md`: 上記方針とローカルでの実行を徹底する運用ルールを明記する。
- **完了条件への影響**: 当初の完了条件「CI環境で決定的に比較できる」は、この
  方針転換により満たさなくなった。CIでの強制力を手放す代わりに得られるのは
  「実フォント・実アイコンで人が読める、ローカルレビュー向けの Golden 画像」
  というシンプルな構成である。将来チーム開発になる、または Golden 化する
  コンポーネントが増えて重要度が上がった場合は、CI runner を `macos-latest`
  にする等の再導入を検討する余地を残す。

## リスクと対応

- **CI Golden（Ahemフォント固定）下でテキストが色付きブロック化すると、
  `MetaInfoRow` の見た目の差分検出手段はアイコン（`CircleAvatar`の色 + `Icon`の
  グリフ）だけになる。もし `Icon(IconData)` もブロック/tofu化してしまう場合、
  この代表コンポーネントのGolden Testはレイアウトの箱組みしか検証できず、
  意図した「見た目の回帰検出」という価値が薄くなる**: 実装手順6（Golden画像を
  初めて生成した直後）で、アイコンが実際のMaterial Iconsグリフとして描画されて
  いるかを最初に目視確認する。ブロック化していた場合は、シナリオ構成やアイコンの
  検証方法（例: 色のみで判定する設計に寄せる等）を見直す。
- **初回のGolden画像がCIで一致しない可能性**: ローカルで生成した
  `goldens/ci/*.png` は Ahem フォント固定のため理論上プラットフォーム非依存だが、
  念のため Draft PR 作成後に CI 実行結果を確認し、差分が出た場合は CI 上で
  `--update-goldens` 相当の対応（画像を再生成しコミット）を取る。
- **`MetaInfoRow` という仮称が最終的な命名と異なる可能性**: プランレビュー時に
  ユーザーに最終確認し、実装前に確定する。
- **alchemist が今後 designsystem 以外のパッケージにも波及した場合の対応**:
  本Issueでは `check_pr.yaml` の変更を designsystem ステップのみに限定する。
  他パッケージで Golden Test を追加する際は、そのパッケージのテストステップにも
  同様に `--dart-define=CI=true` を追加する必要がある旨を `docs/testing.md` に
  一言残す。
