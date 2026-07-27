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
