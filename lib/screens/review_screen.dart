import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../models/power_block.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class _ReviewTarget {
  final int lbdId;
  final int powerBlockId;
  final String powerBlockName;
  final int powerBlockNumber;
  final String label;
  final String zone;
  final String inventoryNumber;

  const _ReviewTarget({
    required this.lbdId,
    required this.powerBlockId,
    required this.powerBlockName,
    required this.powerBlockNumber,
    required this.label,
    this.zone = '',
    this.inventoryNumber = '',
  });
}

class ReviewTab extends StatefulWidget {
  const ReviewTab({super.key});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  final TextEditingController _notesController = TextEditingController();

  List<ReviewEntry> _entries = [];
  List<ReviewReport> _reports = [];
  final Map<String, Map<String, dynamic>?> _reportDetails = {};
  bool _loading = true;
  bool _saving = false;
  int? _selectedLbdId;
  String _selectedResult = 'fail';
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
    _notesController.dispose();
    super.dispose();
  }

  String _lbdLabel(LbdItem lbd) {
    if ((lbd.identifier ?? '').trim().isNotEmpty) return lbd.identifier!.trim();
    if ((lbd.name ?? '').trim().isNotEmpty) return lbd.name!.trim();
    return 'LBD ${lbd.id}';
  }

  List<_ReviewTarget> _buildTargets(List<PowerBlock> blocks) {
    final targets = <_ReviewTarget>[];
    for (final block in blocks) {
      final lbds = [...block.lbds]
        ..sort((left, right) => _lbdLabel(left).compareTo(_lbdLabel(right)));
      for (final lbd in lbds) {
        targets.add(
          _ReviewTarget(
            lbdId: lbd.id,
            powerBlockId: block.id,
            powerBlockName: block.name,
            powerBlockNumber: block.powerBlockNumber,
            label: _lbdLabel(lbd),
            zone: block.zone ?? '',
            inventoryNumber: lbd.inventoryNumber ?? '',
          ),
        );
      }
    }
    targets.sort((left, right) {
      final blockDiff = left.powerBlockNumber.compareTo(right.powerBlockNumber);
      if (blockDiff != 0) return blockDiff;
      return left.label.compareTo(right.label);
    });
    return targets;
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
    final targets = _buildTargets(state.blocks);
    if (_selectedLbdId == null || !targets.any((target) => target.lbdId == _selectedLbdId)) {
      _selectedLbdId = targets.isEmpty ? null : targets.first.lbdId;
    }
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

  ReviewEntry? _latestEntryForLbd(int lbdId) {
    for (final entry in _entries) {
      if (entry.lbdId == lbdId) return entry;
    }
    return null;
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

  Future<void> _submitReview() async {
    final lbdId = _selectedLbdId;
    if (lbdId == null) return;

    setState(() => _saving = true);
    final state = context.read<AppState>();
    await state.api.submitReview(
      lbdId: lbdId,
      reviewResult: _selectedResult,
      reviewDate: _selectedDateIso,
      notes: _notesController.text.trim(),
      trackerId: state.currentTracker?.id,
    );
    _notesController.clear();
    _reportDetails.clear();
    await _load();
    if (!mounted) return;
    setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final blocks = state.blocks;
    final targets = _buildTargets(blocks);
    final selectedTarget = targets.where((target) => target.lbdId == _selectedLbdId).firstOrNull;
    final latestEntries = <int, ReviewEntry>{
      for (final entry in _entries)
        if (entry.lbdId > 0) entry.lbdId: entry,
    };
    final failingCount = latestEntries.values.where((entry) => entry.reviewResult == 'fail').length;
    final selectedEntry = selectedTarget == null ? null : _latestEntryForLbd(selectedTarget.lbdId);
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
                  'Run pass/fail quality walks per LBD. Failed LBDs stay on the review report until they pass a later check.',
                  style: AppTheme.font(size: 12, color: C.textSub),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _SummaryPill(label: 'Blocks', value: '${blocks.length}', color: C.cyan)),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryPill(label: 'LBDs', value: '${targets.length}', color: C.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryPill(label: 'Need Fixes', value: '$failingCount', color: C.gold)),
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
          Text('Review LBDs', style: AppTheme.font(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (targets.isEmpty)
            GlassCard(
              child: Text('No LBDs loaded for this tracker.', style: AppTheme.font(size: 13, color: C.textSub)),
            )
          else
            ...targets.map((target) {
              final latest = _latestEntryForLbd(target.lbdId);
              final isSelected = target.lbdId == _selectedLbdId;
              final tone = latest?.reviewResult == 'pass'
                  ? C.green
                  : latest?.reviewResult == 'fail'
                      ? C.gold
                      : C.cyan;
              return GestureDetector(
                onTap: () => setState(() => _selectedLbdId = target.lbdId),
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
                        child: Text('${target.powerBlockNumber}', style: AppTheme.displayFont(size: 14, color: tone)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(target.label, style: AppTheme.font(size: 15, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              '${target.powerBlockName}${target.zone.isNotEmpty ? ' · ${target.zone}' : ''}',
                              style: AppTheme.font(size: 12, color: C.textSub),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              latest == null
                                  ? 'Not reviewed on $_selectedDateIso'
                                  : '${latest.reviewResult.toUpperCase()} by ${latest.reviewedBy}',
                              style: AppTheme.font(size: 12, color: C.textSub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          if (selectedTarget != null) ...[
            Text('Selected Review', style: AppTheme.font(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(18),
              glowColor: _selectedResult == 'pass' ? C.green : C.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selectedTarget.label, style: AppTheme.font(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${selectedTarget.powerBlockName} · PB ${selectedTarget.powerBlockNumber}${selectedTarget.inventoryNumber.isNotEmpty ? ' · ${selectedTarget.inventoryNumber}' : ''}',
                    style: AppTheme.font(size: 12, color: C.textSub),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedEntry?.notes.isNotEmpty == true
                        ? selectedEntry!.notes
                        : 'Add notes from the quality walk before saving.',
                    style: AppTheme.font(size: 12, color: C.textSub),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Pass'),
                          selected: _selectedResult == 'pass',
                          selectedColor: C.green.withValues(alpha: 0.18),
                          onSelected: (_) => setState(() => _selectedResult = 'pass'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Fail'),
                          selected: _selectedResult == 'fail',
                          selectedColor: C.gold.withValues(alpha: 0.18),
                          onSelected: (_) => setState(() => _selectedResult = 'fail'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Review notes'),
                  ),
                  const SizedBox(height: 12),
                  NeonButton(
                    label: _saving ? 'SAVING...' : 'SAVE REVIEW',
                    icon: Icons.verified_rounded,
                    onPressed: _saving ? null : _submitReview,
                    height: 48,
                    gradientColors: _selectedResult == 'pass'
                        ? const [C.green, Color(0xFF00A96C)]
                        : const [Color(0xFFFFD36A), Color(0xFFFF9A4A)],
                    foregroundColor: _selectedResult == 'pass' ? Colors.white : const Color(0xFF231100),
                  ),
                ],
              ),
            ),
          ],
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
                    glowColor: entry.reviewResult == 'pass' ? C.green : C.gold,
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
                glowColor: C.gold,
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
                                color: C.gold.withValues(alpha: 0.10),
                                border: Border.all(color: C.gold.withValues(alpha: 0.22)),
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