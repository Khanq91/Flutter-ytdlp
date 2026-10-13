# Flutter-ytdlp

App Android tải video/audio từ URL, chuyển toàn bộ luồng downloader hiện có của Muzicz sang project độc lập để review. Muzicz chưa bị chỉnh sửa hoặc gỡ module.

Mã chính: `lib/features/downloader/`. Native backend: `android/app/src/main/kotlin/com/example/flutter_ytdlp/` và `android/app/src/main/python/ytdlp_bridge.py`.

Xem [phạm vi chuyển, các điều chỉnh và checklist review](docs/MUZICZ_MIGRATION.md), cùng [bảng đối chiếu 54 file nguồn](docs/muzicz-source-map.json).

## Chạy và kiểm tra

Yêu cầu Flutter 3.44.5 (Dart 3.12), Android SDK/NDK 27.0.12077973, Java tương thích Gradle và Python 3.13 có `venv`. App hỗ trợ Android API 24+, ABI arm64-v8a/x86_64.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
flutter build apk --debug
```

Nếu Chaquopy không tìm được Python 3.13, trỏ đến interpreter trước khi build (PowerShell):

```powershell
$env:YTDLP_BUILD_PYTHON = 'C:\path\to\Python313\python.exe'
flutter build apk --debug --no-pub
```

[Chaquopy yêu cầu Python build có cùng major/minor với runtime](https://chaquo.com/chaquopy/doc/current/android.html#buildpython). Có thể dùng [gói Python NuGet cho build/CI](https://docs.python.org/3.13/using/windows.html#the-nuget-org-packages) trong thư mục riêng; không cần thay Python hệ thống. Bản build kiểm tra ở máy này sử dụng `.dart_tool/python313-full/tools/python.exe` (cache local, không commit).

Trên Windows, nếu `flutter pub get` báo thiếu symlink support cho plugin desktop, bật Developer Mode rồi chạy lại. Dependencies đã resolve vẫn có thể dùng cho kiểm tra Android bằng `--no-pub`.

Build release giữ cấu hình signing sẵn có: `android/app/release.jks` và các biến `STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Workflow `.github/workflows/build-apk.yml` dùng các secrets hiện có; chưa chạy/publish workflow trong đợt chuyển này.

Các thư mục nền tảng khác vẫn là scaffold cũ, chưa có backend download tương đương Android. `.temp/` là bản lưu cũ, không tham gia app đang chạy.
