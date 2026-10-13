// lib/widgets/app_shell.dart

import 'package:flutter/material.dart';
import 'network_status_badge.dart';

/// Bọc toàn bộ nội dung màn hình.
/// Đảm bảo [NetworkStatusBadge] luôn nằm góc trên phải
/// bất kể đang ở màn hình nào.
class AppShell extends StatelessWidget {
  final Widget child;

  /// Có hiển thị AppBar không (một số màn hình tự quản lý AppBar)
  final PreferredSizeWidget? appBar;

  const AppShell({
    super.key,
    required this.child,
    this.appBar,
  });

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     backgroundColor: Colors.transparent,
  //     appBar: appBar,
  //     body: Stack(
  //       children: [
  //         // Nội dung chính
  //         child,
  //
  //         // Network badge — luôn góc trên phải, trên hết
  //         const Positioned(
  //           top: 12,
  //           right: 16,
  //           child: SafeArea(
  //             child: NetworkStatusBadge(),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scaffold nằm dưới
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: child,
        ),

        // Badge overlay toàn app
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            minimum: const EdgeInsets.only(top: 52, right: 24),
            child: const NetworkStatusBadge(),
          ),
        ),
      ],
    );
  }
}
