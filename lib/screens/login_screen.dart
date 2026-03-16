import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

enum _AuthMode { signIn, register, verify }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _jobTokenCtrl = TextEditingController();
  final _verificationCodeCtrl = TextEditingController();
  bool _rememberLogin = false;
  bool _didApplyRouteArgs = false;
  bool _submitting = false;
  _AuthMode _mode = _AuthMode.signIn;
  String? _error;
  String? _info;
  static const _logoHeroTag = 'login-logo-hero';

  late AnimationController _lightningCtrl;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
    _lightningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyRouteArgs) return;
    _didApplyRouteArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;
    final mode = (args['authMode'] as String? ?? '').trim();
    setState(() {
      if ((args['name'] as String?)?.isNotEmpty ?? false) {
        _nameCtrl.text = args['name'] as String;
      }
      if ((args['pin'] as String?)?.isNotEmpty ?? false) {
        _pinCtrl.text = args['pin'] as String;
      }
      if ((args['email'] as String?)?.isNotEmpty ?? false) {
        _emailCtrl.text = args['email'] as String;
      }
      _info = (args['message'] as String?)?.trim();
      _error = null;
      _submitting = false;
      if (mode == 'verify') {
        _mode = _AuthMode.verify;
      } else if (mode == 'register') {
        _mode = _AuthMode.register;
      }
    });
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberLogin = prefs.getBool('rememberLogin') ?? false;
    if (!mounted) return;
    setState(() {
      _rememberLogin = rememberLogin;
      if (rememberLogin) {
        _nameCtrl.text = prefs.getString('savedLoginName') ?? '';
        _pinCtrl.text = prefs.getString('savedLoginPin') ?? '';
      } else {
        _nameCtrl.text = prefs.getString('lastUser') ?? '';
      }
    });
  }

  Future<void> _persistSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberLogin', _rememberLogin);
    if (_rememberLogin) {
      await prefs.setString('savedLoginName', _nameCtrl.text.trim());
      await prefs.setString('savedLoginPin', _pinCtrl.text.trim());
      return;
    }
    await prefs.remove('savedLoginName');
    await prefs.remove('savedLoginPin');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _emailCtrl.dispose();
    _jobTokenCtrl.dispose();
    _verificationCodeCtrl.dispose();
    _lightningCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final jobToken = _jobTokenCtrl.text.trim();
    final code = _verificationCodeCtrl.text.trim();

    switch (_mode) {
      case _AuthMode.signIn:
        if (name.isEmpty || pin.isEmpty) {
          setState(() => _error = 'Enter name and PIN');
          return;
        }
        break;
      case _AuthMode.register:
        if (name.isEmpty || pin.isEmpty || email.isEmpty || jobToken.isEmpty) {
          setState(() => _error = 'Name, PIN, recovery email, and site token are required');
          return;
        }
        if (pin.length != 4 || int.tryParse(pin) == null) {
          setState(() => _error = 'PIN must be exactly 4 digits');
          return;
        }
        if (!email.contains('@')) {
          setState(() => _error = 'Enter a valid recovery email');
          return;
        }
        break;
      case _AuthMode.verify:
        if (email.isEmpty || code.isEmpty) {
          setState(() => _error = 'Enter your email and verification code');
          return;
        }
        break;
    }

    setState(() {
      _submitting = true;
      _error = null;
      if (_mode != _AuthMode.verify) {
        _info = null;
      }
    });

    if (_mode != _AuthMode.verify) {
      await _persistSavedLogin();
    }
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/video', arguments: {
      'authAction': switch (_mode) {
        _AuthMode.signIn => 'signIn',
        _AuthMode.register => 'register',
        _AuthMode.verify => 'verify',
      },
      'name': name,
      'pin': pin,
      'email': email,
      'jobToken': jobToken,
      'code': code,
      'heroTag': _logoHeroTag,
    });
  }

  Future<void> _resendVerification() async {
    if (_submitting) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your recovery email first');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await context.read<AppState>().resendVerification(email);
    if (!mounted) return;

    setState(() {
      _submitting = false;
      if (result.verificationRequired) {
        final previewCode = (result.previewCode ?? '').trim();
        _info = [
          result.message ?? 'A new verification code has been sent.',
          if (previewCode.isNotEmpty) 'Preview code: $previewCode',
        ].join(' ');
      } else {
        _error = result.error ?? 'Could not resend verification code';
      }
    });
  }

  void _switchMode(_AuthMode nextMode) {
    setState(() {
      _mode = nextMode;
      _error = null;
      if (nextMode != _AuthMode.verify) {
        _info = null;
        _verificationCodeCtrl.clear();
      }
    });
  }

  String get _title {
    switch (_mode) {
      case _AuthMode.register:
        return 'Create Account';
      case _AuthMode.verify:
        return 'Verify Email';
      case _AuthMode.signIn:
        return 'Sign In';
    }
  }

  String get _subtitle {
    switch (_mode) {
      case _AuthMode.register:
        return 'Use your recovery email and site token to create your account';
      case _AuthMode.verify:
        return 'Enter the code that was sent to your recovery email';
      case _AuthMode.signIn:
        return 'Access your tracking dashboard';
    }
  }

  String get _buttonLabel {
    switch (_mode) {
      case _AuthMode.register:
        return 'CREATE ACCOUNT';
      case _AuthMode.verify:
        return 'VERIFY EMAIL';
      case _AuthMode.signIn:
        return 'SIGN IN';
    }
  }

  IconData get _buttonIcon {
    switch (_mode) {
      case _AuthMode.register:
        return Icons.person_add_rounded;
      case _AuthMode.verify:
        return Icons.verified_user_rounded;
      case _AuthMode.signIn:
        return Icons.arrow_forward_rounded;
    }
  }

  List<Color> get _buttonGradient {
    switch (_mode) {
      case _AuthMode.register:
        return const [Color(0xFF00E5FF), Color(0xFF7C4DFF)];
      case _AuthMode.verify:
        return const [Color(0xFF63E6BE), Color(0xFF00BFA5)];
      case _AuthMode.signIn:
        return const [Color(0xFFFFD95A), Color(0xFFFF8A00)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: AppTheme.backgroundGradient),
          // Lightning background
          AnimatedBuilder(
            animation: _lightningCtrl,
            builder: (_, __) => CustomPaint(
              painter: _LoginLightningPainter(_lightningCtrl.value),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Hero(
                      tag: _logoHeroTag,
                      child: Container(
                        width: 296,
                        height: 296,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 296,
                          height: 296,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Column(
                        children: [
                          Text(
                            'PRINCESS',
                            style: AppTheme.displayFont(
                              size: 40,
                              weight: FontWeight.w900,
                              color: C.text,
                            ).copyWith(
                              letterSpacing: 2.4,
                              shadows: [
                                Shadow(
                                  color: C.cyan.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                ),
                                Shadow(
                                  color: C.gold.withValues(alpha: 0.20),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'TRACKERS',
                            style: AppTheme.displayFont(
                              size: 20,
                              weight: FontWeight.w700,
                              color: C.cyan,
                            ).copyWith(
                              letterSpacing: 8,
                              shadows: [
                                Shadow(
                                  color: C.cyan.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    IgnorePointer(
                      ignoring: _submitting,
                      child: GlassCard(
                        padding: const EdgeInsets.all(28),
                        glowColor: C.cyan,
                        glowBlur: 22,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: AppTheme.font(size: 20, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitle,
                              style: AppTheme.font(size: 13, color: C.textDim),
                            ),
                            const SizedBox(height: 28),
                            if (_mode != _AuthMode.verify) ...[
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
                                textInputAction: _mode == _AuthMode.signIn
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                onSubmitted: _mode == _AuthMode.signIn ? (_) => _submit() : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_mode == _AuthMode.register) ...[
                              GlowTextField(
                                controller: _emailCtrl,
                                label: 'Recovery Email',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              GlowTextField(
                                controller: _jobTokenCtrl,
                                label: 'Site Token',
                                icon: Icons.key_rounded,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (_mode == _AuthMode.verify) ...[
                              GlowTextField(
                                controller: _emailCtrl,
                                label: 'Recovery Email',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              GlowTextField(
                                controller: _verificationCodeCtrl,
                                label: 'Verification Code',
                                icon: Icons.mark_email_read_rounded,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _submitting ? null : _resendVerification,
                                  child: Text(
                                    'Resend code',
                                    style: AppTheme.font(size: 13, color: C.cyan, weight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                            if (_mode != _AuthMode.verify) _buildRememberLogin(),
                            if (_info != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoBanner(),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _buildErrorBanner(),
                            ],
                            const SizedBox(height: 24),
                            NeonButton(
                              label: _buttonLabel,
                              icon: _buttonIcon,
                              gradientColors: _buttonGradient,
                              foregroundColor: C.bg,
                              loading: _submitting,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: _submitting,
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              if (_mode == _AuthMode.signIn) {
                                _switchMode(_AuthMode.register);
                              } else {
                                _switchMode(_AuthMode.signIn);
                              }
                            },
                            child: Text.rich(
                              TextSpan(
                                text: _mode == _AuthMode.signIn
                                    ? "Don't have an account? "
                                    : 'Already have an account? ',
                                style: AppTheme.font(size: 13, color: C.textDim),
                                children: [
                                  TextSpan(
                                    text: _mode == _AuthMode.signIn ? 'Create one' : 'Sign In',
                                    style: AppTheme.font(
                                      size: 13,
                                      color: C.cyan,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('v1.0.0',
                              style: AppTheme.font(size: 11, color: C.textDim)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberLogin() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _rememberLogin = !_rememberLogin),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _rememberLogin
                ? C.cyan.withValues(alpha: 0.4)
                : const Color(0x14FFFFFF),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: _rememberLogin
                    ? C.cyan.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: _rememberLogin ? C.cyan : const Color(0x30FFFFFF),
                  width: 1.4,
                ),
              ),
              child: _rememberLogin
                  ? const Icon(Icons.check_rounded, size: 15, color: C.cyan)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Save login',
                      style: AppTheme.font(size: 13, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Keep this name and PIN filled in next time.',
                      style: AppTheme.font(size: 11, color: C.textDim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.cyan.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: C.cyan, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_info!, style: AppTheme.font(size: 13, color: C.text)),
        ),
      ]),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.pink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.pink.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: C.pink, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_error!, style: AppTheme.font(size: 13, color: C.pink)),
        ),
      ]),
    );
  }
}

// ─── Lightning background for login page ───
class _LoginLightningPainter extends CustomPainter {
  final double t;
  _LoginLightningPainter(this.t);

  Path _bolt(Offset a, Offset b, int segs, double dev, int seed) {
    final p = Path()..moveTo(a.dx, a.dy);
    final rng = math.Random(seed);
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return p;
    final nx = -dy / len, ny = dx / len;
    for (int i = 1; i < segs; i++) {
      final lp = i / segs;
      final jitter = (rng.nextDouble() - 0.5) * 2 * dev;
      p.lineTo(a.dx + dx * lp + nx * jitter, a.dy + dy * lp + ny * jitter);
    }
    p.lineTo(b.dx, b.dy);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // dense ambient lightning bolts
    const bolts = [
      (0.05, 0.08, 0.40, 0.50, 0),
      (0.65, 0.04, 0.95, 0.38, 11),
      (0.10, 0.70, 0.50, 0.95, 22),
      (0.55, 0.60, 0.92, 0.88, 33),
      (0.00, 0.18, 0.30, 0.26, 44),
      (0.72, 0.18, 0.98, 0.22, 55),
      (0.08, 0.44, 0.35, 0.58, 66),
      (0.62, 0.46, 0.96, 0.68, 77),
      (0.04, 0.90, 0.26, 0.78, 88),
    ];

    for (int bi = 0; bi < bolts.length; bi++) {
      final (ax, ay, bx, by, seed) = bolts[bi];
      final phase = (t + bi * 0.25) % 1.0;
        final flash =
          phase < 0.12 ? math.sin(phase / 0.12 * math.pi) : 0.0;
      if (flash <= 0.01) continue;

      final rolledSeed = seed + (t * 0.4 + bi).toInt() * 7;
      final start = Offset(w * ax, h * ay);
      final end = Offset(w * bx, h * by);
      final boltPath = _bolt(start, end, 8, 18.0, rolledSeed);

      canvas.drawPath(
        boltPath,
        Paint()
            ..color = C.cyan.withValues(alpha: flash * 0.16)
          ..style = PaintingStyle.stroke
            ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawPath(
        boltPath,
        Paint()
            ..color = Colors.white.withValues(alpha: flash * 0.35)
          ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );

      // Branch bolts
      final rng = math.Random(rolledSeed + 1);
      for (int br = 0; br < 3; br++) {
        final branchT = 0.3 + rng.nextDouble() * 0.4;
        final bstart = Offset(
          start.dx + (end.dx - start.dx) * branchT,
          start.dy + (end.dy - start.dy) * branchT,
        );
        final bAngle = math.atan2(end.dy - start.dy, end.dx - start.dx) +
            (rng.nextDouble() - 0.5) * 1.0;
        final bLen = 30.0 + rng.nextDouble() * 60;
        final bend = Offset(
          bstart.dx + math.cos(bAngle) * bLen,
          bstart.dy + math.sin(bAngle) * bLen,
        );
        canvas.drawPath(
          _bolt(bstart, bend, 5, 10, rolledSeed + br + 50),
          Paint()
            ..color = C.purple.withValues(alpha: flash * 0.14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // Drifting spark particles
    const particleCount = 34;
    for (int i = 0; i < particleCount; i++) {
      final rng = math.Random(i * 137 + 5);
      final phase =
          (t * (0.25 + rng.nextDouble() * 0.15) + rng.nextDouble()) % 1.0;
      final baseX = rng.nextDouble() * w;
      final x = baseX + math.sin(phase * math.pi * 3 + i) * 15;
      final y = h - phase * h * 1.2;
      if (y < -20 || y > h + 20) continue;

      final twinkle = math.sin(t * math.pi * 12 + i * 2.9);
      final alpha = ((twinkle + 1) / 2) * 0.12;
      if (alpha < 0.01) continue;

      final sz = 0.6 + rng.nextDouble() * 1.2;
      final colors = [C.cyan, C.purple, C.gold, Colors.white];
      final sc = colors[i % colors.length];

      canvas.drawCircle(
        Offset(x, y),
        sz * 2.5,
        Paint()
          ..color = sc.withValues(alpha: alpha * 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 3),
      );
      canvas.drawCircle(
        Offset(x, y),
        sz,
        Paint()..color = sc.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_LoginLightningPainter old) => true;
}
