import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'scan_camera_screen.dart';
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

  /// Staged claims kept at screen level so submit + back button can see them
  final List<Map<String, dynamic>> _stagedClaims = [];

  String _lbdLabel(LbdItem lbd) {
    final identifier = (lbd.identifier ?? '').trim();
    if (identifier.isNotEmpty) return identifier;
    final name = (lbd.name ?? '').trim();
    if (name.isNotEmpty) return name;
    return 'LBD ${lbd.id}';
  }

  String _todayIsoDate() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Map<String, List<int>> _normalizeAssignments(dynamic raw) {
    if (raw is! Map) return {};
    final normalized = <String, List<int>>{};
    raw.forEach((key, value) {
      final ids = (value as List? ?? const [])
          .map((entry) => int.tryParse(entry.toString()) ?? 0)
          .where((entry) => entry > 0)
          .toList();
      if (ids.isNotEmpty) {
        normalized[key.toString()] = ids;
      }
    });
    return normalized;
  }

  String _selectionSummary(AppState state, String statusType, Map<String, List<int>> assignments) {
    final ids = assignments[statusType] ?? const [];
    if (ids.isEmpty) return 'None selected';
    final labels = block.lbds
        .where((lbd) => ids.contains(lbd.id))
        .map(_lbdLabel)
        .toList();
    return labels.isEmpty ? 'None selected' : labels.join(', ');
  }

  Future<void> _showClaimDialog(AppState state, {Uint8List? initialScanBytes}) async {
    final tracker = state.currentTracker;
    final availableTaskTypes = tracker?.statusTypes ?? const <String>[];

    // Process initial scan bytes before opening dialog
    Map<String, dynamic>? initialDraft;
    Map<String, List<int>> initialAssignments = {};
    List<String> initialTaskTypes = [];

    if (initialScanBytes != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: C.cyan)),
      );
      try {
        initialDraft = await state.api.scanClaimSheetDraft(
          blockId: block.id,
          trackerId: tracker?.id,
          fileName: 'claim_scan.jpg',
          fileBytes: initialScanBytes,
        );
        initialAssignments = _normalizeAssignments(initialDraft['assignments']);
        initialTaskTypes = availableTaskTypes.where(initialAssignments.containsKey).toList();
      } catch (_) {}
      if (mounted) Navigator.pop(context);
    }

    final suggestions = await state.api.getClaimPeople();
    if (!mounted) return;
    final crewOptions = <String>[...suggestions];
    final currentUserName = state.user?.name.trim();
    final canDefaultToCurrentUser = currentUserName != null &&
      currentUserName.isNotEmpty &&
      crewOptions.any((name) => name.toLowerCase() == currentUserName.toLowerCase());

    // Current claim editor state
    var currentCrew = <String>{};
    var currentAssignments = initialAssignments.isNotEmpty
        ? initialAssignments
      : <String, List<int>>{};
    var currentTaskTypes = initialTaskTypes.isNotEmpty
        ? initialTaskTypes
      : <String>[];
    Map<String, dynamic>? currentScanDraft = initialDraft;
    var isScanning = false;
    String? scanError;
    String? validationError;
    var currentTaskIndex = 0;
    var claimWorkDate = ((initialDraft?['work_date']?.toString() ?? '').split('T').first.trim().isNotEmpty)
      ? (initialDraft?['work_date']?.toString() ?? '').split('T').first.trim()
      : _todayIsoDate();

    if (currentCrew.isEmpty && canDefaultToCurrentUser) {
      currentCrew.add(currentUserName!);
    }

    final extraController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void normalizeTaskIndex() {
              if (currentTaskTypes.isEmpty) {
                currentTaskIndex = 0;
                return;
              }
              if (currentTaskIndex >= currentTaskTypes.length) {
                currentTaskIndex = currentTaskTypes.length - 1;
              }
            }

            void toggleTaskType(String statusType) {
              setModalState(() {
                validationError = null;
                if (currentTaskTypes.contains(statusType)) {
                  currentTaskTypes.remove(statusType);
                  currentAssignments.remove(statusType);
                } else {
                  currentTaskTypes.add(statusType);
                  currentAssignments.putIfAbsent(statusType, () => <int>[]);
                  currentTaskIndex = currentTaskTypes.length - 1;
                }
                normalizeTaskIndex();
              });
            }

            final currentTaskType = currentTaskTypes.isEmpty
                ? null
                : currentTaskTypes[currentTaskIndex];

            Future<void> runScan() async {
              final proceed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: C.surface,
                  title: Text('WARNING!', style: AppTheme.displayFont(size: 18, color: C.gold)),
                  content: Text(
                    'FEATURE IS IN BETA STAGE AND CAN BE INACCURATE. BE SURE TO DOUBLE CHECK CLAIMS.',
                    style: AppTheme.font(size: 14, color: C.text),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel', style: AppTheme.font(color: C.textDim)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Proceed'),
                    ),
                  ],
                ),
              );
              if (proceed != true) return;
              if (!context.mounted) return;

              final Uint8List? imageBytes = await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute(builder: (_) => const ScanCameraScreen()),
              );
              if (imageBytes == null) return;

              setModalState(() {
                isScanning = true;
                scanError = null;
              });

              try {
                final draft = await state.api.scanClaimSheetDraft(
                  blockId: block.id,
                  trackerId: tracker?.id,
                  fileName: 'claim_scan.jpg',
                  fileBytes: imageBytes,
                );
                final parsedAssignments = _normalizeAssignments(draft['assignments']);
                setModalState(() {
                  currentScanDraft = draft;
                  final draftWorkDate = (draft['work_date']?.toString() ?? '').split('T').first.trim();
                  if (draftWorkDate.isNotEmpty) {
                    claimWorkDate = draftWorkDate;
                  }
                  if (parsedAssignments.isNotEmpty) {
                    currentAssignments
                      ..clear()
                      ..addAll(parsedAssignments);
                    currentTaskTypes
                      ..clear()
                      ..addAll(
                        availableTaskTypes.where(parsedAssignments.containsKey),
                      );
                    normalizeTaskIndex();
                  }
                });
              } catch (error) {
                setModalState(() {
                  scanError = error.toString().replaceFirst('Exception: ', '');
                });
              } finally {
                setModalState(() {
                  isScanning = false;
                });
              }
            }

            final warnings = (currentScanDraft?['warnings'] as List? ?? const [])
                .map((entry) => entry.toString())
                .where((entry) => entry.trim().isNotEmpty)
                .toList();

            List<String> resolveCurrentPeople() {
              final extras = extraController.text
                  .split(RegExp(r'[\n,]'))
                  .map((name) => name.trim())
                  .where((name) => name.isNotEmpty);
              final people = <String>[];
              final seen = <String>{};
              for (final person in [...currentCrew, ...extras]) {
                final key = person.toLowerCase();
                if (seen.add(key)) {
                  people.add(person);
                }
              }
              return people;
            }

            Map<String, dynamic>? buildCurrentClaim() {
              final people = resolveCurrentPeople();
              if (people.isEmpty) {
                setModalState(() {
                  validationError = 'Select at least one crew member.';
                });
                return null;
              }
              if (currentTaskTypes.isEmpty) {
                setModalState(() {
                  validationError = 'Choose at least one task type.';
                });
                return null;
              }
              final missing = currentTaskTypes
                  .where((statusType) => (currentAssignments[statusType] ?? []).isEmpty)
                  .map((statusType) => state.getStatusName(statusType))
                  .toList();
              if (missing.isNotEmpty) {
                setModalState(() {
                  validationError = 'Select LBDs for ${missing.join(", ")}.';
                });
                return null;
              }
              return {
                'people': people,
                'assignments': {
                  for (final statusType in currentTaskTypes)
                    statusType: List<int>.from(currentAssignments[statusType] ?? const <int>[]),
                },
                'scanDraft': currentScanDraft,
                'workDate': claimWorkDate,
              };
            }

            void resetWorkingClaim() {
              currentCrew = <String>{};
              currentAssignments = <String, List<int>>{};
              currentTaskTypes = <String>[];
              extraController.clear();
              currentScanDraft = null;
              scanError = null;
              validationError = null;
              currentTaskIndex = 0;
              claimWorkDate = _todayIsoDate();
              if (canDefaultToCurrentUser) {
                currentCrew.add(currentUserName!);
              }
            }

            Future<void> pickWorkDate() async {
              final initialDate = DateTime.tryParse(claimWorkDate) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null) return;
              final month = picked.month.toString().padLeft(2, '0');
              final day = picked.day.toString().padLeft(2, '0');
              setModalState(() {
                claimWorkDate = '${picked.year}-$month-$day';
                if (currentScanDraft != null) {
                  currentScanDraft = {
                    ...currentScanDraft!,
                    'work_date': claimWorkDate,
                  };
                }
              });
            }

            void stageClaim({required bool closeDialog}) {
              final claim = buildCurrentClaim();
              if (claim == null) return;
              _stagedClaims.add(claim);
              setModalState(() {
                resetWorkingClaim();
              });
              if (mounted) setState(() {});
              if (closeDialog) {
                Navigator.pop(context);
              }
            }

            Widget buildTaskSelector() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Types',
                    style: AppTheme.font(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTaskTypes.map((statusType) {
                      final isSelected = currentTaskTypes.contains(statusType);
                      final color = state.getStatusColor(statusType);
                      return GestureDetector(
                        onTap: () => toggleTaskType(statusType),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.18) : const Color(0x0AFFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected ? color.withValues(alpha: 0.45) : const Color(0x14FFFFFF),
                            ),
                          ),
                          child: Text(
                            state.getStatusName(statusType),
                            style: AppTheme.font(
                              size: 12,
                              weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? color : C.textSub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            Widget buildTaskLbdPicker() {
              if (currentTaskType == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: Text(
                    'Pick one or more task types to start assigning exact LBDs.',
                    style: AppTheme.font(size: 12, color: C.textSub),
                  ),
                );
              }

              final currentSelections = currentAssignments[currentTaskType] ?? const <int>[];
              final currentTaskName = state.getStatusName(currentTaskType);
              final currentTaskColor = state.getStatusColor(currentTaskType);
              final allCurrentTaskIds = block.lbds.map((lbd) => lbd.id).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTaskName,
                              style: AppTheme.font(size: 14, weight: FontWeight.w700, color: currentTaskColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Task ${currentTaskIndex + 1} of ${currentTaskTypes.length}',
                              style: AppTheme.font(size: 11, color: C.textDim),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentTaskColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: currentTaskColor.withValues(alpha: 0.28)),
                        ),
                        child: Text(
                          '${currentSelections.length} selected',
                          style: AppTheme.font(size: 11, weight: FontWeight.w700, color: currentTaskColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: currentSelections.length == allCurrentTaskIds.length
                            ? null
                            : () => setModalState(() {
                                  validationError = null;
                                  currentAssignments[currentTaskType] = List<int>.from(allCurrentTaskIds);
                                }),
                        icon: const Icon(Icons.select_all_rounded, size: 18),
                        label: const Text('Select All'),
                      ),
                      TextButton.icon(
                        onPressed: currentSelections.isEmpty
                            ? null
                            : () => setModalState(() {
                                  validationError = null;
                                  currentAssignments[currentTaskType] = <int>[];
                                }),
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x14FFFFFF)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: block.lbds.length,
                      itemBuilder: (context, index) {
                        final lbd = block.lbds[index];
                        final isSelected = currentSelections.contains(lbd.id);
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          activeColor: currentTaskColor,
                          checkColor: C.bg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            _lbdLabel(lbd),
                            style: AppTheme.font(size: 13, color: C.text),
                          ),
                          subtitle: (lbd.name ?? '').trim() != _lbdLabel(lbd)
                              ? Text(
                                  lbd.name ?? '',
                                  style: AppTheme.font(size: 11, color: C.textDim),
                                )
                              : null,
                          onChanged: (value) {
                            setModalState(() {
                              validationError = null;
                              final updated = List<int>.from(currentAssignments[currentTaskType] ?? const []);
                              if (value ?? false) {
                                if (!updated.contains(lbd.id)) {
                                  updated.add(lbd.id);
                                }
                              } else {
                                updated.remove(lbd.id);
                              }
                              currentAssignments[currentTaskType] = updated;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  if (currentTaskTypes.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: currentTaskIndex == 0
                              ? null
                              : () => setModalState(() {
                                    currentTaskIndex -= 1;
                                    validationError = null;
                                  }),
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('Previous Task'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: currentTaskIndex >= currentTaskTypes.length - 1
                                ? null
                                : () => setModalState(() {
                                      currentTaskIndex += 1;
                                      validationError = null;
                                    }),
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text('Next Task'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            }

            return AlertDialog(
              backgroundColor: C.surface,
              title: Text(
                'Add Claim for ${block.name}',
                style: AppTheme.font(size: 18, weight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick the crew for this claim, choose the exact date, then select tasks and LBDs. Add Claim keeps this window open so you can stage another claim on the same block.',
                        style: AppTheme.font(size: 12, color: C.textSub),
                      ),
                      // Show previously staged claims
                      if (_stagedClaims.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('Staged Claims', style: AppTheme.font(size: 14, weight: FontWeight.w700, color: C.green)),
                        const SizedBox(height: 6),
                        ..._stagedClaims.asMap().entries.map((e) {
                          final idx = e.key;
                          final claim = e.value;
                          final ppl = List<String>.from(claim['people'] ?? []);
                          final asgn = claim['assignments'] as Map<String, dynamic>? ?? {};
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: C.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: C.green.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: C.green, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${claim['work_date'] ?? 'Today'} • ${ppl.join(", ")} \u2192 ${asgn.keys.map((k) => state.getStatusName(k)).join(", ")}',
                                    style: AppTheme.font(size: 12, color: C.text),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _stagedClaims.removeAt(idx);
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                  child: const Icon(Icons.close_rounded, size: 16, color: C.textDim),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(color: Color(0x14FFFFFF), height: 18),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'Crew',
                        style: AppTheme.font(size: 14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...crewOptions.map((name) {
                        final isChecked = currentCrew.contains(name);
                        return CheckboxListTile(
                          value: isChecked,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: C.cyan,
                          checkColor: C.bg,
                          title: Text(
                            name,
                            style: AppTheme.font(size: 13, color: C.text),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              if (value ?? false) {
                                currentCrew.add(name);
                              } else {
                                currentCrew.remove(name);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 10),
                      TextField(
                        controller: extraController,
                        minLines: 2,
                        maxLines: 4,
                        style: AppTheme.font(size: 13, color: C.text),
                        decoration: InputDecoration(
                          labelText: 'Extra names',
                          hintText: 'Comma or new-line separated',
                          labelStyle: AppTheme.font(size: 12, color: C.textSub),
                          hintStyle: AppTheme.font(size: 12, color: C.textDim),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Claim Date',
                        style: AppTheme.font(size: 14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: pickWorkDate,
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(claimWorkDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      buildTaskSelector(),
                      const SizedBox(height: 16),
                      // Scan button (always available)
                      Text(
                        'Scan Claim Sheet',
                        style: AppTheme.font(size: 14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isScanning ? null : () => runScan(),
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Scan Sheet'),
                              const SizedBox(width: 6),
                              Text('Beta', style: AppTheme.font(size: 10, weight: FontWeight.w700, color: C.gold)),
                            ],
                          ),
                        ),
                      ),
                      if (isScanning) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: C.cyan),
                            ),
                            const SizedBox(width: 10),
                            Text('Scanning claim sheet...', style: AppTheme.font(size: 12, color: C.textSub)),
                          ],
                        ),
                      ],
                      if (currentScanDraft != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: C.cyan.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.cyan.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latest scan draft',
                                style: AppTheme.font(size: 12, weight: FontWeight.w700, color: C.cyan),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${currentScanDraft!['work_date'] ?? claimWorkDate}',
                                style: AppTheme.font(size: 12, color: C.text),
                              ),
                              Text(
                                'Source: ${currentScanDraft!['source'] ?? 'manual'}',
                                style: AppTheme.font(size: 12, color: C.textSub),
                              ),
                              if (warnings.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  warnings.join('\n'),
                                  style: AppTheme.font(size: 11, color: C.gold),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (scanError != null) ...[
                        const SizedBox(height: 10),
                        Text(scanError!, style: AppTheme.font(size: 12, color: C.pink)),
                      ],
                      const SizedBox(height: 16),
                      buildTaskLbdPicker(),
                      const SizedBox(height: 18),
                      Text(
                        'Current Selection',
                        style: AppTheme.font(size: 14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Claim date: $claimWorkDate',
                        style: AppTheme.font(size: 12, color: C.textSub),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x14FFFFFF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: currentTaskTypes.map((statusType) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 92,
                                    child: Text(
                                      state.getStatusName(statusType),
                                      style: AppTheme.font(size: 12, weight: FontWeight.w700, color: state.getStatusColor(statusType)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectionSummary(state, statusType, currentAssignments),
                                      style: AppTheme.font(size: 12, color: C.textSub),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (validationError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          validationError!,
                          style: AppTheme.font(size: 12, color: C.pink),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: AppTheme.font(color: C.textDim)),
                ),
                OutlinedButton(
                  onPressed: () => stageClaim(closeDialog: false),
                  child: const Text('Add Claim'),
                ),
                ElevatedButton(
                  onPressed: () => stageClaim(closeDialog: true),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dialog closed — staged claims are already in _stagedClaims
    // Submit happens via header button or back button, not here.
  }

  /// Submit all staged claims with confirmation
  Future<bool> _submitStagedClaims(
    AppState state, {
    bool navigateBackOnSuccess = true,
  }) async {
    if (_stagedClaims.isEmpty) return false;

    // Build confirmation summary
    final summaryLines = <String>[];
    for (int i = 0; i < _stagedClaims.length; i++) {
      final claim = _stagedClaims[i];
      final people = List<String>.from(claim['people'] ?? []);
      final claimAssignments = _normalizeAssignments(claim['assignments']);
      summaryLines.add('Claim ${i + 1} (${claim['work_date'] ?? 'Today'}): ${people.join(", ")}');
      for (final entry in claimAssignments.entries) {
        final taskName = state.getStatusName(entry.key);
        final lbdNames = block.lbds
            .where((lbd) => entry.value.contains(lbd.id))
            .map(_lbdLabel)
            .toList();
        summaryLines.add('  $taskName (${lbdNames.length}): ${lbdNames.join(", ")}');
      }
      summaryLines.add('');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Is the claiming 100% accurate?',
            style: AppTheme.font(size: 16, weight: FontWeight.w700)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Text(
              summaryLines.join('\n'),
              style: AppTheme.font(size: 13, color: C.textSub),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No, Edit', style: AppTheme.font(color: C.pink)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final success = await state.submitBlockClaimsBatch(
      block.id,
      claims: List<Map<String, dynamic>>.from(_stagedClaims),
    );
    if (success) {
      setState(() => _stagedClaims.clear());
      if (navigateBackOnSuccess && mounted) {
        state.setSelectedTab(1);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim save failed. Please try again.')),
      );
    }
    return success;
  }

  /// Back-button intercept: if staged claims exist, prompt to submit or discard
  Future<bool> _onBackPressed(AppState state) async {
    if (_stagedClaims.isEmpty) return true; // allow navigation

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Unsaved Claims',
            style: AppTheme.font(size: 16, weight: FontWeight.w700)),
        content: Text(
          'You have ${_stagedClaims.length} staged claim${_stagedClaims.length > 1 ? 's' : ''}. Would you like to submit them or exit without saving?',
          style: AppTheme.font(size: 13, color: C.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Exit Without Saving', style: AppTheme.font(color: C.pink)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'submit'),
            child: const Text('Submit Claims'),
          ),
        ],
      ),
    );

    if (choice == 'submit') {
      final success = await _submitStagedClaims(
        state,
        navigateBackOnSuccess: false,
      );
      return success;
    } else if (choice == 'discard') {
      setState(() => _stagedClaims.clear());
      return true;
    }
    return false; // dialog dismissed, stay on page
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is PowerBlock) {
        block = args;
      } else {
        block = PowerBlock(id: 0, name: 'Unknown Block', powerBlockNumber: 0);
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tracker = state.currentTracker;
    final canClaimFromHere = state.user != null && state.selectedTab == 3;

    if (block.id == 0) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          backgroundColor: C.bg.withValues(alpha: 0.9),
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: C.cyan),
          title: Text('Power Block', style: AppTheme.font(size: 18, weight: FontWeight.w700)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This block could not be opened. Go back and try again.',
              textAlign: TextAlign.center,
              style: AppTheme.font(size: 14, color: C.textSub),
            ),
          ),
        ),
      );
    }

    final fresh = state.blocks.where((b) => b.id == block.id).firstOrNull;
    if (fresh != null) block = fresh;

    final completionStatus = tracker?.statusTypes.isNotEmpty == true
        ? tracker!.statusTypes.last
        : 'term';
    int completedCount = 0;
    final totalLbds = block.lbds.length;
    for (final lbd in block.lbds) {
      final isCompleted = lbd.statuses
          .where((s) => s.statusType == completionStatus && s.isCompleted)
          .isNotEmpty;
      if (isCompleted) completedCount++;
    }
    final pct = totalLbds > 0 ? completedCount / totalLbds : 0.0;

    return PopScope(
      canPop: _stagedClaims.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onBackPressed(state);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          backgroundColor: C.bg.withValues(alpha: 0.9),
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: C.cyan),
          title: Text(block.name,
              style: AppTheme.font(size: 18, weight: FontWeight.w700)),
          actions: [
            if (canClaimFromHere && _stagedClaims.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ElevatedButton.icon(
                  onPressed: () => _submitStagedClaims(state),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Submit (${_stagedClaims.length})'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: AppTheme.font(size: 12, weight: FontWeight.w700),
                  ),
                ),
              ),
            if (canClaimFromHere && block.isClaimed)
              IconButton(
                icon: const Icon(Icons.flag, color: C.pink),
                tooltip: 'Release',
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
                cacheExtent: 2000,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: block.lbds.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHeader(
                        state,
                        pct,
                        completionStatus,
                        canClaimFromHere: canClaimFromHere,
                      ),
                    );
                  }
                  return _LbdTile(lbd: block.lbds[i - 1], viewOnly: true);
                },
              ),
      ),
    );
  }

  Widget _buildHeader(
    AppState state,
    double pct,
    String completionStatus, {
    required bool canClaimFromHere,
  }) {
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
                Text('${(pct * 100).toInt()}% ${state.getStatusName(completionStatus).toLowerCase()}',
                    style: AppTheme.font(size: 12, color: C.textSub)),
                if (block.hasIfc) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/ifc', arguments: {
                      'block_id': block.id,
                      'block_name': block.name,
                      'ifc_page_number': block.ifcPageNumber,
                      'ifc_filename': block.ifcFilename,
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: C.cyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.cyan.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined, size: 16, color: C.cyan),
                          const SizedBox(width: 6),
                          Text('View IFC',
                              style: AppTheme.font(size: 12, weight: FontWeight.w700, color: C.cyan)),
                          if (block.ifcPageNumber != null) ...[
                            const SizedBox(width: 6),
                            Text('Page ${block.ifcPageNumber}',
                                style: AppTheme.font(size: 10, color: C.textSub)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (!canClaimFromHere) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Claiming and LBD selection are available only from the Claim tab.',
                    style: AppTheme.font(size: 11, color: C.textDim),
                  ),
                ],
                if (block.isClaimed) ...[
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
                      'Claimed: ${block.claimedLabel}',
                      style: AppTheme.font(
                          size: 11,
                          weight: FontWeight.w600,
                          color: C.purple),
                    ),
                  ),
                  if (block.claimAssignments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      block.claimAssignments.entries
                          .map((entry) => '${state.getStatusName(entry.key)}: ${entry.value.length}')
                          .join(' • '),
                      style: AppTheme.font(size: 11, color: C.textSub),
                    ),
                  ],
                ],
                if (canClaimFromHere) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showClaimDialog(state),
                        icon: const Icon(Icons.people_alt_rounded, size: 18),
                        label: const Text('Add Claim'),
                      ),
                      if (_stagedClaims.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _submitStagedClaims(state),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text('Submit (${_stagedClaims.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.green,
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final proceed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: C.surface,
                              title: Text('WARNING!', style: AppTheme.displayFont(size: 18, color: C.gold)),
                              content: Text(
                                'FEATURE IS IN BETA STAGE AND CAN BE INACCURATE. BE SURE TO DOUBLE CHECK CLAIMS.',
                                style: AppTheme.font(size: 14, color: C.text),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel', style: AppTheme.font(color: C.textDim)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Proceed'),
                                ),
                              ],
                            ),
                          );
                          if (proceed != true || !mounted) return;
                          final imageBytes = await Navigator.of(context).push<Uint8List>(
                            MaterialPageRoute(builder: (_) => const ScanCameraScreen()),
                          );
                          if (imageBytes != null && mounted) {
                            _showClaimDialog(state, initialScanBytes: imageBytes);
                          }
                        },
                        icon: const Icon(Icons.document_scanner_outlined, size: 18),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Scan Sheet'),
                            const SizedBox(width: 4),
                            Text('Beta', style: AppTheme.font(size: 10, weight: FontWeight.w700, color: C.gold)),
                          ],
                        ),
                      ),
                    ],
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
  final bool viewOnly;
  const _LbdTile({required this.lbd, this.viewOnly = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
                onTap: viewOnly ? null : () => state.toggleStatus(lbd.id, st, !completed),
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
