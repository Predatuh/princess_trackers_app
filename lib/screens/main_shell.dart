import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'blocks_screen.dart';
import 'map_screen.dart';
import 'worklog_screen.dart';
import 'reports_screen.dart';
import 'admin_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  final _tabs = const [
    DashboardTab(),
    BlocksTab(),
    MapTab(),
    WorkLogTab(),
    ReportsTab(),
    AdminTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: C.bg,
      extendBody: true,
      appBar: _buildAppBar(state),
      body: Stack(
        children: [
          const _ElectricBackground(),
          IndexedStack(
            index: _tabIndex,
            children: _tabs,
          ),
        ],
      ),
      bottomNavigationBar: FuturisticNavBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        showAdmin: state.user?.role == 'admin' || state.user?.role == 'assistant_admin',
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppState state) {
    return AppBar(
      backgroundColor: C.bg.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [C.cyan, C.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppTheme.neonGlow(C.cyan, blur: 12, opacity: 0.35),
            ),
            child: const Text(
              '\u265B',
              style: TextStyle(
                fontSize: 20,
                color: C.gold,
                shadows: [
                  Shadow(color: Color(0xFFFFD700), blurRadius: 10),
                  Shadow(color: Color(0xFFFFAA00), blurRadius: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PRINCESS',
                style: AppTheme.displayFont(
                  size: 13,
                  weight: FontWeight.w700,
                  color: C.text,
                ),
              ),
              Text(
                'TRACKERS',
                style: AppTheme.displayFont(
                  size: 9,
                  weight: FontWeight.w400,
                  color: C.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded,
              color: C.cyan.withValues(alpha: 0.7), size: 22),
          onPressed: () => state.loadBlocks(),
        ),
        IconButton(
          icon: Icon(Icons.logout_rounded,
              color: C.textDim, size: 22),
          onPressed: () async {
            await state.logout();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

}

// ─────────────────────────────────────────────────────────
// ELECTRIC BACKGROUND — ambient lightning + spark particles
// ─────────────────────────────────────────────────────────

class _ElectricBackground extends StatefulWidget {
  const _ElectricBackground();

  @override
  State<_ElectricBackground> createState() => _ElectricBackgroundState();
}

class _ElectricBackgroundState extends State<_ElectricBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ElectricBgPainter(_ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ElectricBgPainter extends CustomPainter {
  final double t;
  _ElectricBgPainter(this.t);

  // Build a jagged lightning path between two points
  Path _bolt(Offset a, Offset b, int segs, double dev, int seed) {
    final p = Path()..moveTo(a.dx, a.dy);
    final rng = math.Random(seed);
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = -dy / len, ny = dx / len; // normal
    for (int i = 1; i < segs; i++) {
      final lp = i / segs;
      final jitter = (rng.nextDouble() - 0.5) * 2 * dev;
      p.lineTo(
        a.dx + dx * lp + nx * jitter,
        a.dy + dy * lp + ny * jitter,
      );
    }
    p.lineTo(b.dx, b.dy);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // ── Ambient lightning bolts ──
    // 4 bolts at different screen positions, staggered flash timing
    const boltDefs = [
      (0.05, 0.1, 0.35, 0.55, 0),
      (0.7, 0.05, 0.95, 0.4, 11),
      (0.15, 0.75, 0.55, 0.95, 22),
      (0.6, 0.6, 0.9, 0.85, 33),
    ];

    for (int bi = 0; bi < boltDefs.length; bi++) {
      final (ax, ay, bx, by, seed) = boltDefs[bi];
      final phase = (t + bi * 0.25) % 1.0;
      final flash = phase < 0.08
          ? math.sin(phase / 0.08 * math.pi)
          : 0.0;
      if (flash <= 0.01) continue;

      final rolledSeed = seed + (t * 0.4 + bi).toInt() * 7;
      final start = Offset(w * ax, h * ay);
      final end = Offset(w * bx, h * by);
      final boltPath = _bolt(start, end, 8, 18.0, rolledSeed);

      // Glow halo
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = C.cyan.withValues(alpha: flash * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Core bright line
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = Colors.white.withValues(alpha: flash * 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round,
      );

      // Branches: 2 sub-bolts forking off the main
      final rng = math.Random(rolledSeed + 1);
      for (int br = 0; br < 2; br++) {
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
            ..color = C.purple.withValues(alpha: flash * 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // ── Drifting spark particles ──
    const particleCount = 28;
    for (int i = 0; i < particleCount; i++) {
      final rng = math.Random(i * 137 + 5);
      final phase = (t * (0.25 + rng.nextDouble() * 0.15) + rng.nextDouble()) % 1.0;
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
  bool shouldRepaint(_ElectricBgPainter old) => old.t != t;
}
