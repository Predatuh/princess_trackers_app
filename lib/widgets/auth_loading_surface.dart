import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

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
  late final AnimationController _spinController;
  late final AnimationController _pulseController;
  late final AnimationController _scanController;
  late final AnimationController _releaseController;
  late final AnimationController _failureController;

  bool _didNotifyRelease = false;
  bool _hasRiveAsset = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
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
    _spinController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
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
        _spinController,
        _pulseController,
        _scanController,
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
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: _FallbackLoaderPainter(
                    spinValue: _spinController.value,
                    pulseValue: _pulseController.value,
                    releaseValue: releaseValue,
                    failureValue: failureValue,
                    phase: widget.phase,
                  ),
                ),
                Center(
                  child: _LogoCore(
                    phase: widget.phase,
                    pulseValue: _pulseController.value,
                    scanValue: _scanController.value,
                    releaseValue: releaseValue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogoCore extends StatelessWidget {
  const _LogoCore({
    required this.phase,
    required this.pulseValue,
    required this.scanValue,
    required this.releaseValue,
  });

  final AuthLoaderPhase phase;
  final double pulseValue;
  final double scanValue;
  final double releaseValue;

  @override
  Widget build(BuildContext context) {
    final highlightColor = phase == AuthLoaderPhase.failed ? C.pink : C.cyan;
    final accentColor = phase == AuthLoaderPhase.failed ? C.pink : C.gold;
    final coreSize = 220.0 + (releaseValue * 12);

    return SizedBox(
      width: coreSize,
      height: coreSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.16, -0.22),
            radius: 0.88,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              const Color(0xFF111B2C),
              const Color(0xFF060A12),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: highlightColor.withValues(alpha: 0.22 + (pulseValue * 0.12)),
              blurRadius: 28,
              spreadRadius: -10,
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.16 + (releaseValue * 0.18)),
              blurRadius: 42,
              spreadRadius: -16,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        highlightColor.withValues(alpha: 0.05),
                        Colors.transparent,
                        accentColor.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(38),
                child: Transform.scale(
                  scale: 0.985 + (pulseValue * 0.02),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment(0, (scanValue * 1.8) - 0.9),
                    child: Container(
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            highlightColor.withValues(alpha: 0.07),
                            highlightColor.withValues(alpha: 0.32),
                            highlightColor.withValues(alpha: 0.07),
                            Colors.transparent,
                          ],
                        ),
                      ),
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

class _FallbackLoaderPainter extends CustomPainter {
  const _FallbackLoaderPainter({
    required this.spinValue,
    required this.pulseValue,
    required this.releaseValue,
    required this.failureValue,
    required this.phase,
  });

  final double spinValue;
  final double pulseValue;
  final double releaseValue;
  final double failureValue;
  final AuthLoaderPhase phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = math.min(size.width, size.height) * 0.28;
    final highlightColor = phase == AuthLoaderPhase.failed ? C.pink : C.cyan;
    final accentColor = phase == AuthLoaderPhase.failed ? C.pink : C.gold;

    _paintBackdropGlow(canvas, center, baseRadius, highlightColor, accentColor);
    _paintStaticRings(canvas, center, baseRadius, highlightColor, accentColor);
    _paintActiveSweep(canvas, center, baseRadius, highlightColor, accentColor);
    _paintOrbitDots(canvas, center, baseRadius, highlightColor, accentColor);

    if (phase == AuthLoaderPhase.releasing) {
      _paintRelease(canvas, center, baseRadius, highlightColor, accentColor);
    }

    if (phase == AuthLoaderPhase.failed) {
      _paintFailure(canvas, center, baseRadius);
    }
  }

  void _paintBackdropGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color highlightColor,
    Color accentColor,
  ) {
    final ambientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          highlightColor.withValues(alpha: 0.14 + (pulseValue * 0.06)),
          accentColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 2.3),
      );
    canvas.drawCircle(center, radius * 2.3, ambientPaint);
  }

  void _paintStaticRings(
    Canvas canvas,
    Offset center,
    double radius,
    Color highlightColor,
    Color accentColor,
  ) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius * 1.34, ringPaint);
    canvas.drawCircle(center, radius * 1.10, ringPaint);

    final accentRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = highlightColor.withValues(alpha: 0.12 + (pulseValue * 0.08));
    canvas.drawCircle(center, radius * 1.22, accentRing);

    final trimRect = Rect.fromCircle(center: center, radius: radius * 1.34);
    final trimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6
      ..color = accentColor.withValues(alpha: 0.56);
    canvas.drawArc(
      trimRect,
      -math.pi / 2,
      math.pi * 0.24,
      false,
      trimPaint,
    );
    canvas.drawArc(
      trimRect,
      math.pi * 0.72,
      math.pi * 0.16,
      false,
      trimPaint,
    );
  }

  void _paintActiveSweep(
    Canvas canvas,
    Offset center,
    double radius,
    Color highlightColor,
    Color accentColor,
  ) {
    final orbitRect = Rect.fromCircle(center: center, radius: radius * 1.22);
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          Colors.transparent,
          highlightColor.withValues(alpha: 0.10),
          highlightColor,
          accentColor,
          Colors.transparent,
        ],
        stops: const [0.0, 0.36, 0.62, 0.82, 1.0],
        transform: GradientRotation(spinValue * math.pi * 2),
      ).createShader(orbitRect);

    final sweep = phase == AuthLoaderPhase.releasing
        ? math.pi * (0.9 + (releaseValue * 0.5))
        : math.pi * (0.42 + (pulseValue * 0.08));
    canvas.drawArc(
      orbitRect,
      -math.pi / 2 + (spinValue * math.pi * 2),
      sweep,
      false,
      sweepPaint,
    );
  }

  void _paintOrbitDots(
    Canvas canvas,
    Offset center,
    double radius,
    Color highlightColor,
    Color accentColor,
  ) {
    final orbitRadius = radius * 1.46;
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (var index = 0; index < 4; index++) {
      final progress = (spinValue + (index * 0.17)) % 1.0;
      final angle = (progress * math.pi * 2) - (math.pi / 2);
      final distance = orbitRadius + (math.sin((progress + pulseValue) * math.pi * 2) * 6);
      final dotCenter = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );

      dotPaint.color = index.isEven
          ? highlightColor.withValues(alpha: 0.72)
          : accentColor.withValues(alpha: 0.68);
      canvas.drawCircle(dotCenter, index.isEven ? 4.6 : 3.4, dotPaint);
    }
  }

  void _paintRelease(
    Canvas canvas,
    Offset center,
    double radius,
    Color highlightColor,
    Color accentColor,
  ) {
    for (var index = 0; index < 3; index++) {
      final progress = ((releaseValue - (index * 0.1)) / 0.9).clamp(0.0, 1.0);
      if (progress <= 0) {
        continue;
      }

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 - index
        ..color = (index.isEven ? highlightColor : accentColor).withValues(
          alpha: (1 - progress) * 0.34,
        );
      canvas.drawCircle(center, radius * (1.1 + (progress * 1.1)), ringPaint);
    }
  }

  void _paintFailure(Canvas canvas, Offset center, double radius) {
    final warningPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = C.pink.withValues(alpha: 0.42 * (1 - failureValue));
    final warningRadius = radius * (1.5 + (failureValue * 0.15));
    canvas.drawCircle(center, warningRadius, warningPaint);
  }

  @override
  bool shouldRepaint(covariant _FallbackLoaderPainter oldDelegate) {
    return oldDelegate.spinValue != spinValue ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.releaseValue != releaseValue ||
        oldDelegate.failureValue != failureValue ||
        oldDelegate.phase != phase;
  }
}