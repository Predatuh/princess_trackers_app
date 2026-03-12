import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/power_block.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Blocks tab — shown inside MainShell
class BlocksTab extends StatelessWidget {
  const BlocksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final blocks = state.blocks;

    if (state.isLoading && blocks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2),
      );
    }

    return RefreshIndicator(
      color: C.cyan,
      backgroundColor: C.surface,
      onRefresh: () => state.loadBlocks(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: blocks.length,
        itemBuilder: (ctx, i) => StaggeredItem(
          index: i,
          baseDelay: const Duration(milliseconds: 40),
          child: _BlockCard(block: blocks[i]),
        ),
      ),
    );
  }
}

// Keep old name for backward compat
class BlocksScreen extends StatelessWidget {
  const BlocksScreen({super.key});
  @override
  Widget build(BuildContext context) => const BlocksTab();
}

class _BlockCard extends StatelessWidget {
  final PowerBlock block;
  const _BlockCard({required this.block});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final tracker = state.currentTracker;

    int done = 0, total = 0;
    for (final lbd in block.lbds) {
      for (final s in lbd.statuses) {
        total++;
        if (s.isCompleted) done++;
      }
    }
    final pct = total > 0 ? done / total : 0.0;

    Color accentColor = C.cyan;
    if (tracker != null && block.lbdSummary.isNotEmpty) {
      for (final st in tracker.statusTypes) {
        final completed = block.lbdSummary[st] ?? 0;
        if (completed < block.lbdCount) {
          accentColor = state.getStatusColor(st);
          break;
        }
      }
    }
    if (pct >= 1.0) accentColor = C.green;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/block', arguments: block),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Block number with progress ring
                ProgressArc(
                  value: pct,
                  color: accentColor,
                  size: 46,
                  strokeWidth: 3,
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
                      Text(
                        block.name,
                        style: AppTheme.font(
                          size: 15,
                          weight: FontWeight.w700,
                          color: C.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${block.lbdCount} ${tracker?.itemNamePlural ?? "items"} · ${(pct * 100).toInt()}%',
                        style: AppTheme.font(size: 12, color: C.textSub),
                      ),
                    ],
                  ),
                ),
                if (block.claimedBy != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: C.purple.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      block.claimedBy!,
                      style: AppTheme.font(
                        size: 11,
                        weight: FontWeight.w600,
                        color: C.purple,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: C.textDim, size: 20),
              ],
            ),
            const SizedBox(height: 12),

            // Status chips
            if (tracker != null)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tracker.statusTypes.map((st) {
                  final count = block.lbdSummary[st] ?? 0;
                  final color = state.getStatusColor(st);
                  final name = state.getStatusName(st);
                  final complete = count >= block.lbdCount && block.lbdCount > 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: complete ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withValues(alpha: complete ? 0.5 : 0.15),
                      ),
                    ),
                    child: Text(
                      '$name: $count/${block.lbdCount}',
                      style: AppTheme.font(
                        size: 10,
                        weight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
