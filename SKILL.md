---
name: yt-highlight-shorts
description: Use when cần cắt highlight/đoạn cao trào từ video YouTube thành short dọc cho YouTube Shorts, TikTok, Reels; tải video bằng yt-dlp chất lượng tuỳ ý; tìm đoạn hay nhất trong video dài bằng loudness analysis; convert video ngang 16:9 sang dọc 9:16 giữ subtitle; cắt video thành clip ngắn có giới hạn thời lượng. Triggers — cut highlight, tìm đoạn cao trào, dựng short dọc, yt-dlp download, vertical shorts, highlight detection, ffmpeg cut, cắt clip youtube, shorts 1080x1920.
---

# yt-highlight-shorts

## Overview

Pipeline 5 bước: **tải → tìm highlight bằng loudness → xác minh bằng frame → cut → dựng dọc 9:16**. Nguyên tắc cốt lõi: **mọi quyết định cut phải có bằng chứng** (RMS loudness + contact sheet xem bằng mắt), không đoán mò timestamp.

Scripts: `scripts/` — bash thuần, chỉ cần `yt-dlp` + `ffmpeg`. Chạy trên macOS / Linux / **Windows (Git Bash hoặc WSL)**.

## When to Use

- Có URL YouTube (hoặc file video ngang 16:9) cần tách highlight thành clip ngắn
- Cần format dọc cho Shorts/TikTok/Reels ở phân giải bất kỳ (1080×1920, 720×1280...)

**Không dùng khi:** video dọc sẵn (chỉ cần cut), hoặc cần edit sáng màu/nhạc — dùng editor thường.

## Tham số điều chỉnh (đọc từ prompt user)

| Tham số | Cờ | Mặc định | Ý nghĩa |
|---|---|---|---|
| Chất lượng tải | preset `download_video.sh` | `best` | `worst` / `720` / `1080` / **số bất kỳ** (vd `480`, `1440` = cap chiều cao, ép H.264+AAC) |
| Phân giải dọc | `RES=WxH` (`to_shorts.sh` arg 4) | `1080x1920` | Canvas dọc — layout tự tính theo tỷ lệ |
| Thời lượng tối thiểu | `min_dur` (arg 5) | `3` | Clip ngắn hơn bị bỏ + cảnh báo |
| Thời lượng tối đa | `max_dur` (arg 6) | `60` | Clip dài hơn bị bỏ + cảnh báo |
| Cửa sổ loudness | `analyze_loudness.sh` arg 2 | `30` | ≈ độ dài clip mong muốn |
| Khoảng cách kết quả | arg 3 | `150` | Khử trùng lặp giữa các highlight |
| Vị trí subject | `x_offset` (cột 4 clips.txt) | `437` (giữa) | Pixel X của NGUỒN nơi bắt đầu crop dọc |

## Pipeline

### 1. Tải video — `download_video.sh`

```bash
scripts/download_video.sh "https://www.youtube.com/watch?v=ID" 720 /tmp/work   # 720p
scripts/download_video.sh "$URL" 480 out/                                       # 480p tuỳ ý
```

**Dùng preset số** — ép `avc1`+`aac`, audio copy nguyên gốc vào mp4. `best` có thể trả AV1+Opus (Opus trong mp4 kém tương thích).

### 2. Tìm đoạn cao trào — `analyze_loudness.sh`

```bash
# cửa sổ 15s cho clip ngắn; 30s cho clip tiêu chuẩn
scripts/analyze_loudness.sh video.mp4 15 120 10 > windows.tsv
```

RMS loudness mỗi giây (ffmpeg `astats`) → cửa sổ trượt → top N khử trùng lặp. Đoạn ồn nhất thường = cao trào. **Chỉnh `window_sec` ≈ thời lượng clip muốn cắt.**

### 3. Xác minh bằng mắt — `make_contact_sheet.sh`

```bash
scripts/make_contact_sheet.sh video.mp4 512 30 sheet_512.jpg
```

Xem sheet: đoạn có đúng cảnh không, subject trái/giữa/phải → quyết định `x_offset`. **Bắt buộc** — loudness chỉ là signal.

### 4. Cut clips — `cut_clips.sh`

```bash
scripts/cut_clips.sh video.mp4 clips.txt highlights/ 5 90   # clip 5–90s
```

`clips.txt` mỗi dòng: `start_sec dur_sec ten_clip` (xem `scripts/clips.example.txt`). Video re-encode H.264 CRF 23 (chính xác frame), **audio copy nguyên gốc**. Dòng vi phạm min/max bị bỏ, exit code ≠ 0.

### 5. Dựng dọc — `to_shorts.sh`

```bash
scripts/to_shorts.sh video.mp4 clips_shorts.txt shorts/ 1080x1920 3 60
scripts/to_shorts.sh video.mp4 clips_shorts.txt shorts/ 720x1280 15 30     # TikTok ngắn
```

