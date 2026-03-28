import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/power_block.dart';
import '../models/tracker.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// ═══════════════════════════════════════════════════════════
// ADMIN TAB — Colors, Names, Map Labels, Users
// ═══════════════════════════════════════════════════════════

class AdminTab extends StatefulWidget {
  const AdminTab({super.key});

  @override
  State<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<AdminTab> with TickerProviderStateMixin {
  TabController? _tabController;
  bool _loadsInitiated = false;

  // Colors tab
  final Map<String, String> _editColors = {};
  bool _savingColors = false;

  // Names tab
  final Map<String, TextEditingController> _nameControllers = {};
  bool _savingNames = false;

  // Map Labels tab
  List<Map<String, dynamic>> _areas = [];
  bool _loadingAreas = false;

  // Users tab
  List<dynamic> _users = [];
  final Map<int, Map<String, dynamic>> _recentPinResets = {};
  bool _loadingUsers = false;
  List<Map<String, dynamic>> _roleDefinitions = [];

  // Claim backfill tab
  List<String> _claimPeople = [];
  List<PowerBlock> _backfillBlocks = [];
  final Set<String> _backfillCrew = {};
  final TextEditingController _backfillExtraPeopleController = TextEditingController();
  int? _backfillTrackerId;
  int? _backfillBlockId;
  String _backfillDate = _todayIsoDateValue();
  bool _loadingBackfillPeople = false;
  bool _loadingBackfillBlocks = false;
  bool _savingBackfill = false;
  Map<String, List<int>> _backfillAssignments = const {};

  static const _presetColors = [
    '#FF4C6A', '#FF8C42', '#FFD700', '#00E87A', '#00D4FF',
    '#7C6CFC', '#E040FB', '#FF6B9D', '#26A69A', '#5C6BC0',
    '#42A5F5', '#66BB6A', '#FFCA28', '#EF5350', '#AB47BC',
    '#78909C', '#8D6E63', '#29B6F6', '#F06292', '#FFFFFF',
  ];

  static String _todayIsoDateValue() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    final role = state.user?.role;

    // Create tab controller lazily once we know the user role
    if (_tabController == null && role != null) {
      final isMainAdmin = role == 'admin';
      _tabController = TabController(length: isMainAdmin ? 5 : 3, vsync: this);
    }

    // Sync colors and name controllers — putIfAbsent preserves user edits
    for (final key in state.columnOrder) {
      _editColors.putIfAbsent(key, () => state.statusColors[key] ?? '#888888');
      _nameControllers.putIfAbsent(
        key,
        () => TextEditingController(text: state.getStatusName(key)),
      );
    }

    // Initiate API loads only once after user is known
    if (!_loadsInitiated && role != null) {
      _loadsInitiated = true;
      _loadAreas();
      if (role == 'admin') {
        _loadUsers();
        _loadClaimPeople();
      }
    }

    if (role == 'admin') {
      _ensureBackfillTracker(state);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    _backfillExtraPeopleController.dispose();
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────

  Future<void> _loadAreas() async {
    setState(() => _loadingAreas = true);
    try {
      final maps = await context.read<AppState>().api.getSiteMaps();
      final allAreas = <Map<String, dynamic>>[];
      for (final m in maps) {
        final areas = (m['areas'] as List?) ?? [];
        for (final a in areas) {
          if ((a as Map)['bbox_x'] != null) {
            allAreas.add(Map<String, dynamic>.from(a));
          }
        }
      }
      if (mounted) setState(() { _areas = allAreas; _loadingAreas = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final api = context.read<AppState>().api;
      final results = await Future.wait<dynamic>([
        api.getUsersPayload(),
        api.getAuditLogs(limit: 250),
      ]);
      final usersPayload = Map<String, dynamic>.from(results[0] as Map);
      final users = (usersPayload['users'] as List?) ?? const <dynamic>[];
      final roleDefinitions = (usersPayload['roles'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry.cast<String, dynamic>()))
          .toList();
      final auditItems = results[1] as List<dynamic>;
      final recentPinResets = <int, Map<String, dynamic>>{};
      for (final entry in auditItems) {
        if (entry is! Map) continue;
        final action = entry['action']?.toString();
        final targetId = int.tryParse(entry['target_id']?.toString() ?? '');
        if (action != 'user.pin.reset' || targetId == null || recentPinResets.containsKey(targetId)) {
          continue;
        }
        recentPinResets[targetId] = Map<String, dynamic>.from(entry.cast<String, dynamic>());
      }
      if (mounted) {
        setState(() {
          _users = users;
          _roleDefinitions = roleDefinitions;
          _recentPinResets
            ..clear()
            ..addAll(recentPinResets);
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadClaimPeople() async {
    setState(() => _loadingBackfillPeople = true);
    try {
      final people = await context.read<AppState>().api.getClaimPeople();
      if (!mounted) return;
      setState(() {
        _claimPeople = people;
        _loadingBackfillPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBackfillPeople = false);
    }
  }

  // ── Save actions ─────────────────────────────────────

  Future<void> _saveColors() async {
    setState(() => _savingColors = true);
    final state = context.read<AppState>();
    final names = {for (final e in _nameControllers.entries) e.key: e.value.text};
    final ok = await state.api.saveSettings({
      'tracker_id': state.currentTracker?.id,
      'colors': _editColors,
      'names': names,
    });
    if (ok && mounted) {
      await state.reloadSettings();
      _showSnack('Colors saved!');
    }
    if (mounted) setState(() => _savingColors = false);
  }

  Future<void> _saveNames() async {
    setState(() => _savingNames = true);
    final state = context.read<AppState>();
    final names = {for (final e in _nameControllers.entries) e.key: e.value.text};
    final ok = await state.api.saveSettings({
      'tracker_id': state.currentTracker?.id,
      'names': names,
      'colors': state.statusColors,
    });
    if (ok && mounted) {
      await state.reloadSettings();
      _showSnack('Names saved!');
    }
    if (mounted) setState(() => _savingNames = false);
  }

  Future<void> _updateLabelColor(int areaId, String hexColor) async {
    await context.read<AppState>().api.updateSiteArea(areaId, {'label_color': hexColor});
    if (!mounted) return;
    setState(() {
      final idx = _areas.indexWhere((a) => a['id'] == areaId);
      if (idx >= 0) _areas[idx] = {..._areas[idx], 'label_color': hexColor};
    });
  }

  Future<void> _updateZone(int areaId, String? zone) async {
    await context.read<AppState>().api.updateSiteArea(areaId, {'zone': zone ?? ''});
    if (!mounted) return;
    setState(() {
      final idx = _areas.indexWhere((a) => a['id'] == areaId);
      if (idx >= 0) _areas[idx] = {..._areas[idx], 'zone': zone};
    });
  }

  Future<void> _deleteArea(int areaId) async {
    final ok = await context.read<AppState>().api.deleteSiteArea(areaId);
    if (ok && mounted) {
      setState(() => _areas.removeWhere((a) => a['id'] == areaId));
      _showSnack('Label removed');
    }
  }

  Future<void> _setUserRole(int userId, String role) async {
    await context.read<AppState>().api.updateUserRole(
      userId,
      role,
    );
    if (!mounted) return;
    _showSnack('Role updated');
    await _loadUsers();
  }

  void _ensureBackfillTracker(AppState state) {
    final trackers = state.trackers.where((tracker) => tracker.isActive).toList();
    if (trackers.isEmpty) {
      return;
    }
    final hasCurrent = trackers.any((tracker) => tracker.id == _backfillTrackerId);
    final nextTrackerId = hasCurrent
        ? _backfillTrackerId
        : (state.currentTracker?.id ?? trackers.first.id);
    if (nextTrackerId == null || nextTrackerId == _backfillTrackerId) {
      return;
    }
    _backfillTrackerId = nextTrackerId;
    _loadBackfillBlocks(nextTrackerId);
  }

  Future<void> _loadBackfillBlocks(int trackerId) async {
    setState(() {
      _loadingBackfillBlocks = true;
      _backfillBlockId = null;
      _backfillAssignments = const {};
    });
    try {
      final blocks = await context.read<AppState>().api.getPowerBlocks(trackerId);
      blocks.sort((left, right) => left.powerBlockNumber.compareTo(right.powerBlockNumber));
      if (!mounted) return;
      setState(() {
        _backfillBlocks = blocks;
        _loadingBackfillBlocks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _backfillBlocks = [];
        _loadingBackfillBlocks = false;
      });
    }
  }

  Tracker? _selectedBackfillTracker(AppState state) {
    for (final tracker in state.trackers) {
      if (tracker.id == _backfillTrackerId) {
        return tracker;
      }
    }
    return null;
  }

  PowerBlock? _selectedBackfillBlock() {
    for (final block in _backfillBlocks) {
      if (block.id == _backfillBlockId) {
        return block;
      }
    }
    return null;
  }

  String _roleLabel(String role) {
    for (final roleDefinition in _roleDefinitions) {
      if (roleDefinition['key']?.toString() == role) {
        return roleDefinition['label']?.toString() ?? role;
      }
    }
    switch (role) {
      case 'assistant_admin':
        return 'Asst. Admin';
      case 'user':
        return 'Worker';
      default:
        return role.replaceAll('_', ' ');
    }
  }

  String _statusName(Tracker? tracker, String statusType) {
    return tracker?.statusNames[statusType] ?? statusType;
  }

  Color _statusColor(Tracker? tracker, String statusType) {
    return _hexColor(tracker?.statusColors[statusType] ?? '#00D4FF');
  }

  String _lbdLabel(LbdItem lbd) {
    final identifier = lbd.identifier?.trim();
    if (identifier != null && identifier.isNotEmpty) return identifier;
    final name = lbd.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'LBD ${lbd.id}';
  }

  String _formatIsoDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${monthNames[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  List<String> _resolvedBackfillPeople() {
    final merged = <String>[];
    final seen = <String>{};
    final extras = _backfillExtraPeopleController.text
        .split(RegExp(r'[\n,]'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty);
    for (final name in [..._backfillCrew, ...extras]) {
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      merged.add(name);
    }
    return merged;
  }

  Future<void> _pickBackfillDate() async {
    final initialDate = DateTime.tryParse(_backfillDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    setState(() => _backfillDate = '${picked.year}-$month-$day');
  }

  void _toggleBackfillLbd(String statusType, int lbdId, bool isSelected) {
    final updated = Map<String, List<int>>.from(_backfillAssignments);
    final currentIds = List<int>.from(updated[statusType] ?? const <int>[]);
    if (isSelected) {
      if (!currentIds.contains(lbdId)) {
        currentIds.add(lbdId);
      }
      currentIds.sort();
      updated[statusType] = currentIds;
    } else {
      currentIds.remove(lbdId);
      if (currentIds.isEmpty) {
        updated.remove(statusType);
      } else {
        updated[statusType] = currentIds;
      }
    }
    setState(() => _backfillAssignments = updated);
  }

  void _replaceBackfillTaskSelection(String statusType, List<int> ids) {
    final updated = Map<String, List<int>>.from(_backfillAssignments);
    if (ids.isEmpty) {
      updated.remove(statusType);
    } else {
      updated[statusType] = [...ids]..sort();
    }
    setState(() => _backfillAssignments = updated);
  }

  Future<void> _submitBackfill(AppState state) async {
    final tracker = _selectedBackfillTracker(state);
    final block = _selectedBackfillBlock();
    final people = _resolvedBackfillPeople();
    if (tracker == null) {
      _showSnack('Choose a tracker first.');
      return;
    }
    if (block == null) {
      _showSnack('Choose a power block first.');
      return;
    }
    if (people.isEmpty) {
      _showSnack('Select at least one crew member.');
      return;
    }
    if (_backfillAssignments.isEmpty) {
      _showSnack('Select at least one task and LBD.');
      return;
    }

    setState(() => _savingBackfill = true);
    try {
      await state.api.backfillClaimActivity(
        blockId: block.id,
        trackerId: tracker.id,
        people: people,
        assignments: _backfillAssignments,
        workDate: _backfillDate,
        claimedBy: state.user?.name,
      );
      if (!mounted) return;
      setState(() {
        _backfillBlockId = null;
        _backfillAssignments = const {};
        _backfillCrew.clear();
        _backfillExtraPeopleController.clear();
      });
      _showSnack('Claim activity backfilled for ${block.name} on ${_formatIsoDate(_backfillDate)}');
    } on Exception catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _savingBackfill = false);
      }
    }
  }

  Future<void> _resetUserPin(int userId, String name) async {
    final pinCtrl = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: C.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x18FFFFFF)),
          ),
          title: Text('Reset PIN', style: AppTheme.font(size: 16, weight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set a new 4-digit PIN for $name.', style: AppTheme.font(size: 13, color: C.textSub)),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                style: AppTheme.font(size: 14),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New PIN',
                  labelStyle: AppTheme.font(size: 13, color: C.textDim),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0x10FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: C.cyan.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: AppTheme.font(size: 12, color: C.pink)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppTheme.font(color: C.textDim)),
            ),
            TextButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                if (pin.length != 4 || int.tryParse(pin) == null) {
                  setDialogState(() => errorText = 'PIN must be 4 digits');
                  return;
                }
                final ok = await context.read<AppState>().api.resetUserPin(userId, pin);
                if (!ok) {
                  setDialogState(() => errorText = 'Could not reset PIN');
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('PIN updated for "$name"');
              },
              child: Text('SAVE', style: AppTheme.font(color: C.cyan, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog() {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final jobTokenCtrl = TextEditingController();
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: C.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x18FFFFFF)),
          ),
          title: Text('Create User',
              style: AppTheme.font(size: 16, weight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: AppTheme.font(size: 14),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: AppTheme.font(size: 13, color: C.textDim),
                  filled: true,
                  fillColor: const Color(0x10FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: C.cyan.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                style: AppTheme.font(size: 14),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '4-digit PIN',
                  labelStyle: AppTheme.font(size: 13, color: C.textDim),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0x10FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: C.cyan.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jobTokenCtrl,
                style: AppTheme.font(size: 14),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Job Site Token',
                  labelStyle: AppTheme.font(size: 13, color: C.textDim),
                  filled: true,
                  fillColor: const Color(0x10FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: C.cyan.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: AppTheme.font(size: 12, color: C.pink)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppTheme.font(color: C.textDim)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                final jobToken = jobTokenCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Name is required');
                  return;
                }
                if (pin.length != 4 || int.tryParse(pin) == null) {
                  setDialogState(() => errorText = 'PIN must be 4 digits');
                  return;
                }
                if (jobToken.isEmpty) {
                  setDialogState(() => errorText = 'Job site token is required');
                  return;
                }
                try {
                  final result = await context.read<AppState>().api.adminCreateUser(
                    name,
                    pin,
                    jobToken: jobToken,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack(result['message']?.toString() ?? 'User "$name" created.');
                  await _loadUsers();
                } on Exception catch (e) {
                  setDialogState(() => errorText = e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: Text('CREATE',
                  style: AppTheme.font(color: C.cyan, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppTheme.font(size: 14)),
      backgroundColor: C.surface,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatPinResetLabel(Map<String, dynamic>? entry) {
    if (entry == null) return 'No PIN reset recorded yet';
    final createdAtRaw = entry['created_at']?.toString();
    final actorName = entry['actor_name']?.toString() ?? 'Admin';
    final createdAt = createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw)?.toLocal();
    if (createdAt == null) return 'Last PIN reset by $actorName';
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = monthNames[createdAt.month - 1];
    final day = createdAt.day;
    final year = createdAt.year;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final hour24 = createdAt.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = ((hour24 + 11) % 12) + 1;
    return 'Last PIN reset $month $day, $year at $hour12:$minute $period by $actorName';
  }

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      final full = h.length == 6 ? 'FF$h' : h;
      return Color(int.parse(full, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Future<String?> _pickColor(String current) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x18FFFFFF)),
        ),
        title: Text('Pick Color',
            style: AppTheme.font(size: 16, weight: FontWeight.w700)),
        content: SizedBox(
          width: 240,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetColors.map((hex) {
              final color = _hexColor(hex);
              final isSelected =
                  hex.toLowerCase() == current.toLowerCase();
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected ? Colors.white : Colors.transparent,
                      width: isSelected ? 3 : 0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8)
                          ]
                        : [],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTheme.font(color: C.textDim)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role = state.user?.role;

    if (role != 'admin' && role != 'assistant_admin') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, color: C.textDim, size: 64),
            const SizedBox(height: 16),
            Text('Admin access required',
                style: AppTheme.font(size: 16, color: C.textDim)),
          ],
        ),
      );
    }

    if (_tabController == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildTabBar(role == 'admin'),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildColorsTab(state),
              _buildNamesTab(state),
              _buildMapLabelsTab(),
              if (role == 'admin') _buildUsersTab(),
              if (role == 'admin') _buildBackfillTab(state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isMainAdmin) {
    return Container(
      color: C.surface.withValues(alpha: 0.8),
      child: TabBar(
        controller: _tabController,
        labelStyle: AppTheme.font(size: 12, weight: FontWeight.w700),
        unselectedLabelStyle: AppTheme.font(size: 12),
        labelColor: C.cyan,
        unselectedLabelColor: C.textDim,
        indicatorColor: C.cyan,
        indicatorWeight: 2,
        tabs: [
          const Tab(text: 'Colors'),
          const Tab(text: 'Names'),
          const Tab(text: 'Map Labels'),
          if (isMainAdmin) const Tab(text: 'Users'),
          if (isMainAdmin) const Tab(text: 'Claims'),
        ],
      ),
    );
  }

  // ── Claim Backfill Tab ───────────────────────────────

  Widget _buildBackfillTab(AppState state) {
    final tracker = _selectedBackfillTracker(state);
    final block = _selectedBackfillBlock();
    final liveAssignments = block?.visibleClaimAssignments ?? const <String, List<int>>{};
    final activeTrackers = state.trackers.where((entry) => entry.isActive).toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: C.cyan,
            onRefresh: () async {
              await _loadClaimPeople();
              if (_backfillTrackerId != null) {
                await _loadBackfillBlocks(_backfillTrackerId!);
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            glowColor: C.gold,
            glowBlur: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historical Claim Backfill',
                    style: AppTheme.font(size: 16, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Use this only for older claims that need to appear in past-day reports without changing the live claim state on the tracker.',
                  style: AppTheme.font(size: 12, color: C.textSub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tracker', style: AppTheme.font(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _backfillTrackerId,
                  isExpanded: true,
                  dropdownColor: C.surface,
                  style: AppTheme.font(size: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0x10FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                    ),
                  ),
                  items: activeTrackers
                      .map((entry) => DropdownMenuItem<int>(
                            value: entry.id,
                            child: Text(entry.displayName, style: AppTheme.font(size: 13)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _backfillTrackerId = value;
                      _backfillBlockId = null;
                      _backfillAssignments = const {};
                    });
                    _loadBackfillBlocks(value);
                  },
                ),
                const SizedBox(height: 14),
                Text('Claim Date', style: AppTheme.font(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickBackfillDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_formatIsoDate(_backfillDate), style: AppTheme.font(size: 13)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Power Block', style: AppTheme.font(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (_loadingBackfillBlocks)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2)),
                  )
                else if (_backfillBlocks.isEmpty)
                  Text('No blocks loaded for this tracker yet.',
                      style: AppTheme.font(size: 12, color: C.textDim))
                else
                  DropdownButtonFormField<int>(
                    value: _backfillBlockId,
                    isExpanded: true,
                    dropdownColor: C.surface,
                    style: AppTheme.font(size: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0x10FFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                      ),
                    ),
                    items: _backfillBlocks
                        .map((entry) => DropdownMenuItem<int>(
                              value: entry.id,
                              child: Text(
                                '#${entry.powerBlockNumber} • ${entry.name}',
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.font(size: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _backfillBlockId = value;
                        _backfillAssignments = const {};
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crew', style: AppTheme.font(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (_loadingBackfillPeople)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2)),
                  )
                else if (_claimPeople.isEmpty)
                  Text('No saved crew names yet. Add names below.',
                      style: AppTheme.font(size: 12, color: C.textDim))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _claimPeople.map((name) {
                      final isSelected = _backfillCrew.contains(name);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(name, style: AppTheme.font(size: 12)),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _backfillCrew.add(name);
                            } else {
                              _backfillCrew.remove(name);
                            }
                          });
                        },
                        selectedColor: C.cyan.withValues(alpha: 0.18),
                        backgroundColor: const Color(0x0AFFFFFF),
                        checkmarkColor: C.cyan,
                        side: BorderSide(
                          color: isSelected ? C.cyan : const Color(0x18FFFFFF),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _backfillExtraPeopleController,
                  minLines: 2,
                  maxLines: 4,
                  style: AppTheme.font(size: 13),
                  decoration: InputDecoration(
                    labelText: 'Extra names',
                    hintText: 'Comma or new-line separated',
                    labelStyle: AppTheme.font(size: 12, color: C.textSub),
                    hintStyle: AppTheme.font(size: 12, color: C.textDim),
                    filled: true,
                    fillColor: const Color(0x10FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x18FFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assignments', style: AppTheme.font(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (tracker == null)
                  Text('Choose a tracker to start assigning work.',
                      style: AppTheme.font(size: 12, color: C.textDim))
                else if (block == null)
                  Text('Choose a power block to select tasks and LBDs.',
                      style: AppTheme.font(size: 12, color: C.textDim))
                else ...[
                  if (block.isClaimed) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.gold.withValues(alpha: 0.24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Live Claim',
                            style: AppTheme.font(size: 12, weight: FontWeight.w700, color: C.gold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            block.claimedLabel != null && block.claimedLabel!.trim().isNotEmpty
                                ? 'Crew: ${block.claimedLabel}'
                                : 'This block already has live claim assignments.',
                            style: AppTheme.font(size: 12, color: C.text),
                          ),
                          if (liveAssignments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...liveAssignments.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${_statusName(tracker, entry.key)}: ${entry.value.length} already claimed',
                                style: AppTheme.font(size: 11, color: C.textSub),
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ],
                  Text(
                    '${block.name} • ${block.lbdCount} ${tracker.itemNamePlural.toLowerCase()}',
                    style: AppTheme.font(size: 12, color: C.textSub),
                  ),
                  const SizedBox(height: 12),
                  ...tracker.statusTypes.map((statusType) {
                    final selectedIds = _backfillAssignments[statusType] ?? const <int>[];
                    final liveClaimedIds = Set<int>.from(liveAssignments[statusType] ?? const <int>[]);
                    final availableIds = block.lbds
                        .map((entry) => entry.id)
                        .where((id) => !liveClaimedIds.contains(id) || selectedIds.contains(id))
                        .toList();
                    final taskColor = _statusColor(tracker, statusType);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: taskColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: taskColor.withValues(alpha: 0.22)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _statusName(tracker, statusType),
                                  style: AppTheme.font(size: 13, weight: FontWeight.w700, color: taskColor),
                                ),
                              ),
                              Text(
                                liveClaimedIds.isEmpty
                                    ? '${selectedIds.length} selected'
                                    : '${selectedIds.length} selected • ${liveClaimedIds.length} already claimed',
                                style: AppTheme.font(size: 11, weight: FontWeight.w700, color: taskColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: availableIds.isEmpty
                                    ? null
                                    : () => _replaceBackfillTaskSelection(
                                          statusType,
                                          availableIds,
                                        ),
                                icon: const Icon(Icons.select_all_rounded, size: 16),
                                label: const Text('Select All'),
                              ),
                              TextButton.icon(
                                onPressed: selectedIds.isEmpty
                                    ? null
                                    : () => _replaceBackfillTaskSelection(statusType, const []),
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                label: const Text('Clear'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: block.lbds.length,
                              itemBuilder: (context, index) {
                                final lbd = block.lbds[index];
                                final isSelected = selectedIds.contains(lbd.id);
                                final isLiveClaimed = liveClaimedIds.contains(lbd.id);
                                final isUnavailable = isLiveClaimed && !isSelected;
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: taskColor,
                                  value: isSelected,
                                  title: Text(
                                    _lbdLabel(lbd),
                                    style: AppTheme.font(size: 12, color: isUnavailable ? C.textDim : C.text),
                                  ),
                                  subtitle: (() {
                                    final parts = <String>[];
                                    if ((lbd.name ?? '').trim().isNotEmpty && (lbd.name ?? '').trim() != _lbdLabel(lbd)) {
                                      parts.add(lbd.name!.trim());
                                    }
                                    if (isLiveClaimed) {
                                      parts.add('Already claimed');
                                    }
                                    if (parts.isEmpty) return null;
                                    return Text(
                                      parts.join(' • '),
                                      style: AppTheme.font(
                                        size: 11,
                                        color: isLiveClaimed ? C.gold : C.textDim,
                                      ),
                                    );
                                  })(),
                                  onChanged: isUnavailable
                                      ? null
                                      : (value) => _toggleBackfillLbd(statusType, lbd.id, value ?? false),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                glowColor: C.cyan,
                glowBlur: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block == null
                          ? 'Choose a tracker and power block, then save the historical claim here.'
                          : 'Ready to save ${block.name} for ${_formatIsoDate(_backfillDate)}.',
                      style: AppTheme.font(size: 12, color: C.textSub),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: NeonButton(
                        label: 'SAVE HISTORICAL CLAIM',
                        icon: Icons.history_toggle_off_rounded,
                        loading: _savingBackfill,
                        onPressed: _savingBackfill ? null : () => _submitBackfill(state),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Colors Tab ───────────────────────────────────────

  Widget _buildColorsTab(AppState state) {
    final columns = state.columnOrder;
    if (columns.isEmpty) {
      return Center(
          child: Text('No columns configured',
              style: AppTheme.font(color: C.textDim)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...columns.map((key) {
          final hexColor = _editColors[key] ?? '#888888';
          final color = _hexColor(hexColor);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.getStatusName(key),
                      style:
                          AppTheme.font(size: 14, weight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickColor(hexColor);
                      if (picked != null) {
                        setState(() => _editColors[key] = picked);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(hexColor,
                            style:
                                AppTheme.font(size: 12, color: C.textSub)),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_rounded,
                            size: 14, color: C.textDim),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: NeonButton(
            label: 'SAVE COLORS',
            icon: Icons.palette_rounded,
            loading: _savingColors,
            onPressed: _savingColors ? null : _saveColors,
          ),
        ),
      ],
    );
  }

  // ── Names Tab ────────────────────────────────────────

  Widget _buildNamesTab(AppState state) {
    final columns = state.columnOrder;
    if (columns.isEmpty) {
      return Center(
          child: Text('No columns configured',
              style: AppTheme.font(color: C.textDim)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...columns.map((key) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(key,
                        style: AppTheme.font(size: 12, color: C.textDim)),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameControllers[key],
                      style: AppTheme.font(size: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: const Color(0x10FFFFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0x18FFFFFF)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0x18FFFFFF)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: C.cyan.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: NeonButton(
            label: 'SAVE NAMES',
            icon: Icons.drive_file_rename_outline_rounded,
            loading: _savingNames,
            onPressed: _savingNames ? null : _saveNames,
          ),
        ),
      ],
    );
  }

  // ── Map Labels Tab ───────────────────────────────────

  Widget _buildMapLabelsTab() {
    if (_loadingAreas) {
      return const Center(
          child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2));
    }
    if (_areas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: C.textDim, size: 48),
            const SizedBox(height: 12),
            Text('No map labels placed yet',
                style: AppTheme.font(color: C.textDim)),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: NeonButton(
                label: 'REFRESH',
                icon: Icons.refresh_rounded,
                onPressed: _loadAreas,
                height: 40,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: C.cyan,
      onRefresh: _loadAreas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _areas.length,
        itemBuilder: (context, i) {
          final area = _areas[i];
          final id = area['id'] as int? ?? 0;
          final name = area['name']?.toString() ?? 'Area $id';
          final labelColor = area['label_color']?.toString() ?? '#FFFFFF';
          final color = _hexColor(labelColor);
          final currentZone = area['zone']?.toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name,
                            style: AppTheme.font(
                                size: 14, weight: FontWeight.w600)),
                      ),
                      // Color picker swatch
                      GestureDetector(
                        onTap: () async {
                          final picked = await _pickColor(labelColor);
                          if (picked != null) await _updateLabelColor(id, picked);
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0x40FFFFFF), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                      // Delete button
                      GestureDetector(
                        onTap: () => _confirmDelete(id, name),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline_rounded,
                              color: C.pink, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Zone assignment row
                  Row(
                    children: [
                      Icon(Icons.layers_rounded, size: 14, color: C.textDim),
                      const SizedBox(width: 6),
                      Text('Zone:',
                          style: AppTheme.font(size: 12, color: C.textDim)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _zoneChip(null, currentZone, id),
                              for (int z = 1; z <= 6; z++)
                                _zoneChip('Zone $z', currentZone, id),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _zoneChip(String? zone, String? currentZone, int areaId) {
    final label = zone ?? 'None';
    final active = zone == currentZone;
    return GestureDetector(
      onTap: () => _updateZone(areaId, zone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? C.cyan.withValues(alpha: 0.2) : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? C.cyan : const Color(0x18FFFFFF),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.font(
            size: 11,
            color: active ? C.cyan : C.textDim,
            weight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(int areaId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x18FFFFFF)),
        ),
        title: Text('Remove Label?',
            style: AppTheme.font(size: 16, weight: FontWeight.w700)),
        content: Text(
          'Remove "$name" from the map?',
          style: AppTheme.font(size: 14, color: C.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTheme.font(color: C.textDim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteArea(areaId);
            },
            child: Text('Remove',
                style: AppTheme.font(color: C.pink, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Users Tab ────────────────────────────────────────

  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return const Center(
          child: CircularProgressIndicator(color: C.cyan, strokeWidth: 2));
    }
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, color: C.textDim, size: 48),
            const SizedBox(height: 12),
            Text('No users found',
                style: AppTheme.font(color: C.textDim)),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: NeonButton(
                label: 'REFRESH',
                icon: Icons.refresh_rounded,
                onPressed: _loadUsers,
                height: 40,
              ),
            ),
          ],
        ),
      );
    }

    final roleOptions = _roleDefinitions
        .map((entry) => entry['key']?.toString() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();

    return Stack(
      children: [
        RefreshIndicator(
          color: C.cyan,
          onRefresh: _loadUsers,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (context, i) {
              final user = _users[i] as Map;
              final userId = user['id'] as int? ?? 0;
              final name = user['name']?.toString() ?? 'User $userId';
              final currentRole = user['role']?.toString() ?? 'user';
              final isMainAdmin = user['username']?.toString() == 'admin';
                final safeRole = roleOptions.contains(currentRole) ? currentRole : null;
              final pinResetLabel = _formatPinResetLabel(_recentPinResets[userId]);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: C.purple.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: C.purple.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: AppTheme.font(
                                    size: 16,
                                    weight: FontWeight.w700,
                                    color: C.purple),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: AppTheme.font(
                                        size: 14, weight: FontWeight.w600)),
                                Text(
                                  _roleLabel(currentRole),
                                  style: AppTheme.font(size: 11, color: C.textDim),
                                ),
                              ],
                            ),
                          ),
                          if (!isMainAdmin && roleOptions.isNotEmpty)
                            DropdownButton<String>(
                              value: safeRole,
                              dropdownColor: C.surface,
                              style: AppTheme.font(size: 12),
                              underline: const SizedBox.shrink(),
                              icon: Icon(Icons.expand_more_rounded,
                                  color: C.cyan.withValues(alpha: 0.7), size: 18),
                              items: roleOptions
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                    child: Text(_roleLabel(r),
                                            style: AppTheme.font(size: 12)),
                                      ))
                                  .toList(),
                              onChanged: (r) {
                                if (r != null && r != currentRole) {
                                  _setUserRole(userId, r);
                                }
                              },
                            ),
                        ],
                      ),
                      if (!isMainAdmin) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            pinResetLabel,
                            style: AppTheme.font(size: 11, color: C.textDim),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Forgot PIN? Reset it here and tell them the new one.',
                                style: AppTheme.font(size: 11, color: C.textDim),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 38,
                              child: NeonButton(
                                label: 'RESET PIN',
                                icon: Icons.lock_reset_rounded,
                                onPressed: () => _resetUserPin(userId, name),
                                height: 38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Floating add user button
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: _showCreateUserDialog,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: C.cyan.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: C.cyan, width: 1.5),
                boxShadow: [
                  BoxShadow(color: C.cyan.withValues(alpha: 0.3), blurRadius: 12),
                ],
              ),
              child: const Icon(Icons.person_add_rounded, color: C.cyan, size: 24),
            ),
          ),
        ),
      ],
    );
  }
}
