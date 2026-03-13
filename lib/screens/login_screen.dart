import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

enum _AuthPhase { idle, loading, success }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  _AuthPhase _phase = _AuthPhase.idle;
  String? _error;

  // Initial entrance fade
  late AnimationController _enterCtrl;
  late Animation<double> _enterFade;

  // Zoom transition (0=idle, 1=fully zoomed)
  late AnimationController _transCtrl;
  late Animation<double> _formFade;
  late Animation<double> _logoScale;
  late Animation<double> _overlayFade;

  // Continuous sparks (fast cycle for electric feel)
  late AnimationController _sparkCtrl;

  // Charging energy buildup
  late AnimationController _chargeCtrl;

  // One-shot overload explosion (longer for dramatic effect)
  late AnimationController _explodeCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _enterFade =
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _formFade = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _transCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    ));
    _logoScale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _transCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _overlayFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _transCtrl,
      curve: const Interval(0.1, 0.55, curve: Curves.easeOut),
    ));

    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _chargeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _explodeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _explodeCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _enterCtrl.dispose();
    _transCtrl.dispose();
    _sparkCtrl.dispose();
    _chargeCtrl.dispose();
    _explodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_phase != _AuthPhase.idle) return;
    setState(() {
      _phase = _AuthPhase.loading;
      _error = null;
    });
    _transCtrl.forward();

    final state = context.read<AppState>();
    final ok =
        await state.login(_nameCtrl.text.trim(), _pinCtrl.text.trim());
    if (!mounted) return;

    if (ok) {
      setState(() => _phase = _AuthPhase.success);
      // Start charging buildup
      _chargeCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 2400));
      // Then the overload explosion
      if (mounted) _explodeCtrl.forward();
    } else {
      await _transCtrl.reverse();
      if (mounted) {
        setState(() {
          _phase = _AuthPhase.idle;
          _error = state.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Base gradient always visible
          Container(decoration: AppTheme.backgroundGradient),

          // Animated mesh only in idle
          if (_phase == _AuthPhase.idle)
            const AnimatedMeshBackground(child: SizedBox.expand()),

          // Form layout (fades out when loading starts)
          if (_phase != _AuthPhase.success)
            FadeTransition(
              opacity: _phase == _AuthPhase.idle
                  ? _enterFade
                  : _formFade,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        _buildLogo(80),
                        const SizedBox(height: 24),
                        Text(
                          'PRINCESS',
                          style: AppTheme.displayFont(
                              size: 28,
                              weight: FontWeight.w700,
                              color: C.text),
                        ),
                        Text(
                          'TRACKERS',
                          style: AppTheme.displayFont(
                              size: 14,
                              weight: FontWeight.w400,
                              color: C.cyan),
                        ),
                        const SizedBox(height: 48),
                        GlassCard(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Sign In',
                                  style: AppTheme.font(
                                      size: 20,
                                      weight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                'Access your tracking dashboard',
                                style: AppTheme.font(
                                    size: 13, color: C.textDim),
                              ),
                              const SizedBox(height: 28),
                              GlowTextField(
                                controller: _nameCtrl,
                                label: 'Name',
                                icon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              GlowTextField(
                                controller: _pinCtrl,
                                label: 'PIN',
                                icon: Icons.lock_outline_rounded,
                                obscure: true,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                onSubmitted: (_) => _login(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8),
                                  decoration: BoxDecoration(
                                    color: C.pink
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                        color: C.pink
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline,
                                        color: C.pink, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_error!,
                                          style: AppTheme.font(
                                              size: 13,
                                              color: C.pink)),
                                    ),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: 24),
                              NeonButton(
                                label: 'SIGN IN',
                                icon: Icons.arrow_forward_rounded,
                                loading:
                                    _phase == _AuthPhase.loading,
                                onPressed: _login,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('v1.0.0',
                            style: AppTheme.font(
                                size: 11, color: C.textDim)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Loading / success overlay: zooming logo + sparks/explosion
          if (_phase != _AuthPhase.idle)
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_transCtrl, _sparkCtrl, _chargeCtrl, _explodeCtrl]),
              builder: (_, __) {
                // Screen shake during explosion
                double shakeX = 0, shakeY = 0;
                if (_explodeCtrl.value > 0 && _explodeCtrl.value < 0.6) {
                  final intensity = 12.0 * (1 - _explodeCtrl.value / 0.6);
                  shakeX = math.sin(_explodeCtrl.value * 47) * intensity;
                  shakeY = math.cos(_explodeCtrl.value * 53) * intensity;
                }
                return Transform.translate(
                  offset: Offset(shakeX, shakeY),
                  child: Opacity(
                    opacity: _overlayFade.value.clamp(0.0, 1.0),
                    child: Center(child: _buildAnimatingLogo()),
                  ),
                );
              },
            ),

          // Overload flash — multi-stage: cyan flash → white burn → fade
          if (_phase == _AuthPhase.success)
            AnimatedBuilder(
              animation: Listenable.merge([_chargeCtrl, _explodeCtrl]),
              builder: (_, __) {
                // During charge: pulsing cyan overlay
                double chargeGlow = 0;
                if (_chargeCtrl.value > 0.5) {
                  final p = (_chargeCtrl.value - 0.5) * 2; // 0→1
                  chargeGlow = math.sin(p * math.pi * 4) * 0.15 * p;
                }
                // During explosion: intense white burn
                double explodeFlash = 0;
                if (_explodeCtrl.value > 0) {
                  final t = _explodeCtrl.value;
                  if (t < 0.3) {
                    explodeFlash = (t / 0.3); // ramp up
                  } else if (t < 0.5) {
                    explodeFlash = 1.0; // hold white
                  } else {
                    explodeFlash = (1.0 - (t - 0.5) / 0.5); // fade out
                  }
                }
                final totalAlpha = (chargeGlow + explodeFlash * 0.95).clamp(0.0, 1.0);
                if (totalAlpha <= 0) return const SizedBox.shrink();
                return Container(
                  color: Color.lerp(
                    C.cyan.withValues(alpha: totalAlpha * 0.6),
                    Colors.white.withValues(alpha: totalAlpha),
                    _explodeCtrl.value.clamp(0.0, 1.0),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatingLogo() {
    final logoSize = 80.0 + 180.0 * _logoScale.value;
    final canvasSize = logoSize + 220.0; // bigger canvas for bigger effects
    final showSparks = _phase == _AuthPhase.loading ||
        (_phase == _AuthPhase.success && _explodeCtrl.value == 0.0);
    final chargeT = _chargeCtrl.value;

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Charge-up energy rings
          if (chargeT > 0 && _explodeCtrl.value == 0)
            Positioned.fill(
              child: CustomPaint(
                painter: _ChargeRingPainter(chargeT, logoSize / 2),
              ),
            ),
          // Floating sparks while loading
          if (showSparks)
            Positioned.fill(
              child: CustomPaint(
                painter: _SparkPainter(
                    _sparkCtrl.value, logoSize / 2, chargeT),
              ),
            ),
          // Overload explosion
          if (_explodeCtrl.value > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: _OverloadExplosionPainter(
                    _explodeCtrl.value, logoSize / 2),
              ),
            ),
          // Logo — scales up then shatters away during explosion
          if (_explodeCtrl.value < 0.35)
            Transform.scale(
              scale: _explodeCtrl.value > 0
                  ? 1.0 + _explodeCtrl.value * 3.0 // swell up before shattering
                  : 1.0,
              child: Opacity(
                opacity: _explodeCtrl.value > 0.15
                    ? (1.0 - ((_explodeCtrl.value - 0.15) / 0.2)).clamp(0.0, 1.0)
                    : 1.0,
                child: _buildLogo(logoSize, chargeT),
              ),
            )
          else if (_explodeCtrl.value == 0)
            _buildLogo(logoSize, chargeT),
        ],
      ),
    );
  }

  Widget _buildLogo(double size, [double chargeT = 0]) {
    // Intensifying glow during charge-up
    final glowColor = Color.lerp(C.cyan, Colors.white, chargeT * 0.5)!;
    final glowBlur = 30.0 + chargeT * 40;
    final pulseScale = 1.0 + math.sin(chargeT * math.pi * 6) * 0.03 * chargeT;

    return Transform.scale(
      scale: pulseScale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.4 + chargeT * 0.4),
              blurRadius: glowBlur,
              spreadRadius: -2 + chargeT * 8,
            ),
            BoxShadow(
              color: C.purple.withValues(alpha: 0.15 + chargeT * 0.2),
              blurRadius: glowBlur * 1.5,
              spreadRadius: -5 + chargeT * 4,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [C.cyan, C.purple],
                ),
              ),
              child: Icon(Icons.track_changes_rounded,
                  size: size * 0.5, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LIGHTNING PAINTER — multi-segment branching bolts
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// SPARK PAINTER — floating, twinkling spark particles
// ─────────────────────────────────────────────
class _SparkPainter extends CustomPainter {
  final double t;
  final double logoRadius;
  final double chargeT;

  _SparkPainter(this.t, this.logoRadius, this.chargeT);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final intensity = 1.0 + chargeT * 1.5;

    // ── Layer 1: Orbiting spark ring ──
    final orbitCount = (20 * intensity).round().clamp(20, 40);
    for (int i = 0; i < orbitCount; i++) {
      final baseAngle = (i / orbitCount) * 2 * math.pi;
      final speed = 0.3 + (i % 3) * 0.15;
      final angle = baseAngle + t * 2 * math.pi * speed;

      // Twinkle flicker
      final twinkle = (math.sin(t * 2 * math.pi * (1.5 + i * 0.2) + i * 2.7) + 1) / 2;
      if (twinkle < 0.15) continue;
      final opacity = ((twinkle - 0.15) / 0.85).clamp(0.0, 1.0) * (0.6 + chargeT * 0.4);

      // Radial drift — sparks float in/out from logo
      final drift = math.sin(t * 1.8 + i * 1.5) * (12 + chargeT * 20);
      final radius = logoRadius + 10 + drift;

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      // Spark size — small base, grows with charge
      final sparkSize = (1.2 + chargeT * 2.5 + twinkle * 1.5) * (0.8 + (i % 3) * 0.2);

      // Color palette
      final colors = [C.cyan, C.purple, C.gold, Colors.white];
      final sparkColor = colors[i % colors.length];

      // Outer glow halo
      canvas.drawCircle(
        Offset(x, y),
        sparkSize * 3,
        Paint()
          ..color = sparkColor.withValues(alpha: opacity * 0.1)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sparkSize * 3),
      );
      // Mid glow
      canvas.drawCircle(
        Offset(x, y),
        sparkSize * 1.5,
        Paint()
          ..color = sparkColor.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sparkSize * 1.5),
      );
      // Bright core
      canvas.drawCircle(
        Offset(x, y),
        sparkSize * 0.6,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.9)
          ..style = PaintingStyle.fill,
      );

      // 4-point star cross on brighter sparks
      if (twinkle > 0.6 && sparkSize > 2) {
        final crossLen = sparkSize * 2.5;
        final crossOpacity = opacity * 0.35;
        final crossPaint = Paint()
          ..color = sparkColor.withValues(alpha: crossOpacity)
          ..strokeWidth = 0.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5);
        // Horizontal
        canvas.drawLine(
          Offset(x - crossLen, y), Offset(x + crossLen, y), crossPaint);
        // Vertical
        canvas.drawLine(
          Offset(x, y - crossLen), Offset(x, y + crossLen), crossPaint);
      }
    }

    // ── Layer 2: Rising embers (float upward like fire sparks) ──
    final emberCount = (10 + chargeT * 18).round();
    for (int i = 0; i < emberCount; i++) {
      final seed = i * 5.37 + 2.1;
      final phase = (t * (0.4 + (i % 4) * 0.1) + seed) % 1.0;

      // Rise from bottom of orbit to top, then reset
      final riseAngle = -math.pi / 2 + math.sin(seed) * 0.8; // mostly upward
      final spreadAngle = (i / emberCount) * 2 * math.pi + math.sin(seed * 1.3) * 0.5;
      final startR = logoRadius + 5;
      final travelDist = (30 + chargeT * 50) * phase;

      final x = center.dx + startR * math.cos(spreadAngle) +
          travelDist * math.cos(riseAngle) + math.sin(t * 3 + seed) * 8;
      final y = center.dy + startR * math.sin(spreadAngle) +
          travelDist * math.sin(riseAngle);

      // Fade in quickly, fade out slowly
      final fadeIn = (phase * 4).clamp(0.0, 1.0);
      final fadeOut = (1 - phase).clamp(0.0, 1.0);
      final emberOpacity = fadeIn * fadeOut * (0.5 + chargeT * 0.5);

      final emberSize = (0.6 + chargeT * 2.0) * (1 - phase * 0.5);
      final emberColors = [C.gold, C.cyan, C.purple, Colors.white, C.pink];
      final emberColor = emberColors[i % emberColors.length];

      // Glow
      canvas.drawCircle(
        Offset(x, y),
        emberSize * 2,
        Paint()
          ..color = emberColor.withValues(alpha: emberOpacity * 0.2)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, emberSize * 2.5),
      );
      // Core
      canvas.drawCircle(
        Offset(x, y),
        emberSize,
        Paint()
          ..color = emberColor.withValues(alpha: emberOpacity * 0.85)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, emberSize * 0.4),
      );
    }

    // ── Layer 3: Shimmering dust ring (subtle sparkle halo) ──
    final dustCount = (30 + chargeT * 20).round();
    for (int i = 0; i < dustCount; i++) {
      final angle = (i / dustCount) * 2 * math.pi + t * math.pi * 0.2;
      final wobble = math.sin(t * 2.5 + i * 1.7) * 6;
      final r = logoRadius + 4 + wobble + (i % 5) * 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      final flicker = (math.sin(t * 5 + i * 3.3) + 1) / 2;
      if (flicker < 0.4) continue;
      final dustOpacity = ((flicker - 0.4) / 0.6) * 0.3;
      final dustSize = 0.5 + flicker * 0.8;

      canvas.drawCircle(
        Offset(x, y),
        dustSize,
        Paint()
          ..color = Colors.white.withValues(alpha: dustOpacity)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Layer 4: Charge-up spark trails (during charge phase) ──
    if (chargeT > 0.2) {
      final trailCount = ((chargeT - 0.2) / 0.8 * 12).round().clamp(0, 12);
      for (int i = 0; i < trailCount; i++) {
        final angle = (i / 12) * 2 * math.pi + t * math.pi * 1.5;
        final trailR = logoRadius + 8;

        // Draw a trail of 4-5 diminishing dots spiraling inward
        for (int d = 0; d < 5; d++) {
          final dOffset = d * 0.04;
          final da = angle - dOffset * math.pi * 2;
          final dr = trailR + d * 3;
          final dx = center.dx + dr * math.cos(da);
          final dy = center.dy + dr * math.sin(da);
          final dSize = (2.0 - d * 0.3) * chargeT;
          final dOpacity = (0.6 - d * 0.1) * chargeT;

          final trailColor = i % 2 == 0 ? C.cyan : C.gold;
          canvas.drawCircle(
            Offset(dx, dy),
            dSize.clamp(0.3, 5.0),
            Paint()
              ..color = trailColor.withValues(alpha: dOpacity.clamp(0.0, 1.0))
              ..style = PaintingStyle.fill
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, dSize),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.t != t || old.chargeT != chargeT;
}

// ─────────────────────────────────────────────
// CHARGE RING PAINTER — energy buildup rings
// ─────────────────────────────────────────────
class _ChargeRingPainter extends CustomPainter {
  final double t; // 0→1 charge progress
  final double logoRadius;

  _ChargeRingPainter(this.t, this.logoRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Concentric pulsing rings that appear and tighten
    final ringCount = (3 + t * 4).round();
    for (int i = 0; i < ringCount; i++) {
      final phase = (t * 3 + i * 0.7) % 1.0;
      final radius = logoRadius * (1.1 + phase * 0.8);
      final opacity = (math.sin(phase * math.pi) * (0.15 + t * 0.3)).clamp(0.0, 1.0);
      final width = 1.5 + (1 - phase) * 2;
      final color = i.isEven ? C.cyan : C.purple;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2),
      );
    }

    // Inner energy core glow intensifying
    if (t > 0.4) {
      final coreIntensity = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        logoRadius * 0.95,
        Paint()
          ..color = C.cyan.withValues(alpha: coreIntensity * 0.2)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, logoRadius * 0.4),
      );
    }

    // Final overload warning flicker
    if (t > 0.8) {
      final warn = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
      final flicker = (math.sin(t * 60) + 1) / 2;
      canvas.drawCircle(
        center,
        logoRadius * 1.05,
        Paint()
          ..color = Colors.white.withValues(alpha: warn * flicker * 0.4)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, logoRadius * 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_ChargeRingPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
// OVERLOAD EXPLOSION PAINTER — massive burst
// ─────────────────────────────────────────────
class _OverloadExplosionPainter extends CustomPainter {
  final double t; // 0→1
  final double logoRadius;

  _OverloadExplosionPainter(this.t, this.logoRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = logoRadius / 65;

    // === Wave 1: Inner fast particles (small, bright, fast) ===
    const innerCount = 36;
    for (int i = 0; i < innerCount; i++) {
      final angle = (i / innerCount) * 2 * math.pi +
          math.sin(i * 1.7) * 0.3;
      final speed = (100.0 + (i % 7) * 25.0) * scale;
      final dist = speed * t * t; // accelerating
      final fadeStart = 0.3 + (i % 5) * 0.05;
      final pOpacity = t < fadeStart
          ? 1.0
          : math.pow(1.0 - ((t - fadeStart) / (1 - fadeStart)), 1.8)
              .toDouble()
              .clamp(0.0, 1.0);
      final pSize = (1.5 + (i % 3) * 0.8) * (1 - t * 0.3);

      final x = center.dx + dist * math.cos(angle);
      final y = center.dy + dist * math.sin(angle);

      final color = i % 4 == 0
          ? C.purple
          : (i % 4 == 1 ? C.cyan : (i % 4 == 2 ? Colors.white : C.gold));
      canvas.drawCircle(
        Offset(x, y),
        pSize.clamp(0.2, 8.0),
        Paint()
          ..color = color.withValues(alpha: pOpacity * 0.95)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pSize * 1.2),
      );
    }

    // === Wave 2: Larger energy chunks (slower, bigger, glowier) ===
    const chunkCount = 16;
    final chunkDelay = 0.05;
    final ct = (t - chunkDelay).clamp(0.0, 1.0);
    if (ct > 0) {
      for (int i = 0; i < chunkCount; i++) {
        final angle = (i / chunkCount) * 2 * math.pi;
        final speed = (60.0 + (i % 4) * 20.0) * scale;
        final dist = speed * ct;
        final pOpacity = math.pow(1.0 - ct, 1.2).toDouble().clamp(0.0, 1.0);
        final pSize = (4.0 + (i % 3) * 2.5) * (1 - ct * 0.4);

        final x = center.dx + dist * math.cos(angle);
        final y = center.dy + dist * math.sin(angle);
        final color = i.isEven ? C.cyan : C.purple;

        // Glow halo
        canvas.drawCircle(
          Offset(x, y),
          pSize * 2.5,
          Paint()
            ..color = color.withValues(alpha: pOpacity * 0.15)
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, pSize * 3),
        );
        // Core
        canvas.drawCircle(
          Offset(x, y),
          pSize.clamp(0.3, 14.0),
          Paint()
            ..color = Colors.white.withValues(alpha: pOpacity * 0.8)
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, pSize * 0.5),
        );
      }
    }

    // === Spark burst radiating outward during explosion ===
    if (t < 0.5) {
      const sparkBurstCount = 24;
      final burstOpacity = (1 - t * 2).clamp(0.0, 1.0);
      for (int i = 0; i < sparkBurstCount; i++) {
        final angle = (i / sparkBurstCount) * 2 * math.pi;
        final dist = (30 + t * 150) * scale;
        final x = center.dx + dist * math.cos(angle);
        final y = center.dy + dist * math.sin(angle);
        final sSize = (2.0 + (i % 3) * 1.0) * (1 - t);
        final colors = [C.cyan, C.gold, C.purple, Colors.white];
        final sColor = colors[i % colors.length];

        // Glow
        canvas.drawCircle(
          Offset(x, y),
          sSize * 2.5,
          Paint()
            ..color = sColor.withValues(alpha: burstOpacity * 0.25)
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sSize * 2),
        );
        // Core
        canvas.drawCircle(
          Offset(x, y),
          sSize,
          Paint()
            ..color = Colors.white.withValues(alpha: burstOpacity * 0.9)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // === Shockwave rings (multiple, staggered) ===
    for (int r = 0; r < 3; r++) {
      final ringDelay = r * 0.08;
      final rt = (t - ringDelay).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final ringRadius = logoRadius * (0.5 + rt * 3.0);
      final ringOpacity = math.pow(1 - rt, 2.0).toDouble().clamp(0.0, 1.0);
      final strokeW = (4.0 - r * 0.8) * (1 - rt * 0.7);
      if (ringOpacity > 0 && strokeW > 0.1) {
        final ringColor = r == 0 ? Colors.white : (r == 1 ? C.cyan : C.purple);
        canvas.drawCircle(
          center,
          ringRadius,
          Paint()
            ..color = ringColor.withValues(alpha: ringOpacity * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + rt * 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OverloadExplosionPainter old) => old.t != t;
}
