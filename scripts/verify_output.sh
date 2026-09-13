#!/usr/bin/env bash
# verify_output.sh — kiểm chứng sản phẩm trước khi claim xong:
# resolution/duration/audio codec + 3 frame mẫu (10%/50%/90%) mỗi clip.
# Usage: verify_output.sh <file.mp4|dir> [frames_outdir]
set -euo pipefail

usage() {
  echo "Usage: $0 <file.mp4|dir> [frames_outdir]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
target=$1
frames_dir=${2:-}
if [[ -d "$target" ]]; then
  files=("$target"/*.mp4)
else
  files=("$target")
fi

printf "%-45s %8s %12s %8s\n" "FILE" "DUR(s)" "RES" "AUDIO"
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$f")
  ac=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$f")
  printf "%-45s %8.1f %12s %8s\n" "$(basename "$f")" "$d" "${res/x/×}" "$ac"
done

if [[ -n "$frames_dir" ]]; then
  mkdir -p "$frames_dir"
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f" .mp4)
    d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
    for pct in 10 50 90; do
      t=$(awk -v d="$d" -v p="$pct" 'BEGIN{printf "%d", d*p/100}')
      ffmpeg -v error -ss "$t" -i "$f" -frames:v 1 -y "$frames_dir/${base}_${pct}.jpg"
    done
  done
  echo "Frame mẫu: $frames_dir" >&2
fi
