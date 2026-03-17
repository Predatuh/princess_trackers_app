import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/tracker.dart';
import '../models/power_block.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/realtime_sync_service.dart';

class AppState extends ChangeNotifier {
  static const Set<String> _retiredStatusTypes = {'quality_check', 'quality_docs'};

  final ApiService api = ApiService();
  late final RealtimeSyncService _realtime;

  // Auth
  User? user;
  bool isLoading = false;
  String? error;

  // Trackers
  List<Tracker> trackers = [];
  Tracker? currentTracker;
  int selectedTab = 0;

  // Settings (status colors / names from current tracker)
  Map<String, String> statusColors = {};
  Map<String, String> statusNames = {};
  List<String> columnOrder = [];

  // Power blocks for current tracker
  List<PowerBlock> blocks = [];

  // All tracker block data (for dashboard hub)
  Map<int, List<PowerBlock>> allTrackerBlocks = {};
  Map<int, Map<String, dynamic>> allTrackerSettings = {};

  // Workers
  List<Worker> workers = [];

  // Offline state
  bool isOffline = false;
  final List<Map<String, dynamic>> _pendingQueue = [];
  late final Stream<List<ConnectivityResult>> _connectivityStream;

  AppState() {
    _realtime = RealtimeSyncService(baseUrl: ApiService.baseUrl);
    _connectivityStream = Connectivity().onConnectivityChanged;
    _connectivityStream.listen(_onConnectivityChanged);
    _checkConnectivity();
  }

  @override
  void dispose() {
    _realtime.disconnect();
    super.dispose();
  }

  void _connectRealtimeIfReady() {
    if (user == null) return;
    _realtime.connect(
      onBlocksChanged: () {
        if (currentTracker != null && !isOffline) {
          loadBlocks();
        }
      },
      onHubChanged: () {
        if (trackers.isNotEmpty && !isOffline && allTrackerBlocks.isNotEmpty) {
          loadAllTrackerData();
        }
      },
    );
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _onConnectivityChanged(result);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOffline = isOffline;
    isOffline = results.every((r) => r == ConnectivityResult.none);
    if (wasOffline && !isOffline) {
      _flushPendingQueue();
    }
    notifyListeners();
  }

  Future<void> _flushPendingQueue() async {
    if (_pendingQueue.isEmpty) return;
    final toProcess = List<Map<String, dynamic>>.from(_pendingQueue);
    _pendingQueue.clear();
    await _savePendingQueue();
    for (final item in toProcess) {
      try {
        final type = item['type'] as String? ?? 'status';
        if (type == 'claim') {
          await api.claimBlock(
            item['blockId'] as int,
            claim: item['claim'] as bool? ?? true,
            people: List<String>.from(item['people'] ?? const []),
            assignments: Map<String, List<int>>.from(
              (item['assignments'] as Map? ?? const {}).map(
                (key, value) => MapEntry(
                  key.toString(),
                  List<int>.from(value as List? ?? const []),
                ),
              ),
            ),
          );
        } else {
          await api.updateLbdStatus(
            item['lbdId'] as int,
            item['statusType'] as String,
            item['value'] as bool,
          );
        }
      } catch (_) {
        // Re-queue on failure
        _pendingQueue.add(item);
      }
    }
    if (_pendingQueue.isNotEmpty) await _savePendingQueue();
    // Refresh blocks after syncing
    if (_pendingQueue.isEmpty && currentTracker != null) loadBlocks();
  }

