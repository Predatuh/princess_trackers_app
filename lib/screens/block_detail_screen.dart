import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/power_block.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class BlockDetailScreen extends StatefulWidget {
  const BlockDetailScreen({super.key});

  @override
  State<BlockDetailScreen> createState() => _BlockDetailScreenState();
}

class _BlockDetailScreenState extends State<BlockDetailScreen> {
  late PowerBlock block;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      block = ModalRoute.of(context)!.settings.arguments as PowerBlock;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tracker = state.currentTracker;

    final fresh = state.blocks.where((b) => b.id == block.id).firstOrNull;
    if (fresh != null) block = fresh;

    int done = 0, total = 0;
    for (final lbd in block.lbds) {
      for (final s in lbd.statuses) {
        total++;
        if (s.isCompleted) done++;
      }
    }
    final pct = total > 0 ? done / total : 0.0;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: C.cyan),
        title: Text(block.name,
            style: AppTheme.font(size: 18, weight: FontWeight.w700)),
        actions: [
          if (state.user != null)
            block.claimedBy == null
                ? IconButton(
                    icon: const Icon(Icons.flag_outlined, color: C.purple),
                    tooltip: 'Claim',
                    onPressed: () => state.claimBlock(block.id),
                  )
                : IconButton(
                    icon: const Icon(Icons.flag, color: C.purple),
                    tooltip: 'Unclaim',
                    onPressed: () => state.unclaimBlock(block.id),
                  ),
        ],
      ),
      body: block.lbds.isEmpty
          ? Center(
              child: Text(
                'No ${tracker?.itemNamePlural ?? "items"} in this block',
                style: AppTheme.font(color: C.textDim),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: block.lbds.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return StaggeredItem(
                    index: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHeader(pct, done, total),
                    ),
                  );
                }
                return StaggeredItem(
                  index: i,
                  baseDelay: const Duration(milliseconds: 40),
                  child: _LbdTile(lbd: block.lbds[i - 1]),
                );
              },
            ),
    );
  }

  Widget _buildHeader(double pct, int done, int total) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ProgressArc(
            value: pct,
            color: pct >= 1.0 ? C.green : C.cyan,
            size: 64,
            strokeWidth: 4.5,
            child: Text(
              '${(pct * 100).toInt()}%',
              style: AppTheme.displayFont(
                size: 14,
                color: pct >= 1.0 ? C.green : C.cyan,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.name,
                    style: AppTheme.font(size: 16, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$done of $total tasks complete',
                    style: AppTheme.font(size: 12, color: C.textSub)),
                if (block.claimedBy != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: C.purple.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Claimed: ${block.claimedBy}',
                      style: AppTheme.font(
                          size: 11,
                          weight: FontWeight.w600,
                          color: C.purple),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LbdTile extends StatelessWidget {
  final LbdItem lbd;
  const _LbdTile({required this.lbd});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final tracker = state.currentTracker;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(lbd.name ?? '',
                    style: AppTheme.font(size: 14, weight: FontWeight.w600)),
              ),
              if (lbd.identifier != null && lbd.identifier!.isNotEmpty)
                Text(lbd.identifier!,
                    style: AppTheme.font(size: 11, color: C.textDim)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (tracker?.statusTypes ?? []).map((st) {
              final status = lbd.statuses
                  .where((s) => s.statusType == st)
                  .firstOrNull;
              final completed = status?.isCompleted ?? false;
              final color = state.getStatusColor(st);
              final name = state.getStatusName(st);

              return GestureDetector(
                onTap: () => state.toggleStatus(lbd.id, st, !completed),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: completed
                        ? color.withValues(alpha: 0.2)
                        : const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: completed
                          ? color.withValues(alpha: 0.5)
                          : const Color(0x14FFFFFF),
                    ),
                    boxShadow: completed
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.15),
                                blurRadius: 8,
                                spreadRadius: -2)
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: completed ? color : C.textDim,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: AppTheme.font(
                          size: 12,
                          weight: completed
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: completed ? color : C.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
