import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tracker.dart';
import '../models/power_block.dart';
import '../models/app_models.dart';
import 'http_client.dart';

class ApiService {
  static const String baseUrl = 'https://www.princesscoded.net';
  late final http.Client _client;
  User? currentUser;

  ApiService() {
    _client = createHttpClient();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  // ── Auth ──────────────────────────────────────────────

  Future<User?> login(String name, String pin) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'name': name, 'pin': pin}),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      currentUser = User.fromJson(j['user']);
      return currentUser;
    }
    return null;
  }

  Future<User?> checkSession() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j['user'] != null) {
        currentUser = User.fromJson(j['user']);
        return currentUser;
      }
    }
    return null;
  }

  Future<void> logout() async {
    await _client.post(Uri.parse('$baseUrl/api/auth/logout'), headers: _headers);
    currentUser = null;
  }

  // ── Trackers ──────────────────────────────────────────

  Future<List<Tracker>> getTrackers() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/admin/trackers'),
      headers: _headers,
    );
    final j = jsonDecode(res.body);
    return (j['data'] as List).map((t) => Tracker.fromJson(t)).toList();
  }

  // ── Settings ──────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings(int trackerId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/admin/settings?tracker_id=$trackerId'),
      headers: _headers,
    );
    return jsonDecode(res.body)['data'];
  }

  // ── Power Blocks ──────────────────────────────────────

  Future<List<PowerBlock>> getPowerBlocks(int trackerId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/tracker/power-blocks?tracker_id=$trackerId'),
      headers: _headers,
    );
    debugPrint('getPowerBlocks status=${res.statusCode} bodyLen=${res.body.length}');
    final j = jsonDecode(res.body);
    debugPrint('getPowerBlocks success=${j['success']} dataLen=${(j['data'] as List?)?.length}');
    return (j['data'] as List).map((b) => PowerBlock.fromJson(b)).toList();
  }

  Future<PowerBlock> getPowerBlock(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/tracker/power-blocks/$id'),
      headers: _headers,
    );
    return PowerBlock.fromJson(jsonDecode(res.body)['data']);
  }

  // ── LBD Status ────────────────────────────────────────

  Future<bool> updateLbdStatus(
      int lbdId, String statusType, bool isCompleted) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/tracker/lbds/$lbdId/status/$statusType'),
      headers: _headers,
      body: jsonEncode({'is_completed': isCompleted}),
    );
    return res.statusCode == 200;
  }

  // ── Claim ─────────────────────────────────────────────

  Future<bool> claimBlock(int blockId, {bool claim = true}) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/tracker/power-blocks/$blockId/claim'),
      headers: _headers,
      body: jsonEncode({'action': claim ? 'claim' : 'unclaim'}),
    );
    return res.statusCode == 200;
  }

  // ── Bulk Complete ─────────────────────────────────────

  Future<int> bulkComplete(int blockId,
      {List<String>? statusTypes, bool isCompleted = true}) async {
    final body = <String, dynamic>{'power_block_id': blockId, 'is_completed': isCompleted};
    if (statusTypes != null) body['status_types'] = statusTypes;
    final res = await _client.post(
      Uri.parse('$baseUrl/api/admin/bulk-complete'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['updated'] ?? 0;
    }
    return 0;
  }

  // ── Workers ───────────────────────────────────────────

  Future<List<Worker>> getWorkers({bool all = false}) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workers${all ? "?all=true" : ""}'),
      headers: _headers,
    );
    final j = jsonDecode(res.body);
    return (j['data'] as List).map((w) => Worker.fromJson(w)).toList();
  }

  // ── Work Entries ──────────────────────────────────────

  Future<List<WorkEntry>> getWorkEntries(String date, int trackerId) async {
    final res = await _client.get(
      Uri.parse(
          '$baseUrl/api/work-entries?date=$date&tracker_id=$trackerId'),
      headers: _headers,
    );
    final j = jsonDecode(res.body);
    return (j['data'] as List).map((e) => WorkEntry.fromJson(e)).toList();
  }

  Future<bool> createWorkEntries({
    required String date,
    required List<int> workerIds,
    required List<int> powerBlockIds,
    required String taskType,
    int? trackerId,
  }) async {
    final body = <String, dynamic>{
      'date': date,
      'worker_ids': workerIds,
      'power_block_ids': powerBlockIds,
      'task_type': taskType,
    };
    if (trackerId != null) body['tracker_id'] = trackerId;
    final res = await _client.post(
      Uri.parse('$baseUrl/api/work-entries'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return res.statusCode == 201;
  }

  Future<bool> deleteWorkEntry(int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/work-entries/$id'),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  // ── Reports ───────────────────────────────────────────

  Future<List<DailyReport>> getReports(int trackerId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/reports?tracker_id=$trackerId'),
      headers: _headers,
    );
    final j = jsonDecode(res.body);
    return (j['data'] as List).map((r) => DailyReport.fromJson(r)).toList();
  }

  // ── Map ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSiteMaps() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/map/sitemaps'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return (j['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<String?> getMapImageUrl() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/pdf/get-map'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j['success'] == true) return j['map_url'];
    }
    return null;
  }

  Future<List<dynamic>> getMapStatus(int mapId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/map/map-status/$mapId'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j['data'] as List;
    }
    return [];
  }

  Future<Map<String, dynamic>> getReportDetail(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/reports/$id'),
      headers: _headers,
    );
    return jsonDecode(res.body)['data'];
  }

  Future<DailyReport?> generateReport(
      {String? date, int? trackerId}) async {
    final body = <String, dynamic>{};
    if (date != null) body['date'] = date;
    if (trackerId != null) body['tracker_id'] = trackerId;
    final res = await _client.post(
      Uri.parse('$baseUrl/api/reports/generate'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return DailyReport.fromJson(jsonDecode(res.body)['data']);
    }
    return null;
  }

  // ── Admin ────────────────────────────────────────────

  Future<bool> saveSettings(Map<String, dynamic> data) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/admin/settings'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  Future<bool> updateSiteArea(int areaId, Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/map/area/$areaId'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteSiteArea(int areaId) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/map/area/$areaId'),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  Future<List<dynamic>> getUsers() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/auth/users'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body)['data'] as List?) ?? [];
    }
    return [];
  }

  Future<bool> updateUserRole(int userId, String role) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/auth/users/$userId'),
      headers: _headers,
      body: jsonEncode({'role': role}),
    );
    return res.statusCode == 200;
  }
}
