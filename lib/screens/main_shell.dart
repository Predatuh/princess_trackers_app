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
      body: IndexedStack(
        index: _tabIndex,
        children: _tabs,
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
      title: state.trackers.length <= 1
          ? Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [C.cyan, C.purple],
                    ),
                    boxShadow: AppTheme.neonGlow(C.cyan, blur: 10, opacity: 0.2),
                  ),
                  child: const Icon(Icons.track_changes_rounded,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  state.currentTracker?.name ?? 'Princess Trackers',
                  style: AppTheme.font(
                    size: 18,
                    weight: FontWeight.w700,
                    color: C.text,
                  ),
                ),
              ],
            )
          : _trackerDropdown(state),
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

  Widget _trackerDropdown(AppState state) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: state.currentTracker?.id,
        dropdownColor: C.surface,
        style: AppTheme.font(size: 18, weight: FontWeight.w700),
        icon: Icon(Icons.arrow_drop_down_rounded,
            color: C.cyan.withValues(alpha: 0.7)),
        items: state.trackers.map((t) {
          return DropdownMenuItem(value: t.id, child: Text(t.name));
        }).toList(),
        onChanged: (id) {
          if (id == null) return;
          final t = state.trackers.firstWhere((t) => t.id == id);
          state.switchTracker(t);
        },
      ),
    );
  }
}
