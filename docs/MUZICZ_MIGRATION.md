# Bản chuyển downloader từ Muzicz

Đây là báo cáo bản chuyển ban đầu. Các thay đổi sau khi người dùng test URL, gồm mở thẳng màn nhập link và sửa metadata/TikTok, nằm trong [METADATA_FIXES.md](METADATA_FIXES.md). Số file tương đương và kết quả kiểm tra bên dưới là tại thời điểm chuyển ban đầu.

Nguồn: `Muzicz`, commit `0f5fcadced1772e869b0cbacfa87e73cb99464e5`.
Đợt chuyển này chỉ sửa Flutter-ytdlp. Muzicz giữ nguyên để đối chiếu và gỡ module ở đợt sau.

## Phạm vi

| Phần | Vị trí trong Flutter-ytdlp |
| --- | --- |
| Toàn bộ 35 file Dart của downloader: gateway, phân tích URL, playlist, chọn format/thư mục, hàng đợi, kết quả; models/providers/services/widgets | `lib/features/downloader/` — cùng đường dẫn với nguồn |
| Theme, glass container, reveal list, định dạng thời lượng, chuẩn hóa tiếng Việt | `lib/theme/`, `lib/widgets/`, `lib/utils/` |
| Chuỗi giao diện được downloader sử dụng | `lib/core/app_strings.dart` |
| Method channel và tiện ích storage | `android/app/src/main/kotlin/com/example/flutter_ytdlp/MainActivity.kt` |
| Hàng đợi tải nền, lưu trạng thái, retry, cancel, notification, giới hạn 2 tác vụ | `android/app/src/main/kotlin/com/example/flutter_ytdlp/DownloadForegroundService.kt` |
| Khởi tạo Python dùng chung và tách audio native | `YtdlpPython.kt`, `AudioExtractor.kt` trong cùng thư mục Kotlin |
| Backend yt-dlp | `android/app/src/main/python/ytdlp_bridge.py` |
| Test của downloader | `test/features/downloader/` |
| Khởi động và kiểm tra điều hướng app độc lập | `lib/main.dart`, `test/widget_test.dart` |

Không có path dependency, symlink hoặc import sang project Muzicz. Python bridge và logic download được giữ nguyên; các import Dart/package Kotlin đổi sang định danh app đích. Code downloader cũ ở `lib/models`, `lib/providers`, `lib/screens`, `lib/services`, các widget cũ và binary `libytdlp.so` không còn được sử dụng nên đã thay thế/gỡ bỏ. Thư mục `.temp` cũ được giữ nguyên, không phải mã chạy của ứng dụng.

## Các điều chỉnh để chạy độc lập

- `main.dart` chỉ khởi tạo Flutter, Riverpod, theme và mở gateway. Không khởi tạo player, audio service, thư viện nhạc hoặc visualizer. Giữ tên package `flutter_ytdlp`, Android application ID `com.example.flutter_ytdlp`, label/icon/version và cấu hình ký release của app đích.
- Gateway giữ giao diện và kiểm tra mạng của nguồn; bỏ nút quét thư viện, ghi chú quét lại và import onboarding. Nút quay lại chỉ hiện khi có màn trước đó. Màn phân tích vẫn nằm sau gateway nên nút back của nguồn hoạt động bình thường.
- `MainActivity` dùng `FlutterFragmentActivity`; bỏ đăng ký/dispose visualizer và lớp activity của audio player. Giữ toàn bộ handler của `ytdlp_channel`.
- `AppStrings` giữ nguyên giá trị của 17 nhãn cần dùng; không mang các nhãn player/library không liên quan. Các chữ và preset thư mục mang tên Muzicz bên trong downloader được giữ theo nguồn để review độ tương đồng.
- Test Android giữ các kiểm tra downloader, bỏ duy nhất test music scanner/on_audio_query vốn thuộc thư viện nhạc.
- Manifest khai báo foreground service `dataSync`, notification, storage và FileProvider theo phần downloader của nguồn; không mang service phát nhạc hoặc quyền microphone. Giữ khai báo nhận share text như nguồn.
- Build dùng Chaquopy/Python 3.13, minSdk 24, ABI `arm64-v8a` và `x86_64`; clear ABI mặc định của Flutter trước khi thêm hai ABI này. Giữ yt-dlp không ghim phiên bản như nguồn.
- Flutter tối thiểu 3.44/Dart 3.12 do các API widget hiện tại của nguồn. CI dùng Flutter 3.44.5 và chạy thêm bộ test trước build.
- Có thể chỉ định interpreter build bằng biến môi trường `YTDLP_BUILD_PYTHON`; không có đường dẫn máy cá nhân hardcode trong Gradle.
- Các phiên bản dependency dùng chung trong `pubspec.lock` đã đối chiếu và khớp lockfile Muzicz, kể cả dependency gián tiếp.

