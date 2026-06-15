#!/usr/bin/env bash
# RASHIN のバージョンチェックと更新。
#   ローカルの VERSION と GitHub(OSS) の最新を比較し、OSS が新しければ更新する。
#   更新は「追跡ファイル（フレームワーク部分）」だけ。my-* と .claude/agent-memory/ は
#   git 管理外なので一切変更されない（消えない・上書きされない）。
#
#   使い方:
#     scripts/update.sh           # チェックし、新しければ fast-forward 更新
#     scripts/update.sh --check   # チェックのみ（更新しない）
#
#   環境変数:
#     RASHIN_REPO   GitHub のスラッグ owner/repo（curl フォールバック用。既定は origin から推定）
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
cd "$ROOT"

check_only=0
[ "${1:-}" = "--check" ] && check_only=1

local_ver="$(tr -d ' \t\r\n' < VERSION 2>/dev/null || true)"
[ -z "$local_ver" ] && { echo "エラー: VERSION ファイルが読めません。" >&2; exit 1; }

# $1 > $2（厳密に新しい）なら gt を出力。semver をフィールドごとに数値比較（sort -V 非依存）。
ver_cmp() { awk -v a="${1#v}" -v b="${2#v}" 'BEGIN{na=split(a,x,".");nb=split(b,y,".");n=(na>nb?na:nb);for(i=1;i<=n;i++){xi=(i<=na?x[i]+0:0);yi=(i<=nb?y[i]+0:0);if(xi>yi){print"gt";exit}if(xi<yi){print"lt";exit}}print"eq"}'; }

branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
remote_ver=""

# 1) git remote(origin) から取得
if [ -d .git ] && git remote get-url origin >/dev/null 2>&1; then
  git fetch -q origin 2>/dev/null || true
  remote_ver="$(git show "origin/$branch:VERSION" 2>/dev/null | tr -d ' \t\r\n' || true)"
fi

# 2) だめなら raw.githubusercontent から取得（GitHub スラッグが分かる場合）
if [ -z "$remote_ver" ] && command -v curl >/dev/null 2>&1; then
  slug="${RASHIN_REPO:-}"
  if [ -z "$slug" ]; then
    url="$(git remote get-url origin 2>/dev/null || true)"
    case "$url" in
      *github.com*) slug="$(printf '%s' "$url" | sed -E 's#.*github\.com[:/]+##; s#\.git$##; s#/+$##')" ;;
    esac
  fi
  if [ -n "$slug" ]; then
    for b in "$branch" main master; do
      remote_ver="$(curl -fsS --max-time 8 "https://raw.githubusercontent.com/$slug/$b/VERSION" 2>/dev/null | tr -d ' \t\r\n')"
      [ -n "$remote_ver" ] && break
    done
  fi
fi

if [ -z "$remote_ver" ]; then
  echo "リモートのバージョンを取得できませんでした。" >&2
  echo "  GitHub の 'origin' リモート（git remote -v）と接続性を確認してください。" >&2
  echo "  git クローンでない場合は RASHIN_REPO=owner/repo を指定してください。" >&2
  exit 1
fi

echo "ローカル: v$local_ver  /  OSS: v$remote_ver"

if [ "$(ver_cmp "$remote_ver" "$local_ver")" != "gt" ]; then
  echo "最新です（更新は不要）。"
  exit 0
fi

echo "OSS の方が新しいバージョンです。"
if [ "$check_only" -eq 1 ]; then
  echo "（--check のため更新しません。更新するには引数なしで再実行）"
  exit 0
fi

# --- 更新（フレームワークのみ。my-* は gitignore で保護される）---
if [ ! -d .git ]; then
  echo "git クローンではないため自動更新できません。git clone での利用を推奨します。" >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "警告: 追跡ファイルにローカル変更があります。先に commit か stash をしてください。" >&2
  echo "（my-* と .claude/agent-memory/ は git 管理外なので、この警告とは無関係に保持されます）" >&2
  exit 1
fi

echo "更新中: origin/$branch へ fast-forward..."
if git merge --ff-only "origin/$branch" >/dev/null 2>&1; then
  new_ver="$(tr -d ' \t\r\n' < VERSION 2>/dev/null || echo "$remote_ver")"
  echo "更新しました: v$local_ver -> v$new_ver"
  echo "my-* と .claude/agent-memory/ は変更していません。"
else
  echo "fast-forward できませんでした（ローカルに独自コミットがある可能性）。" >&2
  echo "手動で 'git pull --rebase' などを確認してください。" >&2
  exit 1
fi
