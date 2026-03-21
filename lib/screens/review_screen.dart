import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../models/power_block.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ReviewTab extends StatefulWidget {
  const ReviewTab({super.key});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  List<ReviewEntry> _entries = [];
  List<ReviewReport> _reports = [];
  final Map<String, Map<String, dynamic>?> _reportDetails = {};
  bool _loading = true;
  int? _selectedBlockId;
  DateTime _selectedDate = DateTime.now();
  String? _selectedReportDate;

  String get _selectedDateIso =>
      '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _lbdLabel(LbdItem lbd) {
    if ((lbd.identifier ?? '').trim().isNotEmpty) return lbd.identifier!.trim();
    if ((lbd.name ?? '').trim().isNotEmpty) return lbd.name!.trim();
    return 'LBD ${lbd.id}';
  }

  List<LbdItem> _lbdsForBlock(PowerBlock block) {
    final lbds = [...block.lbds];
    lbds.sort((left, right) => _lbdLabel(left).compareTo(_lbdLabel(right)));
    return lbds;
  }

  ReviewEntry? _latestEntryForLbd(int lbdId) {
    for (final entry in _entries) {
      if (entry.lbdId == lbdId) return entry;
    }
    return null;
  }

  void _mergeReviewEntries(List<ReviewEntry> newEntries) {
    final replacedLbdIds = newEntries.map((entry) => entry.lbdId).toSet();
    final retainedEntries = _entries.where((entry) {
      return !(replacedLbdIds.contains(entry.lbdId) && entry.reviewDate == _selectedDateIso);
    }).toList();
    _entries = [...newEntries, ...retainedEntries];
  }

  ({int passCount, int failCount, int pendingCount, int total}) _blockSummary(PowerBlock block) {
    int passCount = 0;
    int failCount = 0;
    int pendingCount = 0;
    for (final lbd in _lbdsForBlock(block)) {
      final latest = _latestEntryForLbd(lbd.id);
      if (latest == null) {
        pendingCount += 1;
      } else if (latest.reviewResult == 'pass') {
        passCount += 1;
      } else {
        failCount += 1;
      }
    }
    return (passCount: passCount, failCount: failCount, pendingCount: pendingCount, total: block.lbds.length);
  }

  void _ensureSelection(List<PowerBlock> blocks) {
    if (blocks.isEmpty) {
      _selectedBlockId = null;
      return;
    }
    if (_selectedBlockId == null || !blocks.any((block) => block.id == _selectedBlockId)) {
      _selectedBlockId = blocks.first.id;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    if (state.blocks.isEmpty && state.currentTracker != null) {
      await state.loadBlocks();
    }
    final trackerId = state.currentTracker?.id;
    _entries = await state.api.getReviews(date: _selectedDateIso, trackerId: trackerId);
    _reports = await state.api.getReviewReports(trackerId: trackerId);
    _reports.sort((left, right) => right.reportDate.compareTo(left.reportDate));
    _ensureSelection(state.blocks);
    if (_selectedReportDate == null && _reports.isNotEmpty) {
      _selectedReportDate = _reports.first.reportDate;
    }
    if (_selectedReportDate != null) {
      await _loadReportDetail(_selectedReportDate!);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadReportDetail(String reportDate) async {
    if (_reportDetails.containsKey(reportDate)) return;
    final trackerId = context.read<AppState>().currentTracker?.id;
    _reportDetails[reportDate] = await context.read<AppState>().api.getReviewReportByDate(reportDate, trackerId: trackerId);
  }

  Future<void> _pickDate() async {
    final nextDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (nextDate == null) return;
    setState(() => _selectedDate = nextDate);
    await _load();
  }

  Future<void> _generateReviewReport() async {
    final state = context.read<AppState>();
    await state.api.generateReviewReport(
      date: _selectedDateIso,
      trackerId: state.currentTracker?.id,
    );
    _reportDetails.clear();
    _selectedReportDate = _selectedDateIso;
    await _load();
  }

  Future<void> _openBulkReviewDialog(PowerBlock block) async {
    final state = context.read<AppState>();
    final lbds = _lbdsForBlock(block);
    final selectedIds = <int>{};
    final currentResults = <int, String>{
      for (final lbd in lbds)
        lbd.id: _latestEntryForLbd(lbd.id)?.reviewResult ?? 'pending',
    };
    final notesController = TextEditingController();
    bool saving = false;
    String activeView = 'pending';

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(this.context);

              int countForView(String view) {
                if (view == 'selected') return selectedIds.length;
                if (view == 'all') return lbds.length;
                return lbds.where((lbd) => (currentResults[lbd.id] ?? 'pending') == view).length;
              }

              List<LbdItem> visibleLbds() {
                final sorted = [...lbds]
                  ..sort((left, right) {
                    final leftSelected = selectedIds.contains(left.id) ? 0 : 1;
                    final rightSelected = selectedIds.contains(right.id) ? 0 : 1;
                    if (leftSelected != rightSelected) return leftSelected - rightSelected;
                    return _lbdLabel(left).compareTo(_lbdLabel(right));
                  });

                return sorted.where((lbd) {
                  final status = currentResults[lbd.id] ?? 'pending';
                  switch (activeView) {
                    case 'selected':
                      return selectedIds.contains(lbd.id);
                    case 'pass':
                    case 'fail':
                    case 'pending':
                      return status == activeView;
                    default:
                      return true;
                  }
                }).toList();
              }

              Future<void> applyResult(String result) async {
                final targetIds = selectedIds.toList();
                if (targetIds.isEmpty) {
                  return;
                }

                setDialogState(() => saving = true);
                try {
                  final createdEntries = await state.api.submitBulkReviews(
                    reviews: [
                      for (final lbdId in targetIds)
                        {
                          'lbd_id': lbdId,
                          'review_result': result,
                        }
                    ],
                    reviewDate: _selectedDateIso,
                    notes: notesController.text.trim(),
                    trackerId: state.currentTracker?.id,
                  );
                  _reportDetails.clear();
                  if (mounted) {
                    setState(() => _mergeReviewEntries(createdEntries));
                  } else {
                    _mergeReviewEntries(createdEntries);
                  }
                  setDialogState(() {
                    for (final lbdId in targetIds) {
                      currentResults[lbdId] = result;
                      selectedIds.remove(lbdId);
                    }
                    if (activeView == 'selected' && selectedIds.isEmpty) {
                      activeView = 'pending';
                    }
                    saving = false;
                  });
                  notesController.clear();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${targetIds.length} LBDs marked ${result.toUpperCase()}.')),
                  );
                } catch (error) {
                  if (!mounted) return;
                  setDialogState(() => saving = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Review save failed: $error')),
                  );
                }
              }

              final filteredLbds = visibleLbds();
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                backgroundColor: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
                  decoration: AppTheme.glassDecoration(radius: 24).copyWith(
                    color: const Color(0xFF0B1322).withValues(alpha: 0.96),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Review Power Block',
                                    style: AppTheme.font(size: 11, weight: FontWeight.w800, color: C.cyan).copyWith(letterSpacing: 1.2),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(block.name, style: AppTheme.font(size: 20, weight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PB ${block.powerBlockNumber}${(block.zone ?? '').isNotEmpty ? ' · ${block.zone}' : ''} · ${lbds.length} LBDs',
                                    style: AppTheme.font(size: 12, color: C.textSub),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: saving ? null : () => navigator.pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: C.text,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => setDialogState(() {
                                        selectedIds
                                          ..clear()
                                          ..addAll(visibleLbds().map((lbd) => lbd.id));
                                      }),
                              child: const Text('Select All'),
                            ),
                            OutlinedButton(
                              onPressed: saving ? null : () => setDialogState(selectedIds.clear),
                              child: const Text('Clear'),
                            ),
                            FilledButton(
                              onPressed: saving || selectedIds.isEmpty ? null : () => applyResult('pass'),
                              style: FilledButton.styleFrom(backgroundColor: C.green),
                              child: Text(saving ? 'Applying...' : 'Pass Selected'),
                            ),
                            FilledButton(
                              onPressed: saving || selectedIds.isEmpty ? null : () => applyResult('fail'),
                              style: FilledButton.styleFrom(backgroundColor: C.pink, foregroundColor: Colors.white),
                              child: Text(saving ? 'Applying...' : 'Fail Selected'),
                            ),
                            Text(
                              '${selectedIds.length} selected · ${activeView.toUpperCase()} view',
                              style: AppTheme.font(size: 12, color: C.textSub),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in [
                              ('selected', 'Selected'),
                              ('pending', 'Pending'),
                              ('fail', 'Fail'),
                              ('pass', 'Pass'),
                              ('all', 'All'),
                            ])
                              ChoiceChip(
                                label: Text('${item.$2} (${countForView(item.$1)})'),
                                selected: activeView == item.$1,
                                onSelected: saving ? null : (_) => setDialogState(() => activeView = item.$1),
                                selectedColor: C.cyan.withValues(alpha: 0.18),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Optional notes for these review changes'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: lbds.isEmpty
                            ? Center(child: Text('No LBDs found for this power block.', style: AppTheme.font(size: 12, color: C.textSub)))
                            : filteredLbds.isEmpty
                                ? Center(
                                    child: Text('No LBDs in the ${activeView.toUpperCase()} view.', style: AppTheme.font(size: 12, color: C.textSub)),
                                  )
                                : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                itemCount: filteredLbds.length,
                                itemBuilder: (context, index) {
                                  final lbd = filteredLbds[index];
                                  final latest = _latestEntryForLbd(lbd.id);
                                  final current = currentResults[lbd.id] ?? 'pending';
                                  final tone = current == 'pass'
                                      ? C.green
                                      : current == 'fail'
                                        ? C.pink
                                          : C.cyan;
                                  final status = current == 'pass'
                                      ? 'PASS'
                                      : current == 'fail'
                                          ? 'FAIL'
                                          : 'PENDING';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: AppTheme.glassDecoration(radius: 16).copyWith(
                                      border: Border.all(color: tone.withValues(alpha: 0.24)),
                                      color: Colors.white.withValues(alpha: 0.03),
                                    ),
                                    child: CheckboxListTile(
                                      value: selectedIds.contains(lbd.id),
                                      activeColor: C.cyan,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      onChanged: saving
                                          ? null
                                          : (checked) => setDialogState(() {
                                                if (checked == true) {
                                                  selectedIds.add(lbd.id);
                                                } else {
                                                  selectedIds.remove(lbd.id);
                                                }
                                              }),
                                      title: Text(_lbdLabel(lbd), style: AppTheme.font(size: 14, weight: FontWeight.w700)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if ((lbd.inventoryNumber ?? '').isNotEmpty)
                                            Text(lbd.inventoryNumber!, style: AppTheme.font(size: 11, color: C.textSub)),
                                          Text(
                                            latest == null ? 'Not reviewed on $_selectedDateIso' : '${latest.reviewResult.toUpperCase()} by ${latest.reviewedBy}',
                                            style: AppTheme.font(size: 11, color: C.textSub),
                                          ),
                                        ],
                                      ),
                                      secondary: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          color: tone.withValues(alpha: 0.14),
                                          border: Border.all(color: tone.withValues(alpha: 0.22)),
                                        ),
                                        child: Text(status, style: AppTheme.font(size: 11, weight: FontWeight.w800, color: tone)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving ? null : () => navigator.pop(),
                                child: const Text('Done'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final blocks = state.blocks;
    _ensureSelection(blocks);
    final latestEntries = <int, ReviewEntry>{
      for (final entry in _entries)
        if (entry.lbdId > 0) entry.lbdId: entry,
    };
    final failingCount = latestEntries.values.where((entry) => entry.reviewResult == 'fail').length;
    final selectedReport = _selectedReportDate == null ? null : _reportDetails[_selectedReportDate!];
    final selectedReportData = selectedReport == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(selectedReport['data'] as Map<String, dynamic>? ?? const {});
    final failedReportItems = (selectedReportData['failed_lbds'] as List? ??
            selectedReportData['failed_blocks'] as List? ??
            const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2));
    }

    return RefreshIndicator(
      color: C.cyan,
      backgroundColor: C.surface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            glowColor: C.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quality Review', style: AppTheme.font(size: 18, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Open a power block in a popup, select multiple LBDs, bulk apply pass or fail, then save the full draft together.',
                  style: AppTheme.font(size: 12, color: C.textSub),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _SummaryPill(label: 'Blocks', value: '${blocks.length}', color: C.cyan)),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryPill(label: 'LBDs', value: '${blocks.fold<int>(0, (sum, block) => sum + block.lbds.length)}', color: C.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryPill(label: 'Need Fixes', value: '$failingCount', color: C.pink)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(_selectedDateIso),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeonButton(
                        label: 'REPORT',
                        icon: Icons.assessment_rounded,
                        onPressed: _generateReviewReport,
                        height: 46,
                        gradientColors: const [Color(0xFFFFD36A), Color(0xFFFF9A4A)],
                        foregroundColor: const Color(0xFF231100),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Review Power Blocks', style: AppTheme.font(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (blocks.isEmpty)
            GlassCard(
              child: Text('No power blocks loaded for this tracker.', style: AppTheme.font(size: 13, color: C.textSub)),
            )
          else
            ...blocks.map((block) {
              final summary = _blockSummary(block);
              final isSelected = block.id == _selectedBlockId;
              final tone = summary.failCount > 0
                  ? C.pink
                  : summary.total > 0 && summary.passCount == summary.total
                      ? C.green
                      : C.cyan;
              final subtitle = summary.failCount > 0
                  ? '${summary.failCount} failed · ${summary.passCount} passed'
                  : summary.total > 0 && summary.passCount == summary.total
                      ? '${summary.passCount} passed'
                      : '${summary.pendingCount} pending';
              return GestureDetector(
                onTap: () async {
                  setState(() => _selectedBlockId = block.id);
                  await _openBulkReviewDialog(block);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassDecoration(radius: 16).copyWith(
                    border: Border.all(color: isSelected ? tone.withValues(alpha: 0.45) : const Color(0x22FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: tone.withValues(alpha: 0.14),
                          border: Border.all(color: tone.withValues(alpha: 0.28)),
                        ),
                        alignment: Alignment.center,
                        child: Text('${block.powerBlockNumber}', style: AppTheme.displayFont(size: 14, color: tone)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(block.name, style: AppTheme.font(size: 15, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              '${block.lbds.length} LBDs${(block.zone ?? '').isNotEmpty ? ' · ${block.zone}' : ''}',
                              style: AppTheme.font(size: 12, color: C.textSub),
                            ),
                            const SizedBox(height: 3),
                            Text(subtitle, style: AppTheme.font(size: 12, color: C.textSub)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.open_in_new_rounded, color: tone),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          Text('Recent Review Activity', style: AppTheme.font(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_entries.isEmpty)
            GlassCard(
              child: Text('No review entries for $_selectedDateIso.', style: AppTheme.font(size: 13, color: C.textSub)),
            )
          else
            ..._entries.take(12).map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    glowColor: entry.reviewResult == 'pass' ? C.green : C.pink,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.reviewTargetLabel.isNotEmpty ? entry.reviewTargetLabel : entry.powerBlockName,
                          style: AppTheme.font(size: 14, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(entry.powerBlockName, style: AppTheme.font(size: 12, color: C.textSub)),
                        const SizedBox(height: 4),
                        Text('${entry.reviewResult.toUpperCase()} · ${entry.reviewedBy}',
                            style: AppTheme.font(size: 12, color: C.textSub)),
                        if (entry.notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(entry.notes, style: AppTheme.font(size: 12, color: C.text)),
                        ],
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 18),
          Text('Review Reports', style: AppTheme.font(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_reports.isEmpty)
            GlassCard(
              child: Text('No review reports generated yet.', style: AppTheme.font(size: 13, color: C.textSub)),
            )
          else ...[
            ..._reports.map((report) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () async {
                      setState(() => _selectedReportDate = report.reportDate);
                      await _loadReportDetail(report.reportDate);
                      if (!mounted) return;
                      setState(() {});
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      glowColor: report.reportDate == _selectedReportDate ? C.cyan : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(report.reportDate, style: AppTheme.font(size: 14, weight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                  '${report.totalReviews} reviews · ${report.failCount} LBDs need fixes',
                                  style: AppTheme.font(size: 12, color: C.textSub),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: C.textDim),
                        ],
                      ),
                    ),
                  ),
                )),
            if (selectedReportData.isNotEmpty) ...[
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                glowColor: C.pink,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LBDs That Need Fixes', style: AppTheme.font(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (failedReportItems.isEmpty)
                      Text('No failed LBDs in this report.', style: AppTheme.font(size: 12, color: C.textSub))
                    else
                      ...failedReportItems.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: C.pink.withValues(alpha: 0.10),
                                border: Border.all(color: C.pink.withValues(alpha: 0.22)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry['review_target_label']?.toString() ?? entry['lbd_identifier']?.toString() ?? entry['lbd_name']?.toString() ?? 'LBD',
                                    style: AppTheme.font(size: 13, weight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry['power_block_name']?.toString() ?? 'Power Block',
                                    style: AppTheme.font(size: 11, color: C.textSub),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${entry['reviewed_by'] ?? 'Unknown'} · ${entry['review_result'] ?? 'fail'}',
                                    style: AppTheme.font(size: 11, color: C.textSub),
                                  ),
                                  if ((entry['notes']?.toString() ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(entry['notes'].toString(), style: AppTheme.font(size: 12, color: C.text)),
                                  ],
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.font(size: 11, color: C.textSub)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.displayFont(size: 18, color: color)),
        ],
      ),
    );
  }
}