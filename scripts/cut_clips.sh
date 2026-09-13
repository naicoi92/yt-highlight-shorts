#!/usr/bin/env bash
# cut_clips.sh — cắt nhiều clip từ video theo file timestamps.
# Chạy được trên macOS / Linux / Windows (Git Bash hoặc WSL); cần ffmpeg.
# Mỗi dòng clips.txt: <start_sec> <dur_sec> <ten_clip> [# mo ta]
#   (chấp nhận cả CRLF của Notepad Windows; extension .mp4 tự thêm nếu thiếu)
# Usage: cut_clips.sh <video> <clips.txt> <outdir> [min_dur=3] [max_dur=60]
#   min_dur/max_dur: giới hạn thời lượng clip — dòng vi phạm bị bỏ với cảnh báo.
set -euo pipefail

usage() {
  echo "Usage: $0 <video> <clips.txt> <outdir> [min_dur=3] [max_dur=60]" >&2
  echo "  clips.txt mỗi dòng: <start_sec> <dur_sec> <ten_clip> [# mo ta]" >&2
  exit 1
}

[[ $# -ge 3 ]] || usage
video=$1 list=$2 outdir=$3
min_dur=${4:-3}
max_dur=${5:-60}
crf=${CRF:-23}   # CRF=18 cho bản chất lượng cao nhất (god prompt)
[[ -f "$video" ]] || { echo "Không thấy file: $video" >&2; exit 1; }
[[ -f "$list" ]] || { echo "Không thấy file: $list" >&2; exit 1; }
mkdir -p "$outdir"

# Audio copy chỉ an toàn với codec mp4-compatible; còn lại re-encode AAC (nội dung giữ nguyên).
acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$video" | head -1)
case "$acodec" in
  aac|mp3|ac3) acopy=(-c:a copy) ;;
  *) acopy=(-c:a aac -b:a 128k)
     echo "Cảnh báo: audio '$acodec' không copy được vào mp4 → re-encode AAC (nội dung âm thanh giữ nguyên)" >&2 ;;
esac

cutclip() { # KHÔNG đặt tên hàm "cut" — sẽ shadow /usr/bin/cut
  local ss=$1 t=$2 name=$3
  # ffmpeg chọn muxer theo extension — tự thêm .mp4 nếu tên clip thiếu
  [[ $name == *.mp4 ]] || name="${name}.mp4"
  # -nostdin: ffmpeg không được ăn stdin của vòng lặp read
  ffmpeg -nostdin -v error -ss "$ss" -i "$video" -t "$t" \
    -c:v libx264 -preset veryfast -crf "$crf" "${acopy[@]}" \
    -movflags +faststart -y "$outdir/$name"
}

# Sanitize CRLF → LF (file tạo bằng Notepad Windows)
sanitized=$(mktemp)
tr -d '\r' < "$list" > "$sanitized"
trap 'rm -f "$sanitized"' EXIT

fail=0
while read -r ss dur name rest; do
  [[ -z "${ss:-}" || "$ss" == \#* ]] && continue
  # Kiểm tra thời lượng trong [min_dur, max_dur]
  if ! awk -v d="$dur" -v m="$min_dur" -v M="$max_dur" 'BEGIN{exit !(d>=m && d<=M)}'; then
    echo "BỎ: $name (dur=$dur ngoài giới hạn [$min_dur, $max_dur])" >&2
    fail=$((fail + 1))
    continue
  fi
  echo ">> $name (start=$ss dur=$dur)" >&2
  cutclip "$ss" "$dur" "$name"
done < "$sanitized"

echo "Xong. Clip nằm ở: $outdir (bỏ $fail dòng vi phạm)" >&2
[[ $fail -eq 0 ]]
