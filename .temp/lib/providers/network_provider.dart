// lib/providers/network_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network_service.dart';

/// Stream trạng thái mạng — dùng khắp app
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = NetworkService.instance;
  service.init();
  ref.onDispose(service.dispose);
  return service.statusStream;
});

/// Shortcut: chỉ cần biết online hay không
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(networkStatusProvider).maybeWhen(
    data: (status) => status == NetworkStatus.online,
    orElse: () => true, // Giả sử online khi đang load
  );
});
