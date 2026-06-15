#!/usr/bin/env bash
# 信頼できる外部タイムソースから現在時刻を取得して表示する。
#
# 優先順位:
#   1) NTP (sntp)        … 時刻専門機関と同期（既定 NICT=日本標準時 JST の公式機関）。
#                          往復遅延を補正し秒精度で正確。
#   2) HTTPS 時刻専門API … 時刻配信専門サービス(timeapi.io)の JSON を取得。秒精度・FW に強い退避先。
#   3) ローカル時計      … 上記が使えない時の最後の手段（stderr に警告）。
#   （sntp が無い環境＝最小構成の Linux 等では、自動的に 2) HTTPS へフォールバックする）
#
#   使い方:
#     scripts/now.sh              -> ISO 8601 UTC（例: 2026-06-15T03:34:56Z）
#     scripts/now.sh '+%Y-%m-%d'  -> 指定フォーマット（ローカルタイムゾーン）
#
#   環境変数:
#     RASHIN_NTP_SERVER   参照する NTP サーバ（空白区切りで複数可。先頭から順に試す）。
#                         既定: "ntp.nict.jp ntp.jst.mfeed.ad.jp"（いずれも日本標準時の公開サーバ）
#     RASHIN_TIME_HTTP_URL  HTTP フォールバックで参照する時刻専門 API（UTC の JSON を返すこと）。
#                         既定: "https://timeapi.io/api/Time/current/zone?timeZone=UTC"
#
# 注: これは「信頼できる時刻の参照」であり、システムクロックの同期(設定)は行わない。
#     使ったソースは stderr に "time-source: ..." として出す（記録時の判断用）。
set -uo pipefail

fmt="${1:-}"
ntp_servers="${RASHIN_NTP_SERVER:-ntp.nict.jp ntp.jst.mfeed.ad.jp}"
time_http_url="${RASHIN_TIME_HTTP_URL:-https://timeapi.io/api/Time/current/zone?timeZone=UTC}"
epoch=""
src=""

# 1) NTP（時刻専門機関）。sntp は「ローカル時計のオフセット（offset +/- error）」を表示するので補正する。
if command -v sntp >/dev/null 2>&1; then
  for server in $ntp_servers; do
    # "+/-" の直前のフィールドがオフセット（macOS/Linux 双方の出力に対応）
    off="$(sntp -t 2 "$server" 2>/dev/null | awk '{for(i=1;i<NF;i++) if($(i+1)=="+/-"){print $i; exit}}')"
    if [ -n "${off:-}" ]; then
      off_round="$(printf '%.0f' "$off" 2>/dev/null || echo 0)"
      epoch=$(( $(date +%s) - off_round ))
      src="ntp:$server"
      break
    fi
  done
fi

# 2) HTTPS 時刻専門API（NTP/UDP123 が塞がれた環境向けの退避先）。時刻配信専門サービスの UTC JSON のみを使う。
#    例: timeapi.io は {"...","dateTime":"2026-06-15T06:58:41.500...","timeZone":"UTC",...} を返す。
if [ -z "$epoch" ] && command -v curl >/dev/null 2>&1; then
  dt="$(curl -fsS --max-time 5 "$time_http_url" 2>/dev/null | sed -n 's/.*"dateTime":"\([0-9T:-]*\)\..*/\1/p')"
  if [ -n "$dt" ]; then
    epoch="$(date -u -d "$dt" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%S' "$dt" +%s 2>/dev/null || true)"
    [ -n "$epoch" ] && src="http:timeapi"
  fi
fi

# epoch を指定フォーマットで出力（BSD/GNU date 両対応）。 $2 は -u か空。
fmt_epoch() { date $2 -r "$1" "$3" 2>/dev/null || date $2 -d "@$1" "$3" 2>/dev/null; }

if [ -n "$epoch" ]; then
  if [ -z "$fmt" ]; then fmt_epoch "$epoch" "-u" "+%Y-%m-%dT%H:%M:%SZ"
  else fmt_epoch "$epoch" "" "$fmt"; fi
  echo "time-source: $src" >&2
else
  echo "time-source: local-clock (外部ソースに接続できずローカル時計を使用)" >&2
  if [ -z "$fmt" ]; then date -u "+%Y-%m-%dT%H:%M:%SZ"; else date "$fmt"; fi
fi
