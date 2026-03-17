import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_logo_asset.dart';
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

class _MainShellState extends State<MainShell>
    {
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
      body: Column(
        children: [
          if (state.isOffline || state.pendingQueueCount > 0)
            _OfflineBanner(
              isOffline: state.isOffline,
              pendingQueueCount: state.pendingQueueCount,
            ),
          Expanded(
            child: IndexedStack(
              index: state.selectedTab,
              children: _tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: FuturisticNavBar(
        currentIndex: state.selectedTab,
        onTap: state.setSelectedTab,
        showAdmin: state.user?.canAccessAdmin ?? false,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppState state) {
    return AppBar(
      toolbarHeight: 124,
      backgroundColor: C.bg.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 4,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 290;
          final crownSize = compact ? 118.0 : 136.0;
          final titleGap = compact ? 2.0 : 6.0;

          return Row(
            children: [
              SizedBox(
                width: crownSize,
                height: crownSize,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: AnimatedCrownAsset(),
                ),
              ),
              SizedBox(width: titleGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PRINCESS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.displayFont(
                        size: compact ? 16 : 18,
                        weight: FontWeight.w700,
                        color: C.text,
                      ),
                    ),
                    Text(
                      'TRACKERS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.displayFont(
                        size: compact ? 11 : 12,
                        weight: FontWeight.w600,
                        color: C.cyan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded,
              color: C.cyan.withValues(alpha: 0.7), size: 22),
          onPressed: () => state.loadBlocks(),
        ),
        IconButton(
          icon: Icon(Icons.logout_rounded, color: C.textDim, size: 22),
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

class _OfflineBanner extends StatelessWidget {
  final bool isOffline;
  final int pendingQueueCount;

  const _OfflineBanner({
    required this.isOffline,
    required this.pendingQueueCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOffline ? C.gold : C.cyan;
    final icon = isOffline ? Icons.cloud_off_rounded : Icons.sync_rounded;
    final text = isOffline
        ? 'Offline mode. $pendingQueueCount change${pendingQueueCount == 1 ? '' : 's'} waiting to sync.'
        : 'Back online. Sync queue: $pendingQueueCount change${pendingQueueCount == 1 ? '' : 's'}.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.font(size: 12, weight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

