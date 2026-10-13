// lib/features/downloader/screens/downloader_gateway_screen.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import '../core/app_router.dart';
import 'package:flutter_ytdlp/core/app_strings.dart';

class DownloaderGatewayScreen extends StatefulWidget {
  const DownloaderGatewayScreen({super.key});

  @override
  State<DownloaderGatewayScreen> createState() =>
      _DownloaderGatewayScreenState();
}

class _DownloaderGatewayScreenState extends State<DownloaderGatewayScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectSub;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _checkConnectivity();
    _connectSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectSub.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = results.any((r) => r != ConnectivityResult.none);
      });
    }
  }

  void _goToDownloader() {
    Navigator.of(context).pushNamed(AppRoutes.analyze);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        tooltip: AppStrings.back,
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: c.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    Text(
                      AppStrings.downloadMusic,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Status card ─────────────────────
                      _NetworkStatusCard(isOnline: _isOnline),
                      const SizedBox(height: 20),

                      // ── Info text ───────────────────────
                      _InfoCard(isOnline: _isOnline),
                      const SizedBox(height: 32),

                      // ── Nút tải từ URL ──────────────────
                      _GatewayButton(
                        icon: Icons.link_rounded,
                        label: AppStrings.downloadFromUrl,
                        subtitle: AppStrings.gatewayDownloadSubtitle,
                        gradient: c.primaryGradient,
                        enabled: _isOnline,
                        disabledReason: AppStrings.gatewayNeedNetwork,
                        onTap: _goToDownloader,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Network status card ────────────────────────────────────────────────────

class _NetworkStatusCard extends StatelessWidget {
  const _NetworkStatusCard({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = isOnline ? c.success : c.error;
    final label = isOnline ? AppStrings.networkOnline : AppStrings.networkOffline;
    final icon = isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  isOnline
                      ? AppStrings.networkReady
                      : AppStrings.networkConnectHint,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          // Dot indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info card ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: c.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.note,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.download_rounded,
            text:
                AppStrings.gatewayNoteStorage,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.audio_file_rounded,
            text: AppStrings.gatewayNoteAudio,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.wifi_rounded,
            text: AppStrings.gatewayNoteInternet,
            highlight: !isOnline,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.highlight = false,
  });
  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = highlight ? c.warning : c.textTertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: color,
              height: 1.5,
              fontWeight: highlight ? FontWeight.w500 : FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Gateway button ─────────────────────────────────────────────────────────

class _GatewayButton extends StatefulWidget {
  const _GatewayButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.enabled,
    required this.onTap,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final bool enabled;
  final VoidCallback onTap;
  final String? disabledReason;

  @override
  State<_GatewayButton> createState() => _GatewayButtonState();
}

class _GatewayButtonState extends State<_GatewayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      hint: widget.enabled ? widget.subtitle : widget.disabledReason,
      onTap: widget.enabled ? widget.onTap : null,
      // The texts inside are already carried by label/hint.
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: widget.enabled ? 1.0 : 0.45,
        child: GestureDetector(
          onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
          onTapUp:
              widget.enabled
                  ? (_) async {
                    await _ctrl.reverse();
                    widget.onTap();
                  }
                  : null,
          onTapCancel: widget.enabled ? () => _ctrl.reverse() : null,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient:
                    widget.enabled
                        ? widget.gradient
                        : c.disabledGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow:
                    widget.enabled
                        ? [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.onPlayer.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: c.onPlayer, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.onPlayer,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.enabled
                              ? widget.subtitle
                              : (widget.disabledReason ?? widget.subtitle),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: c.onPlayerHigh,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: c.onPlayerHigh,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
