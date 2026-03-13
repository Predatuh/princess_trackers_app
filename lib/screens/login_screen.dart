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

          // Overload flash â€” multi-stage: cyan flash â†’ white burn â†’ fade
          if (_phase == _AuthPhase.success)
            AnimatedBuilder(
              animation: Listenable.merge([_chargeCtrl, _explodeCtrl]),
              builder: (_, __) {
                // During charge: pulsing cyan overlay
                double chargeGlow = 0;
                if (_chargeCtrl.value > 0.5) {
                  final p = (_chargeCtrl.value - 0.5) * 2; // 0â†’1
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
          // Logo â€” scales up then shatters away during explosion
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


// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// WIRE SPARK PAINTER â€” jagged electrical arcs + crackling discharge
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SparkPainter extends CustomPainter {
  final double t;
  final double logoRadius;
  final double chargeT;

  _SparkPainter(this.t, this.logoRadius, this.chargeT);

  // Generate a jagged lightning path from start to end
  Path _jaggedPath(Offset start, Offset end, int segments, double deviation, int seed) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    final rng = math.Random(seed + (t * 60).toInt());
    for (int i = 1; i < segments; i++) {
      final lerp = i / segments;
      final midX = start.dx + (end.dx - start.dx) * lerp;
      final midY = start.dy + (end.dy - start.dy) * lerp;
      final perpX = -(end.dy - start.dy) / (end - start).distance;
      final perpY = (end.dx - start.dx) / (end - start).distance;
      final jitter = (rng.nextDouble() - 0.5) * 2 * deviation;
      path.lineTo(midX + perpX * jitter, midY + perpY * jitter);
    }
    path.lineTo(end.dx, end.dy);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final intensity = 1.0 + chargeT * 2.0;
    final arcCount = (6 * intensity).round().clamp(6, 16);

    // â”€â”€ Jagged electric arcs radiating from crown edge â”€â”€
    for (int i = 0; i < arcCount; i++) {
      final seed = i * 137 + (t * 30).toInt();
      final rng = math.Random(seed);
      // Arc origin on the logo circle, randomised angle
      final baseAngle = (i / arcCount) * 2 * math.pi + t * math.pi * 0.4;
      final angleJitter = rng.nextDouble() * 0.5 - 0.25;
      final angle = baseAngle + angleJitter;

      final startDist = logoRadius * 0.9;
      final flickerLen = 20.0 + rng.nextDouble() * (30 + chargeT * 60);
      final start = Offset(
        center.dx + startDist * math.cos(angle),
        center.dy + startDist * math.sin(angle),
      );
      final end = Offset(
        center.dx + (startDist + flickerLen) * math.cos(angle),
        center.dy + (startDist + flickerLen) * math.sin(angle),
      );

      // Flicker: blink arcs in/out rapidly
      final flicker = math.sin(t * math.pi * 18 + i * 2.3);
      if (flicker < -0.1) continue;
      final alpha = (flicker + 0.1).clamp(0.0, 1.0) * (0.6 + chargeT * 0.4);

      // Branch colours â€” cyan/white core, purple glow
      final isWhite = i % 3 == 0;
      final arcColor = isWhite ? Colors.white : C.cyan;

      // Outer glow stroke
      final glowPaint = Paint()
        ..color = C.cyan.withValues(alpha: alpha * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0 + chargeT * 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(
          _jaggedPath(start, end, 5 + i % 3, 8 + chargeT * 10, seed), glowPaint);

      // Core bright stroke
      final corePaint = Paint()
        ..color = arcColor.withValues(alpha: alpha * 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + (isWhite ? 0.5 : 0)
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
          _jaggedPath(start, end, 5 + i % 3, 8 + chargeT * 10, seed), corePaint);

      // Tiny spark dot at tip
      final tip = end;
      canvas.drawCircle(
        tip,
        1.5 + rng.nextDouble(),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // â”€â”€ Crackling small secondary sparks around logo edge â”€â”€
    final crackleCount = (12 + chargeT * 20).round();
    for (int i = 0; i < crackleCount; i++) {
      final seed2 = i * 53 + (t * 45).toInt();
      final rng2 = math.Random(seed2);
      final angle = rng2.nextDouble() * 2 * math.pi;
      final r = logoRadius + rng2.nextDouble() * (8 + chargeT * 15);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      final flicker2 = math.sin(t * math.pi * 25 + i * 4.7);
      if (flicker2 < 0) continue;
      final sz = 0.8 + rng2.nextDouble() * 1.5;
      final sparkColors = [C.cyan, Colors.white, C.gold, C.purple];
      final sc = sparkColors[i % sparkColors.length];
      canvas.drawCircle(
        Offset(x, y),
        sz * 1.8,
        Paint()
          ..color = sc.withValues(alpha: flicker2 * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 2),
      );
      canvas.drawCircle(
        Offset(x, y),
        sz,
        Paint()..color = Colors.white.withValues(alpha: flicker2 * 0.85),
      );
    }

    // â”€â”€ During heavy charge: forking bolts (crown shorting out) â”€â”€
    if (chargeT > 0.3) {
      final forkAlpha = ((chargeT - 0.3) / 0.7).clamp(0.0, 1.0);
      final forkCount = (forkAlpha * 4).round().clamp(1, 4);
      for (int fi = 0; fi < forkCount; fi++) {
        final fa = fi * (math.pi / 2) + t * math.pi;
        final fseed = fi * 91 + (t * 20).toInt();
        final fstart = Offset(
          center.dx + logoRadius * 0.8 * math.cos(fa),
          center.dy + logoRadius * 0.8 * math.sin(fa),
        );
        final fend = Offset(
          center.dx + (logoRadius + 50 + chargeT * 40) * math.cos(fa + 0.1),
          center.dy + (logoRadius + 50 + chargeT * 40) * math.sin(fa + 0.1),
        );
        final fFlicker = (math.sin(t * math.pi * 22 + fi * 5) + 1) / 2;
        if (fFlicker < 0.2) continue;

        // Forking branch
        final fmidAngle = fa + (math.Random(fseed).nextDouble() - 0.5) * 0.6;
        final fmid = Offset(
          center.dx + (logoRadius + 25) * math.cos(fmidAngle),
          center.dy + (logoRadius + 25) * math.sin(fmidAngle),
        );
        final fEnd2 = Offset(
          center.dx + (logoRadius + 40 + chargeT * 30) * math.cos(fmidAngle + 0.3),
          center.dy + (logoRadius + 40 + chargeT * 30) * math.sin(fmidAngle + 0.3),
        );

        for (final pts in [
          [fstart, fend],
          [fmid, fEnd2]
        ]) {
          canvas.drawPath(
            _jaggedPath(pts[0], pts[1], 6, 12 + chargeT * 8, fseed),
            Paint()
              ..color = Colors.white.withValues(alpha: fFlicker * forkAlpha * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.t != t || old.chargeT != chargeT;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// CHARGE RING PAINTER â€” electric overload buildup rings
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ChargeRingPainter extends CustomPainter {
  final double t; // 0â†’1 charge progress
  final double logoRadius;

  _ChargeRingPainter(this.t, this.logoRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Expanding electromagnetic rings that pulse outward
    final ringCount = (2 + t * 3).round();
    for (int i = 0; i < ringCount; i++) {
      final phase = (t * 2 + i * 0.5) % 1.0;
      final radius = logoRadius * (1.05 + phase * 1.2);
      final flickerAlpha = math.sin(t * math.pi * 16 + i) * 0.5 + 0.5;
      final opacity = (math.sin(phase * math.pi) * (0.12 + t * 0.35) * flickerAlpha).clamp(0.0, 1.0);
      final strokeW = 1.2 + (1 - phase) * 1.8;
      final color = i.isEven ? C.cyan : C.purple;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeW * 3),
      );
    }

    // Core electromagnetic glow that brightens on overload
    if (t > 0.3) {
      final coreI = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
      final flicker = (math.sin(t * math.pi * 30) + 1) / 2;
      canvas.drawCircle(
        center,
        logoRadius * 0.9,
        Paint()
          ..color = C.cyan.withValues(alpha: coreI * flicker * 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, logoRadius * 0.5),
      );
    }

    // Pre-overload warning: rapid white flicker at high charge
    if (t > 0.75) {
      final warn = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
      final warnFlicker = (math.sin(t * math.pi * 50) + 1) / 2;
      canvas.drawCircle(
        center,
        logoRadius * 1.02,
        Paint()
          ..color = Colors.white.withValues(alpha: warn * warnFlicker * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, logoRadius * 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_ChargeRingPainter old) => old.t != t;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SHATTER EXPLOSION PAINTER â€” crown fragments fly outward
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _OverloadExplosionPainter extends CustomPainter {
  final double t; // 0â†’1
  final double logoRadius;

  _OverloadExplosionPainter(this.t, this.logoRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = logoRadius / 65;

    // â”€â”€ Shockwave shatter rings â”€â”€
    for (int r = 0; r < 4; r++) {
      final delay = r * 0.06;
      final rt = (t - delay).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final ringR = logoRadius * (0.4 + rt * 3.5);
      final ringAlpha = math.pow(1 - rt, 1.8).toDouble().clamp(0.0, 1.0);
      final sw = (3.5 - r * 0.5) * (1 - rt * 0.8);
      if (ringAlpha > 0 && sw > 0.1) {
        final rc = r == 0 ? Colors.white : (r == 1 ? C.cyan : (r == 2 ? C.purple : C.gold));
        canvas.drawCircle(
          center,
          ringR,
          Paint()
            ..color = rc.withValues(alpha: ringAlpha * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + rt * 5),
        );
      }
    }

    // â”€â”€ Crown shard fragments flying outward â”€â”€
    // Each shard is a small irregular polygon
    const shardCount = 24;
    for (int i = 0; i < shardCount; i++) {
      final rng = math.Random(i * 137);
      final angle = (i / shardCount) * 2 * math.pi + rng.nextDouble() * 0.4;
      final speed = (80.0 + rng.nextDouble() * 60) * scale;
      final spinSpeed = (rng.nextDouble() - 0.5) * 8;

      // Fragments accelerate outward then slow
      final dist = speed * t * (2 - t); // ease out
      final shardX = center.dx + dist * math.cos(angle);
      final shardY = center.dy + dist * math.sin(angle);

      // Fade out
      final fadeStart = 0.25 + rng.nextDouble() * 0.3;
      final opacity = t < fadeStart
          ? 1.0
          : math.pow(1 - ((t - fadeStart) / (1 - fadeStart)), 1.5)
              .toDouble()
              .clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      // Shard shape â€” small irregular triangle/quad
      final shardSize = (3.0 + rng.nextDouble() * 4.0) * (1 - t * 0.4);
      final rotation = t * spinSpeed * math.pi;

      canvas.save();
      canvas.translate(shardX, shardY);
      canvas.rotate(rotation);

      // Draw a triangular shard
      final path = Path();
      final pts = 3 + (i % 2); // 3 or 4 points
      for (int p = 0; p < pts; p++) {
        final a = (p / pts) * 2 * math.pi + rng.nextDouble() * 0.6;
        final r2 = shardSize * (0.5 + rng.nextDouble() * 0.5);
        if (p == 0) {
          path.moveTo(r2 * math.cos(a), r2 * math.sin(a));
        } else {
          path.lineTo(r2 * math.cos(a), r2 * math.sin(a));
        }
      }
      path.close();

      // Shard fill â€” glowing fragment material
      final shardColors = [C.cyan, C.purple, C.gold, Colors.white];
      final sc = shardColors[i % shardColors.length];

      canvas.drawPath(
        path,
        Paint()
          ..color = sc.withValues(alpha: opacity * 0.9)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shardSize * 0.4),
      );
      // Bright edge highlight
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );

      canvas.restore();
    }

    // â”€â”€ High-energy bolt spray at explosion origin (early phase) â”€â”€
    if (t < 0.45) {
      final boltAlpha = (1 - t / 0.45).clamp(0.0, 1.0);
      const boltCount = 16;
      final rngB = math.Random((t * 60).toInt());
      for (int b = 0; b < boltCount; b++) {
        final bAngle = (b / boltCount) * 2 * math.pi;
        final bLen = (20 + rngB.nextDouble() * 40) * scale * (1 + t);
        final bEnd = Offset(
          center.dx + bLen * math.cos(bAngle),
          center.dy + bLen * math.sin(bAngle),
        );
        // Jagged bolt from center
        final bPath = Path();
        bPath.moveTo(center.dx, center.dy);
        final segments = 4;
        for (int s = 1; s < segments; s++) {
          final lerp = s / segments;
          final mx = center.dx + (bEnd.dx - center.dx) * lerp;
          final my = center.dy + (bEnd.dy - center.dy) * lerp;
          final jitter = (rngB.nextDouble() - 0.5) * 12;
          bPath.lineTo(mx + jitter, my + jitter);
        }
        bPath.lineTo(bEnd.dx, bEnd.dy);

        canvas.drawPath(
          bPath,
          Paint()
            ..color = C.cyan.withValues(alpha: boltAlpha * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawPath(
          bPath,
          Paint()
            ..color = Colors.white.withValues(alpha: boltAlpha * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OverloadExplosionPainter old) => old.t != t;
}
