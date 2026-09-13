#!/usr/bin/env bash
# analyze_loudness.sh — tìm đoạn ồn nhất (cao trào: cãi vã, ACTION) trong video
# bằng RMS loudness mỗi giây + cửa sổ trượt.
# Chạy được trên macOS / Linux / Windows (Git Bash hoặc WSL); cần ffmpeg.
# Usage: analyze_loudness.sh <video> [window_sec=30] [min_gap_sec=150] [top_n=10]
#   window_sec : độ dài cửa sổ trượt ≈ độ dài clip mong muốn
#   min_gap_sec: khoảng cách tối thiểu giữa 2 kết quả (khử trùng lặp)
#   top_n      : số kết quả trả về
# Output: TSV "start_sec avg_rms" xếp theo ồn giảm dần (stdout).
set -euo pipefail

usage() {
  echo "Usage: $0 <video> [window_sec=30] [min_gap_sec=150] [top_n=10]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
video=$1
window=${2:-30}
gap=${3:-150}
top=${4:-10}
[[ -f "$video" ]] || { echo "Không thấy file: $video" >&2; exit 1; }

# File RMS đặt TÊN RELATIVE trong cwd — KHÔNG dùng path mktemp dạng /tmp/...:
# path nhúng trong chuỗi filter không được Git Bash auto-convert sang dạng Windows
# → native ffmpeg.exe sẽ hiểu /tmp/... là C:\tmp\... và fail.
rms="yt_rms_$$.txt"
pairs="yt_pairs_$$.txt"
trap 'rm -f "$rms" "$pairs"' EXIT

# 1. RMS mỗi giây: resample 8kHz → cửa sổ 8000 mẫu = 1s → astats reset mỗi cửa sổ.
#    ametadata ghi ra FILE (không dùng stdout để tránh trộn log ffmpeg).
ffmpeg -nostdin -v error -i "$video" -vn \
  -af "aresample=8000,asetnsamples=8000:pad=1,astats=metadata=1:reset=1,ametadata=mode=print:key=lavfi.astats.Overall.RMS_level:file=$rms" \
  -f null - 2>/dev/null

# 2. Parse cặp (time, rms). LƯU Ý: sub(/.*:/) vì $NF của dòng pts_time là "pts_time:N".
awk '/pts_time/{t=$NF; sub(/.*:/,"",t)} /RMS_level/{sub(/.*=/,""); print t+0, $1+0}' "$rms" > "$pairs"

# 3. Cửa sổ trượt $window giây → trung bình RMS → sort giảm dần → khử trùng lặp theo khoảng cách $gap.
awk -v W="$window" '{v[NR]=$2; t[NR]=$1; n=NR}
  END{for(i=W;i<=n-W;i++){s=0; for(j=i;j<i+W;j++) s+=v[j]; printf "%.0f %.1f\n", t[i], s/W}}' \
  "$pairs" \
| sort -k2 -nr \
| awk -v G="$gap" '!seen[int($1/G)]++' \
| head -n "$top"
