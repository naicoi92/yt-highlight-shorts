#!/usr/bin/env bash
# make_contact_sheet.sh — contact sheet (mosaic) các frame trong một đoạn video
# để XÁC MINH nội dung bằng mắt trước khi cut.
# Chạy được trên macOS / Linux / Windows (Git Bash hoặc WSL); cần ffmpeg.
# Usage: make_contact_sheet.sh <video> <start_sec> <duration_sec> <out.jpg> [cols=5] [rows=2]
set -euo pipefail

usage() {
  echo "Usage: $0 <video> <start_sec> <duration_sec> <out.jpg> [cols=5] [rows=2]" >&2
  exit 1
}

[[ $# -ge 4 ]] || usage
video=$1 start=$2 dur=$3 out=$4 cols=${5:-5} rows=${6:-2}
[[ -f "$video" ]] || { echo "Không thấy file: $video" >&2; exit 1; }

total=$((cols * rows))
# Lấy $total frame đều nhau trong đoạn, thu nhỏ về 160px rồi ghép lưới.
ffmpeg -nostdin -v error -ss "$start" -t "$dur" -i "$video" \
  -vf "fps=${total}/${dur},scale=160:-1,tile=${cols}x${rows}" \
  -frames:v 1 -y "$out"
echo "$out"
