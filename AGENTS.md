# Material GitHub Searcher Agent Guide

このリポジトリでは Claude Code と Codex が同じ開発規約・スキル定義を共有する。
共通のエージェント・コマンド・スキル定義は `.agents/` を唯一の実体とし、
ツール固有ディレクトリには複製しない。

- `.claude` と `.codex` は `.agents` へのシンボリックリンク。
- `CLAUDE.md` は本ファイルへのシンボリックリンク。

## 会話・ドキュメント

会話とドキュメントは日本語、コード上の識別子は英語を使う。

## 定義

- コミット: `.agents/skills/commit-changes/SKILL.md`
- PRレビューレポート: `.agents/skills/pr-review-report/SKILL.md`
- ブランチ戦略: `docs/branching.md`
- エージェント活用開発フロー: `docs/agent-driven-development.md`

## 複数エージェントによる並列開発（git worktree runner）

複数のエージェントに並行して開発を行わせる際は `git gtr`（git worktree runner）を使い、
作業ブランチを worktree で分離する。ローカル環境には `gtr` コマンドがインストール済み。

- `git gtr new <branch>` : worktree を作成する。
- `git gtr ai <branch>` : 作成した worktree でエージェントを起動する。
- `git gtr rm <branch>` : worktree を削除する。

推奨運用は 1 Issue = 1 worktree とし、Issue ごとにブランチと worktree を分けて並行作業する。

worktree 作成時にコピーしたい未追跡ローカルファイル（`.env` 等）のパターンは、
リポジトリ直下の `.gtrconfig` の `gtr.copy.include` に設定する。
