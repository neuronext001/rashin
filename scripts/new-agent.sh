#!/usr/bin/env bash
# 新しいユーザー独自エージェントを雛形から作成する。
#   使い方: scripts/new-agent.sh <名前>
#   例:      scripts/new-agent.sh summarizer
#            -> .claude/agents/my-agents/my-summarizer.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$ROOT/templates/agent-template.md"

if [ "$#" -lt 1 ]; then
  echo "使い方: scripts/new-agent.sh <名前>   (例: summarizer)" >&2
  exit 1
fi

# 入力を正規化: 小文字化 -> 連続空白を - に -> 先頭の my- を除去（最後に剥がすことで my-my- を防ぐ）
name="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[[:space:]]\{1,\}/-/g' -e 's/^my-//')"

# 小文字・数字・ハイフンのみ（先頭末尾ハイフン不可）を許可
if ! printf '%s' "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "エラー: 名前は小文字・数字・ハイフンのみにしてください（例: meeting-notes）。" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "エラー: 雛形が見つかりません: $TEMPLATE" >&2
  exit 1
fi

dest_dir="$ROOT/.claude/agents/my-agents"
dest="$dest_dir/my-$name.md"
mkdir -p "$dest_dir"

if [ -e "$dest" ]; then
  echo "エラー: すでに存在します: ${dest#"$ROOT"/}" >&2
  exit 1
fi

# {{NAME}} を置換して生成（BSD/GNU 両対応のため -i は使わない。name は [a-z0-9-] のみで安全）
sed "s/{{NAME}}/$name/g" "$TEMPLATE" > "$dest"

echo "作成しました: ${dest#"$ROOT"/}"
echo "次: このファイルを開いて description と本文を埋めてください。"
