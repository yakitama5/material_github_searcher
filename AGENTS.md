# Material GitHub Searcher Agent Guide

このリポジトリでは Claude Code と Codex が同じ開発規約・スキル定義を共有する。
共通のエージェント・コマンド・スキル定義は `.agents/` を唯一の実体とし、
ツール固有ディレクトリには複製しない。

- `.claude` と `.codex` は `.agents` へのシンボリックリンク。
- `CLAUDE.md` は本ファイルへのシンボリックリンク。

## 会話・ドキュメント

会話とドキュメントは日本語、コード上の識別子は英語を使う。

## ブランチ戦略

GitHub Flow を採用する。`develop` は作らない。

- `main` は常にデプロイ可能な状態を保つ。
- 作業は `main` から都度ブランチを切り、完了したら `main` への PR でマージする。
- リリース列やステージング環境を前提とする `develop` 運用は、
  このプロジェクトの規模には運用コストが見合わないため採用しない。
  複数人開発やリリース管理が必要になった段階で再検討する。
- マージ後のブランチは削除し、作業ブランチは短命に保つ。

## 定義

- コミット: `.agents/skills/commit-changes/SKILL.md`
- PRレビューレポート: `.agents/skills/pr-review-report/SKILL.md`
