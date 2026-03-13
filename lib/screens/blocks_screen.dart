import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/power_block.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

enum _StatusFilter { all, inProgress, complete }
enum _ClaimFilter { all, claimed, unclaimed }
enum _SortMode { blockNumber, name, progressAsc, progressDesc }

/// Blocks tab — shown inside MainShell
class BlocksTab extends StatefulWidget {
  const BlocksTab({super.key});

  @override
  State<BlocksTab> createState() => _BlocksTabState();
}

class _BlocksTabState extends State<BlocksTab> {
  final _searchController = TextEditingController();
  _StatusFilter _statusFilter = _StatusFilter.all;
  _ClaimFilter _claimFilter = _ClaimFilter.all;
  _SortMode _sortMode = _SortMode.blockNumber;
  bool _showFilters = false;
  String? _zoneFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _blockProgress(PowerBlock block) {
    int done = 0, total = 0;
    for (final lbd in block.lbds) {
      for (final s in lbd.statuses) {
        total++;
        if (s.isCompleted) done++;
      }
    }
    return total > 0 ? done / total : 0.0;
  }

  List<PowerBlock> _applyFilters(List<PowerBlock> blocks) {
    var filtered = List<PowerBlock>.from(blocks);

    // Search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((b) =>
          b.name.toLowerCase().contains(query) ||
          b.powerBlockNumber.toString().contains(query)).toList();
    }

    // Status filter
    if (_statusFilter == _StatusFilter.complete) {
      filtered = filtered.where((b) => _blockProgress(b) >= 1.0).toList();
    } else if (_statusFilter == _StatusFilter.inProgress) {
      filtered = filtered.where((b) {
        final p = _blockProgress(b);
        return p > 0.0 && p < 1.0;
      }).toList();
    }

    // Claim filter
    if (_claimFilter == _ClaimFilter.claimed) {
      filtered = filtered.where((b) => b.claimedBy != null).toList();
    } else if (_claimFilter == _ClaimFilter.unclaimed) {
      filtered = filtered.where((b) => b.claimedBy == null).toList();
    }

    // Zone filter
    if (_zoneFilter != null) {
      filtered = filtered.where((b) => b.zone == _zoneFilter).toList();
    }

    // Sort
    switch (_sortMode) {
      case _SortMode.blockNumber:
        filtered.sort((a, b) => a.powerBlockNumber.compareTo(b.powerBlockNumber));
        break;
      case _SortMode.name:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortMode.progressAsc:
        filtered.sort((a, b) => _blockProgress(a).compareTo(_blockProgress(b)));
        break;
      case _SortMode.progressDesc:
        filtered.sort((a, b) => _blockProgress(b).compareTo(_blockProgress(a)));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allBlocks = state.blocks;

    if (state.isLoading && allBlocks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2),
      );
    }

    final filtered = _applyFilters(allBlocks);

    return RefreshIndicator(
      color: C.cyan,
      backgroundColor: C.surface,
      onRefresh: () => state.loadBlocks(),
      child: Column(
        children: [
          // ── Search + filter toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x14FFFFFF)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: AppTheme.font(size: 14, color: C.text),
                      decoration: InputDecoration(
                        hintText: 'Search blocks...',
                        hintStyle: AppTheme.font(size: 13, color: C.textDim),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.textDim, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () => setState(() => _searchController.clear()),
                                child: const Icon(Icons.close_rounded, color: C.textDim, size: 16),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: _showFilters ? C.cyan.withValues(alpha: 0.15) : const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showFilters ? C.cyan.withValues(alpha: 0.4) : const Color(0x14FFFFFF),
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _showFilters ? C.cyan : C.textDim,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Filter panel ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _showFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status filter row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _statusFilter == _StatusFilter.all,
                          color: C.cyan,
                          onTap: () => setState(() => _statusFilter = _StatusFilter.all),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'In Progress',
                          selected: _statusFilter == _StatusFilter.inProgress,
                          color: C.purple,
                          onTap: () => setState(() => _statusFilter = _StatusFilter.inProgress),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'Complete',
                          selected: _statusFilter == _StatusFilter.complete,
                          color: C.green,
                          onTap: () => setState(() => _statusFilter = _StatusFilter.complete),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 20, color: const Color(0x14FFFFFF)),
                        const SizedBox(width: 12),
                        _FilterChip(
                          label: 'Claimed',
                          selected: _claimFilter == _ClaimFilter.claimed,
                          color: C.purple,
                          onTap: () => setState(() => _claimFilter =
                              _claimFilter == _ClaimFilter.claimed ? _ClaimFilter.all : _ClaimFilter.claimed),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'Unclaimed',
                          selected: _claimFilter == _ClaimFilter.unclaimed,
                          color: C.pink,
                          onTap: () => setState(() => _claimFilter =
                              _claimFilter == _ClaimFilter.unclaimed ? _ClaimFilter.all : _ClaimFilter.unclaimed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zone filter row
                  Builder(builder: (context) {
                    final zones = allBlocks
                        .map((b) => b.zone)
                        .where((z) => z != null && z.isNotEmpty)
                        .toSet()
                        .toList()..sort();
                    if (zones.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Icon(Icons.place_rounded, color: C.textDim, size: 14),
                              const SizedBox(width: 6),
                              Text('Zone:', style: AppTheme.font(size: 11, color: C.textDim)),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'All',
                                selected: _zoneFilter == null,
                                color: C.gold,
                                onTap: () => setState(() => _zoneFilter = null),
                              ),
                              ...zones.map((z) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _FilterChip(
                                  label: z!,
                                  selected: _zoneFilter == z,
                                  color: C.gold,
                                  onTap: () => setState(() =>
                                      _zoneFilter = _zoneFilter == z ? null : z),
                                ),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                  // Sort row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(Icons.sort_rounded, color: C.textDim, size: 14),
                        const SizedBox(width: 6),
                        Text('Sort:', style: AppTheme.font(size: 11, color: C.textDim)),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: '#',
                          selected: _sortMode == _SortMode.blockNumber,
                          onTap: () => setState(() => _sortMode = _SortMode.blockNumber),
                        ),
                        const SizedBox(width: 6),
                        _SortChip(
                          label: 'Name',
                          selected: _sortMode == _SortMode.name,
                          onTap: () => setState(() => _sortMode = _SortMode.name),
                        ),
                        const SizedBox(width: 6),
                        _SortChip(
                          label: 'Progress ↑',
                          selected: _sortMode == _SortMode.progressAsc,
                          onTap: () => setState(() => _sortMode = _SortMode.progressAsc),
                        ),
                        const SizedBox(width: 6),
                        _SortChip(
                          label: 'Progress ↓',
                          selected: _sortMode == _SortMode.progressDesc,
                          onTap: () => setState(() => _sortMode = _SortMode.progressDesc),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),

          // ── Results count ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} block${filtered.length == 1 ? '' : 's'}',
                  style: AppTheme.font(size: 11, color: C.textDim),
                ),
                if (filtered.length != allBlocks.length) ...[
                  Text(
                    '  of ${allBlocks.length}',
                    style: AppTheme.font(size: 11, color: C.textDim),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _searchController.clear();
                      _statusFilter = _StatusFilter.all;
                      _claimFilter = _ClaimFilter.all;
                      _sortMode = _SortMode.blockNumber;
                      _zoneFilter = null;
                    }),
                    child: Text(
                      'Clear filters',
                      style: AppTheme.font(size: 11, color: C.cyan),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Block list ──
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list_off_rounded, color: C.textDim, size: 40),
                        const SizedBox(height: 12),
                        Text('No blocks match filters',
                            style: AppTheme.font(size: 14, color: C.textSub)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => StaggeredItem(
                      index: i,
                      baseDelay: const Duration(milliseconds: 40),
                      child: _BlockCard(block: filtered[i]),
                    ),
                  ),
          ),
        ],
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

// ═══════════════════════════════════════════════════════════
// FILTER CHIP
// ═══════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : const Color(0x14FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: AppTheme.font(
            size: 12,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : C.textSub,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SORT CHIP
// ═══════════════════════════════════════════════════════════

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? C.cyan.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? C.cyan.withValues(alpha: 0.3) : const Color(0x0EFFFFFF),
          ),
        ),
        child: Text(
          label,
          style: AppTheme.font(
            size: 11,
            weight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? C.cyan : C.textDim,
          ),
        ),
      ),
    );
  }
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
