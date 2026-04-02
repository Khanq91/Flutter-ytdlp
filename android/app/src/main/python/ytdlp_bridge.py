# android/app/src/main/python/ytdlp_bridge.py

import yt_dlp
import json
import os

# ─── Global progress state (Kotlin sẽ poll thay vì nhận callback) ───────────
_progress = {
    "status": "idle",       # idle | downloading | finished | error
    "percent": 0.0,
    "speed": "",
    "eta": "",
    "filename": "",
    "error": "",
}

def get_progress():
    """Kotlin gọi hàm này để poll tiến trình download"""
    return json.dumps(_progress)

def reset_progress():
    """Gọi trước mỗi lần download mới"""
    global _progress
    _progress = {
        "status": "idle",
        "percent": 0.0,
        "speed": "",
        "eta": "",
        "filename": "",
        "error": "",
    }


# ─── JSON helper ─────────────────────────────────────────────────────────────
def _safe_json(obj):
    """
    Lọc info dict của yt-dlp trước khi dumps.
    yt-dlp trả về nhiều kiểu không serializable: bytes, None lồng nhau, v.v.
    """
    if isinstance(obj, dict):
        return {k: _safe_json(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_safe_json(i) for i in obj]
    if isinstance(obj, (str, int, float, bool)) or obj is None:
        return obj
    # bytes, object lạ → chuyển thành string
    return str(obj)


# ─── Analyze ─────────────────────────────────────────────────────────────────
def analyze(url: str) -> str:
    # ── Bước 1: Flat scan — chỉ lấy metadata cấp playlist, KHÔNG fetch từng video ──
    flat_opts = {
        "quiet":        True,
        "no_warnings":  True,
        "ignoreerrors": True,
        "extract_flat": "in_playlist",  # ← nhanh: chỉ lấy id/title/duration
    }
    try:
        with yt_dlp.YoutubeDL(flat_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info is None:
                return json.dumps({"error": "Không lấy được thông tin"})

            all_entries   = [e for e in (info.get("entries") or []) if e is not None]
            valid_entries = [e for e in all_entries if e.get("id")]
            skipped       = len(all_entries) - len(valid_entries)
            is_playlist   = info.get("_type") == "playlist" or bool(all_entries)

            if is_playlist:
                # Playlist → trả về ngay, KHÔNG cần bước 2
                result = {
                    "success":        True,
                    "_type":          "playlist",
                    "title":          info.get("title", "Playlist"),
                    "thumbnail":      (info.get("thumbnails") or [{}])[-1].get("url"),
                    "playlist_count": len(valid_entries),
                    "skipped_count":  skipped,
                    "formats":        [],
                }
                return json.dumps(_safe_json(result))

        # ── Bước 2: Video đơn → fetch lại với full extraction để lấy formats ──
        # (TikTok, Instagram... cần extract_flat=False để có formats)
        video_opts = {
            "quiet":        True,
            "no_warnings":  True,
            "ignoreerrors": True,
            "extract_flat": False,
            "noplaylist":   True,  # Chặn yt-dlp không expand playlist nếu URL nhập nhằng
        }
        with yt_dlp.YoutubeDL(video_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info is None:
                return json.dumps({"error": "Không lấy được thông tin"})

            formats = []
            for f in (info.get("formats") or []):
                formats.append({
                    "format_id":       f.get("format_id", ""),
                    "ext":             f.get("ext", ""),
                    "resolution":      f.get("resolution") or f.get("format_note", ""),
                    "format_note":     f.get("format_note", ""),
                    "filesize":        f.get("filesize"),
                    "filesize_approx": f.get("filesize_approx"),
                    "vcodec":          f.get("vcodec", ""),
                    "acodec":          f.get("acodec", ""),
                    "fps":             f.get("fps"),
                    "tbr":             f.get("tbr"),
                    "abr":             f.get("abr"),
                    "height":          f.get("height"),
                    "width":           f.get("width"),
                })

            result = {
                "title":         info.get("title", ""),
                "duration":      info.get("duration", 0),
                "thumbnail":     info.get("thumbnail", ""),
                "uploader":      info.get("uploader", ""),
                "formats":       formats,
                "skipped_count": 0,
            }
            return json.dumps(_safe_json(result))

    except Exception as e:
        return json.dumps({"error": str(e)})

# ─── Download ─────────────────────────────────────────────────────────────────
def _make_progress_hook():
    """
    Tạo hook nội bộ — cập nhật _progress global.
    Kotlin sẽ poll get_progress() thay vì nhận callback trực tiếp.
    (Chaquopy không hỗ trợ truyền lambda Kotlin → Python callable)
    """
    def hook(d):
        global _progress
        status = d.get("status", "")

        if status == "downloading":
            downloaded = d.get("downloaded_bytes", 0) or 0
            total      = d.get("total_bytes") or d.get("total_bytes_estimate") or 1
            percent    = round(downloaded / total * 100, 1) if total else 0.0

            _progress = {
                "status":   "downloading",
                "percent":  percent,
                "speed":    d.get("_speed_str", "").strip(),
                "eta":      d.get("_eta_str", "").strip(),
                "filename": d.get("filename", ""),
                "error":    "",
            }

        elif status == "finished":
            _progress["status"]  = "finished"
            _progress["percent"] = 100.0

        elif status == "error":
            _progress["status"] = "error"
            _progress["error"]  = str(d.get("error", "Unknown error"))

    return hook


def download(url: str, format_id: str, output_path: str = "") -> str:
    reset_progress()

    if not output_path:
        output_path = os.environ["HOME"]

    actual_format = format_id

    if format_id in ("__extract_m4a__", "__extract_mp3__", "__extract_audio__"):
        actual_format = "bestvideo+bestaudio/best"

    # ✅ Đếm video bị skip trong download
    skipped_videos = []

    def _error_hook(d):
        """yt-dlp gọi hook này khi gặp lỗi từng video trong playlist"""
        if d.get("status") == "error":
            skipped_videos.append({
                "id":    d.get("info_dict", {}).get("id", "unknown"),
                "title": d.get("info_dict", {}).get("title", "unknown"),
                "error": str(d.get("error", "")),
            })

    ydl_opts = {
        "format":              actual_format,
        "outtmpl":             os.path.join(output_path, "%(title)s.%(ext)s"),
        "quiet":               True,
        "no_warnings":         True,
        "merge_output_format": "mp4",
        "progress_hooks":      [_make_progress_hook()],
        "postprocessor_hooks": [],
        "ignoreerrors":        True,
        "noplaylist":          False,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Patch để bắt lỗi từng video
            original_report_error = ydl.report_error
            def patched_report_error(message, *args, **kwargs):
                skipped_videos.append({"error": str(message)})
                # Không gọi original để tránh raise exception
            ydl.report_error = patched_report_error

            info = ydl.extract_info(url, download=True)
            if info is None:
                return json.dumps({"success": False, "error": "Không tải được"})

            if info.get("_type") == "playlist":
                entries = [e for e in (info.get("entries") or []) if e]
                return json.dumps({
                    "success":       True,
                    "title":         info.get("title", ""),
                    "downloaded":    len(entries),           # ✅ số tải thành công
                    "skipped":       len(skipped_videos),    # ✅ số bị bỏ qua
                    "skipped_list":  skipped_videos,         # ✅ chi tiết từng video
                    "path":          output_path,
                })

            filename = ydl.prepare_filename(info)
            return json.dumps({
                "success": True,
                "path":    filename,
                "title":   info.get("title", ""),
                "skipped": 0,
            })

    except Exception as e:
        _progress["status"] = "error"
        _progress["error"]  = str(e)
        return json.dumps({"success": False, "error": str(e)})

def get_playlist_entries(url: str) -> str:
    """
    Fetch danh sách từng video trong playlist.
    Dùng extract_flat để nhanh, không fetch format từng video.
    """
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "ignoreerrors": True,
        "extract_flat": "in_playlist",
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info is None:
                return json.dumps({"success": False, "error": "Không lấy được thông tin"})

            entries = []
            for e in (info.get("entries") or []):
                if e is None or not e.get("id"):
                    continue
                entries.append({
                    "id":        e.get("id", ""),
                    "title":     e.get("title") or e.get("id", ""),
                    "thumbnail": e.get("thumbnail") or e.get("thumbnails", [{}])[-1].get("url") if e.get("thumbnails") else None,
                    "duration":  e.get("duration"),
                    "url":       e.get("url") or e.get("webpage_url") or f"https://www.youtube.com/watch?v={e.get('id', '')}",
                    "uploader":  e.get("uploader") or e.get("channel", ""),
                })

            return json.dumps(_safe_json({
                "success": True,
                "title":   info.get("title", "Playlist"),
                "total":   len(entries),
                "entries": entries,
            }))

    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})