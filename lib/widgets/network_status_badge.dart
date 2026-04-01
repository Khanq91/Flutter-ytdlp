// lib/widgets/network_status_badge.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../providers/network_provider.dart';
import '../services/network_service.dart';

/// Badge hiển thị trạng thái mạng — luôn nằm góc phải trên cùng.
/// Dùng trong AppShell qua Positioned widget.
class NetworkStatusBadge extends ConsumerStatefulWidget {
  const NetworkStatusBadge({super.key});

  @override
  ConsumerState<NetworkStatusBadge> createState() => _NetworkStatusBadgeState();
}

class _NetworkStatusBadgeState extends ConsumerState<NetworkStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  NetworkStatus? _previousStatus;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(networkStatusProvider);

    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        // Animate khi đổi trạng thái
        if (_previousStatus != null && _previousStatus != status) {
          _controller
            ..reset()
            ..forward();
        }
        _previousStatus = status;

        final isOnline = status == NetworkStatus.online;

        return FadeTransition(
          opacity: _fadeAnim,
          child: _BadgePill(isOnline: isOnline),
        );
      },
    );
  }
}

class _BadgePill extends StatelessWidget {
  final bool isOnline;

  const _BadgePill({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline
        ? const Color(0xFF34C759) // xanh lá hệ thống iOS
        : const Color(0xFFFF3B30); // đỏ

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isOnline ? 'Online' : 'Offline',
              key: ValueKey(isOnline),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
