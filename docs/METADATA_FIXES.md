# Sửa phân tích URL và màn khởi động

Phản hồi sau bản chuyển: YouTube/playlist timeout, Facebook/TikTok chỉ báo không lấy được thông tin. Phạm vi thay đổi chỉ trong Flutter-ytdlp; Muzicz giữ nguyên.

## Thay đổi

- Mở thẳng màn “from Muzicz” nhập URL. Tạo đúng một root route `/dl/analyze`, không có gateway/nút back trống ở root; giữ route này khi chuyển sang hàng đợi tải.
- `analyze()` dùng một lần `extract_info()` cho video đơn. Trước đây gọi hai lần bằng hai YoutubeDL instance, tăng thời gian chờ và bỏ mất session/cookie của lần đầu.
- Preview playlist không duyệt hết các trang entries. Tên/số lượng playlist được đọc từ metadata; màn chọn playlist mới tải entries đầy đủ.
- URL `watch?v=...&list=...` được coi là video đơn. Cả analyze và download dùng `noplaylist=True`; URL `/playlist?list=...` vẫn tải playlist bình thường.
- Timeout Dart cho metadata tăng từ 30 lên 120 giây. Request Python có socket timeout 20 giây và một lần retry; timeout tổng ở Dart không hủy coroutine native đang chạy.
- Không dùng `ignoreerrors=True` cho metadata và không cắt lỗi còn 120 ký tự. Người dùng nhận được nguyên nhân từ extractor thay vì thông báo chung khi yt-dlp trả `None`.
- Thêm `curl-cffi==0.16.2` cho browser impersonation của yt-dlp. Wheel Android arm64/x86_64 lấy từ index của Flet. Runtime `libc++_shared.so` đi kèm wheel được copy vào `lib/<ABI>` của APK bằng task Gradle; chỉ cài wheel vào Python là chưa đủ để Android linker tìm được thư viện này.
- Nâng NDK lên 28.2.13676358 theo yêu cầu plugin `integration_test`. Thêm endpoint chẩn đoán `getBackendInfo` để kiểm tra yt-dlp/curl-cffi thực sự import được trong Android, không cần request mạng.

## Bằng chứng chẩn đoán

Các URL được người dùng cung cấp, chỉ đọc metadata:

| Trường hợp | URL |
| --- | --- |
| Playlist | `https://www.youtube.com/playlist?list=PLqQqNpXWFqHpZsOWV7-KPMHe2tTBAB2RG` |
| Video | `https://www.youtube.com/watch?v=RChxQsvPTEs&list=PLqQqNpXWFqHpZsOWV7-KPMHe2tTBAB2RG&index=1` |
| Facebook | `https://www.facebook.com/share/v/1d2kGLBV5z/` |
| TikTok | `https://vt.tiktok.com/ZSbKTBhQQ/` |

Trên Windows, yt-dlp 2026.08.19 chưa có curl-cffi tái hiện lỗi TikTok `Unexpected response from webpage request`. Khi có curl-cffi, bridge sửa trả về playlist 115 mục, YouTube 42 format, Facebook 5 format và TikTok 10 format. Số lượng format có thể thay đổi theo mạng/website.

Lần kiểm tra Android đầu tiên: YouTube/playlist và Facebook qua; TikTok còn lỗi. Endpoint chẩn đoán xác định `dlopen failed: library libc++_shared.so not found`; đây là lý do bổ sung task đóng gói runtime C++ cho cả hai ABI.

Unit test mới kiểm tra request video không bị gọi hai lần, preview playlist không duyệt lazy entries, lỗi extractor không bị che/cắt mất, và watch URL không vô tình tải cả playlist. Integration test chỉ chạy khi bật `LIVE_METADATA_TESTS=true`, kiểm tra cả import native và metadata bốn URL qua MethodChannel thật.

## Kết quả kiểm tra cuối

- Android 16, giả lập x86_64 (16 KB page): cả bốn URL qua MethodChannel thật đều lấy metadata thành công; tổng thời gian test khoảng 50 giây.
- 31 Flutter test và 6 Python test đều qua. Analyzer không có lỗi/warning; còn một lint info có sẵn trong `download_provider_test.dart`.
- Runtime C++ được đóng gói cho arm64-v8a và x86_64; chưa chạy trên thiết bị arm64 thật.

## Giới hạn

Chưa kiểm tra tải hết file, ghép stream hoặc tách audio trong đợt sửa metadata này. YouTube có thể thiếu một số format do APK chưa đóng gói JavaScript runtime/EJS; việc trả metadata thành công không chứng minh mọi format tải được. [Tài liệu EJS của yt-dlp](https://github.com/yt-dlp/yt-dlp/wiki/EJS).

Wheel Android: [index curl-cffi của Flet](https://pypi.flet.dev/curl-cffi/). Cơ chế impersonation: [dependency chính thức của yt-dlp](https://github.com/yt-dlp/yt-dlp#dependencies).
