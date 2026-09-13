#!/usr/bin/env bash
# to_shorts.sh — dựng clip ngang 16:9 thành dọc 9:16 (mặc định 1080×1920) cho Shorts.
# Chạy được trên macOS / Linux / Windows (Git Bash hoặc WSL); cần ffmpeg + ffprobe.
#
# Layout: nền blur full canvas + ảnh chính crop lệch tâm (theo subject từng clip)
# + caption bar đáy giữ subtitle burn-in của nguồn nguyên vẹn.
# Layout tính TOÁN ĐỘNG theo resolution nguồn và canvas → mọi phân giải đều đúng tỷ lệ.
#
# clips.txt mỗi dòng: <start_sec> <dur_sec> <ten_clip> [x_offset]
#   x_offset  = toạ độ X (pixel của NGUỒN) bắt đầu crop dọc; trống = giữa khung.
#               Xem frame từng clip (make_contact_sheet.sh) để chọn offset đúng subject.
#   (chấp nhận cả CRLF của Notepad Windows; extension .mp4 tự thêm nếu thiếu)
#
# Usage: to_shorts.sh <video> <clips.txt> <outdir> [RES=WxH] [min_dur=3] [max_dur=60]
#   RES     : canvas dọc, mặc định 1080x1920. Vd 720x1280, 1080x1920.
#   min/max : giới hạn thời lượng clip (giây) — dòng vi phạm bị bỏ với cảnh báo.
set -euo pipefail

usage() {
  echo "Usage: $0 <video> <clips.txt> <outdir> [RES=WxH] [min_dur=3] [max_dur=60]" >&2
  echo "  clips.txt: <start_sec> <dur_sec> <ten_clip> [x_offset]" >&2
  exit 1
}

[[ $# -ge 3 ]] || usage
video=$1 list=$2 outdir=$3
RES=${4:-1080x1920}
min_dur=${5:-3}
max_dur=${6:-60}
[[ -f "$video" ]] || { echo "Không thấy file: $video" >&2; exit 1; }
[[ -f "$list" ]] || { echo "Không thấy file: $list" >&2; exit 1; }

W=${RES%x*} H=${RES#*x}
[[ "$W" =~ ^[0-9]+$ && "$H" =~ ^[0-9]+$ ]] || { echo "RES sai định dạng: $RES (vd 1080x1920)" >&2; exit 1; }

# Phân giải nguồn — layout tính từ đây, không hard-code 720p
src_w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$video")
src_h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$video")

even() { local n=$1; (( n % 2 == 0 )) || n=$((n + 1)); echo "$n"; }

# Vùng crop dọc trên nguồn: rộng 404/720 * src_h, cao 580/720 * src_h (tỷ lệ như bản gốc)
# Vùng strip caption: phần nguồn còn lại bên dưới (chứa subtitle burn-in)
crop_h=$(even $(( src_h * 580 / 720 )))
crop_w=$(even $(( src_h * 404 / 720 )))
strip_h_src=$(( src_h - crop_h ))
main_h=$(even $(( W * crop_h / crop_w )))
strip_h=$(even $(( W * strip_h_src / src_w )))
strip_y=$(( H - strip_h ))

acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$video" | head -1)
case "$acodec" in
  aac|mp3|ac3) acopy=(-c:a copy) ;;
  *) acopy=(-c:a aac -b:a 128k)
     echo "Cảnh báo: audio '$acodec' → re-encode AAC (nội dung âm thanh giữ nguyên)" >&2 ;;
esac

mkdir -p "$outdir"

mkshort() {
  local ss=$1 t=$2 name=$3 x=$4
  [[ $name == *.mp4 ]] || name="${name}.mp4"
  # yuv420p yêu cầu toạ độ chẵn; clamp x vào [0, src_w - crop_w]
  (( x % 2 == 0 )) || x=$((x + 1))
  local xmax=$(( src_w - crop_w ))
  (( x < 0 )) && x=0
  (( x > xmax )) && x=$xmax
  # -nostdin: ffmpeg không được ăn stdin của vòng lặp read
  ffmpeg -nostdin -v error -ss "$ss" -i "$video" -t "$t" \
    -filter_complex "\
[0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},boxblur=20:2,eq=brightness=-0.12[bg];\
[0:v]crop=${crop_w}:${crop_h}:${x}:0,scale=${W}:${main_h}:flags=lanczos[main];\
[0:v]crop=${src_w}:${strip_h_src}:0:${crop_h},scale=${W}:${strip_h}[strip];\
[bg][main]overlay=0:0[comp];\
[comp][strip]overlay=0:${strip_y}[v]" \
    -map "[v]" -map 0:a \
    -c:v libx264 -preset veryfast -crf 23 "${acopy[@]}" \
    -movflags +faststart -y "$outdir/$name"
}

# Sanitize CRLF → LF (file tạo bằng Notepad Windows)
sanitized=$(mktemp)
tr -d '\r' < "$list" > "$sanitized"
trap 'rm -f "$sanitized"' EXIT

fail=0
while read -r ss dur name x rest; do
  [[ -z "${ss:-}" || "$ss" == \#* ]] && continue
  x=${x:-437}
  if ! awk -v d="$dur" -v m="$min_dur" -v M="$max_dur" 'BEGIN{exit !(d>=m && d<=M)}'; then
    echo "BỎ: $name (dur=$dur ngoài giới hạn [$min_dur, $max_dur])" >&2
    fail=$((fail + 1))
    continue
  fi
  echo ">> $name (start=$ss dur=$dur x=$x)" >&2
  mkshort "$ss" "$dur" "$name" "$x"
done < "$sanitized"

echo "Xong. Shorts ${W}x${H} nằm ở: $outdir (bỏ $fail dòng vi phạm)" >&2
[[ $fail -eq 0 ]]
