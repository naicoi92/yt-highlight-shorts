#!/usr/bin/env bash
# download_video.sh — tải video YouTube bằng yt-dlp theo preset chất lượng.
# Chạy được trên macOS / Linux / Windows (Git Bash hoặc WSL); cần yt-dlp + ffmpeg trong PATH.
# Usage: download_video.sh <url> [worst|720|1080|best|<số-pixel>] [outdir]
#   <số-pixel>  : cap chiều cao tuỳ ý, vd 480, 1440 (ép H.264 + AAC)
# Output: đường dẫn file đã tải (stdout), log ra stderr.
set -euo pipefail

usage() {
  echo "Usage: $0 <url> [worst|720|1080|best|<height_px>] [outdir]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
url=$1
quality=${2:-best}
outdir=${3:-.}
mkdir -p "$outdir"

avc_pair() { # H.264 + AAC — tương thích mp4, audio copy nguyên gốc được
  local h=$1
  echo "bv*[height<=${h}][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=${h}]"
}

case "$quality" in
  worst)
    fmt="worstvideo*+worstaudio/worst"
    ;;
  best)
    fmt="bv*+ba/b"
    ;;
  *)
    # preset số hoặc tuỳ ý: 480/720/1080/1440...
    [[ "$quality" =~ ^[0-9]+$ ]] || { echo "Preset không hợp lệ: $quality" >&2; exit 1; }
    fmt=$(avc_pair "$quality")
    ;;
esac

cd "$outdir"
yt-dlp -f "$fmt" --merge-output-format mp4 -o "%(title).80s [%(id)s].%(ext)s" "$url" 1>&2

file=$(ls -t *.mp4 2>/dev/null | head -1)
[[ -n "$file" ]] || { echo "Không tìm thấy file mp4 sau khi tải" >&2; exit 1; }
echo "$outdir/$file"
