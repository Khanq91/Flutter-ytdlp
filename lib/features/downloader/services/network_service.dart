// lib/services/network_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

typedef ConnectivityChanges = Stream<List<ConnectivityResult>> Function();
typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

class NetworkService {
  NetworkService({
    ConnectivityChanges? connectivityChanges,
    ConnectivityCheck? checkConnectivity,
  }) : _connectivityChanges =
           connectivityChanges ?? (() => Connectivity().onConnectivityChanged),
       _checkConnectivity =
           checkConnectivity ?? (() => Connectivity().checkConnectivity());

  final ConnectivityChanges _connectivityChanges;
  final ConnectivityCheck _checkConnectivity;
  final _controller = StreamController<NetworkStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _disposed = false;

  Stream<NetworkStatus> get statusStream => _controller.stream;

  // ── Init ───────────────────────────────────────────────

  void init() {
    if (_disposed) {
      throw StateError('NetworkService has already been disposed.');
    }
    if (_sub != null) return;

    _sub = _connectivityChanges().listen((results) {
      _controller.add(_toStatus(results));
    });
  }

  // ── Get current ───────────────────────────────────────

  Future<NetworkStatus> getCurrentStatus() async {
    final results = await _checkConnectivity();
    return _toStatus(results);
  }

  Future<bool> get isOnline async {
    final status = await getCurrentStatus();
    return status == NetworkStatus.online;
  }

  // ── Dispose ───────────────────────────────────────────

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub?.cancel();
    await _controller.close();
  }

  // ── Private ───────────────────────────────────────────

  NetworkStatus _toStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }
}
