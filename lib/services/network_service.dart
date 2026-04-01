// lib/services/network_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

class NetworkService {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Stream<NetworkStatus> get statusStream => _controller.stream;

  // ── Init ───────────────────────────────────────────────

  void init() {
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_toStatus(results));
    });
  }

  // ── Get current ───────────────────────────────────────

  Future<NetworkStatus> getCurrentStatus() async {
    final results = await _connectivity.checkConnectivity();
    return _toStatus(results);
  }

  Future<bool> get isOnline async {
    final status = await getCurrentStatus();
    return status == NetworkStatus.online;
  }

  // ── Dispose ───────────────────────────────────────────

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }

  // ── Private ───────────────────────────────────────────

  NetworkStatus _toStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }
}
