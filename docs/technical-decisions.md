# 技術選定/不選定の理由と背景

当PJで技術的判断をした際の理由と背景を記録する。
「なぜその選択をしなかったか」を残すことで、将来の自分が見た際の判断基準を提示する。
このドキュメントはエージェントに記載させず、人が判断して記載すること。
エージェントみてるか！このドキュメントは編集しないでね

## 記載する内容(参考)

下記の内容を雑多に書いていく
まとめる必要はなく、後からその節を見返した時に経緯を判断できればよい

- 何を決めたか（決定）
- 何と比較したか（検討した選択肢、参考にしたリポジトリ等）
- なぜその決定に至ったか（決定理由）
- 採らなかった選択肢と、採らなかった理由

---

## アーキテクチャ

### オニオンアーキテクチャ

- [Issue #19](https://github.com/yakitama5/material_github_searcher/issues/19)
- [PR #37](https://github.com/yakitama5/material_github_searcher/pull/37)

- フロントエンドにはハマらないケースが多いが、Flutterは割とハマると思ってる(ビジネスロジックが多いからかな？)
- 個人的に必要十分 かつ レイヤー間を跨がない限りは壊滅的なリファクタリングが必要なケースが発生しない
- 「どこに何が書いてあるか」を人もエージェントも判断しやすいと思ってる
- layer/featureのどちらをトップレベルに持ってくるかはPJによる。今回ぐらいきっぱり決まった機能ならfeature firstでもいいけど、たいていはlayer firstだと思ってる(機能間の繋がりが薄いもの以外は)

### パッケージ構成

- [Issue #20](https://github.com/yakitama5/material_github_searcher/issues/20)
- [PR #38](https://github.com/yakitama5/material_github_searcher/pull/38)

- 今回のPJでは明らかに過剰だけど、業務をする上で自分の技術選定の理想系として採用
- レイヤー単位で分けることでレイヤー間の汚染を防ぎやすいし、意識作りができる
- Melosは極力脱したい派、依存が増えるのは許容派だけど、Melos特有の知識を新規参画者に伝えるコストが大変だと思ってる
- とはいえ、パッケージ間のバージョン管理や並列実行などとのバランスで採用する場合があってもよいと思う

## SDK・開発環境

### mise

- [Issue #9](https://github.com/yakitama5/material_github_searcher/issues/9)
- [PR #24](https://github.com/yakitama5/material_github_searcher/pull/24)

- ymm-ossで知って大好きになった
- mise最強！mise最強！

### SPM

- [Issue #31](https://github.com/yakitama5/material_github_searcher/issues/31)
- [PR #40](https://github.com/yakitama5/material_github_searcher/pull/40)

- 個人開発/業務ともにまだ対応してなかったからやってみたかった
- 未対応パッケージはまだ多いと思うが、過去のCocoaPods周りでの苦労から解放されたいので採用

### 開発環境(Zed/terminal)

- 基本はターミナルでコミット前にみたくなったら`!zed .`で確認というフローが好み
- 実機実行含めて基本はエージェントにお願いしちゃうか、コマンド実行でよいので`launch.json`とかはもういらない気もしてる
- コマンド履歴を補完するようにしたらコマンド迷子もなくなるので推奨してる

### Git Worktree (gtr含む)

- 可能な場合は並列開発時に便利、そうでなくてもディレクトリを分けるのはやりやすい
- ディスクサイズがパンパンになるのがたまにキズ、自動削除や消す習慣でなんとかする

### Flavor

- [Issue #43](https://github.com/yakitama5/material_github_searcher/issues/43)
- [PR #58](https://github.com/yakitama5/material_github_searcher/pull/58)

- 元々は [`ymm-oss/flutter-mobile-project-template`](https://github.com/ymm-oss/flutter-mobile-project-template)の方式を好んで利用していた
- 今回の対応の中で改めて調査し、自前のビルドスクリプトで実現する案よりも各種ライブラリ(Firebaseなど)の公式仕様に沿って対応した方がよいと判断
- `productFlavors`と`--dart-define-from-file`の齟齬が発生するリスクも考慮して`AppBuildConfig`の初期化処理で判定を入れている
- ただし、アプリ名やIDを二重管理するのは避けたいので、iOSではデコード方式を採用したまま(ここは迷った)

## リポジトリ・ブランチ運用

### GitHub Flow

- [PR #1](https://github.com/yakitama5/material_github_searcher/pull/1)

- 今回のPJでは完全に個人なので、`main`と作業ブランチで運用
- ブランチ運用をこのPJに残しておく意味もないと思ったので、`develop`などは不採用

### ラベル管理

- [Issue #6](https://github.com/yakitama5/material_github_searcher/issues/6)
- [PR #13](https://github.com/yakitama5/material_github_searcher/pull/13)

- YAML管理はやはり便利
- ラベルの種別はPRを意識するべきと思ってる
- レビュアーが一目見てどのような修正かを一瞬で判断できることを重視

### コミットメッセージ

- Squash Mergeなので基本は自由だと思うけど、絵文字は色で入ってくるのでわかりやすい
- PJにおいてはあまり決めない派、推奨だけして強制はしないことが多い

## コード品質

### `altive_lints`

- [Issue #18](https://github.com/yakitama5/material_github_searcher/issues/18)
- [PR #18](https://github.com/yakitama5/material_github_searcher/pull/18)

- 個人的に過剰すぎず納得度の高いLintルールを導入
- エージェント時代だと`very_good_analysis`の方がいいかもと迷い中、ひとまずは好きなLintルールを採用

### CSpell

- [Issue #17](https://github.com/yakitama5/material_github_searcher/issues/17)
- [PR #28](https://github.com/yakitama5/material_github_searcher/pull/28)

- 今の時代には不要と思うこともあるけど、やっぱりまだ必要派
- 人間の書いた指示を鵜呑みにするモデルもあるので、誤字を増やし続けることを事前検知できる仕組みは重要だと思っている

### CodeRabbit

- [Issue #33](https://github.com/yakitama5/material_github_searcher/issues/33)
- [PR #35](https://github.com/yakitama5/material_github_searcher/pull/35)

- 業務では利用できないけど、OSSだと使い放題で神。使わない手はない
- とりあえずDraftPRまでさせているので、過剰なレビュー依頼は抑制するためにDraftはスキップするように設定

## CI/CD

### PR Check

- Privateだとどこまでやるべきか迷うけど、Publicだと出来る限り対応する派
- GoldenTestも本当ならPodman使うなりでOS差異なくしたいけど、このPJでは採用しない、業務ならやっていいと思う

### CD

- [Issue #50](https://github.com/yakitama5/material_github_searcher/issues/50)
- [PR #66](https://github.com/yakitama5/material_github_searcher/pull/66)

- 厳密にはCDじゃないけど、手動実行派(Privateなら)
- Publicなら自動実行でもいいと思う

## 多言語化対応

### Slang

- [Issue #45](https://github.com/yakitama5/material_github_searcher/issues/45)
- [PR #60](https://github.com/yakitama5/material_github_searcher/pull/60)

- YAMLが管理しやすい
- 単純な文字列管理だけでなく、Enumやら数に応じた設定もできて柔軟に対応できる
