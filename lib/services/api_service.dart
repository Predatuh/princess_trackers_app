import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tracker.dart';
import '../models/power_block.dart';
import '../models/app_models.dart';
import 'http_client.dart';

class ApiService {
  static const String railwayBaseUrl = 'https://tracker-production-74add.up.railway.app';
  static const String customDomainBaseUrl = 'https://www.princesstrackers.com';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: customDomainBaseUrl,
  );
  static const List<String> _fallbackBaseUrls = <String>[
    customDomainBaseUrl,
    'https://princesstrackers.com',
    railwayBaseUrl,
  ];
  late final http.Client _client;
  late String _activeRootUrl;
  User? currentUser;

  ApiService() {
    _client = createHttpClient();
    _activeRootUrl = _normalizeBaseUrl(baseUrl);
  }

  static String _normalizeBaseUrl(String rawUrl) => rawUrl.endsWith('/')
      ? rawUrl.substring(0, rawUrl.length - 1)
      : rawUrl;

  String get currentBaseUrl => _activeRootUrl;

  List<String> get _rootUrlCandidates {
    final ordered = <String>[_activeRootUrl];
    for (final rawUrl in <String>[baseUrl, ..._fallbackBaseUrls]) {
      final normalized = _normalizeBaseUrl(rawUrl);
      if (!ordered.contains(normalized)) {
        ordered.add(normalized);
      }
    }
    return ordered;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  bool _looksLikeDeadHost(http.Response res) {
    if ((res.headers['x-railway-fallback'] ?? '').toLowerCase() == 'true') {
      return true;
    }
    if (res.statusCode >= 500) {
      return true;
    }
    if (res.statusCode != 404) {
      return false;
    }
    final body = res.body.toLowerCase();
    return body.contains('application not found') || body.contains('x-railway-fallback');
  }

  void _rememberWorkingRoot(String rootUrl) {
    if (_activeRootUrl == rootUrl) {
      return;
    }
    _activeRootUrl = rootUrl;
    if (kDebugMode) {
      debugPrint('ApiService switched active host to $_activeRootUrl');
    }
  }

  Future<http.Response> _sendWithFallback(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    Object? lastError;
    http.Response? lastResponse;

    for (final rootUrl in _rootUrlCandidates) {
      try {
        final uri = Uri.parse('$rootUrl$path');
        late final http.Response response;
        switch (method) {
          case 'GET':
            response = await _client.get(uri, headers: headers);
            break;
          case 'POST':
            response = await _client.post(uri, headers: headers, body: body);
            break;
          case 'PUT':
            response = await _client.put(uri, headers: headers, body: body);
            break;
          case 'DELETE':
            response = await _client.delete(uri, headers: headers);
            break;
          default:
            throw UnsupportedError('Unsupported method $method');
        }

        if (_looksLikeDeadHost(response)) {
          lastResponse = response;
          continue;
        }

        _rememberWorkingRoot(rootUrl);
        return response;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastResponse != null) {
      return lastResponse;
    }
    throw Exception(lastError?.toString() ?? 'Request failed');
  }

  Future<http.Response> _get(String path) => _sendWithFallback('GET', path, headers: _headers);

  Future<http.Response> _post(String path, {Object? body}) =>
      _sendWithFallback('POST', path, headers: _headers, body: body);

  Future<http.Response> _put(String path, {Object? body}) =>
      _sendWithFallback('PUT', path, headers: _headers, body: body);

  Future<http.Response> _delete(String path) => _sendWithFallback('DELETE', path, headers: _headers);

  Map<String, dynamic> _decodeJsonResponse(http.Response res, String operation) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = _tryDecodeBody(res);
      throw Exception(
        body['error']?.toString() ??
            body['message']?.toString() ??
            '$operation failed (${res.statusCode})',
      );
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
    final res = await _post('/api/auth/login', body: jsonEncode({'name': name, 'pin': pin}));
    return _parseAuthResult(res, 'Invalid name or PIN');
  }

  Future<AuthFlowResult> register(
    String name,
    String pin, {
    required String jobToken,
  }) async {
    final res = await _post('/api/auth/register', body: jsonEncode({
        'name': name,
        'pin': pin,
        'job_token': jobToken,
      }));
    return _parseAuthResult(res, 'Failed to create account');
  }

  Future<User?> checkSession() async {
    final res = await _get('/api/auth/me');
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
    await _post('/api/auth/logout');
    await clearPersistedCookies();
    currentUser = null;
  }

  // ── Trackers ──────────────────────────────────────────

  Future<List<Tracker>> getTrackers() async {
    final res = await _get('/api/admin/trackers');
    final j = _decodeJsonResponse(res, 'Load trackers');
    return (j['data'] as List).map((t) => Tracker.fromJson(t)).toList();
  }

  // ── Settings ──────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings(int trackerId) async {
    final res = await _get('/api/admin/settings?tracker_id=$trackerId');
    return _decodeJsonResponse(res, 'Load settings')['data'];
  }

  // ── Power Blocks ──────────────────────────────────────

  Future<List<PowerBlock>> getPowerBlocks(int trackerId) async {
    final res = await _get('/api/tracker/power-blocks?tracker_id=$trackerId');
    if (kDebugMode) {
      debugPrint('getPowerBlocks status=${res.statusCode} bodyLen=${res.body.length}');
    }
    final j = _decodeJsonResponse(res, 'Load power blocks');
    if (kDebugMode) {
      debugPrint('getPowerBlocks success=${j['success']} dataLen=${(j['data'] as List?)?.length}');
    }
    return (j['data'] as List).map((b) => PowerBlock.fromJson(b)).toList();
  }

  Future<PowerBlock> getPowerBlock(int id, {int? trackerId}) async {
    final query = trackerId != null ? '?tracker_id=$trackerId' : '';
    final res = await _get('/api/tracker/power-blocks/$id$query');
    return PowerBlock.fromJson(_decodeJsonResponse(res, 'Load power block')['data']);
  }

  // ── LBD Status ────────────────────────────────────────

  Future<bool> updateLbdStatus(
      int lbdId, String statusType, bool isCompleted) async {
    final res = await _put('/api/tracker/lbds/$lbdId/status/$statusType',
        body: jsonEncode({'is_completed': isCompleted}));
    return res.statusCode == 200;
  }

  // ── Claim ─────────────────────────────────────────────

  Future<List<String>> getClaimPeople() async {
    final res = await _get('/api/tracker/claim-people');
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
      Map<String, List<int>> assignments = const {},
      int? trackerId,
      String? workDate}) async {
    final body = <String, dynamic>{
      'action': claim ? 'claim' : 'unclaim',
      'actor_name': currentUser?.name,
      'people': people,
      'assignments': assignments,
    };
    if (trackerId != null) body['tracker_id'] = trackerId;
    if (workDate != null && workDate.trim().isNotEmpty) body['work_date'] = workDate.trim();
    final res = await _post('/api/tracker/power-blocks/$blockId/claim', body: jsonEncode({
        ...body,
      }));
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> scanClaimSheetDraft({
    required int blockId,
    required String fileName,
    required Uint8List fileBytes,
    int? trackerId,
  }) async {
    final res = await _post('/api/reports/claim-scan/draft', body: jsonEncode({
        'power_block_id': blockId,
        'tracker_id': trackerId,
        'file_name': fileName,
        'image_base64': base64Encode(fileBytes),
      }));
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
    String? workDate,
  }) async {
    final body = <String, dynamic>{
      'power_block_id': blockId,
      'tracker_id': trackerId,
      'actor_name': currentUser?.name,
      'people': people,
      'assignments': assignments,
      'draft': draft,
    };
    if (workDate != null && workDate.trim().isNotEmpty) body['work_date'] = workDate.trim();
    final res = await _post('/api/reports/claim-scan/submit', body: jsonEncode({
        ...body,
      }));
    if (res.statusCode == 404) {
      throw Exception('Claim sheet upload is not available on this server yet.');
    }
    return _decodeJsonResponse(res, 'Submit claim scan')['data'];
  }

  Future<Map<String, dynamic>> backfillClaimActivity({
    required int blockId,
    required List<String> people,
    required Map<String, List<int>> assignments,
    required String workDate,
    int? trackerId,
    String? claimedBy,
  }) async {
    final body = <String, dynamic>{
      'power_block_id': blockId,
      'people': people,
      'assignments': assignments,
      'work_date': workDate,
    };
    if (trackerId != null) body['tracker_id'] = trackerId;
    if (claimedBy != null && claimedBy.trim().isNotEmpty) {
      body['claimed_by'] = claimedBy.trim();
    }
    final res = await _post(
      '/api/reports/claim-activities/backfill',
      body: jsonEncode(body),
    );
    return _decodeJsonResponse(res, 'Backfill claim activity')['data'];
  }

  String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$currentBaseUrl$path';
  }

  // ── Bulk Complete ─────────────────────────────────────

  Future<int> bulkComplete(int blockId,
      {List<String>? statusTypes, bool isCompleted = true}) async {
    final body = <String, dynamic>{'power_block_id': blockId, 'is_completed': isCompleted};
    if (statusTypes != null) body['status_types'] = statusTypes;
    final res = await _post('/api/admin/bulk-complete', body: jsonEncode(body));
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['updated'] ?? 0;
    }
    return 0;
  }

  // ── Workers ───────────────────────────────────────────

  Future<List<Worker>> getWorkers({bool all = false}) async {
    final res = await _get('/api/workers${all ? "?all=true" : ""}');
    final j = _decodeJsonResponse(res, 'Load workers');
    return (j['data'] as List).map((w) => Worker.fromJson(w)).toList();
  }

  // ── Work Entries ──────────────────────────────────────

  Future<List<WorkEntry>> getWorkEntries(String date, int trackerId) async {
    final res = await _get('/api/work-entries?date=$date&tracker_id=$trackerId');
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
    final res = await _post('/api/work-entries', body: jsonEncode(body));
    return res.statusCode == 201;
  }

  Future<bool> deleteWorkEntry(int id) async {
    final res = await _delete('/api/work-entries/$id');
    return res.statusCode == 200;
  }

  // ── Reports ───────────────────────────────────────────

  Future<List<DailyReport>> getReports(int trackerId) async {
    final res = await _get('/api/reports?tracker_id=$trackerId');
    final j = jsonDecode(res.body);
    return (j['data'] as List).map((r) => DailyReport.fromJson(r)).toList();
  }

  Future<DailyReport?> getReportByDate(
    String date, {
    int? trackerId,
    bool ensure = false,
  }) async {
    final suffix = StringBuffer();
    if (trackerId != null) {
      suffix.write('?tracker_id=$trackerId');
      if (ensure) suffix.write('&ensure=1');
    } else if (ensure) {
      suffix.write('?ensure=1');
    }
    final res = await _get('/api/reports/date/$date${suffix.toString()}');
    final data = _decodeJsonResponse(res, 'Load dated report')['data'];
    if (data == null) {
      return null;
    }
    return DailyReport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Map ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSiteMaps() async {
    final res = await _get('/api/map/sitemaps');
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return (j['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<String?> getMapImageUrl() async {
    final res = await _get('/api/pdf/get-map');
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j['success'] == true) return j['map_url'];
    }
    return null;
  }

  Future<List<dynamic>> getMapStatus(int mapId) async {
    final res = await _get('/api/map/map-status/$mapId');
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j['data'] as List;
    }
    return [];
  }

  Future<Map<String, dynamic>> getReportDetail(int id) async {
    final res = await _get('/api/reports/$id');
    return jsonDecode(res.body)['data'];
  }

  Future<DailyReport?> generateReport(
      {String? date, int? trackerId}) async {
    final body = <String, dynamic>{};
    if (date != null) body['date'] = date;
    if (trackerId != null) body['tracker_id'] = trackerId;
    final res = await _post('/api/reports/generate', body: jsonEncode(body));
    if (res.statusCode == 200) {
      return DailyReport.fromJson(jsonDecode(res.body)['data']);
    }
    return null;
  }

  Future<List<ReviewEntry>> getReviews({required String date, int? trackerId}) async {
    final suffix = trackerId != null ? '&tracker_id=$trackerId' : '';
    final res = await _get('/api/reviews?date=$date$suffix');
    final j = _decodeJsonResponse(res, 'Load reviews');
    return (j['data'] as List).map((entry) => ReviewEntry.fromJson(entry)).toList();
  }

  Future<ReviewEntry?> submitReview({
    required int lbdId,
    required String reviewResult,
    required String reviewDate,
    String? notes,
    int? trackerId,
  }) async {
    final body = <String, dynamic>{
      'lbd_id': lbdId,
      'review_result': reviewResult,
      'review_date': reviewDate,
      'notes': notes ?? '',
    };
    if (trackerId != null) body['tracker_id'] = trackerId;
    final res = await _post('/api/reviews', body: jsonEncode(body));
    if (res.statusCode == 201) {
      return ReviewEntry.fromJson(_decodeJsonResponse(res, 'Submit review')['data']);
    }
    return null;
  }

  Future<List<ReviewEntry>> submitBulkReviews({
    required List<Map<String, dynamic>> reviews,
    required String reviewDate,
    String? notes,
    int? trackerId,
  }) async {
    final body = <String, dynamic>{
      'reviews': reviews,
      'review_date': reviewDate,
      'notes': notes ?? '',
    };
    if (trackerId != null) body['tracker_id'] = trackerId;
    final res = await _post('/api/reviews/bulk', body: jsonEncode(body));
    final j = _decodeJsonResponse(res, 'Submit bulk reviews');
    return (j['data'] as List).map((entry) => ReviewEntry.fromJson(entry)).toList();
  }

  Future<List<ReviewReport>> getReviewReports({int? trackerId}) async {
    final suffix = trackerId != null ? '?tracker_id=$trackerId' : '';
    final res = await _get('/api/review-reports$suffix');
    final j = _decodeJsonResponse(res, 'Load review reports');
    return (j['data'] as List).map((report) => ReviewReport.fromJson(report)).toList();
  }

  Future<Map<String, dynamic>?> getReviewReportByDate(String date, {int? trackerId}) async {
    final suffix = trackerId != null ? '?tracker_id=$trackerId' : '';
    final res = await _get('/api/review-reports/date/$date$suffix');
    final j = _decodeJsonResponse(res, 'Load review report detail');
    return j['data'] as Map<String, dynamic>?;
  }

  Future<ReviewReport?> generateReviewReport({String? date, int? trackerId}) async {
    final body = <String, dynamic>{};
    if (date != null) body['date'] = date;
    if (trackerId != null) body['tracker_id'] = trackerId;
    final res = await _post('/api/review-reports/generate', body: jsonEncode(body));
    if (res.statusCode == 200) {
      return ReviewReport.fromJson(_decodeJsonResponse(res, 'Generate review report')['data']);
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
      final res = await _put('/api/admin/settings/colors', body: jsonEncode(body));
      ok = ok && res.statusCode == 200;
      body.remove('colors');
    }

    if (data['names'] != null) {
      body['names'] = data['names'];
      final res = await _put('/api/admin/settings/names', body: jsonEncode(body));
      ok = ok && res.statusCode == 200;
      body.remove('names');
    }

    return ok;
  }

  Future<bool> updateSiteArea(int areaId, Map<String, dynamic> data) async {
    final res = await _put('/api/map/area/$areaId', body: jsonEncode(data));
    return res.statusCode == 200;
  }

  Future<bool> deleteSiteArea(int areaId) async {
    final res = await _delete('/api/map/area/$areaId');
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> createSiteArea(Map<String, dynamic> data) async {
    final res = await _post('/api/map/area', body: jsonEncode(data));
    if (res.statusCode == 201) {
      final j = jsonDecode(res.body);
      return j['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<Map<String, dynamic>> getUsersPayload() async {
    final res = await _get('/api/auth/users');
    return _decodeJsonResponse(res, 'Load users');
  }

  Future<List<dynamic>> getUsers() async {
    final payload = await getUsersPayload();
    return (payload['users'] as List?) ?? [];
  }

  Future<List<dynamic>> getAuditLogs({int limit = 250}) async {
    final res = await _get('/api/admin/audit-logs?limit=$limit');
    if (res.statusCode == 200) {
      return (jsonDecode(res.body)['data'] as List?) ?? [];
    }
    return [];
  }

  Future<bool> updateUserRole(int userId, String role,
      {List<String> permissions = const []}) async {
    final res = await _put('/api/auth/users/$userId/role',
        body: jsonEncode({'role': role, 'permissions': permissions}));
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
    final res = await _post('/api/auth/users', body: jsonEncode({
        'name': name,
        'pin': pin,
        'job_token': jobToken,
      }));
    return _decodeJsonResponse(res, 'Create user');
  }

  Future<bool> resetUserPin(int userId, String pin) async {
    final res = await _put('/api/auth/users/$userId/pin', body: jsonEncode({'pin': pin}));
    return res.statusCode == 200;
  }

  // ── IFC ───────────────────────────────────────────────

  Future<Uint8List?> getIfcPdf(int blockId) async {
    final res = await _get('/api/tracker/power-blocks/$blockId/ifc');
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    return null;
  }
}
