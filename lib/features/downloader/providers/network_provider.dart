// lib/providers/network_provider.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network_service.dart';

final networkServiceProvider = Provider<NetworkService>((ref) {
  final service = NetworkService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Stream trạng thái mạng — dùng khắp app
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(networkServiceProvider);
  service.init();
  return service.statusStream;
});
