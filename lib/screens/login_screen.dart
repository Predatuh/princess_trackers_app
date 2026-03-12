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

  // Continuous sparks
  late AnimationController _sparkCtrl;

  // One-shot explosion
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
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _explodeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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
      await Future.delayed(const Duration(milliseconds: 350));
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
                  [_transCtrl, _sparkCtrl, _explodeCtrl]),
              builder: (_, __) => Opacity(
                opacity: _overlayFade.value.clamp(0.0, 1.0),
                child: Center(child: _buildAnimatingLogo()),
              ),
            ),

          // White flash on explosion
          if (_phase == _AuthPhase.success)
            AnimatedBuilder(
              animation: _explodeCtrl,
              builder: (_, __) => Opacity(
                opacity: (_explodeCtrl.value *
                        _explodeCtrl.value *
                        0.9)
                    .clamp(0.0, 1.0),
                child: Container(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatingLogo() {
    // Logo zooms from ~80px to ~260px as _logoScale goes 0→1
    final logoSize = 80.0 + 180.0 * _logoScale.value;
    final canvasSize = logoSize + 120.0;
    final showSparks = _phase == _AuthPhase.loading ||
        (_phase == _AuthPhase.success && _explodeCtrl.value == 0.0);

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showSparks)
            Positioned.fill(
              child: CustomPaint(
                painter:
                    _SparkPainter(_sparkCtrl.value, logoSize / 2),
              ),
            ),
          if (_explodeCtrl.value > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: _ExplosionPainter(
                    _explodeCtrl.value, logoSize / 2),
              ),
            ),
          _buildLogo(logoSize),
        ],
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppTheme.neonGlowStrong(C.cyan),
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
    );
  }
}

// ─────────────────────────────────────────────
// SPARK PAINTER — electric arcs while loading
// ─────────────────────────────────────────────
class _SparkPainter extends CustomPainter {
  final double t;
  final double logoRadius;

  _SparkPainter(this.t, this.logoRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const boltCount = 10;
    const particleCount = 6;

    final linePaint = Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final glowPaint = Paint()
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    for (int i = 0; i < boltCount; i++) {
      final baseAngle = (i / boltCount) * 2 * math.pi;
      final wobble =
          math.sin(t * 2 * math.pi * 1.7 + i * 1.9) * 0.35;
      final angle = baseAngle + wobble;

      // Per-bolt flicker at different frequencies
      final flash =
          (math.sin(t * 2 * math.pi * (2.1 + i * 0.3) + i * 2.5) +
                  1) /
              2;
      if (flash < 0.25) continue;
      final opacity = ((flash - 0.25) / 0.75).clamp(0.0, 1.0);
      final len = 14.0 + 22.0 * flash;

      // Bolt start from circle edge
      final sx = center.dx + logoRadius * math.cos(angle);
      final sy = center.dy + logoRadius * math.sin(angle);
      final ex = sx +
          len * math.cos(angle) +
          math.sin(t * 7 + i * 1.3) * 7;
      final ey = sy +
          len * math.sin(angle) +
          math.cos(t * 7 + i * 1.3) * 7;

      // Mid-point jag (makes it look electric)
      final mx =
          (sx + ex) / 2 + math.sin(t * 11 + i) * 6;
      final my =
          (sy + ey) / 2 + math.cos(t * 11 + i) * 6;

      final color = i.isEven
          ? C.cyan.withValues(alpha: opacity * 0.95)
          : C.purple.withValues(alpha: opacity * 0.85);

      final path = Path()
        ..moveTo(sx, sy)
        ..lineTo(mx, my)
        ..lineTo(ex, ey);

      glowPaint.color = color.withValues(alpha: opacity * 0.3);
      linePaint.color = color;
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);

      // Branch spark on every 3rd bolt
      if (i % 3 == 0 && flash > 0.55) {
        final ba = angle + 0.45;
        final bLen = len * 0.5;
        final bPath = Path()
          ..moveTo(mx, my)
          ..lineTo(mx + bLen * math.cos(ba),
              my + bLen * math.sin(ba));
        linePaint.color = color.withValues(alpha: opacity * 0.5);
        canvas.drawPath(bPath, linePaint);
      }
    }

    // Orbiting particles
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi +
          t * 2 * math.pi * 0.6;
      final orbitR =
          logoRadius + 18 + math.sin(t * 3.2 + i) * 9;
      final x = center.dx + orbitR * math.cos(angle);
      final y = center.dy + orbitR * math.sin(angle);
      final pOpacity =
          (0.35 + 0.65 * math.sin(t * 4 + i)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        1.8,
        Paint()
          ..color = C.cyan.withValues(alpha: pOpacity)
          ..style = PaintingStyle.fill
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
// EXPLOSION PAINTER — burst on login success
// ─────────────────────────────────────────────
class _ExplosionPainter extends CustomPainter {
  final double t; // 0→1
  final double logoRadius;

  _ExplosionPainter(this.t, this.logoRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const count = 22;
    final scale = logoRadius / 65;

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final speed = (55.0 + (i % 5) * 30.0) * scale;
      final dist = speed * t;
      final pOpacity =
          math.pow(1.0 - t, 1.4).toDouble().clamp(0.0, 1.0);
      final pSize =
          (2.5 + (i % 4) * 1.3) * (1 - t * 0.5);

      final x = center.dx + dist * math.cos(angle);
      final y = center.dy + dist * math.sin(angle);

      final color = i % 3 == 0
          ? C.purple
          : (i % 3 == 1 ? C.cyan : Colors.white);
      canvas.drawCircle(
        Offset(x, y),
        pSize.clamp(0.1, 10.0),
        Paint()
          ..color = color.withValues(alpha: pOpacity * 0.9)
          ..style = PaintingStyle.fill
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, pSize * 0.7),
      );
    }

    // Expanding neon ring
    final ringRadius = logoRadius * (0.9 + t * 1.6);
    final ringOpacity = (1 - t * 1.2).clamp(0.0, 1.0);
    if (ringOpacity > 0) {
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..color = C.cyan.withValues(alpha: ringOpacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - t)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, 8 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_ExplosionPainter old) => old.t != t;
}