  Future<void> _savePendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_queue', jsonEncode(_pendingQueue));
  }

  Future<void> _loadPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pending_queue');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _pendingQueue.addAll(list.cast<Map<String, dynamic>>());
    }
  }

  String _cacheKey(int trackerId) => 'blocks_cache_$trackerId';

  Future<void> _persistSelectedTracker(int trackerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentTrackerId', trackerId);
  }

  List<String> _filterStatusKeys(Iterable<dynamic> keys) {
    return keys
        .map((entry) => entry.toString())
        .where((entry) => !_retiredStatusTypes.contains(entry))
        .toList();
  }

  Map<String, String> _filterStatusMap(Map<dynamic, dynamic> values) {
    final filtered = <String, String>{};
    values.forEach((key, value) {
      final normalizedKey = key.toString();
      if (_retiredStatusTypes.contains(normalizedKey)) {
        return;
      }
      filtered[normalizedKey] = value.toString();
    });
    return filtered;
  }

  void _syncCurrentTrackerBlocks() {
    final trackerId = currentTracker?.id;
    if (trackerId == null) return;
    allTrackerBlocks[trackerId] = List<PowerBlock>.from(blocks);
  }

  ({bool hadStatus, bool previousValue}) _applyLocalLbdStatus(
    int lbdId,
    String statusType,
    bool value,
  ) {
    var hadStatus = false;
    var previousValue = false;

    for (final block in blocks) {
      var touchedBlock = false;
      for (final lbd in block.lbds) {
        if (lbd.id != lbdId) {
          continue;
        }
        touchedBlock = true;
        final existingStatus = lbd.statuses
            .where((status) => status.statusType == statusType)
            .firstOrNull;
        if (existingStatus != null) {
          hadStatus = true;
          previousValue = existingStatus.isCompleted;
          existingStatus.isCompleted = value;
        } else {
          lbd.statuses.add(
            LbdStatus(statusType: statusType, isCompleted: value),
          );
        }
        break;
      }

      if (!touchedBlock) {
        continue;
      }

      block.lbdSummary[statusType] = block.lbds.where((lbd) {
        return lbd.statuses.any(
          (status) => status.statusType == statusType && status.isCompleted,
        );
      }).length;
      break;
    }

    _syncCurrentTrackerBlocks();
    return (hadStatus: hadStatus, previousValue: previousValue);
  }

  void _markAssignmentsCompleted(int blockId, Map<String, List<int>> assignments) {
    if (assignments.isEmpty) return;

    blocks = blocks.map((block) {
      if (block.id != blockId) return block;

      final updatedSummary = Map<String, int>.from(block.lbdSummary);
      assignments.forEach((statusType, lbdIds) {
        final selectedIds = Set<int>.from(lbdIds);
        if (selectedIds.isEmpty) {
          return;
        }
        for (final lbd in block.lbds) {
          if (!selectedIds.contains(lbd.id)) {
            continue;
          }
          final existingStatus = lbd.statuses
              .where((status) => status.statusType == statusType)
              .firstOrNull;
          if (existingStatus != null) {
            existingStatus.isCompleted = true;
          } else {
            lbd.statuses.add(LbdStatus(statusType: statusType, isCompleted: true));
          }
        }
        updatedSummary[statusType] = block.lbds.where((lbd) {
          return lbd.statuses.any(
            (status) => status.statusType == statusType && status.isCompleted,
          );
        }).length;
      });

      return block.copyWith(lbdSummary: updatedSummary, lbds: block.lbds);
    }).toList();

    _syncCurrentTrackerBlocks();
  }

  void _applyTrackerContext(Tracker tracker, {bool useHubCache = true}) {
    final previousTrackerId = currentTracker?.id;
    currentTracker = tracker;

    final cachedSettings = allTrackerSettings[tracker.id] ?? const <String, dynamic>{};
    statusColors = _filterStatusMap(cachedSettings['colors'] ?? tracker.statusColors);
    statusNames = _filterStatusMap(cachedSettings['names'] ?? tracker.statusNames);
    columnOrder = _filterStatusKeys(cachedSettings['all_columns'] ?? tracker.statusTypes);

    if (!useHubCache) return;

    final hubBlocks = allTrackerBlocks[tracker.id];
    if (hubBlocks != null) {
      blocks = List<PowerBlock>.from(hubBlocks);
    } else if (previousTrackerId != tracker.id) {
      blocks = const [];
    }
  }

  Future<void> _cacheBlocks(int trackerId, List<PowerBlock> blockList) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(blockList.map((b) => {
      'id': b.id,
      'name': b.name,
      'power_block_number': b.powerBlockNumber,
      'lbd_count': b.lbdCount,
      'lbd_summary': b.lbdSummary,
      'claimed_by': b.claimedBy,
      'claimed_people': b.claimedPeople,
      'claim_assignments': b.claimAssignments,
      'claimed_at': b.claimedAt,
      'zone': b.zone,
      'lbds': b.lbds.map((l) => {
        'id': l.id,
        'name': l.name,
        'identifier': l.identifier,
        'inventory_number': l.inventoryNumber,
        'statuses': l.statuses.map((s) => {
          'status_type': s.statusType,
          'is_completed': s.isCompleted,
        }).toList(),
      }).toList(),
    }).toList());
    await prefs.setString(_cacheKey(trackerId), encoded);
  }

  Future<List<PowerBlock>> _loadCachedBlocks(int trackerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(trackerId));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((j) => PowerBlock.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Auth ──────────────────────────────────────────────

  Future<AuthFlowResult> login(String name, String pin) async {
    isLoading = true;
    error = null;
    notifyListeners();
    AuthFlowResult result;
    try {
      result = await api.login(name, pin);
      user = result.user;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastUser', name);
        await _loadTrackers();
        _connectRealtimeIfReady();
      } else if (!result.verificationRequired) {
        error = result.error ?? 'Invalid name or PIN';
      } else {
        error = null;
      }
    } catch (e) {
      result = const AuthFlowResult(error: 'Connection error');
      error = result.error;
    }
    isLoading = false;
    notifyListeners();
    return result;
  }

  Future<AuthFlowResult> register(
    String name,
    String pin, {
    required String jobToken,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    AuthFlowResult result;
    try {
      result = await api.createUser(name, pin, jobToken: jobToken);
      if (!result.verificationRequired && result.user == null) {
        error = result.error ?? 'Could not create account';
      }
    } on Exception catch (e) {
      result = AuthFlowResult(error: e.toString().replaceFirst('Exception: ', ''));
      error = result.error;
    } catch (e) {
      result = const AuthFlowResult(error: 'Connection error');
      error = result.error;
    }
    isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    await api.logout();
    _realtime.disconnect();
    user = null;
    trackers = [];
    currentTracker = null;
    selectedTab = 0;
    blocks = [];
    allTrackerBlocks = {};
    allTrackerSettings = {};
    notifyListeners();
  }

  Future<bool> tryRestoreSession() async {
    isLoading = true;
    notifyListeners();
    await _loadPendingQueue();
    user = await api.checkSession();
    if (user != null) {
      await _loadTrackers();
      _connectRealtimeIfReady();
    }
    isLoading = false;
    notifyListeners();
    return user != null;
  }

  // ── Trackers ──────────────────────────────────────────

  Future<void> _loadTrackers() async {
    trackers = await api.getTrackers();
    if (trackers.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedTrackerId = prefs.getInt('currentTrackerId');
      final initialTracker = savedTrackerId == null
          ? trackers.first
          : trackers.where((tracker) => tracker.id == savedTrackerId).firstOrNull ?? trackers.first;
      _applyTrackerContext(initialTracker, useHubCache: true);
      await _persistSelectedTracker(initialTracker.id);
      await _loadSettings();
      await loadBlocks();
      unawaited(loadAllTrackerData());
    }
  }

  Future<void> switchTracker(Tracker t) async {
    _applyTrackerContext(t, useHubCache: true);
    notifyListeners();
    await _persistSelectedTracker(t.id);
    await _loadSettings();
    await loadBlocks();
  }

  Future<void> openTracker(Tracker t) async {
    final sameTracker = currentTracker?.id == t.id;
    _applyTrackerContext(t, useHubCache: true);
    selectedTab = 1;
    notifyListeners();
    await _persistSelectedTracker(t.id);

    if (!sameTracker || (allTrackerBlocks[t.id]?.isEmpty ?? true)) {
      unawaited(_refreshTrackerData(t));
    }
  }

  Future<void> _refreshTrackerData(Tracker tracker) async {
    await _loadSettings(tracker: tracker);
    await loadBlocks(trackerId: tracker.id, showLoading: false);
  }

  void setSelectedTab(int index) {
    if (selectedTab == index) return;
    selectedTab = index;
    notifyListeners();
  }

  Future<void> _loadSettings({Tracker? tracker}) async {
    final activeTracker = tracker ?? currentTracker;
    if (activeTracker == null) return;
    try {
      final s = await api.getSettings(activeTracker.id);
      allTrackerSettings[activeTracker.id] = s;
      if (currentTracker?.id == activeTracker.id) {
        statusColors = _filterStatusMap(s['colors'] ?? activeTracker.statusColors);
        statusNames = _filterStatusMap(s['names'] ?? activeTracker.statusNames);
        columnOrder = _filterStatusKeys(s['all_columns'] ?? activeTracker.statusTypes);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> reloadSettings() => _loadSettings();

  // ── All Trackers Hub Data ─────────────────────────────

  Future<void> loadAllTrackerData() async {
    for (final t in trackers) {
      try {
        allTrackerBlocks[t.id] = await api.getPowerBlocks(t.id);
      } catch (_) {
        allTrackerBlocks[t.id] = [];
      }
      try {
        allTrackerSettings[t.id] = await api.getSettings(t.id);
      } catch (_) {
        allTrackerSettings[t.id] = {};
      }
    }
    notifyListeners();
  }

  // ── Power Blocks ──────────────────────────────────────

  Future<void> loadBlocks({int? trackerId, bool showLoading = true}) async {
    final activeTrackerId = trackerId ?? currentTracker?.id;
    if (activeTrackerId == null) return;
    if (showLoading) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final loadedBlocks = await api.getPowerBlocks(activeTrackerId);
      allTrackerBlocks[activeTrackerId] = loadedBlocks;
      debugPrint('loadBlocks: got ${loadedBlocks.length} blocks for tracker $activeTrackerId');
      await _cacheBlocks(activeTrackerId, loadedBlocks);
      if (currentTracker?.id == activeTrackerId) {
        blocks = loadedBlocks;
        error = null;
      }
    } catch (e) {
      debugPrint('loadBlocks ERROR: $e');
      final cached = await _loadCachedBlocks(activeTrackerId);
      if (cached.isNotEmpty) {
        allTrackerBlocks[activeTrackerId] = cached;
        if (currentTracker?.id == activeTrackerId) {
          blocks = cached;
          isOffline = true;
        }
        debugPrint('loadBlocks: using cached ${cached.length} blocks (offline)');
      } else if (currentTracker?.id == activeTrackerId) {
        error = 'Failed to load blocks';
      }
    }
    if (showLoading) {
      isLoading = false;
    }
    notifyListeners();
  }

  Future<void> toggleStatus(int lbdId, String statusType, bool value) async {
    final snapshot = _applyLocalLbdStatus(lbdId, statusType, value);
    notifyListeners();

    if (currentTracker != null) {
      await _cacheBlocks(currentTracker!.id, blocks);
    }

    if (isOffline) {
      // Queue for later sync
      _pendingQueue.add({
        'type': 'status',
        'lbdId': lbdId,
        'statusType': statusType,
        'value': value,
      });
      await _savePendingQueue();
      return;
    }

    final ok = await api.updateLbdStatus(lbdId, statusType, value);
    if (!ok) {
      if (snapshot.hadStatus) {
        _applyLocalLbdStatus(lbdId, statusType, snapshot.previousValue);
      } else {
        for (final block in blocks) {
          var touchedBlock = false;
          for (final lbd in block.lbds) {
            if (lbd.id != lbdId) {
              continue;
            }
            touchedBlock = true;
            lbd.statuses.removeWhere((status) => status.statusType == statusType);
            break;
          }
          if (!touchedBlock) {
            continue;
          }
          block.lbdSummary[statusType] = block.lbds.where((lbd) {
            return lbd.statuses.any(
              (status) => status.statusType == statusType && status.isCompleted,
            );
          }).length;
          break;
        }
        _syncCurrentTrackerBlocks();
      }

      if (currentTracker != null) {
        await _cacheBlocks(currentTracker!.id, blocks);
      }
      notifyListeners();
    }
  }

  void _updateBlockClaim(int blockId,
      {required String? claimedBy,
      required List<String> claimedPeople,
      required Map<String, List<int>> claimAssignments,
      required String? claimedAt}) {
    blocks = blocks.map((block) {
      if (block.id != blockId) return block;
      return block.copyWith(
        claimedBy: claimedBy,
        claimedPeople: claimedPeople,
        claimAssignments: claimAssignments,
        claimedAt: claimedAt,
      );
    }).toList();
    _syncCurrentTrackerBlocks();
  }

  Future<void> claimBlock(int blockId,
      {List<String> people = const [],
      Map<String, List<int>> assignments = const {}}) async {
    final actor = user?.name;
    final normalized = <String>[];
    final seen = <String>{};
    for (final person in [if (actor != null) actor, ...people]) {
      final name = person.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) normalized.add(name);
    }

    _updateBlockClaim(
      blockId,
      claimedBy: actor,
      claimedPeople: normalized,
      claimAssignments: assignments,
      claimedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _markAssignmentsCompleted(blockId, assignments);
    notifyListeners();

    if (currentTracker != null) {
      await _cacheBlocks(currentTracker!.id, blocks);
    }

    if (isOffline) {
      _pendingQueue.add({
        'type': 'claim',
        'blockId': blockId,
        'claim': true,
        'people': normalized,
        'assignments': assignments,
      });
      await _savePendingQueue();
      return;
    }

    final ok = await api.claimBlock(
      blockId,
      claim: true,
      people: normalized,
      assignments: assignments,
    );
    if (!ok) {
      await loadBlocks(showLoading: false);
      return;
    }
    unawaited(loadBlocks(showLoading: false));
  }

  Future<bool> submitBlockClaimsBatch(
    int blockId, {
    required List<Map<String, dynamic>> claims,
  }) async {
    final actor = user?.name;
    final normalizedClaims = <Map<String, dynamic>>[];
    final allPeople = <String>[];
    final seenPeople = <String>{};
    final combinedAssignments = <String, Set<int>>{};

    for (final claim in claims) {
      final rawPeople = List<String>.from(claim['people'] ?? const <String>[]);
      final claimPeople = <String>[];
      final claimSeen = <String>{};
      for (final person in [if (actor != null) actor, ...rawPeople]) {
        final name = person.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (claimSeen.add(key)) {
          claimPeople.add(name);
        }
        if (seenPeople.add(key)) {
          allPeople.add(name);
        }
      }

      final claimAssignments = <String, List<int>>{};
      final rawAssignments = Map<String, dynamic>.from(
        claim['assignments'] as Map? ?? const {},
      );
      rawAssignments.forEach((statusType, rawIds) {
        final ids = (rawIds as List? ?? const [])
            .map((entry) => int.tryParse(entry.toString()) ?? 0)
            .where((entry) => entry > 0)
            .toSet()
            .toList()
          ..sort();
        if (ids.isEmpty) return;
        claimAssignments[statusType] = ids;
        combinedAssignments.putIfAbsent(statusType, () => <int>{}).addAll(ids);
      });

      if (claimPeople.isEmpty || claimAssignments.isEmpty) {
        continue;
      }

      normalizedClaims.add({
        'people': claimPeople,
        'assignments': claimAssignments,
        'scanDraft': claim['scanDraft'],
      });
    }

    if (normalizedClaims.isEmpty) {
      return false;
    }

    final mergedAssignments = <String, List<int>>{
      for (final entry in combinedAssignments.entries)
        entry.key: entry.value.toList()..sort(),
    };

    _updateBlockClaim(
      blockId,
      claimedBy: actor,
      claimedPeople: allPeople,
      claimAssignments: mergedAssignments,
      claimedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _markAssignmentsCompleted(blockId, mergedAssignments);
    notifyListeners();

    if (currentTracker != null) {
      await _cacheBlocks(currentTracker!.id, blocks);
    }

    if (isOffline) {
      _pendingQueue.add({
        'type': 'claim',
        'blockId': blockId,
        'claim': true,
        'people': allPeople,
        'assignments': mergedAssignments,
      });
      await _savePendingQueue();
      return true;
    }

    try {
      final ok = await api.claimBlock(
        blockId,
        claim: true,
        people: allPeople,
        assignments: mergedAssignments,
      );
      if (!ok) {
        await loadBlocks(showLoading: false);
        return false;
      }

      for (final claim in normalizedClaims) {
        final draft = claim['scanDraft'];
        if (draft is! Map<String, dynamic>) {
          continue;
        }
        try {
          await api.submitClaimScan(
            blockId: blockId,
            people: List<String>.from(claim['people'] ?? const <String>[]),
            assignments: Map<String, List<int>>.from(
              claim['assignments'] as Map? ?? const {},
            ),
            draft: draft,
            trackerId: currentTracker?.id,
          );
        } catch (_) {
          // Claim state is already saved. Scan/report logging is best-effort.
        }
      }

      await loadBlocks(showLoading: false);
      return true;
    } catch (_) {
      await loadBlocks(showLoading: false);
      return false;
    }
  }

  Future<void> unclaimBlock(int blockId) async {
    _updateBlockClaim(
      blockId,
      claimedBy: null,
      claimedPeople: const [],
      claimAssignments: const {},
      claimedAt: null,
    );
    notifyListeners();

    if (currentTracker != null) {
      await _cacheBlocks(currentTracker!.id, blocks);
    }

    if (isOffline) {
      _pendingQueue.add({
        'type': 'claim',
        'blockId': blockId,
        'claim': false,
        'people': const <String>[],
        'assignments': const <String, List<int>>{},
      });
      await _savePendingQueue();
      return;
    }

    await api.claimBlock(blockId, claim: false);
    unawaited(loadBlocks(showLoading: false));
  }

  Future<bool> submitClaimScan(
    int blockId, {
    required List<String> people,
    required Map<String, List<int>> assignments,
    required Map<String, dynamic> draft,
  }) async {
    final actor = user?.name;
    final normalized = <String>[];
    final seen = <String>{};
    for (final person in [if (actor != null) actor, ...people]) {
      final name = person.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) normalized.add(name);
    }

    _updateBlockClaim(
      blockId,
      claimedBy: actor ?? (normalized.isNotEmpty ? normalized.first : null),
      claimedPeople: normalized,
      claimAssignments: assignments,
      claimedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _markAssignmentsCompleted(blockId, assignments);
    notifyListeners();

    if (currentTracker != null) {
      await _cacheBlocks(currentTracker!.id, blocks);
    }

    if (isOffline) {
      await loadBlocks();
      return false;
    }

    try {
      await api.submitClaimScan(
        blockId: blockId,
        people: normalized,
        assignments: assignments,
        draft: draft,
        trackerId: currentTracker?.id,
      );
      unawaited(loadBlocks(showLoading: false));
      return true;
    } catch (_) {
      await loadBlocks(showLoading: false);
      return false;
    }
  }

  // ── Workers ───────────────────────────────────────────

  Future<void> loadWorkers() async {
    workers = await api.getWorkers();
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────

  Color colorFromHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Color getStatusColor(String statusType) {
    final hex = statusColors[statusType] ??
        currentTracker?.statusColors[statusType] ??
        '#888888';
    return colorFromHex(hex);
  }

  String getStatusName(String statusType) {
    return statusNames[statusType] ??
        currentTracker?.statusNames[statusType] ??
        statusType;
  }
}
