#!/usr/bin/env bash

set -euo pipefail

# CI ごとの変更影響範囲を一元管理する。
#
# 通常は NUL 区切りの変更ファイル一覧を標準入力から受け取る。出力は reusable
# workflow の job outputs と、後続の PR Checker の双方で扱いやすい key=value 形式。
# main push では安全網を維持するため、呼び出し側から --all を指定して全 CI を実行する。

format=false
analyze=false
test=false
cspell=false
markdown_lint=false
package_dependencies=false

mark_all() {
  format=true
  analyze=true
  test=true
  cspell=true
  markdown_lint=true
  package_dependencies=true
}

if [[ "${1:-}" == "--all" ]]; then
  mark_all
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--all]" >&2
  exit 2
else
  while IFS= read -r -d '' path; do
    # 判定基盤そのものの変更は、分類漏れを防ぐため全 CI で検証する。
    # check_pr.yaml は全チェックのジョブ定義を1ファイルに集約しているため、
    # 差分だけではどのジョブが変わったか特定できず、同様に全 CI を対象にする。
    case "$path" in
      .github/workflows/detect_ci_changes.yaml | \
        .github/workflows/check_pr.yaml | \
        .github/scripts/detect_ci_changes.sh | \
        .github/scripts/test_detect_ci_changes.sh)
        mark_all
        ;;
    esac

    # cspell.jsonc の files と辞書設定に対応する。生成 Dart は ignorePaths と合わせる。
    case "$path" in
      *.md | *.yaml | *.yml)
        cspell=true
        ;;
      *.dart)
        if [[ "$path" != *.*.dart ]]; then
          cspell=true
        fi
        ;;
      cspell.jsonc | .cspell/*)
        cspell=true
        ;;
    esac

    case "$path" in
      *.md | .markdownlint-cli2.jsonc)
        markdown_lint=true
        ;;
    esac

    # dart format の対象は analyze と同じ Dart Workspace のソース・依存設定。
    # apps/app/build.yaml と assets/i18n/*.i18n.yaml は slang のコード生成入力で、
    # 変更しても再生成(*.g.dart への反映)を忘れると検知できないため対象に含める。
    case "$path" in
      *.dart | */pubspec.yaml | pubspec.yaml | */pubspec.lock | pubspec.lock | \
        mise.toml | .github/actions/setup-flutter/action.yaml | \
        apps/app/build.yaml | apps/app/assets/i18n/*.i18n.yaml)
        format=true
        ;;
    esac

    # Dart Workspace のソース・依存・解析設定は静的解析に影響する。
    case "$path" in
      *.dart | */pubspec.yaml | pubspec.yaml | */pubspec.lock | pubspec.lock | \
        analysis_options.yaml | apps/app/flavor/*.json | mise.toml | \
        .github/actions/setup-flutter/action.yaml | \
        apps/app/build.yaml | apps/app/assets/i18n/*.i18n.yaml)
        analyze=true
        ;;
    esac

    # Dart のテストコードも *.dart に含まれる。解析設定だけの変更では Test は不要。
    case "$path" in
      *.dart | */pubspec.yaml | pubspec.yaml | */pubspec.lock | pubspec.lock | \
        apps/app/flavor/*.json | mise.toml | .github/actions/setup-flutter/action.yaml | \
        apps/app/build.yaml | apps/app/assets/i18n/*.i18n.yaml)
        test=true
        ;;
    esac

    # 依存定義と、依存関係検査・SDK 同期処理自身の変更を検査対象にする。
    # Bash の case パターンでは * が / にも一致するため、将来のサブディレクトリも含む。
    case "$path" in
      */pubspec.yaml | pubspec.yaml | */pubspec.lock | pubspec.lock | \
        tools/*dependenc*.dart | tools/*sdk*sync*.dart | tools/*sync*sdk*.dart | \
        test/tools/*.dart | mise.toml | \
        .github/actions/setup-flutter/action.yaml)
        package_dependencies=true
        ;;
    esac
  done
fi

printf 'format=%s\n' "$format"
printf 'analyze=%s\n' "$analyze"
printf 'test=%s\n' "$test"
printf 'cspell=%s\n' "$cspell"
printf 'markdown_lint=%s\n' "$markdown_lint"
printf 'package_dependencies=%s\n' "$package_dependencies"
