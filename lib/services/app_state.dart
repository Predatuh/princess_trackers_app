import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/tracker.dart';
import '../models/power_block.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();

  // Auth
  User? user;
  bool isLoading = false;
  String? error;

  // Trackers
  List<Tracker> trackers = [];
  Tracker? currentTracker;

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
    _connectivityStream = Connectivity().onConnectivityChanged;
    _connectivityStream.listen(_onConnectivityChanged);
    _checkConnectivity();
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
        await api.updateLbdStatus(
          item['lbdId'] as int,
          item['statusType'] as String,
          item['value'] as bool,
        );
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

  Future<void> _cacheBlocks(int trackerId, List<PowerBlock> blockList) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(blockList.map((b) => {
      'id': b.id,
      'name': b.name,
      'power_block_number': b.powerBlockNumber,
      'lbd_count': b.lbdCount,
      'lbd_summary': b.lbdSummary,
      'claimed_by': b.claimedBy,
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

  Future<bool> login(String name, String pin) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      user = await api.login(name, pin);
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastUser', name);
        await _loadTrackers();
      } else {
        error = 'Invalid name or PIN';
      }
    } catch (e) {
      error = 'Connection error';
    }
    isLoading = false;
    notifyListeners();
    return user != null;
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    trackers = [];
    currentTracker = null;
    blocks = [];
    notifyListeners();
  }

  Future<bool> tryRestoreSession() async {
    isLoading = true;
    notifyListeners();
    await _loadPendingQueue();
    user = await api.checkSession();
    if (user != null) await _loadTrackers();
    isLoading = false;
    notifyListeners();
    return user != null;
  }

  // ── Trackers ──────────────────────────────────────────

  Future<void> _loadTrackers() async {
    trackers = await api.getTrackers();
    if (trackers.isNotEmpty) {
      currentTracker = trackers.first;
      await _loadSettings();
      await loadBlocks();
    }
  }

  Future<void> switchTracker(Tracker t) async {
    currentTracker = t;
    notifyListeners();
    await _loadSettings();
    await loadBlocks();
  }

  Future<void> _loadSettings() async {
    if (currentTracker == null) return;
    try {
      final s = await api.getSettings(currentTracker!.id);
      statusColors = Map<String, String>.from(s['colors'] ?? {});
      statusNames = Map<String, String>.from(s['names'] ?? {});
      columnOrder = List<String>.from(s['all_columns'] ?? const []);
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

  Future<void> loadBlocks() async {
    if (currentTracker == null) return;
    isLoading = true;
    notifyListeners();
    try {
      blocks = await api.getPowerBlocks(currentTracker!.id);
      debugPrint('loadBlocks: got ${blocks.length} blocks');
      await _cacheBlocks(currentTracker!.id, blocks);
    } catch (e) {
      debugPrint('loadBlocks ERROR: $e');
      final cached = await _loadCachedBlocks(currentTracker!.id);
      if (cached.isNotEmpty) {
        blocks = cached;
        isOffline = true;
        debugPrint('loadBlocks: using cached ${blocks.length} blocks (offline)');
      } else {
        error = 'Failed to load blocks';
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleStatus(int lbdId, String statusType, bool value) async {
    // Optimistically update local state immediately
    for (final b in blocks) {
      for (final lbd in b.lbds) {
        if (lbd.id == lbdId) {
          for (final s in lbd.statuses) {
            if (s.statusType == statusType) {
              s.isCompleted = value;
            }
          }
        }
      }
    }
    notifyListeners();

    if (isOffline) {
      // Queue for later sync
      _pendingQueue.add({'lbdId': lbdId, 'statusType': statusType, 'value': value});
      await _savePendingQueue();
      return;
    }

    final ok = await api.updateLbdStatus(lbdId, statusType, value);
    if (!ok) {
      // Revert local state on failure
      for (final b in blocks) {
        for (final lbd in b.lbds) {
          if (lbd.id == lbdId) {
            for (final s in lbd.statuses) {
              if (s.statusType == statusType) {
                s.isCompleted = !value;
              }
            }
          }
        }
      }
      notifyListeners();
    }
  }

  Future<void> claimBlock(int blockId) async {
    await api.claimBlock(blockId, claim: true);
    await loadBlocks();
  }

  Future<void> unclaimBlock(int blockId) async {
    await api.claimBlock(blockId, claim: false);
    await loadBlocks();
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
