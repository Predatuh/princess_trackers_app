import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tracker.dart';
import '../models/power_block.dart';
import '../models/app_models.dart';
import 'http_client.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.princesscoded.net',
  );
  late final http.Client _client;
  User? currentUser;

  ApiService() {
    _client = createHttpClient();
  }

  String get _rootUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> _decodeJsonResponse(http.Response res, String operation) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$operation failed (${res.statusCode})');
    }
    if (res.body.isEmpty) {
      throw Exception('$operation returned an empty response');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('$operation returned an unexpected response');
    }
    return decoded;
  }

  // ── Auth ──────────────────────────────────────────────

  Future<User?> login(String name, String pin) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/auth/login'),
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
      Uri.parse('$_rootUrl/api/auth/me'),
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
    await _client.post(Uri.parse('$_rootUrl/api/auth/logout'), headers: _headers);
    currentUser = null;
  }

  // ── Trackers ──────────────────────────────────────────

  Future<List<Tracker>> getTrackers() async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/admin/trackers'),
      headers: _headers,
    );
    final j = _decodeJsonResponse(res, 'Load trackers');
    return (j['data'] as List).map((t) => Tracker.fromJson(t)).toList();
  }

  // ── Settings ──────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings(int trackerId) async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/admin/settings?tracker_id=$trackerId'),
      headers: _headers,
    );
    return _decodeJsonResponse(res, 'Load settings')['data'];
  }

  // ── Power Blocks ──────────────────────────────────────

  Future<List<PowerBlock>> getPowerBlocks(int trackerId) async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/tracker/power-blocks?tracker_id=$trackerId'),
      headers: _headers,
    );
    if (kDebugMode) {
      debugPrint('getPowerBlocks status=${res.statusCode} bodyLen=${res.body.length}');
    }
    final j = _decodeJsonResponse(res, 'Load power blocks');
    if (kDebugMode) {
      debugPrint('getPowerBlocks success=${j['success']} dataLen=${(j['data'] as List?)?.length}');
    }
    return (j['data'] as List).map((b) => PowerBlock.fromJson(b)).toList();
  }

  Future<PowerBlock> getPowerBlock(int id) async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/tracker/power-blocks/$id'),
      headers: _headers,
    );
    return PowerBlock.fromJson(_decodeJsonResponse(res, 'Load power block')['data']);
  }

  // ── LBD Status ────────────────────────────────────────

  Future<bool> updateLbdStatus(
      int lbdId, String statusType, bool isCompleted) async {
    final res = await _client.put(
      Uri.parse('$_rootUrl/api/tracker/lbds/$lbdId/status/$statusType'),
      headers: _headers,
      body: jsonEncode({'is_completed': isCompleted}),
    );
    return res.statusCode == 200;
  }

  // ── Claim ─────────────────────────────────────────────

  Future<List<String>> getClaimPeople() async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/tracker/claim-people'),
      headers: _headers,
    );
    final j = _decodeJsonResponse(res, 'Load claim people');
    return List<String>.from(j['data'] ?? const []);
  }

  Future<bool> claimBlock(int blockId,
      {bool claim = true, List<String> people = const []}) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/tracker/power-blocks/$blockId/claim'),
      headers: _headers,
      body: jsonEncode({
        'action': claim ? 'claim' : 'unclaim',
        'people': people,
      }),
    );
    return res.statusCode == 200;
  }

  // ── Bulk Complete ─────────────────────────────────────

  Future<int> bulkComplete(int blockId,
      {List<String>? statusTypes, bool isCompleted = true}) async {
    final body = <String, dynamic>{'power_block_id': blockId, 'is_completed': isCompleted};
    if (statusTypes != null) body['status_types'] = statusTypes;
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/admin/bulk-complete'),
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
      Uri.parse('$_rootUrl/api/workers${all ? "?all=true" : ""}'),
      headers: _headers,
    );
    final j = _decodeJsonResponse(res, 'Load workers');
    return (j['data'] as List).map((w) => Worker.fromJson(w)).toList();
  }

  // ── Work Entries ──────────────────────────────────────

  Future<List<WorkEntry>> getWorkEntries(String date, int trackerId) async {
    final res = await _client.get(
      Uri.parse(
          '$_rootUrl/api/work-entries?date=$date&tracker_id=$trackerId'),
      headers: _headers,
    );
    final j = _decodeJsonResponse(res, 'Load work entries');
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
      Uri.parse('$_rootUrl/api/work-entries'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return res.statusCode == 201;
  }

  Future<bool> deleteWorkEntry(int id) async {
    final res = await _client.delete(
      Uri.parse('$_rootUrl/api/work-entries/$id'),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  // ── Reports ───────────────────────────────────────────

  Future<List<DailyReport>> getReports(int trackerId) async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/reports?tracker_id=$trackerId'),
      headers: _headers,
    );
    final j = jsonDecode(res.body);
    return (j['data'] as List).map((r) => DailyReport.fromJson(r)).toList();
  }

  // ── Map ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSiteMaps() async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/map/sitemaps'),
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
      Uri.parse('$_rootUrl/api/pdf/get-map'),
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
      Uri.parse('$_rootUrl/api/map/map-status/$mapId'),
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
      Uri.parse('$_rootUrl/api/reports/$id'),
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
      Uri.parse('$_rootUrl/api/reports/generate'),
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
    final trackerId = data['tracker_id'];
    final body = <String, dynamic>{};
    if (trackerId != null) {
      body['tracker_id'] = trackerId;
    }

    bool ok = true;

    if (data['colors'] != null) {
      body['colors'] = data['colors'];
      final res = await _client.put(
        Uri.parse('$_rootUrl/api/admin/settings/colors'),
        headers: _headers,
        body: jsonEncode(body),
      );
      ok = ok && res.statusCode == 200;
      body.remove('colors');
    }

    if (data['names'] != null) {
      body['names'] = data['names'];
      final res = await _client.put(
        Uri.parse('$_rootUrl/api/admin/settings/names'),
        headers: _headers,
        body: jsonEncode(body),
      );
      ok = ok && res.statusCode == 200;
      body.remove('names');
    }

    return ok;
  }

  Future<bool> updateSiteArea(int areaId, Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse('$_rootUrl/api/map/area/$areaId'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteSiteArea(int areaId) async {
    final res = await _client.delete(
      Uri.parse('$_rootUrl/api/map/area/$areaId'),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> createSiteArea(Map<String, dynamic> data) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/map/area'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      final j = jsonDecode(res.body);
      return j['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<List<dynamic>> getUsers() async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/auth/users'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body)['users'] as List?) ?? [];
    }
    return [];
  }

  Future<bool> updateUserRole(int userId, String role,
      {List<String> permissions = const []}) async {
    final res = await _client.put(
      Uri.parse('$_rootUrl/api/auth/users/$userId/role'),
      headers: _headers,
      body: jsonEncode({'role': role, 'permissions': permissions}),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> createUser(String name, String pin) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'pin': pin}),
    );
    if (res.statusCode == 201) {
      final j = jsonDecode(res.body);
      return j['user'] as Map<String, dynamic>?;
    }
    if (res.statusCode == 409 || res.statusCode == 400) {
      final j = jsonDecode(res.body);
      throw Exception(j['error'] ?? 'Failed to create user');
    }
    return null;
  }
}
