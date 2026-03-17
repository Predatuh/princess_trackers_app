import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_loading_surface.dart';

class VideoTransitionScreen extends StatefulWidget {
  const VideoTransitionScreen({super.key});

  @override
  State<VideoTransitionScreen> createState() => _VideoTransitionScreenState();
}

class _VideoTransitionScreenState extends State<VideoTransitionScreen>
    {
  static const _defaultHeroTag = 'login-logo-hero';

  bool _loginStarted = false;
  bool _loginDone = false;
  bool _animationDone = false;
  bool _loginFailed = false;
  bool _navigating = false;
  String? _error;
  String _heroTag = _defaultHeroTag;
  AuthLoaderPhase _phase = AuthLoaderPhase.charging;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loginStarted) return;
    _loginStarted = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _heroTag = (args?['heroTag'] as String?) ?? _defaultHeroTag;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runLogin(args);
    });
  }

  Future<void> _runLogin(Map<String, dynamic>? args) async {
    if (args == null) {
      setState(() {
        _loginFailed = true;
        _error = 'Missing credentials';
        _phase = AuthLoaderPhase.failed;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    final state = context.read<AppState>();
    final action = (args['authAction'] as String? ?? 'signIn').trim();
    final name = (args['name'] as String? ?? '').trim();
    final pin = (args['pin'] as String? ?? '').trim();
    final jobToken = (args['jobToken'] as String? ?? '').trim();

    late final AuthFlowResult result;
    switch (action) {
      case 'register':
        result = await state.register(name, pin, jobToken: jobToken);
        break;
      case 'signIn':
      default:
        result = await state.login(name, pin);
        break;
    }
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loginFailed = true;
        _error = result.error ?? state.error ?? 'Login failed';
        _phase = AuthLoaderPhase.failed;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    setState(() {
      _loginDone = true;
      _phase = AuthLoaderPhase.releasing;
    });
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted || _animationDone) return;
      _animationDone = true;
      _completeIfReady();
    });
    _completeIfReady();
  }

  void _handleLoaderComplete() {
    if (!mounted || _animationDone) return;
    _animationDone = true;
    _completeIfReady();
  }

  void _completeIfReady() {
    if (!mounted || _navigating || _loginFailed) return;
    if (!_loginDone || !_animationDone) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final logoSize = _targetLogoSize(viewport);
          final status = _statusText();

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF020305),
                      Color(0xFF06111D),
                      Color(0xFF081018),
                      Color(0xFF010102),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: _heroTag,
                        child: AuthLoadingSurface(
                          size: logoSize,
                          phase: _phase,
                          onSequenceComplete: _handleLoaderComplete,
                        ),
                      ),
                      SizedBox(height: math.min(viewport.height * 0.04, 28)),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: DecoratedBox(
                          decoration: AppTheme.glassDecoration(
                            radius: 24,
                            borderColor: (_loginFailed ? C.pink : C.cyan)
                                .withValues(alpha: 0.18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 18,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  status,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.displayFont(
                                    size: math.min(viewport.width * 0.04, 20),
                                    weight: FontWeight.w700,
                                    color: _loginFailed ? C.pink : C.text,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _statusSubtitle(),
                                  textAlign: TextAlign.center,
                                  style: AppTheme.font(
                                    size: 13,
                                    weight: FontWeight.w500,
                                    color: _loginFailed ? C.textSub : C.textSub,
                                    spacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Size _targetLogoSize(Size viewport) {
    final side = math.min(viewport.width * 0.84, viewport.height * 0.48);
    return Size.square(side.clamp(320.0, 940.0));
  }

  String _statusText() {
    if (_loginFailed) {
      return 'Access Denied';
    }
    if (_loginDone) {
      return 'Access Granted';
    }
    return 'Authenticating';
  }

  String _statusSubtitle() {
    if (_loginFailed) {
      return _error ?? 'Your credentials could not be verified.';
    }
    if (_loginDone) {
      return 'Finalizing your workspace and unlocking the app.';
    }
    return 'Securing your session and preparing the dashboard.';
  }
}
