import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/power_block.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Dashboard tab — tracker hub showing ALL trackers
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final state = context.read<AppState>();
      if (state.allTrackerBlocks.isEmpty && state.trackers.isNotEmpty) {
        state.loadAllTrackerData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.isLoading && state.blocks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2),
      );
    }
    if (state.trackers.isEmpty) {
      return Center(
        child: Text('No trackers available',
            style: AppTheme.font(color: C.textDim)),
      );
    }

    return RefreshIndicator(
      color: C.cyan,
      backgroundColor: C.surface,
      onRefresh: () => state.loadAllTrackerData(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Welcome
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: AppTheme.font(size: 14, color: C.textSub)),
                const SizedBox(height: 2),
                Text(state.user?.name ?? '',
                    style: AppTheme.font(
                        size: 26, weight: FontWeight.w700, color: C.text)),
              ],
            ),
          const SizedBox(height: 20),

          const SizedBox(height: 8),

          // Tracker hub section header
          const SectionHeader(
              title: 'Tracker Hub',
              icon: Icons.hub_rounded,
            ),
          const SizedBox(height: 4),

          // Tracker cards
          for (int i = 0; i < state.trackers.length; i++) ...[
            _TrackerHubCard(
                tracker: state.trackers[i],
                blocks: state.allTrackerBlocks[state.trackers[i].id] ??
                    (state.trackers[i].id == state.currentTracker?.id
                        ? state.blocks
                        : []),
                settings: state.allTrackerSettings[state.trackers[i].id] ?? {},
                onTap: () async {
                  await state.openTracker(state.trackers[i]);
                },
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TRACKER HUB CARD — shows one tracker's summary
// ═══════════════════════════════════════════════════════════

class _TrackerHubCard extends StatelessWidget {
  final dynamic tracker;
  final List<PowerBlock> blocks;
  final Map<String, dynamic> settings;
  final VoidCallback onTap;

  const _TrackerHubCard({
    required this.tracker,
    required this.blocks,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalBlocks = blocks.length;
    final totalItems =
        blocks.fold<int>(0, (sum, b) => sum + b.lbdCount);

    // Calculate per-status completion
    final statusTypes = tracker.statusTypes as List<String>;
    final statusColors =
        Map<String, String>.from(settings['colors'] ?? tracker.statusColors);
    final statusNames =
        Map<String, String>.from(settings['names'] ?? tracker.statusNames);

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
    // Termed count — from lbdSummary 'term' key (matches web dashboard logic)
    final termedCount = blocks.fold<int>(
        0, (sum, b) => sum + (b.lbdSummary['term'] ?? 0));
    final statLabel = (tracker.statLabel as String?) ?? 'Termed';
    final pct = totalItems > 0 ? termedCount / totalItems : 0.0;
    final barColor = pct >= 1.0
        ? C.green
        : pct >= 0.5
            ? C.cyan
            : C.purple;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x14FFFFFF)),
          boxShadow: [
            BoxShadow(
              color: barColor.withValues(alpha: 0.06),
              blurRadius: 20,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — icon + name + percentage
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: barColor.withValues(alpha: 0.25)),
                  ),
                  child: Center(
                    child: Text(
                      tracker.icon ?? '📋',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tracker.name,
                    style: AppTheme.font(
                      size: 16,
                      weight: FontWeight.w700,
                      color: C.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: barColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${(pct * 100).toInt()}%',
                    style: AppTheme.displayFont(
                      size: 13,
                      weight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Stat pills row
            Row(
              children: [
                _StatPill(
                    value: '$totalBlocks',
                  label: tracker.dashboardBlocksLabel,
                    color: C.cyan),
                const SizedBox(width: 8),
                _StatPill(
                    value: '$termedCount',
                  label: statLabel,
                    color: C.green),
                const SizedBox(width: 8),
                _StatPill(
                    value: '${(pct * 100).toInt()}%',
                  label: tracker.dashboardProgressLabel,
                    color: C.purple),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: val.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [barColor, barColor.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.4),
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
            const SizedBox(height: 14),

            // Status breakdown rows
            for (int i = 0; i < statusTypes.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _StatusMiniRow(
                name: statusNames[statusTypes[i]] ?? statusTypes[i],
                done: completedCounts[statusTypes[i]] ?? 0,
                total: totalItems,
                color: _colorFromHex(
                    statusColors[statusTypes[i]] ?? '#888888'),
              ),
            ],
            const SizedBox(height: 12),

            // Open button
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Text(tracker.dashboardOpenLabel,
                      style: AppTheme.font(
                          size: 12,
                          weight: FontWeight.w600,
                          color: barColor)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      color: barColor, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFromHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

// ═══════════════════════════════════════════════════════════
// STAT PILL
// ═══════════════════════════════════════════════════════════

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTheme.displayFont(
                    size: 14, weight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTheme.font(
                    size: 10, color: C.textDim)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STATUS MINI ROW — compact progress row
// ═══════════════════════════════════════════════════════════

class _StatusMiniRow extends StatelessWidget {
  final String name;
  final int done;
  final int total;
  final Color color;

  const _StatusMiniRow({
    required this.name,
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(name,
              style: AppTheme.font(
                  size: 11, weight: FontWeight.w600, color: C.text)),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$done/$total',
            style: AppTheme.font(size: 10, color: C.textSub)),
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
