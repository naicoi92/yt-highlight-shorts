# yt-highlight-shorts

Pipeline cắt **highlight từ video YouTube thành shorts dọc 9:16** (YouTube Shorts / TikTok / Reels) — bash thuần, chỉ cần `yt-dlp` + `ffmpeg`.

**Nguyên tắc:** mọi quyết định cut phải có bằng chứng — RMS loudness tìm đoạn cao trào + contact sheet xác minh bằng mắt, không đoán mò timestamp.

## Nội dung

```
yt-highlight-shorts/
├── SKILL.md                    # Đặc tả skill cho AI agent (trigger + pipeline + mistakes)
├── README.md                   # Tài liệu này — hướng dẫn cho người dùng
└── scripts/
    ├── download_video.sh       # Tải video YouTube theo preset chất lượng
    ├── analyze_loudness.sh     # Tìm đoạn ồn nhất (cao trào) bằng RMS loudness
    ├── make_contact_sheet.sh   # Mosaic frame xác minh nội dung bằng mắt
    ├── cut_clips.sh            # Batch cut clip từ file timestamps
    ├── to_shorts.sh            # Dựng dọc 9:16 (blur bg + crop lệch tâm + caption bar)
    ├── verify_output.sh        # Kiểm chứng đầu ra (metadata + frame mẫu)
    └── clips.example.txt       # Ví dụ format timestamps
```

## Cài đặt

Yêu cầu: **bash** (macOS/Linux sẵn có; Windows dùng [Git Bash](https://git-scm.com/download/win) — không cần WSL) + `ffmpeg` + `yt-dlp`.

```bash
# Windows (PowerShell admin)
winget install Gyan.FFmpeg yt-dlp.yt-dlp

# macOS
brew install ffmpeg yt-dlp

# Debian/Ubuntu
sudo apt install ffmpeg && sudo pip install yt-dlp
```

Clone:

```bash
git clone https://github.com/naicoi92/yt-highlight-shorts.git
cd yt-highlight-shorts
```

## Quick start

```bash
S=scripts

# 1. Tải video (preset: worst | 480 | 720 | 1080 | best)
$S/download_video.sh "https://www.youtube.com/watch?v=VIDEO_ID" 720 work/

# 2. Tìm đoạn cao trào — cửa sổ trượt 30s, cách nhau tối thiểu 150s, top 10
$S/analyze_loudness.sh work/video.mp4 30 150 10 > windows.tsv

# 3. Xác minh bằng mắt từng ứng viên — chọn x_offset theo vị trí subject
$S/make_contact_sheet.sh work/video.mp4 512 30 sheet_512.jpg

# 4. Ghi timestamps vào clips.txt rồi batch cut
#    mỗi dòng: <start_sec> <dur_sec> <ten_clip>
$S/cut_clips.sh work/video.mp4 clips.txt highlights/

# 5. Dựng dọc 1080×1920 — clips_shorts.txt thêm cột x_offset
#    mỗi dòng: <start_sec> <dur_sec> <ten_clip> [x_offset]
$S/to_shorts.sh work/video.mp4 clips_shorts.txt shorts/ 1080x1920 3 60

# 6. Kiểm chứng đầu ra
$S/verify_output.sh shorts/ frames_check/
```

`x_offset` = toạ độ X (pixel nguồn) nơi bắt đầu crop dọc 404px — trống = giữa khung (437). Xem contact sheet để đặt đúng subject.

## Tham số

| Tham số | Cờ | Mặc định | Ý nghĩa |
|---|---|---|---|
| Chất lượng tải | preset | `best` | `worst` / số bất kỳ (480, 720, 1080, 1440 = cap chiều cao, ép H.264+AAC) |
| Phân giải dọc | `RES=WxH` | `1080x1920` | Canvas dọc — layout tự tính theo tỷ lệ nguồn |
| Thời lượng min/max | arg 5, 6 | `3` / `60` | Clip ngoài khoảng bị bỏ kèm cảnh báo, exit ≠ 0 |
| Cửa sổ loudness | arg 2 | `30` | Đặt ≈ độ dài clip mong muốn |
| Khoảng cách highlight | arg 3 | `150` | Khử trùng lặp kết quả |
| Vị trí subject | `x_offset` | `437` | Pixel X nguồn bắt đầu crop dọc |

## Tại sao audio luôn là bản gốc?

`to_shorts.sh` và `cut_clips.sh` mặc định `-c:a copy` — stream AAC của YouTube được copy nguyên vẹn, không encode lại. Chỉ fallback sang AAC 128k khi nguồn là codec không nhét được vào mp4 (vd Opus), và nội dung âm thanh vẫn giữ nguyên.

## Windows notes

- Chạy qua **Git Bash** (`bash scripts/xxx.sh`) — Git for Windows chứa bash, không cần WSL.
- File `clips.txt` tạo bằng Notepad (CRLF) được tự động chuẩn hoá.
- Lưu ý path POSIX nhúng trong chuỗi filter ffmpeg — xem [SKILL.md Common Mistakes](SKILL.md).

## Dùng như AI skill

`SKILL.md` viết theo chuẩn [agentskills.io](https://agentskills.io) — copy thư mục này vào `~/.agents/skills/` hoặc `~/.pi/agent/skills/` để agent (pi, Claude Code...) tự trigger khi gặp task cắt highlight YouTube thành shorts.

## Common Mistakes

Xem bảng đầy đủ trong [SKILL.md](SKILL.md) — gồm: subtitle burn-in bị cắt khi crop 9:16, mảnh hình lặp ở caption bar, toạ độ crop lẻ lệch màu yuv420p, Opus-in-mp4, hàm bash tên `cut` shadow `/usr/bin/cut`, `-nostdin` cho ffmpeg trong loop `read`.
