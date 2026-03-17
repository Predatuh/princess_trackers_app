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

  Map<String, dynamic> _tryDecodeBody(http.Response res) {
    if (res.body.isEmpty) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const <String, dynamic>{};
  }

  AuthFlowResult _parseAuthResult(http.Response res, String fallbackError) {
    final body = _tryDecodeBody(res);
    if (res.statusCode >= 200 && res.statusCode < 300 && body['user'] != null) {
      currentUser = User.fromJson(body['user']);
      return AuthFlowResult(user: currentUser, message: body['message']?.toString());
    }
    if (body['verification_required'] == true) {
      return AuthFlowResult(
        verificationRequired: true,
        email: body['email']?.toString(),
        jobSiteName: body['job_site_name']?.toString(),
        message: body['message']?.toString(),
        previewCode: body['preview_code']?.toString(),
      );
    }
    return AuthFlowResult(
      error: body['error']?.toString() ?? fallbackError,
      message: body['message']?.toString(),
    );
  }

  // ── Auth ──────────────────────────────────────────────

  Future<AuthFlowResult> login(String name, String pin) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'name': name, 'pin': pin}),
    );
    return _parseAuthResult(res, 'Invalid name or PIN');
  }

  Future<AuthFlowResult> register(
    String name,
    String pin, {
    required String jobToken,
  }) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'pin': pin,
        'job_token': jobToken,
      }),
    );
    return _parseAuthResult(res, 'Failed to create account');
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
    await clearPersistedCookies();
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
    if (res.statusCode == 404) {
      final fallback = <String>[];
      final name = currentUser?.name.trim();
      if (name != null && name.isNotEmpty) {
        fallback.add(name);
      }
      return fallback;
    }
    final j = _decodeJsonResponse(res, 'Load claim people');
    return List<String>.from(j['data'] ?? const []);
  }

  Future<bool> claimBlock(int blockId,
      {bool claim = true,
      List<String> people = const [],
      Map<String, List<int>> assignments = const {}}) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/tracker/power-blocks/$blockId/claim'),
      headers: _headers,
      body: jsonEncode({
        'action': claim ? 'claim' : 'unclaim',
        'actor_name': currentUser?.name,
        'people': people,
        'assignments': assignments,
      }),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> scanClaimSheetDraft({
    required int blockId,
    required String fileName,
    required Uint8List fileBytes,
    int? trackerId,
  }) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/reports/claim-scan/draft'),
      headers: _headers,
      body: jsonEncode({
        'power_block_id': blockId,
        'tracker_id': trackerId,
        'file_name': fileName,
        'image_base64': base64Encode(fileBytes),
      }),
    );
    if (res.statusCode == 404) {
      throw Exception('Claim sheet upload is not available on this server yet.');
    }
    return _decodeJsonResponse(res, 'Scan claim sheet')['data'];
  }

  Future<Map<String, dynamic>> submitClaimScan({
    required int blockId,
    required List<String> people,
    required Map<String, List<int>> assignments,
    required Map<String, dynamic> draft,
    int? trackerId,
  }) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/reports/claim-scan/submit'),
      headers: _headers,
      body: jsonEncode({
        'power_block_id': blockId,
        'tracker_id': trackerId,
        'actor_name': currentUser?.name,
        'people': people,
        'assignments': assignments,
        'draft': draft,
      }),
    );
    if (res.statusCode == 404) {
      throw Exception('Claim sheet upload is not available on this server yet.');
    }
    return _decodeJsonResponse(res, 'Submit claim scan')['data'];
  }

  String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$_rootUrl$path';
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

  Future<List<dynamic>> getAuditLogs({int limit = 250}) async {
    final res = await _client.get(
      Uri.parse('$_rootUrl/api/admin/audit-logs?limit=$limit'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body)['data'] as List?) ?? [];
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

  Future<AuthFlowResult> createUser(
    String name,
    String pin, {
    required String jobToken,
  }) async {
    return register(name, pin, jobToken: jobToken);
  }

  Future<Map<String, dynamic>> adminCreateUser(
    String name,
    String pin, {
    required String jobToken,
  }) async {
    final res = await _client.post(
      Uri.parse('$_rootUrl/api/auth/users'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'pin': pin,
        'job_token': jobToken,
      }),
    );
    return _decodeJsonResponse(res, 'Create user');
  }

  Future<bool> resetUserPin(int userId, String pin) async {
    final res = await _client.put(
      Uri.parse('$_rootUrl/api/auth/users/$userId/pin'),
      headers: _headers,
      body: jsonEncode({'pin': pin}),
    );
    return res.statusCode == 200;
  }
}
