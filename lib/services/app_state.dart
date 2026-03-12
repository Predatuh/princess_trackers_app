import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Workers
  List<Worker> workers = [];

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
      columnOrder = List<String>.from(
          (s['all_columns'] as List?)?.map((c) => c['key'].toString()) ?? []);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> reloadSettings() => _loadSettings();

  // ── Power Blocks ──────────────────────────────────────

  Future<void> loadBlocks() async {
    if (currentTracker == null) return;
    isLoading = true;
    notifyListeners();
    try {
      blocks = await api.getPowerBlocks(currentTracker!.id);
      debugPrint('loadBlocks: got ${blocks.length} blocks');
    } catch (e) {
      debugPrint('loadBlocks ERROR: $e');
      error = 'Failed to load blocks';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleStatus(int lbdId, String statusType, bool value) async {
    final ok = await api.updateLbdStatus(lbdId, statusType, value);
    if (ok) {
      // Update local state
      for (final b in blocks) {
        for (final lbd in b.lbds) {
          if (lbd.id == lbdId) {
            for (final s in lbd.statuses) {
              if (s.statusType == statusType) {
                s.isCompleted = value;
                notifyListeners();
                return;
              }
            }
          }
        }
      }
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
