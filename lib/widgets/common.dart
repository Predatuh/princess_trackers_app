import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════
// GLASS CARD — Frosted glass container
// ═══════════════════════════════════════════════════════════

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? glowColor;
  final double? glowBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.glowColor,
    this.glowBlur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          ...(glowColor != null
              ? AppTheme.neonGlowStrong(glowColor!)
              : AppTheme.neonGlow(C.cyan, blur: 18, opacity: 0.10)),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0x12FFFFFF),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: C.cyan.withValues(alpha: 0.12)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// NEON BUTTON — Gradient button with glow
// ═══════════════════════════════════════════════════════════

class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final List<Color> gradientColors;
  final double height;
  final IconData? icon;
  final Color foregroundColor;

  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.gradientColors = const [C.cyan, Color(0xFF0090cc)],
    this.height = 56,
    this.icon,
    this.foregroundColor = Colors.white,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;
  late AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmer = Tween(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shimmer, _tapController]),
      builder: (context, child) {
        final tapProgress = Curves.easeOutCubic.transform(_tapController.value);
        final pressScale = 1.0 - (math.sin(tapProgress * math.pi) * 0.025);
        return Container(
          height: widget.height,
          transform: Matrix4.identity()..scale(pressScale, pressScale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withValues(alpha: 0.4 + (0.15 * tapProgress)),
                blurRadius: 20 + (16 * tapProgress),
                spreadRadius: -4 + (2 * tapProgress),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.loading
                  ? null
                  : () {
                      _tapController.forward(from: 0);
                      widget.onPressed?.call();
                    },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _NeonButtonSparkPainter(
                          progress: tapProgress,
                          color: widget.gradientColors.first,
                        ),
                      ),
                    ),
                  ),
                  // Shimmer overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment(_shimmer.value - 1, 0),
                          end: Alignment(_shimmer.value, 0),
                          colors: const [
                            Colors.transparent,
                            Color(0x33FFFFFF),
                            Colors.transparent,
                          ],
                        ).createShader(rect),
                        blendMode: BlendMode.srcATop,
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ),
                  Center(
                    child: widget.loading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.foregroundColor,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, color: widget.foregroundColor, size: 20),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                widget.label,
                                style: AppTheme.font(
                                  size: 16,
                                  weight: FontWeight.w700,
                                  color: widget.foregroundColor,
                                  spacing: 1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NeonButtonSparkPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _NeonButtonSparkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final glowCenter = Offset(size.width * 0.72, size.height * 0.5);
    final burstRadius = size.height * (0.18 + progress * 0.7);
    final fade = (1 - progress).clamp(0.0, 1.0);

    canvas.drawCircle(
      glowCenter,
      burstRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.32 * fade),
            color.withValues(alpha: 0.18 * fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: burstRadius)),
    );

    for (var index = 0; index < 9; index++) {
      final angle = (-0.9 + (index * 0.22)) * math.pi;
      final distance = size.height * (0.16 + progress * (0.36 + (index % 3) * 0.06));
      final start = Offset(
        glowCenter.dx + math.cos(angle) * size.height * 0.12,
        glowCenter.dy + math.sin(angle) * size.height * 0.12,
      );
      final end = Offset(
        glowCenter.dx + math.cos(angle) * distance,
        glowCenter.dy + math.sin(angle) * distance,
      );
      final sparkColor = index.isEven ? Colors.white : color;
      final paint = Paint()
        ..color = sparkColor.withValues(alpha: 0.9 * fade)
        ..strokeWidth = index.isEven ? 1.8 : 1.2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonButtonSparkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ═══════════════════════════════════════════════════════════
// GLOWING TEXT FIELD
// ═══════════════════════════════════════════════════════════

class GlowTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const GlowTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<GlowTextField> createState() => _GlowTextFieldState();
}

