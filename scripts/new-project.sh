#!/usr/bin/env bash
# 新しい案件フォルダを _journal.md つきで作成する。
#   使い方: scripts/new-project.sh <案件名>
#   例:      scripts/new-project.sh acme-contract
#            -> my-projects/acme-contract/_journal.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

if [ "$#" -lt 1 ]; then
  echo "使い方: scripts/new-project.sh <案件名>   (例: acme-contract)" >&2
  exit 1
fi

name="$1"
# フォルダ名のみを許可（パス区切り・先頭スラッシュ・先頭ドットを禁止）
case "$name" in
  ""|*/*|/*|.*) echo "エラー: 案件名はフォルダ名のみにしてください（/ や先頭の . は不可）。" >&2; exit 1;;
esac

dest_dir="$ROOT/my-projects/$name"
journal="$dest_dir/_journal.md"

if [ -e "$dest_dir" ]; then
  echo "エラー: すでに存在します: ${dest_dir#"$ROOT"/}" >&2
  exit 1
fi

mkdir -p "$dest_dir"
# 日付は信頼できる外部タイムソース（scripts/now.sh）から取得。失敗時のみローカル時計。
today="$("$SCRIPT_DIR/now.sh" '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d')"

# heredoc で生成（案件名は日本語など任意の文字を許容するため sed は使わない）
cat > "$journal" <<EOF
# $name — 作業記録（_journal）

> この案件の「目的・現在地・次の一手・経緯」を一枚で把握するための記録です。
> RASHIN のメインエージェントは、作業の再開時にまずこのファイルを読みます。

## 目的・背景
（この案件は何のためか。達成したいゴールは何か。）

## 現在の状態
（いまどこまで進んでいるか。最新の状態に上書きで保つ。）

## 次にやること / 未解決の論点
- [ ] （次の一手）

## 経緯・決定事項（新しいものを上に追記）
### $today
- 案件を開始した。
EOF

echo "作成しました: ${journal#"$ROOT"/}"
echo "この案件の成果物は ${dest_dir#"$ROOT"/} 配下に置いてください。"