## Đối chiếu file

`muzicz-source-map.json` liệt kê 54 file lấy từ nguồn, đường dẫn đích và SHA-256 file nguồn. Trong đó 50 file giống nguồn sau khi chuẩn hóa namespace và xuống dòng. Bốn file có điều chỉnh được nêu rõ bên trên: gateway, MainActivity, AppStrings và test Android.

Có thể dùng IDE Compare hoặc `git diff --no-index` giữa hai thư mục `lib/features/downloader` để review. Những khác biệt import `package:muziczz/` → `package:flutter_ytdlp/` là cần thiết để chạy độc lập.

## Kiểm tra tay trên Android

1. Mở gateway khi online/offline; vào màn tải và quay lại.
2. Dán URL video; phân tích, xem thumbnail/thông tin, chọn video/audio và thư mục.
3. Dán URL playlist; tìm/chọn các entry, thử preset và enqueue nhiều mục.
4. Thử tải đồng thời, hàng đợi, hủy một tác vụ; kiểm tra tác vụ còn lại không bị ảnh hưởng.
5. Đưa app xuống nền, xem notification, mở lại app và kiểm tra khôi phục trạng thái.
6. Thử mất mạng/retry, từ chối quyền notification/storage, đổi thư mục, mở thư mục, xem/xóa lịch sử.
7. Kiểm tra file video/audio thực tế và nhánh tách audio native với cùng URL/format đã chạy trên Muzicz.

Phạm vi là chuyển implementation hiện có, không bổ sung backend cho desktop/iOS/web. Manifest nguồn có SEND intent-filter nhưng MainActivity nguồn chưa đọc nội dung intent để điền URL; bản chuyển giữ giới hạn đó. Kiểm tra tự động không thay thế kiểm tra tải thực tế trên thiết bị, codec và website bên ngoài.

## Kết quả kiểm tra bản chuyển

- `flutter pub get --offline`: thành công sau khi đồng bộ lockfile.
- `flutter analyze --no-pub --no-fatal-infos`: không có error/warning; còn 1 info `prefer_initializing_formals` trong test `_FakeStorage` chép nguyên từ nguồn.
- `flutter test --no-pub`: **30/30 test qua**, gồm các test downloader nguồn và 2 test điều hướng app độc lập/điều kiện offline.
- `flutter build apk --debug --no-pub`: thành công với Flutter 3.44.5 và Python 3.13 local. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Đã xác minh 54 SHA-256 file nguồn, 50 file tương đương sau đổi namespace, tất cả import nội bộ resolve trong Flutter-ytdlp; working tree Muzicz không thay đổi.
- Chưa chạy tải URL hoặc kiểm tra giao diện trên thiết bị Android thật; không có thiết bị kết nối. Chưa build bản release ký bằng keystore hoặc publish workflow.

Build đầu có lỗi cache incremental Kotlin do Pub cache ở ổ C còn project ở ổ D; compiler fallback và build thành công. Build cuối thành công, còn cảnh báo Gradle/AGP/Kotlin cũ từ cấu hình sẵn có. Đợt này giữ các phiên bản đó để hạn chế thay đổi ngoài phạm vi chuyển module.
