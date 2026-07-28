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

## ビルド

### Flavor

- [Issue #43](https://github.com/yakitama5/material_github_searcher/issues/43)
- [PR #58](https://github.com/yakitama5/material_github_searcher/pull/58)

#### 決定に至った背景

- 元々は [`ymm-oss/flutter-mobile-project-template`](https://github.com/ymm-oss/flutter-mobile-project-template)の方式を好んで利用していた
- 今回の対応の中で改めて調査し、自前のビルドスクリプトで実現する案よりも各種ライブラリ(Firebaseなど)の公式仕様に沿って対応した方がよいと判断
- `productFlavors`と`--dart-define-from-file`の齟齬が発生するリスクも考慮して`AppBuildConfig`の初期化処理で判定を入れている
