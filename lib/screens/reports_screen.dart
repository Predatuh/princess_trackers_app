import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Reports tab — shown inside MainShell
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  List<DailyReport> _reports = [];
  bool _loading = true;
  bool _fixOnly = false;

  List<DailyReport> get _visibleReports => _fixOnly
      ? _reports.where((report) => report.fixEntryCount > 0).toList()
      : _reports;

  List<Map<String, dynamic>> _fixEntries(Map<String, dynamic> payload) {
    return (payload['raw_entries'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) => entry['task_type']?.toString() == 'fix')
        .toList();
  }

  Map<String, List<String>> _groupFixEntriesByWorker(List<Map<String, dynamic>> entries) {
    final grouped = <String, List<String>>{};
    for (final entry in entries) {
      final worker = entry['worker_name']?.toString() ?? 'Unknown';
      final block = entry['power_block_name']?.toString() ?? 'Unknown';
      grouped.putIfAbsent(worker, () => <String>[]).add(block);
    }
    return grouped;
  }

  Widget _buildClaimScanPreview({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: C.surfaceLight.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined,
                  color: C.textDim, size: 22),
              const SizedBox(height: 6),
              Text(
                'Image unavailable',
                style: AppTheme.font(size: 11, color: C.textDim),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportReportPdf({
    required String reportDate,
    required Map<String, dynamic> payload,
  }) async {
    final byTask = Map<String, dynamic>.from(payload['by_task'] ?? {});
    final byWorker = Map<String, dynamic>.from(payload['by_worker'] ?? {});
    final byPowerBlock = Map<String, dynamic>.from(payload['by_power_block'] ?? {});
    final rawEntries = (payload['raw_entries'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final workers = (payload['worker_names'] as List? ?? const [])
        .map((entry) => entry.toString())
        .toList();

    final doc = pw.Document();
    final titleStyle = pw.TextStyle(
      fontSize: 22,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blueGrey900,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.cyan800,
    );

    pw.Widget statCard(String title, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColors.blueGrey200),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Princess Trackers', style: titleStyle),
                  pw.SizedBox(height: 4),
                  pw.Text('Daily Progress Report', style: pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600)),
                ],
              ),
              pw.Text(reportDate, style: pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey700)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              pw.Expanded(child: statCard('Total Entries', '${payload['total_entries'] ?? 0}')),
              pw.SizedBox(width: 10),
              pw.Expanded(child: statCard('Workers', '${workers.length}')),
              pw.SizedBox(width: 10),
              pw.Expanded(child: statCard('Power Blocks', '${byPowerBlock.length}')),
            ],
          ),
          if (byPowerBlock.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            pw.Text('Work By Power Block', style: sectionStyle),
            pw.SizedBox(height: 10),
            ...byPowerBlock.entries.map((entry) {
              final taskMap = Map<String, dynamic>.from(entry.value as Map);
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey200),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(entry.key, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    ...taskMap.entries.map((taskEntry) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(
                            '${taskEntry.key}: ${(taskEntry.value as List).join(', ')}',
                            style: pw.TextStyle(fontSize: 10.5, color: PdfColors.blueGrey800),
                          ),
                        )),
                  ],
                ),
              );
            }),
          ],
          if (byTask.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Task Breakdown', style: sectionStyle),
            pw.SizedBox(height: 10),
            ...byTask.entries.map((entry) {
              final workerMap = Map<String, dynamic>.from(entry.value as Map);
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(entry.key, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  ...workerMap.entries.map((workerEntry) => pw.Text(
                        '${workerEntry.key}: ${(workerEntry.value as List).join(', ')}',
                        style: const pw.TextStyle(fontSize: 10.5),
                      )),
                  pw.SizedBox(height: 8),
                ],
              );
            }),
          ],
          if (rawEntries.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Detailed Log', style: sectionStyle),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const ['Worker', 'Task', 'Power Block', 'Date', 'Logged By'],
              data: rawEntries
                  .map((entry) => [
                        entry['worker_name']?.toString() ?? '',
                        entry['task_type']?.toString() ?? '',
                        entry['power_block_name']?.toString() ?? '',
                        entry['work_date']?.toString() ?? '',
                        entry['logged_by']?.toString() ?? '',
                      ])
                  .toList(),
            ),
          ],
          if (byWorker.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Worker Summary', style: sectionStyle),
            pw.SizedBox(height: 8),
            ...byWorker.entries.map((entry) {
              final taskMap = Map<String, dynamic>.from(entry.value as Map);
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(entry.key, style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    ...taskMap.entries.map((taskEntry) => pw.Text(
                          '${taskEntry.key}: ${(taskEntry.value as List).join(', ')}',
                          style: const pw.TextStyle(fontSize: 10),
                        )),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'princess-trackers-$reportDate.pdf',
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final tid = state.currentTracker?.id ?? 0;
    _reports = await state.api.getReports(tid);
    setState(() => _loading = false);
  }

  Future<void> _generateToday() async {
    final state = context.read<AppState>();
    await state.api.generateReport(trackerId: state.currentTracker?.id);
    await _load();
  }

  Future<void> _generateFixReport() async {
    final state = context.read<AppState>();
    await state.api.generateReport(trackerId: state.currentTracker?.id);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _fixOnly = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      children: [
        // Generate report actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _generateToday,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    borderRadius: 14,
                    glowColor: C.green,
                    glowBlur: 10,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: C.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_chart_rounded,
                              color: C.green, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Generate Report',
                                  style: AppTheme.font(
                                      size: 15, weight: FontWeight.w700)),
                              Text("Create today's status report",
                                  style: AppTheme.font(
                                      size: 12, color: C.textSub)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            color: C.green.withValues(alpha: 0.6), size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _generateFixReport,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    borderRadius: 14,
                    glowColor: C.gold,
                    glowBlur: 10,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: C.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.build_circle_outlined,
                              color: C.gold, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Generate Fix Report',
                                  style: AppTheme.font(
                                      size: 15, weight: FontWeight.w700)),
                              Text('Generate and jump to fix activity',
                                  style: AppTheme.font(
                                      size: 12, color: C.textSub)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            color: C.gold.withValues(alpha: 0.7), size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Reports'),
                selected: !_fixOnly,
                onSelected: (_) => setState(() => _fixOnly = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Fix Reports'),
                selected: _fixOnly,
                onSelected: (_) => setState(() => _fixOnly = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Report list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: C.cyan, strokeWidth: 2))
              : _visibleReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insights_rounded,
                              color: C.textDim, size: 48),
                          const SizedBox(height: 12),
                          Text(_fixOnly ? 'No fix reports yet' : 'No reports yet',
                              style: AppTheme.font(color: C.textDim)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: C.cyan,
                      backgroundColor: C.surface,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: _visibleReports.length,
                        itemBuilder: (ctx, i) {
                          final r = _visibleReports[i];
                          final previewUrl = state.api.resolveMediaUrl(r.latestClaimScanImageUrl);
                          return GestureDetector(
                              onTap: () => _showDetail(r.id),
                              child: Container(
                                margin:
                                const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                              decoration: AppTheme.glassDecoration(radius: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: C.cyan.withValues(
                                            alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(
                                                12),
                                      ),
                                      child: const Icon(
                                          Icons
                                              .description_rounded,
                                          color: C.cyan,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(r.reportDate,
                                              style: AppTheme.font(
                                            size: 16,
                                            weight: FontWeight
                                              .w700)),
                                        const SizedBox(height: 2),
                                        Text('${r.data['total_entries'] ?? 0} updates captured for the day',
                                              style: AppTheme.font(
                                                  size: 12,
                                                  color:
                                                      C.textSub)),
                                          const SizedBox(height: 6),
                                          Text('${r.fixEntryCount} fix${r.fixEntryCount == 1 ? '' : 'es'} logged',
                                            style: AppTheme.font(size: 11, color: C.gold)),
                                          if (r.claimScanCount > 0) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: C.cyan.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(999),
                                                    border: Border.all(color: C.cyan.withValues(alpha: 0.25)),
                                                  ),
                                                  child: Text(
                                                    '${r.claimScanCount} claim scan${r.claimScanCount == 1 ? '' : 's'}',
                                                    style: AppTheme.font(size: 11, weight: FontWeight.w700, color: C.cyan),
                                                  ),
                                                ),
                                                if ((r.latestClaimScanPowerBlock ?? '').isNotEmpty)
                                                  Text(
                                                    r.latestClaimScanPowerBlock!,
                                                    style: AppTheme.font(size: 11, color: C.textSub),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (previewUrl != null) ...[
                                      const SizedBox(width: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: _buildClaimScanPreview(
                                          imageUrl: previewUrl,
                                          width: 56,
                                          height: 56,
                                        ),
                                      ),
                                    ],
                                    Icon(
                                        Icons
                                            .chevron_right_rounded,
                                        color: C.textDim,
                                        size: 20),
                                  ],
                                ),
                              ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showDetail(int id) async {
    final state = context.read<AppState>();
    final detail = await state.api.getReportDetail(id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final payload = Map<String, dynamic>.from(
          detail['data'] is Map<String, dynamic> ? detail['data'] : detail,
        );
        final totalEntries = payload['total_entries'] ?? detail['total_entries'] ?? 0;
        final workerNames =
          (payload['worker_names'] as List?)?.cast<String>() ?? [];
        final byTask =
          Map<String, dynamic>.from(payload['by_task'] ?? {});
        final byWorker =
          Map<String, dynamic>.from(payload['by_worker'] ?? {});
        final byPowerBlock =
          Map<String, dynamic>.from(payload['by_power_block'] ?? {});
        final rawEntries = (payload['raw_entries'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
        final claimScans = (payload['claim_scans'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
        final fixEntries = _fixEntries(payload);
        final fixByWorker = _groupFixEntriesByWorker(fixEntries);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: C.textDim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Report: ${detail['report_date'] ?? payload['report_date'] ?? ''}',
                  style:
                      AppTheme.font(size: 20, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalEntries entries · ${workerNames.length} workers · ${fixEntries.length} fixes',
                  style: AppTheme.font(size: 13, color: C.textSub),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        glowColor: C.cyan,
                        glowBlur: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Entries', style: AppTheme.font(size: 11, color: C.textSub)),
                            const SizedBox(height: 4),
                            Text('$totalEntries', style: AppTheme.displayFont(size: 20, color: C.cyan)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        glowColor: C.green,
                        glowBlur: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Workers', style: AppTheme.font(size: 11, color: C.textSub)),
                            const SizedBox(height: 4),
                            Text('${workerNames.length}', style: AppTheme.displayFont(size: 20, color: C.green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        glowColor: C.gold,
                        glowBlur: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fixes', style: AppTheme.font(size: 11, color: C.textSub)),
                            const SizedBox(height: 4),
                            Text('${fixEntries.length}', style: AppTheme.displayFont(size: 20, color: C.gold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _exportReportPdf(
                      reportDate: (detail['report_date'] ?? payload['report_date'] ?? '').toString(),
                      payload: payload,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Export PDF'),
                  ),
                ),
                const SizedBox(height: 20),

                if (fixEntries.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'Fix Activity',
                      icon: Icons.build_circle_rounded,
                      color: C.gold),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    glowColor: C.gold,
                    glowBlur: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fixByWorker.entries
                          .map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: Text(entry.key,
                                          style: AppTheme.font(size: 12, weight: FontWeight.w700, color: C.gold)),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value.toSet().join(', '),
                                        style: AppTheme.font(size: 12, color: C.textSub),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // By Task
                if (byTask.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'By Task',
                      icon: Icons.task_alt_rounded),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: byTask.entries
                          .map((e) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text(e.key,
                                        style: AppTheme.font(
                                            size: 14,
                                            color: C.textSub)),
                                    Text('${e.value}',
                                        style:
                                            AppTheme.displayFont(
                                                size: 14,
                                                color: C.cyan)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (byPowerBlock.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'By Power Block',
                      icon: Icons.grid_view_rounded,
                      color: C.gold),
                  ...byPowerBlock.entries.map((entry) {
                    final taskMap = Map<String, dynamic>.from(entry.value as Map);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        glowColor: C.gold,
                        glowBlur: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key,
                                style: AppTheme.font(size: 15, weight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...taskMap.entries.map((taskEntry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 110,
                                        child: Text(taskEntry.key,
                                            style: AppTheme.font(size: 12, weight: FontWeight.w700, color: C.gold)),
                                      ),
                                      Expanded(
                                        child: Text(
                                          (taskEntry.value as List).join(', '),
                                          style: AppTheme.font(size: 12, color: C.textSub),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // By Worker
                if (byWorker.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'By Worker',
                      icon: Icons.people_rounded,
                      color: C.green),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: byWorker.entries
                          .map((e) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text(e.key,
                                        style: AppTheme.font(
                                            size: 14,
                                            color: C.textSub)),
                                    Text('${e.value}',
                                        style:
                                            AppTheme.displayFont(
                                                size: 14,
                                                color: C.green)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (claimScans.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'Claim Sheet Photos',
                      icon: Icons.photo_library_rounded,
                      color: C.cyan),
                  ...claimScans.map((scan) {
                    final imageUrl = state.api.resolveMediaUrl(scan['image_url']?.toString());
                    final assignmentSummary = Map<String, dynamic>.from(scan['assignment_summary'] ?? {});
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan['power_block_name']?.toString() ?? 'Claim Sheet',
                              style: AppTheme.font(size: 14, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (scan['people'] as List? ?? const []).join(', '),
                              style: AppTheme.font(size: 12, color: C.textSub),
                            ),
                            if (assignmentSummary.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                assignmentSummary.entries.map((entry) => '${entry.key}: ${entry.value}').join(' • '),
                                style: AppTheme.font(size: 11, color: C.cyan),
                              ),
                            ],
                            if (imageUrl != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildClaimScanPreview(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 180,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // Workers list
                if (workerNames.isNotEmpty) ...[
                  const SectionHeader(
                      title: 'Workers',
                      icon: Icons.person_rounded,
                      color: C.purple),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: workerNames
                        .map((n) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: C.purple
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: Border.all(
                                    color: C.purple
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(n,
                                  style: AppTheme.font(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: C.purple)),
                            ))
                        .toList(),
                  ),
                ],

                if (rawEntries.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const SectionHeader(
                      title: 'Detailed Activity Log',
                      icon: Icons.fact_check_rounded,
                      color: C.cyan),
                  ...rawEntries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry['worker_name'] ?? ''} · ${entry['task_type'] ?? ''}',
                                style: AppTheme.font(size: 13, weight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Power Block: ${entry['power_block_name'] ?? ''}',
                                style: AppTheme.font(size: 12, color: C.textSub),
                              ),
                              Text(
                                'Date: ${entry['work_date'] ?? ''}  •  Logged By: ${entry['logged_by'] ?? 'Unknown'}',
                                style: AppTheme.font(size: 11, color: C.textDim),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// Keep old name for backward compat
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => const ReportsTab();
}
