# 技術選定/不選定の理由と背景

当PJで技術的判断をした際の理由と背景を記録する。
「なぜその選択をしなかったか」を残すことで、将来の自分が見た際の判断基準を提示する。
このドキュメントはエージェントに記載させず、人が判断して記載すること。

エージェントみてるか！
このドキュメントは編集しないでね

## 記載する内容(参考)

下記の内容を雑多に書いていく
まとめる必要はなく、後からその節を見返した時に経緯を判断できればよい

- 何を決めたか（決定）
- 何と比較したか（検討した選択肢、参考にしたリポジトリ等）
- なぜその決定に至ったか（決定理由）
- 採らなかった選択肢と、採らなかった理由

---

## AI駆動開発

### Claude Code / Codex

#### なぜその決定に至ったか（決定理由）

- 今回の対応はClaudeCode/Codexを利用して対応した
- それぞれ下記のようなフローで実施
  - ClaudeCode: メイン(Sonnet 5 High), アドバイザー(Opus 5 High)
  - Codex: メイン(GPT-5.6 Terra Max), アドバイザー(GPT5.6 Sol Medium)
  - Codex(7/31以降): メイン(GPT-5.6 Luna Max), アドバイザー(GPT5.6 Sol High)
- AIは日々進化し、進め方のベストプラクティスが翌週には変わっているなんてことも多いので、PJ側でサブエージェントやルールで縛らない設計とする
- とはいえ、初学者が迷わないように推奨する方針は、 `agent-driven-development.md`に記載

## アーキテクチャ

### オニオンアーキテクチャ

