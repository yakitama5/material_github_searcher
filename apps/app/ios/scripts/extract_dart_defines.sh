#!/bin/sh

# --dart-define-from-file で渡された flavor 設定値(apps/app/flavor/*.json)を
# Xcodeのビルド設定へ単一ソースのまま反映するためのスクリプト。
#
# Flutterは --dart-define-from-file の内容を base64 エンコードしたKEY=VALUEの
# カンマ区切りとして DART_DEFINES に格納する(Flutter/Generated.xcconfig 経由)。
# これをデコードし、Xcodeのビルド設定から読める xcconfig として書き出す。
OUTPUT_FILE="${SRCROOT}/Flutter/Environment.xcconfig"
: > "$OUTPUT_FILE"

function decode_url() { echo "${*}" | base64 --decode; }

IFS=',' read -r -a define_items <<<"$DART_DEFINES"

for index in "${!define_items[@]}"
do
    item=$(decode_url "${define_items[$index]}")
    # FlutterがDART_DEFINESへ自動で含めるFLUTTER_*系の項目はxcconfigの
    # 予約設定と衝突しビルドエラーになるため書き出し対象から除外する。
    lowercase_item=$(echo "$item" | tr '[:upper:]' '[:lower:]')
    if [[ $lowercase_item != flutter* ]]; then
        echo "$item" >> "$OUTPUT_FILE"
    fi
done
