# YTDLModule — Flutter Video Downloader

Module tải video sử dụng `yt-dlp`, thiết kế để tích hợp vào app Flutter lớn hơn.

---

## 📁 Cấu trúc file

```
lib/
├── main.dart
├── core/
│   ├── app_router.dart
│   ├── constants/app_constants.dart
│   └── theme/
│       ├── app_colors.dart          ← Copy từ app chính
│       └── app_theme.dart           ← Copy từ app chính
├── models/
│   ├── video_info.dart
│   ├── format_option.dart
│   └── download_task.dart
├── providers/
│   ├── analyze_provider.dart
│   ├── download_provider.dart
│   └── network_provider.dart
├── services/
│   ├── ytdlp_service.dart           ← Core engine
│   ├── storage_service.dart
│   └── network_service.dart
├── screens/
│   ├── analyze/analyze_screen.dart
│   ├── format/format_screen.dart
│   ├── download/download_screen.dart
│   └── summary/summary_screen.dart
└── widgets/
    ├── app_shell.dart               ← Wrapper chứa NetworkStatusBadge
    ├── network_status_badge.dart    ← Badge mạng góc phải trên
    ├── gradient_background.dart
    ├── glass_card.dart
    ├── primary_button.dart
    └── platform_chip.dart

assets/
└── bin/
    └── yt-dlp                       ← Binary ARM64 (xem bước 2)
```

---

## 🚀 Hướng dẫn Setup

### Bước 1 — Cài dependencies

```bash
flutter pub get
```

### Bước 2 — Download yt-dlp binary ARM64

```bash
# Tạo thư mục assets
mkdir -p assets/bin

# Download binary ARM64 cho Android
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64 \
     -o assets/bin/libytdlp.so

# Cấp quyền thực thi (trên máy dev)
chmod +x assets/bin/libytdlp.so
```

> ⚠️ File binary ~10MB. App sẽ tự `chmod 755` khi chạy lần đầu trên thiết bị.

### Bước 3 — Khai báo assets trong pubspec.yaml

```yaml
flutter:
  assets:
    - assets/bin/
    - assets/images/
```

### Bước 4 — Copy theme files

Copy 2 file sau từ app chính của bạn vào `lib/core/theme/`:
- `app_colors.dart`
- `app_theme.dart`

### Bước 5 — AndroidManifest

Đã có sẵn tại `android/app/src/main/AndroidManifest.xml`.

Cần thêm `file_paths.xml` vào `android/app/src/main/res/xml/`:

```xml
<!-- android/app/src/main/res/xml/file_paths.xml -->
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <files-path name="internal_files" path="." />
</paths>
```

### Bước 6 — build.gradle (minSdk)

```gradle
// android/app/build.gradle
android {
    defaultConfig {
        minSdkVersion 21        // Android 5.0+
        targetSdkVersion 34
    }
}
```

---

## 🔌 Tích hợp vào app chính

### Option A — Embed như module riêng

```dart
// Trong app chính, navigate vào module
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ProviderScope(
      child: YtdlApp(),    // hoặc thẳng AnalyzeScreen()
    ),
  ),
);
```

### Option B — Dùng Providers từ app chính

```dart
// Trong app chính đã có ProviderScope
// Chỉ cần navigate trực tiếp
import 'package:ytdl_module/screens/analyze/analyze_screen.dart';

Navigator.push(context, MaterialPageRoute(
  builder: (_) => const AnalyzeScreen(),
));
```

---

## 📱 Flow màn hình

```
Analyze Screen
    ↓ (analyze OK)
Format Screen
    ↓ (chọn format + nhấn tải)
Download Manager
    ↓ (tất cả done)
Summary Screen
    ↓ (tải thêm)
Analyze Screen
```

---

## ⚠️ Lưu ý quan trọng

### Network Badge
`NetworkStatusBadge` được nhúng trong `AppShell` và **tự động hiển thị góc phải trên** ở mọi màn hình. Không cần config thêm.

### Concurrent Downloads
Mặc định tối đa **10 download song song**. Thay đổi tại:
```dart
// lib/core/constants/app_constants.dart
static const int maxConcurrentDownloads = 10;
```

### Playlist
- YouTube playlist → tạo 1 task duy nhất, yt-dlp tự tải từng video
- Mỗi video trong playlist hiển thị progress riêng qua log parsing

### Thư mục lưu file
- Default: `<sdcard>/Download/YTDLModule/`
- User có thể chọn lại qua `StorageService.instance.pickDownloadDirectory()`

### Android permissions
- Android ≤ 9: `WRITE_EXTERNAL_STORAGE`
- Android 10+: `MANAGE_EXTERNAL_STORAGE` (user phải vào Settings cấp)
- App tự request khi cần

---

## 🐛 Debug

```bash
# Xem log libytdlp.so realtime
adb logcat | grep -i ytdlp

# Kiểm tra binary đã được extract chưa
adb shell ls -la /data/data/<package>/files/libytdlp.so

# Test binary trực tiếp trên thiết bị
adb shell /data/data/<package>/files/libytdlp.so --version
```

---

## 📦 Dependencies chính

| Package | Mục đích |
|---------|----------|
| `flutter_riverpod` | State management |
| `connectivity_plus` | Kiểm tra mạng |
| `path_provider` | Đường dẫn thư mục |
| `permission_handler` | Request permissions |
| `file_picker` | Chọn thư mục download |
| `google_fonts` | Font Outfit |
| `cached_network_image` | Cache thumbnail |
| `uuid` | Generate task ID |