[Issue #19](https://github.com/yakitama5/material_github_searcher/issues/19)

[PR #37](https://github.com/yakitama5/material_github_searcher/pull/37)

#### なぜその決定に至ったか（決定理由）

- フロントエンドにはハマらないケースが多いが、Flutterではかなり機能すると思っている
  - ビジネスロジックが多いから？
  - Firestoreなどの利用が多いから？
- 個人的に必要十分 かつ レイヤー間を跨がない限りは壊滅的なリファクタリングが必要なケースが発生しない
  - エージェントが人間が処理不可能な速度で生成してもコントロールしやすい
- 「どこに何が書いてあるか」を人もエージェントも判断しやすいと思ってる

### パッケージ構成 (layer first)

[Issue #20](https://github.com/yakitama5/material_github_searcher/issues/20)

[PR #38](https://github.com/yakitama5/material_github_searcher/pull/38)

#### 何と比較したか（検討した選択肢、参考にしたリポジトリ等）

- 今回の要件では `feature first` な構造でも問題ないとは思う
- 業務で利用するものは往々にして機能間の横断や責務が変わることが多いので、業務を意識して `layer first` で構成することを選択

#### なぜその決定に至ったか（決定理由）

- layer/featureのどちらをトップレベルに持ってくるかはPJによると思う。
- レイヤー単位で分けることでレイヤー間の汚染を防ぎやすいし、意識作りができる

#### 採らなかった選択肢と、採らなかった理由

- Melos
  - Pub Workspaceの登場以降は極力脱したい派
  - 依存が増えるのは許容できるが、Melos特有の知識を新規参画者に伝えるコストが大変だと思ってる
  - とはいえ、パッケージ間のバージョン管理や並列実行などとのバランスで採用する

## SDK・開発環境

### mise

[Issue #9](https://github.com/yakitama5/material_github_searcher/issues/9)

[PR #24](https://github.com/yakitama5/material_github_searcher/pull/24)

#### 採らなかった選択肢と、採らなかった理由

- fvm
  - 元はFVMを利用していたが、Tasksなどの利便性もありmiseに乗り換えている

### SPM

[Issue #31](https://github.com/yakitama5/material_github_searcher/issues/31)

[PR #40](https://github.com/yakitama5/material_github_searcher/pull/40)

#### なぜその決定に至ったか（決定理由）

- 個人開発/業務ともにまだ対応してなかったからやってみたかった
- 未対応パッケージはまだ多いと思うが、過去のCocoaPods周りでの苦労から解放されたいので採用

### 開発環境(Zed/terminal)

[Zed](https://zed.dev)

[Ghosty](https://ghostty.org)

Windowsの場合は[Cmder](https://cmder.app)

#### なぜその決定に至ったか（決定理由）

- AI駆動開発が主流になった最近ではこの構成で開発することが多い
- どちらも軽量で並列開発に向いていると思っている
- Zed自体もあまり起動することはなく、ファイル配置や気に入らない部分を手動で直したくなったら利用する程度
- Windows/Macに関わらず、pecoなどを用いたコマンド履歴保管ツールを入れることで、複雑なコマンドも迷子にならず開発できる

### Git Worktree (gtr含む)

[git-worktree-runner](https://github.com/coderabbitai/git-worktree-runner)

#### なぜその決定に至ったか（決定理由）

- 可能な場合は並列開発時に便利、そうでなくてもディレクトリを分けるのはやりやすい
- ディスクサイズがパンパンになるのがたまにキズ、自動削除や消す習慣でなんとかする

### Flavor

[Issue #43](https://github.com/yakitama5/material_github_searcher/issues/43)

[PR #58](https://github.com/yakitama5/material_github_searcher/pull/58)

#### なぜその決定に至ったか（決定理由）

- 元々は [`ymm-oss/flutter-mobile-project-template`](https://github.com/ymm-oss/flutter-mobile-project-template)の方式を好んで利用していた
- 今回の対応の中で改めて調査し、自前のビルドスクリプトで実現する案よりも各種ライブラリ(Firebaseなど)の公式仕様に沿って対応した方がよいと判断
- `productFlavors`と`--dart-define-from-file`の齟齬が発生するリスクも考慮して`AppBuildConfig`の初期化処理で判定を入れている
- ただし、アプリ名やIDを二重管理するのは避けたいので、iOSではデコード方式を採用したまま(ここは迷った)

## リポジトリ・ブランチ運用

### GitHub Flow

[PR #1](https://github.com/yakitama5/material_github_searcher/pull/1)

#### なぜその決定に至ったか（決定理由）

- 今回のPJでは完全に個人なので、`main`と作業ブランチで運用
- ブランチ運用をこのPJに残しておく意味もないと思ったので、`develop`などは不採用

### ラベル管理

[Issue #6](https://github.com/yakitama5/material_github_searcher/issues/6)

[PR #13](https://github.com/yakitama5/material_github_searcher/pull/13)

#### なぜその決定に至ったか（決定理由）

- YAMLはやはり管理しやすい
- ラベルの種別はIssueよりも、PRを意識するべきと思ってる
- レビュアーが一目見てどのような修正かを一瞬で判断できることを重視

### コミットメッセージ

#### なぜその決定に至ったか（決定理由）

- Squash Mergeなので基本は自由だと思う
- 視覚的にも絵文字は「色」で入ってくるのでわかりやすい
- PJにおいてはあまり決めない派。PLの立場では「推奨」に留めるが、強制はしないことが多い

## コード品質

### `altive_lints`

[Issue #18](https://github.com/yakitama5/material_github_searcher/issues/18)

[PR #18](https://github.com/yakitama5/material_github_searcher/pull/18)

#### なぜその決定に至ったか（決定理由）

- 過剰すぎず納得度の高いLintルールを導入
- [いち早くAnalyzer Pluginsに移行されていた](https://zenn.dev/riscait/articles/analysis-server-plugin)のですごく信頼性を持って利用している

#### 採らなかった選択肢と、採らなかった理由

- [very_good_analysis](https://pub.dev/packages/very_good_analysis)
  - 昔は過剰だと思っていたが、エージェント時代ではこちらがよいかも？と迷い始めてる

### CSpell

[Issue #17](https://github.com/yakitama5/material_github_searcher/issues/17)

[PR #28](https://github.com/yakitama5/material_github_searcher/pull/28)

#### なぜその決定に至ったか（決定理由）

- 今の時代には不要と思うこともあるけど、やっぱりまだ必要。
- 人間の書いた指示を鵜呑みにするモデルもあるので、誤字を増やし続けることを事前検知できる仕組みは重要

### CodeRabbit

[Issue #33](https://github.com/yakitama5/material_github_searcher/issues/33)

[PR #35](https://github.com/yakitama5/material_github_searcher/pull/35)

#### なぜその決定に至ったか（決定理由）

- 個人開発(OSS)では大変お世話になる存在、使わない手はない
- Claude Code/Codexのエージェントとのやり取りはみているだけで楽しい
- 基盤構築や複雑な機能の場合は、DraftPR→人力レビュー→CodeRabbitとしたいので、過剰なレビュー依頼は抑制するためにDraftはスキップするように設定

## CI/CD

### PR Check

#### なぜその決定に至ったか（決定理由）

- Organization内のPrivateリポジトリの場合はある程度絞って選択するべき
- Publicリポジトリの場合、GitHub Actionsの制限もないので出来る限り対応した方がよいと思っている(試金石としても)
- 本来であれば、GoldenTestもPodman使うなりでOS差異なくしたいけど、このPJでは採用しない、業務ならやるべき

### CD

[Issue #50](https://github.com/yakitama5/material_github_searcher/issues/50)

[PR #66](https://github.com/yakitama5/material_github_searcher/pull/66)

#### なぜその決定に至ったか（決定理由）

- 厳密にはCDじゃないけど、手動実行派(Privateリポジトリの場合)
- Publicなら自動実行でもいいと思う

## 多言語化対応

### Slang

[Issue #45](https://github.com/yakitama5/material_github_searcher/issues/45)

[PR #60](https://github.com/yakitama5/material_github_searcher/pull/60)

#### なぜその決定に至ったか（決定理由）

- YAMLが管理しやすい
- 単純な文字列管理だけでなく、Enumやら数に応じた設定もできて柔軟に対応できる

## デザイン

### Material 3 (Expressiveを含む)

#### なぜその決定に至ったか（決定理由）

- Androidユーザーということもあり、MD3はかなり好み
- 特に少数派に対する考慮がしっかりしており、配色ルールなど含めて非常にわかりやすい
- [過去に記事を書いたこともあり](https://qiita.com/yakuran1/items/e6dbd8a0710d3cbb8fe2)、極力MD3に沿った対応としている

#### 雑記

- material/cupertinoのコア分離の対応まで、Expressiveへの対応が後回しになってるのが少し残念
- Flutterの強みとは逸れるが、Google製ということもありMD3の対応は期待したい
