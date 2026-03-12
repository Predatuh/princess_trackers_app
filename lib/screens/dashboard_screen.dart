import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Dashboard tab — shown inside MainShell
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tracker = state.currentTracker;

    if (state.isLoading && state.blocks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2),
      );
    }
    if (tracker == null) {
      return Center(
        child: Text('No trackers available',
            style: AppTheme.font(color: C.textDim)),
      );
    }

    final blocks = state.blocks;
    final totalItems = blocks.fold<int>(0, (sum, b) => sum + b.lbdCount);
    final statusTypes = tracker.statusTypes;

    final Map<String, int> completedCounts = {};
    for (final st in statusTypes) {
      int count = 0;
      for (final b in blocks) {
        for (final lbd in b.lbds) {
          for (final s in lbd.statuses) {
            if (s.statusType == st && s.isCompleted) count++;
          }
        }
      }
      completedCounts[st] = count;
    }

    // Overall completion — exclude quality_check and quality_docs (admin types)
    const qualityKeys = {'quality_check', 'quality_docs'};
    final coreStatusTypes =
        statusTypes.where((st) => !qualityKeys.contains(st)).toList();
    int totalDone = 0;
    for (final st in coreStatusTypes) {
      totalDone += completedCounts[st] ?? 0;
    }
    final totalPossible = totalItems * coreStatusTypes.length;
    final overallPct = totalPossible > 0 ? totalDone / totalPossible : 0.0;

    // Count LBDs with 'term' status completed
    int termedCount = 0;
    for (final b in blocks) {
      for (final lbd in b.lbds) {
        for (final s in lbd.statuses) {
          if (s.statusType == 'term' && s.isCompleted) termedCount++;
        }
      }
    }

    return RefreshIndicator(
      color: C.cyan,
      backgroundColor: C.surface,
      onRefresh: () => state.loadBlocks(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          StaggeredItem(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: AppTheme.font(size: 14, color: C.textSub),
                ),
                const SizedBox(height: 2),
                Text(
                  state.user?.name ?? '',
                  style: AppTheme.font(
                      size: 26, weight: FontWeight.w700, color: C.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat cards row
          StaggeredItem(
            index: 1,
            child: Row(
              children: [
                StatCard(
                  label: 'Blocks',
                  value: blocks.length,
                  accent: C.cyan,
                  icon: Icons.widgets_rounded,
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: tracker.itemNamePlural,
                  value: totalItems,
                  accent: C.green,
                  icon: Icons.inventory_2_rounded,
                  subtitle:
                      termedCount > 0 ? '$termedCount termed' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Overall progress
          StaggeredItem(
            index: 2,
            child: GlassCard(
              child: Row(
                children: [
                  ProgressArc(
                    value: overallPct,
                    color: C.cyan,
                    size: 70,
                    strokeWidth: 5,
                    child: Text(
                      '${(overallPct * 100).toInt()}%',
                      style: AppTheme.displayFont(size: 14, color: C.cyan),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Progress',
                          style: AppTheme.font(
                            size: 16,
                            weight: FontWeight.w700,
                            color: C.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalDone of $totalPossible tasks complete',
                          style: AppTheme.font(size: 12, color: C.textSub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Status breakdown
          StaggeredItem(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Status Breakdown',
                  icon: Icons.bar_chart_rounded,
                ),
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      for (int i = 0; i < statusTypes.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        _statusRow(
                          name: state.getStatusName(statusTypes[i]),
                          done: completedCounts[statusTypes[i]] ?? 0,
                          total: totalItems,
                          color: state.getStatusColor(statusTypes[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required String name,
    required int done,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? done / total : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.5), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(name,
                    style: AppTheme.font(
                        size: 13, weight: FontWeight.w600, color: C.text)),
              ],
            ),
            Text(
              '$done / $total',
              style: AppTheme.font(size: 12, color: C.textSub),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (_, val, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: val,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Keep original class name for backward compatibility with old route
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to the new main shell
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/home');
    });
    return const Scaffold(backgroundColor: C.bg);
  }
}
