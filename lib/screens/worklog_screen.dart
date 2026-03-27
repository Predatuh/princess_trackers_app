import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/power_block.dart';
import '../models/tracker.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Claim tab — shown inside MainShell
class WorkLogTab extends StatefulWidget {
  const WorkLogTab({super.key});

  @override
  State<WorkLogTab> createState() => _WorkLogTabState();
}

class _WorkLogTabState extends State<WorkLogTab> {
  final _searchController = TextEditingController();
  bool _showClaimed = true;
  bool _showUnclaimed = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PowerBlock> _applyFilters(List<PowerBlock> blocks) {
    var filtered = List<PowerBlock>.from(blocks);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((block) {
        return block.name.toLowerCase().contains(query) ||
            block.powerBlockNumber.toString().contains(query) ||
            (block.claimedLabel ?? '').toLowerCase().contains(query);
      }).toList();
    }

    if (!_showClaimed) {
      filtered = filtered.where((block) => !block.isClaimed).toList();
    }
    if (!_showUnclaimed) {
      filtered = filtered.where((block) => block.isClaimed).toList();
    }

    filtered.sort((left, right) => left.powerBlockNumber.compareTo(right.powerBlockNumber));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.claimTrackerSelectionRequired || state.currentTracker == null) {
      final trackers = state.trackers.where((tracker) => tracker.isActive).toList()
        ..sort((left, right) => left.displayName.compareTo(right.displayName));
      return _ClaimTrackerPicker(trackers: trackers);
    }
    final blocks = _applyFilters(state.blocks);

    if (state.isLoading && state.blocks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2),
      );
    }

    return RefreshIndicator(
      color: C.cyan,
      backgroundColor: C.surface,
      onRefresh: () => state.loadBlocks(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: C.cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_turned_in_rounded, color: C.cyan, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Claim Blocks', style: AppTheme.font(size: 15, weight: FontWeight.w700)),
                            Text(
                              'Open a block here to choose the task and exact LBDs you claimed.',
                              style: AppTheme.font(size: 12, color: C.textSub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: AppTheme.font(size: 14, color: C.text),
                    decoration: InputDecoration(
                      hintText: 'Search blocks or claimed people',
                      prefixIcon: const Icon(Icons.search_rounded, color: C.textDim, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () => setState(() => _searchController.clear()),
                              child: const Icon(Icons.close_rounded, color: C.textDim, size: 16),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Claimed'),
                        selected: _showClaimed,
                        selectedColor: C.purple.withValues(alpha: 0.16),
                        backgroundColor: C.surfaceLight.withValues(alpha: 0.7),
                        side: BorderSide(color: _showClaimed ? C.purple.withValues(alpha: 0.4) : const Color(0x22FFFFFF)),
                        labelStyle: AppTheme.font(size: 12, color: _showClaimed ? C.purple : C.textSub),
                        onSelected: (value) => setState(() => _showClaimed = value),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Unclaimed'),
                        selected: _showUnclaimed,
                        selectedColor: C.green.withValues(alpha: 0.16),
                        backgroundColor: C.surfaceLight.withValues(alpha: 0.7),
                        side: BorderSide(color: _showUnclaimed ? C.green.withValues(alpha: 0.4) : const Color(0x22FFFFFF)),
                        labelStyle: AppTheme.font(size: 12, color: _showUnclaimed ? C.green : C.textSub),
                        onSelected: (value) => setState(() => _showUnclaimed = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  '${blocks.length} block${blocks.length == 1 ? '' : 's'} ready to claim',
                  style: AppTheme.font(size: 11, color: C.textDim),
                ),
              ],
            ),
          ),
          Expanded(
            child: blocks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_late_rounded, color: C.textDim, size: 44),
                        const SizedBox(height: 12),
                        Text('No blocks match this claim view', style: AppTheme.font(size: 14, color: C.textSub)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: blocks.length,
                    itemBuilder: (context, index) {
                      final block = blocks[index];
                      return _ClaimBlockCard(block: block);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClaimTrackerPicker extends StatelessWidget {
  final List<Tracker> trackers;

  const _ClaimTrackerPicker({required this.trackers});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 18,
          glowColor: C.cyan,
          glowBlur: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose Claim Tracker', style: AppTheme.font(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Pick the tracker you want to claim in before opening any power block. Claiming no longer follows the last tracker you opened from the dashboard.',
                style: AppTheme.font(size: 12, color: C.textSub),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...trackers.map((tracker) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => state.selectTrackerForClaim(tracker),
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 18,
                  glowColor: C.green,
                  glowBlur: 14,
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.green.withValues(alpha: 0.28)),
                        ),
                        child: Text(tracker.icon, style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tracker.displayName, style: AppTheme.font(size: 15, weight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              '${tracker.itemNamePlural} · ${tracker.statusTypes.map((statusType) => tracker.statusNames[statusType] ?? statusType).join(' • ')}',
                              style: AppTheme.font(size: 12, color: C.textSub),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: C.textDim),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _ClaimBlockCard extends StatelessWidget {
  final PowerBlock block;

  const _ClaimBlockCard({required this.block});

  List<String> _trackedStatuses(Tracker? tracker) {
    final statuses = tracker?.statusTypes ?? const <String>[];
    return statuses.isNotEmpty ? statuses : const <String>['term'];
  }

  int _completedTaskParts(PowerBlock block, Tracker? tracker) {
    final statuses = _trackedStatuses(tracker);
    if (block.lbds.isEmpty) {
      return statuses.fold<int>(0, (sum, statusType) => sum + (block.lbdSummary[statusType] ?? 0));
    }
    int completed = 0;
    for (final lbd in block.lbds) {
      for (final statusType in statuses) {
        final isCompleted = lbd.statuses.any(
          (status) => status.statusType == statusType && status.isCompleted,
        );
        if (isCompleted) {
          completed++;
        }
      }
    }
    return completed;
  }

  int _totalTaskParts(PowerBlock block, Tracker? tracker) {
    final statuses = _trackedStatuses(tracker);
    return block.lbdCount * statuses.length;
  }

  String _formatPercent(double progress) {
    final percent = progress * 100;
    if ((percent - percent.round()).abs() < 0.005) {
      return '${percent.round()}%';
    }
    return '${percent.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final tracker = state.currentTracker;
    final isClaimed = block.isClaimed;
    final isFullyClaimed = block.isFullyClaimed;
    final completedTaskParts = _completedTaskParts(block, tracker);
    final totalTaskParts = _totalTaskParts(block, tracker);
    final completionProgress = totalTaskParts > 0
        ? (completedTaskParts / totalTaskParts).clamp(0.0, 1.0)
        : 0.0;
    final visualProgress = block.claimProgress > completionProgress ? block.claimProgress : completionProgress;
    final isVisuallyComplete = isFullyClaimed || completionProgress >= 1.0;
    final isVisuallyInProgress = !isVisuallyComplete && visualProgress > 0;
    final accentColor = isVisuallyComplete
        ? C.green
        : (isVisuallyInProgress ? C.gold : C.cyan);
    final cardDecoration = BoxDecoration(
      color: isVisuallyComplete
          ? C.green.withValues(alpha: 0.14)
          : (isVisuallyInProgress ? C.gold.withValues(alpha: 0.08) : const Color(0x12FFFFFF)),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isVisuallyComplete
            ? C.green.withValues(alpha: 0.38)
            : (isVisuallyInProgress ? C.gold.withValues(alpha: 0.28) : C.cyan.withValues(alpha: 0.12)),
      ),
      boxShadow: [
        ...(isVisuallyComplete
            ? AppTheme.neonGlowStrong(C.green)
            : (isVisuallyInProgress
                ? AppTheme.neonGlow(C.gold, blur: 22, opacity: 0.16)
                : AppTheme.neonGlow(C.cyan, blur: 18, opacity: 0.10))),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -12,
        ),
      ],
    );

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/block', arguments: block),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accentColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.28),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${block.powerBlockNumber}',
                    style: AppTheme.displayFont(
                      size: 14,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(block.name, style: AppTheme.font(size: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        '${block.lbdCount} ${tracker?.itemNamePlural ?? 'items'}',
                        style: AppTheme.font(size: 12, color: C.textSub),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: (isVisuallyComplete ? C.green : (isVisuallyInProgress ? C.gold : C.green))
                        .withValues(alpha: isVisuallyComplete ? 0.18 : 0.12),
                    border: Border.all(
                      color: (isVisuallyComplete ? C.green : (isVisuallyInProgress ? C.gold : C.green))
                          .withValues(alpha: isVisuallyComplete ? 0.32 : 0.22),
                    ),
                  ),
                  child: Text(
                    isFullyClaimed
                        ? '100% Claimed'
                      : (isVisuallyComplete
                        ? '100% Complete'
                        : (isClaimed
                          ? 'Claim In Progress'
                          : (isVisuallyInProgress ? 'In Progress' : 'Add Claim'))),
                    style: AppTheme.font(
                      size: 11,
                      weight: FontWeight.w700,
                      color: isVisuallyComplete ? C.green : (isVisuallyInProgress ? C.gold : C.green),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: visualProgress,
                minHeight: 6,
                backgroundColor: C.surfaceLight.withValues(alpha: 0.8),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFullyClaimed
                  ? 'All ${block.lbdCount} ${tracker?.itemNamePlural ?? 'items'} claimed on this block'
                  : (isVisuallyComplete
                      ? '${completedTaskParts}/${totalTaskParts} parts complete • ${_formatPercent(completionProgress)}'
                      : (isClaimed
                      ? '${block.claimedLbdCount}/${block.lbdCount} ${tracker?.itemNamePlural ?? 'items'} claimed'
                      : '${completedTaskParts}/${totalTaskParts} parts complete • ${_formatPercent(completionProgress)}')),
              style: AppTheme.font(
                size: 12,
                color: isVisuallyComplete
                    ? C.green
                    : ((isClaimed || isVisuallyInProgress) ? C.gold : C.textSub),
              ),
            ),
            if (isClaimed) ...[
              const SizedBox(height: 10),
              Text(
                'Crew: ${block.claimedLabel}',
                style: AppTheme.font(size: 12, color: C.textSub),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WorkLogScreen extends StatelessWidget {
  const WorkLogScreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkLogTab();
}
