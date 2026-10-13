class AppConstants {
  AppConstants._();

  /// Giới hạn thực thi được áp dụng bởi Android foreground service.
  /// Progress/cancellation đã được scope theo task ID; giữ ở 2 cho đến khi có
  /// benchmark thiết bị trước khi cân nhắc tăng thêm.
  static const int maxConcurrentDownloads = 2;

  /// Thư mục mặc định nếu user chưa chọn
  static const String defaultDownloadFolder = 'Music/YTDLModule';
}
