import 'package:flutter/material.dart';
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Generate report button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                            style:
                                AppTheme.font(size: 12, color: C.textSub)),
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
        const SizedBox(height: 8),

        // Report list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: C.cyan, strokeWidth: 2))
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insights_rounded,
                              color: C.textDim, size: 48),
                          const SizedBox(height: 12),
                          Text('No reports yet',
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
                        itemCount: _reports.length,
                        itemBuilder: (ctx, i) {
                          final r = _reports[i];
                          return StaggeredItem(
                            index: i,
                            baseDelay:
                                const Duration(milliseconds: 40),
                            child: GestureDetector(
                              onTap: () => _showDetail(r.id),
                              child: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration:
                                    AppTheme.glassDecoration(
                                        radius: 14),
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
                                                  size: 15,
                                                  weight: FontWeight
                                                      .w600)),
                                          Text('Daily Report',
                                              style: AppTheme.font(
                                                  size: 12,
                                                  color:
                                                      C.textSub)),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                        Icons
                                            .chevron_right_rounded,
                                        color: C.textDim,
                                        size: 20),
                                  ],
                                ),
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
        final totalEntries = detail['total_entries'] ?? 0;
        final workerNames =
            (detail['worker_names'] as List?)?.cast<String>() ?? [];
        final byTask =
            Map<String, dynamic>.from(detail['by_task'] ?? {});
        final byWorker =
            Map<String, dynamic>.from(detail['by_worker'] ?? {});

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
                  'Report: ${detail['report_date'] ?? ''}',
                  style:
                      AppTheme.font(size: 20, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalEntries entries · ${workerNames.length} workers',
                  style: AppTheme.font(size: 13, color: C.textSub),
                ),
                const SizedBox(height: 20),

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
