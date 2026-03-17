import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

enum AuthLoaderPhase {
  charging,
  releasing,
  failed,
}

class AuthLoadingSurface extends StatefulWidget {
  const AuthLoadingSurface({
    super.key,
    required this.size,
    required this.phase,
    required this.onSequenceComplete,
    this.riveAsset,
  });

  final Size size;
  final AuthLoaderPhase phase;
  final VoidCallback onSequenceComplete;
  final String? riveAsset;

  @override
  State<AuthLoadingSurface> createState() => _AuthLoadingSurfaceState();
}

class _AuthLoadingSurfaceState extends State<AuthLoadingSurface>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _releaseController;
  late final AnimationController _failureController;

  bool _didNotifyRelease = false;
  bool _hasRiveAsset = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _releaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_didNotifyRelease) {
          _didNotifyRelease = true;
          widget.onSequenceComplete();
        }
      });
    _failureController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _resolveRiveAsset();
  }

  Future<void> _resolveRiveAsset() async {
    final riveAsset = widget.riveAsset;
    if (riveAsset == null || riveAsset.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hasRiveAsset = false;
      });
      return;
    }

    try {
      await rootBundle.load(riveAsset);
      if (!mounted) return;
      setState(() {
        _hasRiveAsset = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasRiveAsset = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant AuthLoadingSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase == widget.phase) {
      return;
    }

    if (widget.phase == AuthLoaderPhase.releasing) {
      _failureController.stop();
      _didNotifyRelease = false;
      _releaseController.forward(from: 0);
      return;
    }

    if (widget.phase == AuthLoaderPhase.failed) {
      _releaseController.stop();
      _failureController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _releaseController.dispose();
    _failureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: Padding(
        padding: EdgeInsets.all(widget.size.width * 0.08),
        child: _hasRiveAsset ? _buildRiveSurface() : _buildFallbackSurface(),
      ),
    );
  }

  Widget _buildRiveSurface() {
    final riveAsset = widget.riveAsset;
    if (riveAsset == null || riveAsset.isEmpty) {
      return _buildFallbackSurface();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size.width * 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.92,
            colors: [
              C.surfaceLight.withValues(alpha: 0.82),
              const Color(0xFF060B16),
              const Color(0xFF03050B),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: AppTheme.neonGlowStrong(C.cyan),
        ),
        child: rive.RiveAnimation.asset(
          riveAsset,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFallbackSurface() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _releaseController,
        _failureController,
      ]),
      builder: (context, _) {
        final releaseValue = Curves.easeInOutCubic.transform(
          _releaseController.value,
        );
        final failureValue = Curves.easeOutCubic.transform(
          _failureController.value,
        );
        final shakeOffset = widget.phase == AuthLoaderPhase.failed
            ? math.sin(failureValue * math.pi * 8) * 8 * (1 - failureValue)
            : 0.0;
        final scaleBoost = widget.phase == AuthLoaderPhase.releasing
            ? 1 + (releaseValue * 0.08)
            : 1.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: scaleBoost,
            child: Center(
              child: _LogoCore(
                phase: widget.phase,
                pulseValue: _pulseController.value,
                releaseValue: releaseValue,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogoCore extends StatefulWidget {
  const _LogoCore({
    required this.phase,
    required this.pulseValue,
    required this.releaseValue,
  });

  final AuthLoaderPhase phase;
  final double pulseValue;
  final double releaseValue;

  @override
  State<_LogoCore> createState() => _LogoCoreState();
}

class _LogoCoreState extends State<_LogoCore> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.asset('assets/animations/loading.mp4');
    _videoCtrl = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      await ctrl.play();
      if (!mounted) return;
      setState(() => _videoReady = true);
    } catch (_) {
      // fallback to static icon
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coreSize = 220.0 + (widget.releaseValue * 12);

    return SizedBox(
      width: coreSize,
      height: coreSize,
      child: ClipOval(
        child: Container(
          color: const Color(0xFF060A12),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Static icon (visible until video is ready)
              Padding(
                padding: const EdgeInsets.all(38),
                child: AnimatedOpacity(
                  opacity: _videoReady ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 350),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              // Loading video (fades in seamlessly)
              if (_videoCtrl != null && _videoCtrl!.value.isInitialized)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _videoReady ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 350),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoCtrl!.value.size.width,
                        height: _videoCtrl!.value.size.height,
                        child: VideoPlayer(_videoCtrl!),
                      ),
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

// Old _FallbackLoaderPainter removed — video replaces it.