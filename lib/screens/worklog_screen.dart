import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/power_block.dart';
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

class _ClaimBlockCard extends StatelessWidget {
  final PowerBlock block;

  const _ClaimBlockCard({required this.block});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final tracker = state.currentTracker;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/block', arguments: block),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecoration(radius: 16),
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
                    color: (block.isClaimed ? C.purple : C.cyan).withValues(alpha: 0.14),
                    border: Border.all(
                      color: (block.isClaimed ? C.purple : C.cyan).withValues(alpha: 0.28),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${block.powerBlockNumber}',
                    style: AppTheme.displayFont(
                      size: 14,
                      color: block.isClaimed ? C.purple : C.cyan,
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
                    color: (block.isClaimed ? C.purple : C.green).withValues(alpha: 0.14),
                    border: Border.all(
                      color: (block.isClaimed ? C.purple : C.green).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    block.isClaimed ? 'Edit Claim' : 'Claim',
                    style: AppTheme.font(
                      size: 11,
                      weight: FontWeight.w700,
                      color: block.isClaimed ? C.purple : C.green,
                    ),
                  ),
                ),
              ],
            ),
            if (block.isClaimed) ...[
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
