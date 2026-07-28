#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DETECTOR="$SCRIPT_DIR/detect_ci_changes.sh"

readonly NONE=$'analyze=false\ntest=false\ncspell=false\nmarkdown_lint=false\npackage_dependencies=false'
readonly DOCS=$'analyze=false\ntest=false\ncspell=true\nmarkdown_lint=true\npackage_dependencies=false'
readonly DART=$'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=false'
readonly PUBSPEC=$'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=true'
readonly ALL=$'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=true\npackage_dependencies=true'

assert_paths() {
  local name="$1"
  local expected="$2"
  shift 2

  local actual
  actual="$(printf '%s\0' "$@" | bash "$DETECTOR")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nexpected:\n%s\nactual:\n%s\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_paths "unrelated file" "$NONE" LICENSE
assert_paths "documentation" "$DOCS" docs/ARCHITECTURE.md
assert_paths "Dart source" "$DART" packages/domain/lib/domain.dart
assert_paths "pubspec" "$PUBSPEC" packages/domain/pubspec.yaml
assert_paths \
  "lockfile" \
  $'analyze=true\ntest=true\ncspell=false\nmarkdown_lint=false\npackage_dependencies=true' \
  pubspec.lock

assert_paths \
  "dart-define flavor file" \
  $'analyze=true\ntest=true\ncspell=false\nmarkdown_lint=false\npackage_dependencies=false' \
  apps/app/flavor/development.json

assert_paths \
  "analysis config" \
  $'analyze=true\ntest=false\ncspell=true\nmarkdown_lint=false\npackage_dependencies=false' \
  analysis_options.yaml

assert_paths \
  "package dependency implementation" \
  $'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=true' \
  tools/src/package_dependency_checker.dart

assert_paths \
  "nested package dependency helper" \
  $'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=true' \
  tools/src/dependency_checker/yaml_reader.dart

assert_paths \
  "nested SDK sync helper" \
  $'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=true' \
  tools/src/sdk_sync/version_reader.dart

assert_paths \
  "future tool test" \
  $'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=true' \
  test/tools/new_validation_test.dart

assert_paths \
  "Analyze workflow itself" \
  $'analyze=true\ntest=false\ncspell=true\nmarkdown_lint=false\npackage_dependencies=false' \
  .github/workflows/analyze.yaml

assert_paths \
  "Test workflow itself" \
  $'analyze=false\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=false' \
  .github/workflows/test.yaml

assert_paths \
  "cspell workflow itself" \
  $'analyze=false\ntest=false\ncspell=true\nmarkdown_lint=false\npackage_dependencies=false' \
  .github/workflows/cspell.yaml

assert_paths \
  "Markdown Lint workflow itself" \
  $'analyze=false\ntest=false\ncspell=true\nmarkdown_lint=true\npackage_dependencies=false' \
  .github/workflows/markdown_lint.yaml

assert_paths \
  "Package Dependencies workflow itself" \
  $'analyze=false\ntest=false\ncspell=true\nmarkdown_lint=false\npackage_dependencies=true' \
  .github/workflows/check_package_dependencies.yaml

assert_paths \
  "Flutter setup" \
  $'analyze=true\ntest=true\ncspell=true\nmarkdown_lint=false\npackage_dependencies=true' \
  .github/actions/setup-flutter/action.yaml

assert_paths \
  "SDK setup" \
  $'analyze=true\ntest=true\ncspell=false\nmarkdown_lint=false\npackage_dependencies=true' \
  mise.toml

assert_paths \
  "generated Dart ignored only by cspell" \
  $'analyze=true\ntest=true\ncspell=false\nmarkdown_lint=false\npackage_dependencies=false' \
  packages/domain/lib/model.g.dart

assert_paths "shared detector" "$ALL" .github/scripts/detect_ci_changes.sh

actual_all="$(bash "$DETECTOR" --all)"
if [[ "$actual_all" != "$ALL" ]]; then
  printf 'FAIL: --all\nexpected:\n%s\nactual:\n%s\n' "$ALL" "$actual_all" >&2
  exit 1
fi

echo "All CI change detection scenarios passed."