`clips_shorts.txt` thêm cột 4 `x_offset`. Layout: nền blur + ảnh chính lệch tâm + caption bar đáy giữ subtitle burn-in. Tỷ lệ layout **tự tính theo phân giải nguồn và canvas** — không hard-code 720p.

### 6. Kiểm chứng — `verify_output.sh`

```bash
scripts/verify_output.sh shorts/ frames_check/
```

Bảng duration/resolution/audio + 3 frame mẫu mỗi clip. **Xem frame trước khi kết luận xong.**

## Windows

- **Có Git Bash** (không phải WSL): `bash scripts/xxx.sh` — đường chính, không đổi gì.
- Cài binary: `winget install Gyan.FFmpeg yt-dlp.yt-dlp` → có sẵn `ffmpeg.exe`, `ffprobe.exe`, `yt-dlp.exe` trong PATH.
- CRLF từ Notepad được scripts tự chuẩn hoá.
- **Không có bash**: agent tự chạy exe trực tiếp theo lệnh tham chiếu ở dưới — bỏ qua wrapper, giữ nguyên flag.

### Lệnh tham chiếu trực tiếp (không cần bash — cho agent gọi exe)

Tải (H.264+AAC, cap 720p):
```
ytdlp -f "bv*[height<=720][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=720]" --merge-output-format mp4 URL
```

Cut 1 clip (audio copy gốc):
```
ffmpeg -ss START -i input.mp4 -t DUR -c:v libx264 -preset veryfast -crf 23 -c:a copy -movflags +faststart -y out.mp4
```

Loudness RMS 1 giây → file (Windows: dùng tên file RELATIVE, đừng dùng /tmp):
```
ffmpeg -nostdin -i input.mp4 -vn -af "aresample=8000,asetnsamples=8000:pad=1,astats=metadata=1:reset=1,ametadata=mode=print:key=lavfi.astats.Overall.RMS_level:file=rms.txt" -f null -
```
Xếp hạng cửa sổ trượt: parse `pts_time:N` + `RMS_level=X` thành cặp (giây, rms) rồi tính trung bình mỗi window — agent làm bằng script ngắn hoặc tính tay trên file rms.txt.

Dựng dọc 9:16 1080×1920 (nguồn 1280×720, crop lệch tâm X=500, caption bar giữ sub):
```
ffmpeg -ss START -i input.mp4 -t DUR -filter_complex "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=20:2,eq=brightness=-0.12[bg];[0:v]crop=404:580:500:0,scale=1080:1551:flags=lanczos[main];[0:v]crop=1280:140:0:580,scale=1080:118[strip];[bg][main]overlay=0:0[comp];[comp][strip]overlay=0:1802[v]" -map "[v]" -map 0:a -c:v libx264 -preset veryfast -crf 23 -c:a copy -movflags +faststart -y out.mp4
```
Khác 720p nguồn: tính lại `crop_w=src_h*404/720`, `crop_h=src_h*580/720`, strip = phần nguồn còn lại dưới crop_h.

## Common Mistakes

| Lỗi | Nguyên nhân / Fix |
|---|---|
| Subtitle bị cắt đầu-cuối | Sub burn-in rộng hơn crop dọc → dùng layout caption bar của `to_shorts.sh` |
| Mảnh hình "chạy" xuống đáy | Caption bar trùng vùng hình main → layout mới tách rời: main trên, strip dưới |
| Crop lệch màu | Toạ độ lẻ trên yuv420p → script tự làm tròn chẵn |
| Audio không phải bản gốc | Nguồn Opus → tải lại preset số (`720`) thay vì re-encode đại |
| Clip bị bỏ hết | Kiểm tra min/max dur truyền vào — script in cảnh báo từng dòng bị bỏ |
| Loudness parse sai cột | `$NF` của dòng `pts_time` là nhãn — giữ nguyên awk trong script |
| Hàm bash tên `cut` | Shadow `/usr/bin/cut` → hàm đặt tên `cutclip` |
| Cut lệch thời điểm | `-ss` đặt **trước** `-i` (seek nhanh + chính xác khi re-encode) |
| Windows: `file=/tmp/...` trong filter fail | Path POSIX nhúng trong chuỗi filter không được Git Bash auto-convert → ffmpeg.exe hiểu là `C:\tmp` — scripts đã dùng tên relative, đừng đổi lại thành path absolute |

## Real-World Impact

Pipeline đã xử lý video 16:37 → 6 shorts 1080×1920 (traffic stop → arrest), tìm đúng 6 cao trào bằng loudness, subtitle giữ nguyên 100%. Đã test: canvas 720×1280, CRLF clips.txt, min/max duration rejection.