class _GlowTextFieldState extends State<GlowTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _focused ? AppTheme.neonGlow(C.cyan, blur: 15, opacity: 0.15) : [],
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        style: AppTheme.font(size: 15, color: C.text),
        onTap: () => setState(() => _focused = true),
        onEditingComplete: () => setState(() => _focused = false),
        decoration: InputDecoration(
          hintText: widget.label,
          hintStyle: AppTheme.font(size: 14, color: C.textDim.withValues(alpha: 0.72)),
          counterText: '',
          prefixIcon: Icon(widget.icon, color: _focused ? C.cyan : C.textDim, size: 20),
          filled: true,
          fillColor: C.surfaceLight.withValues(alpha: 0.86),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x22FFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x22FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: C.cyan.withValues(alpha: 0.85), width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FUTURISTIC BOTTOM NAV BAR
// ═══════════════════════════════════════════════════════════

class FuturisticNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showAdmin;

  const FuturisticNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showAdmin = false,
  });

  static const _baseItems = [
    _NavItem(Icons.dashboard_rounded, 'Home', 0),
    _NavItem(Icons.map_rounded, 'Map', 2),
    _NavItem(Icons.assignment_turned_in_rounded, 'Claim', 3),
    _NavItem(Icons.insights_rounded, 'Reports', 4),
  ];
  static const _adminItem = _NavItem(Icons.settings_rounded, 'Admin', 5);

  @override
  Widget build(BuildContext context) {
    final items = showAdmin ? [..._baseItems, _adminItem] : _baseItems;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0e1f).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x18FFFFFF)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x40000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: C.cyan.withValues(alpha: 0.06),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (i) {
              final active = items[i].tabIndex == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(items[i].tabIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: active ? C.cyan.withValues(alpha: 0.12) : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            items[i].icon,
                            size: active ? 24 : 22,
                            color: active ? C.cyan : C.textDim,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].label,
                          style: AppTheme.font(
                            size: 10,
                            weight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? C.cyan : C.textDim,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: active ? 16 : 0,
                          height: 2.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: C.cyan,
                            boxShadow: active
                                ? [BoxShadow(color: C.cyan.withValues(alpha: 0.6), blurRadius: 8)]
                                : [],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int tabIndex;
  const _NavItem(this.icon, this.label, this.tabIndex);
}

// ═══════════════════════════════════════════════════════════
// STAGGERED LIST ANIMATION
// ═══════════════════════════════════════════════════════════

class StaggeredItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;

  const StaggeredItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 60),
  });

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.baseDelay * widget.index, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ANIMATED PROGRESS ARC
// ═══════════════════════════════════════════════════════════

class ProgressArc extends StatelessWidget {
  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const ProgressArc({
    super.key,
    required this.value,
    this.color = C.cyan,
    this.size = 60,
    this.strokeWidth = 4,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Track
          CustomPaint(
            painter: _ArcPainter(
              value: 1.0,
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: strokeWidth,
            ),
          ),
          // Progress
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) => CustomPaint(
              painter: _ArcPainter(
                value: val,
                color: color,
                strokeWidth: strokeWidth,
                glow: true,
              ),
            ),
          ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double value;
  final Color color;
  final double strokeWidth;
  final bool glow;

  _ArcPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
    this.glow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    if (glow && value > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..color = color.withValues(alpha: 0.2)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, glowPaint);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value || old.color != color;
}

// ═══════════════════════════════════════════════════════════
// ANIMATED BACKGROUND MESH
// ═══════════════════════════════════════════════════════════

class AnimatedMeshBackground extends StatefulWidget {
  final Widget child;
  const AnimatedMeshBackground({super.key, required this.child});

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient
        Container(decoration: AppTheme.backgroundGradient),
        // Animated orbs
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _OrbPainter(_ctrl.value),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _Orb(0.15, 0.25, 120, C.cyan, 0.06),
      _Orb(0.85, 0.65, 160, C.purple, 0.05),
      _Orb(0.5, 0.85, 100, C.green, 0.04),
    ];

    for (final orb in orbs) {
      final dx = math.sin(t * 2 * math.pi + orb.x * 10) * 30;
      final dy = math.cos(t * 2 * math.pi + orb.y * 10) * 20;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [orb.color.withValues(alpha: orb.alpha), Colors.transparent],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * orb.x + dx, size.height * orb.y + dy),
            radius: orb.radius,
          ),
        );
      canvas.drawCircle(
        Offset(size.width * orb.x + dx, size.height * orb.y + dy),
        orb.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}

class _Orb {
  final double x, y, radius;
  final Color color;
  final double alpha;
  const _Orb(this.x, this.y, this.radius, this.color, this.alpha);
}

// ═══════════════════════════════════════════════════════════
// STAT CARD with animated counter
// ═══════════════════════════════════════════════════════════

class StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color accent;
  final IconData icon;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: value),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => Text(
                '$val',
                style: AppTheme.displayFont(size: 28, color: accent),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTheme.font(size: 12, color: C.textSub)),
            if (subtitle != null) ...[              const SizedBox(height: 2),
              Text(subtitle!,
                  style: AppTheme.font(size: 11, color: C.textDim)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color color;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.color = C.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: AppTheme.font(
              size: 13,
              weight: FontWeight.w700,
              color: color,
              spacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
