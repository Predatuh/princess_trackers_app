import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Work log tab — shown inside MainShell
class WorkLogTab extends StatefulWidget {
  const WorkLogTab({super.key});

  @override
  State<WorkLogTab> createState() => _WorkLogTabState();
}

class _WorkLogTabState extends State<WorkLogTab> {
  DateTime _selectedDate = DateTime.now();
  List<WorkEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final tid = state.currentTracker?.id ?? 0;
    _entries = await state.api.getWorkEntries(_fmt(_selectedDate), tid);
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: C.cyan,
            surface: C.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _selectedDate = picked;
      _load();
    }
  }

  Future<void> _deleteEntry(int id) async {
    final state = context.read<AppState>();
    final ok = await state.api.deleteWorkEntry(id);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Date picker bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: _pickDate,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: C.cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_today_rounded,
                            color: C.cyan, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date',
                                style:
                                    AppTheme.font(size: 11, color: C.textDim)),
                            const SizedBox(height: 2),
                            Text(_fmt(_selectedDate),
                                style: AppTheme.displayFont(
                                    size: 16, color: C.text)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: C.cyan.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Entries
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: C.cyan, strokeWidth: 2))
                  : _entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note_rounded,
                                  color: C.textDim, size: 48),
                              const SizedBox(height: 12),
                              Text('No entries for this date',
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
                            itemCount: _entries.length,
                            itemBuilder: (ctx, i) {
                              final e = _entries[i];
                              return StaggeredItem(
                                index: i,
                                baseDelay:
                                    const Duration(milliseconds: 40),
                                child: Dismissible(
                                  key: ValueKey(e.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    padding:
                                        const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color:
                                          C.pink.withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                          color: C.pink
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(
                                        Icons.delete_rounded,
                                        color: C.pink),
                                  ),
                                  onDismissed: (_) =>
                                      _deleteEntry(e.id),
                                  child: Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(14),
                                    decoration:
                                        AppTheme.glassDecoration(
                                            radius: 14),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: C.purple.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    10),
                                          ),
                                          child: const Icon(
                                              Icons.person_rounded,
                                              color: C.purple,
                                              size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(e.workerName,
                                                  style: AppTheme.font(
                                                      size: 14,
                                                      weight: FontWeight
                                                          .w600)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${e.taskType} — ${e.pbName}',
                                                style: AppTheme.font(
                                                    size: 12,
                                                    color: C.textSub),
                                              ),
                                            ],
                                          ),
                                        ),
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
        ),
        // Floating add button
        Positioned(
          right: 20,
          bottom: 80,
          child: GestureDetector(
            onTap: _showAddDialog,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [C.cyan, C.purple],
                ),
                boxShadow: AppTheme.neonGlowStrong(C.cyan),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddDialog() async {
    final state = context.read<AppState>();
    await state.loadWorkers();

    if (!mounted) return;

    final workers = state.workers;
    final blocks = state.blocks;
    final Set<int> selWorkers = {};
    final Set<int> selBlocks = {};
    String taskType = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  Text('Add Work Entry',
                      style: AppTheme.font(
                          size: 20, weight: FontWeight.w700)),
                  const SizedBox(height: 20),

                  // Task type
                  TextField(
                    style: AppTheme.font(size: 15),
                    decoration: InputDecoration(
                      labelText: 'Task Type',
                      labelStyle:
                          AppTheme.font(size: 14, color: C.textDim),
                      prefixIcon: const Icon(
                          Icons.work_outline_rounded,
                          color: C.textDim,
                          size: 20),
                      filled: true,
                      fillColor: const Color(0x0AFFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0x14FFFFFF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0x14FFFFFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: C.cyan, width: 1.5),
                      ),
                    ),
                    onChanged: (v) => taskType = v,
                  ),
                  const SizedBox(height: 16),

                  // Workers
                  Text('Workers',
                      style: AppTheme.font(
                          size: 13,
                          color: C.textSub,
                          weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: workers.map((w) {
                      final on = selWorkers.contains(w.id);
                      return FilterChip(
                        label: Text(w.name),
                        selected: on,
                        selectedColor:
                            C.cyan.withValues(alpha: 0.2),
                        labelStyle: AppTheme.font(
                          size: 13,
                          color: on ? C.cyan : C.textSub,
                        ),
                        backgroundColor: const Color(0x0AFFFFFF),
                        side: BorderSide(
                            color: on
                                ? C.cyan.withValues(alpha: 0.4)
                                : const Color(0x14FFFFFF)),
                        checkmarkColor: C.cyan,
                        onSelected: (v) => setLocal(() {
                          v
                              ? selWorkers.add(w.id)
                              : selWorkers.remove(w.id);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Power blocks
                  Text('Power Blocks',
                      style: AppTheme.font(
                          size: 13,
                          color: C.textSub,
                          weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: blocks.map((b) {
                      final on = selBlocks.contains(b.id);
                      return FilterChip(
                        label: Text('PB ${b.powerBlockNumber}'),
                        selected: on,
                        selectedColor:
                            C.green.withValues(alpha: 0.2),
                        labelStyle: AppTheme.font(
                          size: 13,
                          color: on ? C.green : C.textSub,
                        ),
                        backgroundColor: const Color(0x0AFFFFFF),
                        side: BorderSide(
                            color: on
                                ? C.green.withValues(alpha: 0.4)
                                : const Color(0x14FFFFFF)),
                        checkmarkColor: C.green,
                        onSelected: (v) => setLocal(() {
                          v
                              ? selBlocks.add(b.id)
                              : selBlocks.remove(b.id);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: 'ADD ENTRIES',
                      icon: Icons.add_rounded,
                      onPressed: () async {
                        if (taskType.isEmpty ||
                            selWorkers.isEmpty ||
                            selBlocks.isEmpty) {
                          return;
                        }
                        await state.api.createWorkEntries(
                          date: _fmt(_selectedDate),
                          workerIds: selWorkers.toList(),
                          powerBlockIds: selBlocks.toList(),
                          taskType: taskType,
                          trackerId: state.currentTracker?.id,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

// Keep old name for backward compat
class WorkLogScreen extends StatelessWidget {
  const WorkLogScreen({super.key});
  @override
  Widget build(BuildContext context) => const WorkLogTab();
}
