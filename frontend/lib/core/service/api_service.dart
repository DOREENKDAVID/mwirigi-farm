import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  // Pick the right host for the runtime target:
  //   • Physical Android/iOS phone on same Wi-Fi → dev machine's LAN IP
  //   • Android emulator                          → 10.0.2.2 (its host alias)
  //   • iOS simulator / Web (Chrome) on this PC   → localhost
  static String get baseUrl =>'https://mwirigi-farm.vercel.app/api';
  //static String get baseUrl => 'http://192.168.0.97:5000/api';
  //static String get baseUrl => 'http://10.0.2.2:5000/api';   // Android emulator
  //static String get baseUrl => 'http://localhost:5000/api';  // simulator / web

  // Used by MaterialApp so we can navigate from outside a widget when a
  // 401 indicates the JWT has expired or been revoked. Wired via
  // `MaterialApp(navigatorKey: ApiService.navigatorKey)` in main.dart.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Re-entrancy guard — a burst of in-flight requests can all 401 at once;
  /// only the first should clear tokens and redirect.
  static bool _redirecting = false;

  static const _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _roleKey = 'auth_role';
  static const _userIdKey = 'auth_user_id';

  // ---------- token storage ----------
  static Future<void> saveToken(String token) =>
      _secureStorage.write(key: _tokenKey, value: token);
  static Future<String?> readToken() =>
      _secureStorage.read(key: _tokenKey);
  static Future<void> deleteToken() =>
      _secureStorage.delete(key: _tokenKey);
  static Future<void> _saveRefresh(String token) =>
      _secureStorage.write(key: _refreshKey, value: token);
  static Future<String?> _readRefresh() =>
      _secureStorage.read(key: _refreshKey);
  static Future<void> _deleteRefresh() =>
      _secureStorage.delete(key: _refreshKey);

  // Role of the currently-authenticated user. Used to gate admin UI.
  static Future<void> _saveRole(String role) =>
      _secureStorage.write(key: _roleKey, value: role);
  static Future<String?> readRole() => _secureStorage.read(key: _roleKey);
  static Future<void> _deleteRole() => _secureStorage.delete(key: _roleKey);

  // User id — persisted on login alongside role so the offline
  // SyncQueue can attach an actor to each queued action.
  static Future<void> _saveUserId(String id) =>
      _secureStorage.write(key: _userIdKey, value: id);
  static Future<String?> readUserId() => _secureStorage.read(key: _userIdKey);
  static Future<void> _deleteUserId() =>
      _secureStorage.delete(key: _userIdKey);

  // ---------- HTTP plumbing ----------
  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final t = await readToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Uri _uri(String path) {
    if (!path.startsWith('/')) path = '/$path';
    return Uri.parse('$baseUrl$path');
  }

  static dynamic _decode(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      try {
        return jsonDecode(resp.body);
      } catch (_) {
        return resp.body;
      }
    }
    String message = 'Request failed (${resp.statusCode})';
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        if (decoded['message'] != null) {
          message = decoded['message'].toString();
        } else if (decoded['error'] != null) {
          message = decoded['error'].toString();
        }
      }
    } catch (_) {}

    // Global 401 handler: kick the user back to /auth if the session is gone.
    // Fire-and-forget — the caller still gets the ApiException so screens
    // can show their normal error UI for cases like wrong-password login.
    if (resp.statusCode == 401) {
      _onUnauthorized(message);
    }

    throw ApiException(message, resp.statusCode);
  }

  /// Called whenever the API returns 401. Idempotent across concurrent
  /// requests via [_redirecting]. If the user has no stored token, this is
  /// almost certainly a login attempt with bad credentials — we don't
  /// redirect (we'd be navigating from /auth to /auth, losing the form).
  static Future<void> _onUnauthorized(String reason) async {
    if (_redirecting) return;
    _redirecting = true;

    try {
      final token = await readToken();
      if (token == null || token.isEmpty) {
        // No active session to log out of; let the caller's error path handle it.
        return;
      }

      // 1. Wipe local credentials so subsequent requests don't reuse them.
      await deleteToken();
      await _deleteRefresh();
      await _deleteRole();
      await _deleteUserId();

      // 2. Redirect to the login screen, removing all routes underneath so
      //    the user can't back-button into a protected page. The
      //    use_build_context_synchronously lint fires here because we're
      //    after `await`s, but `navigatorKey.currentState` returns null
      //    when the navigator is disposed — equivalent to a `mounted`
      //    check, which is why this pattern is safe.
      final nav = navigatorKey.currentState;
      if (nav == null) return;

      // ignore: use_build_context_synchronously
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(
            content: Text(
              reason == 'Token expired'
                  ? 'Your session expired. Please log in again.'
                  : 'Session ended. Please log in again.',
            ),
          ),
        );
      }

      nav.pushNamedAndRemoveUntil('/auth', (route) => false);
    } finally {
      // Cool-down so a stampede of in-flight 401s doesn't repeatedly redirect.
      Future.delayed(const Duration(seconds: 1), () => _redirecting = false);
    }
  }

  static Future<dynamic> _get(String path, {bool auth = true}) async {
    if (kDebugMode) debugPrint('GET $path');
    final r = await http.get(_uri(path), headers: await _headers(auth: auth));
    return _decode(r);
  }

  static Future<dynamic> _post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    if (kDebugMode) debugPrint('POST $path');
    final r = await http.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body ?? {}),
    );
    return _decode(r);
  }

  static Future<dynamic> _put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    if (kDebugMode) debugPrint('PUT $path');
    final r = await http.put(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body ?? {}),
    );
    return _decode(r);
  }

  static Future<dynamic> _patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    if (kDebugMode) debugPrint('PATCH $path');
    final r = await http.patch(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body ?? {}),
    );
    return _decode(r);
  }

  static Future<dynamic> _delete(String path, {bool auth = true}) async {
    if (kDebugMode) debugPrint('DELETE $path');
    final r = await http.delete(_uri(path), headers: await _headers(auth: auth));
    return _decode(r);
  }

  /// Public dispatcher used by the offline SyncQueue. Replays a
  /// previously-queued mutation against the live API exactly as if it
  /// had been issued at the time. Returns the decoded body on 2xx;
  /// raises [ApiException] otherwise.
  static Future<dynamic> rawRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _get(path);
      case 'POST':
        return _post(path, body: body);
      case 'PUT':
        return _put(path, body: body);
      case 'PATCH':
        return _patch(path, body: body);
      case 'DELETE':
        return _delete(path);
      default:
        throw ApiException('Unsupported method: $method');
    }
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic v) => v is List ? v : <dynamic>[];

  // ============== AUTH (/api/auth) ==============

  // POST /auth/login -> { token, refreshToken, user }
  // `identifier` accepts either the user's email or their username.
  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    final res = _asMap(await _post('/auth/login',
        body: {'identifier': identifier, 'password': password}, auth: false));
    if (res['token'] is String) await saveToken(res['token'] as String);
    if (res['refreshToken'] is String) {
      await _saveRefresh(res['refreshToken'] as String);
    }
    final user = res['user'];
    if (user is Map) {
      if (user['role'] is String) {
        await _saveRole(user['role'] as String);
      }
      if (user['id'] is String) {
        await _saveUserId(user['id'] as String);
      }
    }
    return res;
  }

  // POST /auth/google -> { token, refreshToken, user }
  // Mirrors `login()` for token persistence so the rest of the app
  // can't tell whether the user signed in with email or OAuth.
  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final res = _asMap(await _post('/auth/google',
        body: {'idToken': idToken}, auth: false));
    if (res['token'] is String) await saveToken(res['token'] as String);
    if (res['refreshToken'] is String) {
      await _saveRefresh(res['refreshToken'] as String);
    }
    final user = res['user'];
    if (user is Map) {
      if (user['role'] is String) {
        await _saveRole(user['role'] as String);
      }
      if (user['id'] is String) {
        await _saveUserId(user['id'] as String);
      }
    }
    return res;
  }

  // POST /auth/apple -> { token, refreshToken, user }
  static Future<Map<String, dynamic>> appleLogin(String identityToken) async {
    final res = _asMap(await _post('/auth/apple',
        body: {'identityToken': identityToken}, auth: false));
    if (res['token'] is String) await saveToken(res['token'] as String);
    if (res['refreshToken'] is String) {
      await _saveRefresh(res['refreshToken'] as String);
    }
    final user = res['user'];
    if (user is Map) {
      if (user['role'] is String) {
        await _saveRole(user['role'] as String);
      }
      if (user['id'] is String) {
        await _saveUserId(user['id'] as String);
      }
    }
    return res;
  }

  // POST /auth/register -> { message, userId }
  // Public signup: role is always assigned server-side (VET).
  static Future<Map<String, dynamic>> register({
    required String userName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    return _asMap(await _post('/auth/register',
        body: {
          'userName': userName,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
        },
        auth: false));
  }

  // POST /auth/admin/users (CEO only) -> { message, user }
  // Admin staff creation: role is selected by the admin.
  static Future<Map<String, dynamic>> createStaff({
    required String userName,
    required String email,
    required String password,
    required String role,
  }) async {
    return _asMap(await _post('/auth/admin/users', body: {
      'userName': userName,
      'email': email,
      'password': password,
      'role': role,
    }));
  }

  // POST /auth/verify-email  body: { email, enteredOtp }
  static Future<Map<String, dynamic>> verifyEmail(String email, String otp) async {
    return _asMap(await _post('/auth/verify-email',
        body: {'email': email, 'enteredOtp': otp}, auth: false));
  }

  // POST /auth/forgot-password  body: { email }
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return _asMap(await _post('/auth/forgot-password',
        body: {'email': email}, auth: false));
  }

  // POST /auth/reset-password  body: { email, enteredOtp, newPassword }
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    return _asMap(await _post('/auth/reset-password',
        body: {
          'email': email,
          'enteredOtp': otp,
          'newPassword': newPassword,
        },
        auth: false));
  }

  // POST /auth/refresh-token (501 stub on backend right now)
  static Future<Map<String, dynamic>> refreshToken() async {
    final rt = await _readRefresh();
    return _asMap(await _post('/auth/refresh-token',
        body: {'refreshToken': rt}, auth: false));
  }

  // POST /auth/logout  body: { refreshToken }, then wipe local tokens
  static Future<void> logout() async {
    final rt = await _readRefresh();
    try {
      if (rt != null && rt.isNotEmpty) {
        await _post('/auth/logout', body: {'refreshToken': rt}, auth: false);
      }
    } catch (_) {
      // best-effort: continue clearing local tokens regardless
    }
    await deleteToken();
    await _deleteRefresh();
    await _deleteRole();
    await _deleteUserId();
  }

  // GET /auth/admin (CEO only)
  static Future<Map<String, dynamic>> getAdminPing() async =>
      _asMap(await _get('/auth/admin'));

  // GET /auth/management
  static Future<Map<String, dynamic>> getManagementPing() async =>
      _asMap(await _get('/auth/management'));

  // ============== DASHBOARD (/api/dashboard) ==============

  // GET /dashboard -> { success, data }  (legacy stub)
  static Future<Map<String, dynamic>> getDashboardData() async {
    final res = _asMap(await _get('/dashboard'));
    final data = res['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return res;
  }

  // GET /dashboard/overview -> full CEO overview payload
  // (KPIs + goals + alerts + 7-day milk trend + unit performance rows)
  static Future<Map<String, dynamic>> getDashboardOverview() async =>
      _asMap(await _get('/dashboard/overview'));

  // ============== REPORTS (/api/reports) ==============

  static Future<Map<String, dynamic>> getDailySummary({String? date}) async {
    final qs = date == null ? '' : '?date=$date';
    return _asMap(await _get('/reports/daily-summary$qs'));
  }

  static Future<Map<String, dynamic>> getTodayMetrics() async =>
      _asMap(await _get('/reports/today'));

  static Future<Map<String, dynamic>> getAnalyticsDashboard({int? days}) async {
    final qs = days == null ? '' : '?days=$days';
    return _asMap(await _get('/reports/analytics$qs'));
  }

  // CSV body returned as a raw string
  static Future<String> exportDairyMonthlyCsv(String month) async {
    final r = await http.get(_uri('/reports/dairy/monthly/csv?month=$month'),
        headers: await _headers(auth: true));
    if (r.statusCode >= 200 && r.statusCode < 300) return r.body;
    throw ApiException('CSV export failed', r.statusCode);
  }

  // ============== DAIRY (/api/dairy) ==============

  // Cows. Filters compose with AND server-side. `unassigned` is a
  // sentinel value the backend recognises for cows missing the
  // relation (so the UI can show the HTML's "⚠ Unassigned" pill).
  static Future<List<dynamic>> getCows({
    String? workerId,
    String? houseId,
    String? search,
  }) async {
    final qs = <String, String>{};
    if (workerId != null && workerId.isNotEmpty) qs['workerId'] = workerId;
    if (houseId != null && houseId.isNotEmpty) qs['houseId'] = houseId;
    if (search != null && search.isNotEmpty) qs['search'] = search;
    final query = qs.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _asList(
      await _get('/dairy/cows${query.isEmpty ? '' : '?$query'}'),
    );
  }

  static Future<Map<String, dynamic>> getCowByTag(String tag) async =>
      _asMap(await _get('/dairy/cows/tag/$tag'));

  static Future<Map<String, dynamic>> createCow(Map<String, dynamic> data) async =>
      _asMap(await _post('/dairy/cows', body: data));

  static Future<Map<String, dynamic>> updateCow(
          String tag, Map<String, dynamic> data) async =>
      _asMap(await _put('/dairy/cows/tag/$tag', body: data));

  static Future<void> deleteCow(String tag) async {
    await _delete('/dairy/cows/tag/$tag');
  }

  // POST /dairy/cows/tag/:tag/release (CEO/DAIRY_MANAGER)
  // Body: { releaseType, releaseDate?, destination?, reason?, documentUrl? }
  static Future<Map<String, dynamic>> releaseCow(
    String tag,
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/dairy/cows/tag/$tag/release', body: data));

  // Milk records
  static Future<List<dynamic>> getMilkRecords() async =>
      _asList(await _get('/dairy/milk'));

  static Future<List<dynamic>> getMilkRecordsByCow(String cowId) async =>
      _asList(await _get('/dairy/milk/cow/$cowId'));

  static Future<Map<String, dynamic>> createMilkRecord(
          Map<String, dynamic> data) async =>
      _asMap(await _post('/dairy/milk', body: data));

  static Future<void> deleteMilkRecord(String id) async {
    await _delete('/dairy/milk/$id');
  }

  // Dairy dashboard / workers
  static Future<Map<String, dynamic>> getDairyDashboard() async =>
      _asMap(await _get('/dairy/dashboard'));

  // GET /dairy/summary -> { totalCows, milkingToday, milkToday, avgPerCow }
  static Future<Map<String, dynamic>> getDairySummary() async =>
      _asMap(await _get('/dairy/summary'));

  static Future<List<dynamic>> getDairyWorkers() async =>
      _asList(await _get('/dairy/workers'));

  // ============== REPRODUCTION (/api/reproduction) ==============

  // GET /reproduction -> { rows, total, page, limit }
  static Future<Map<String, dynamic>> getReproductionRows({
    String? search,
    String? status,
  }) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) params.add('search=$search');
    if (status != null && status.isNotEmpty) params.add('status=$status');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _asMap(await _get('/reproduction$qs'));
  }

  // POST /reproduction (AI or CALVING; discriminator: eventType)
  static Future<Map<String, dynamic>> createReproductionRecord(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/reproduction', body: data));

  // POST /reproduction/confirm — confirms the cow's most recent AI.
  // Used by the "Pregnancy confirmed" option in the m-repro modal.
  static Future<Map<String, dynamic>> confirmReproductionPregnancy(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/reproduction/confirm', body: data));

  // GET /reproduction/:cowId -> full history for one cow
  static Future<Map<String, dynamic>> getReproductionHistory(String cowId) async =>
      _asMap(await _get('/reproduction/$cowId'));

  // PATCH /reproduction/:id -> update pregnancy status / check date
  static Future<Map<String, dynamic>> updateReproductionRecord(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(await _patch('/reproduction/$id', body: patch));

  // DELETE /reproduction/:id -> soft delete
  static Future<void> deleteReproductionRecord(String id) async {
    await _delete('/reproduction/$id');
  }

  static Future<List<dynamic>> getCowsByWorker(String workerId) async =>
      _asList(await _get('/dairy/workers/$workerId/cows'));

  // POST /dairy/workers/:workerId/reassign-cows (CEO/DAIRY_MANAGER)
  // Bulk-moves every active cow from `fromWorkerId` to the worker in
  // the body. Used when a worker is flipped to unavailable so their
  // herd doesn't sit unassigned during the milking session.
  // Body: { toWorkerId }. Returns { reassigned: <count> }.
  static Future<int> reassignWorkerCows({
    required String fromWorkerId,
    required String toWorkerId,
  }) async {
    final res = _asMap(await _post(
      '/dairy/workers/$fromWorkerId/reassign-cows',
      body: {'toWorkerId': toWorkerId},
    ));
    final n = res['reassigned'];
    return n is int ? n : (n is num ? n.toInt() : 0);
  }

  // ============== LAYERS UNIT (/api/layers-unit) ==============
  //
  // Unified Layers Unit endpoint — one round-trip returns layers (KPIs +
  // houses) + brooder + 7-day production trend + vaccination schedule +
  // allocation plan. All derived state (status, phasingOut) is computed
  // server-side.

  // GET /layers-unit -> { layers, brooder, production, vaccination, allocation }
  static Future<Map<String, dynamic>> getLayersUnit() async =>
      _asMap(await _get('/layers-unit'));

  // ============== LAYERS (/api/layers) ==============
  //
  // Daily production module. Backend is fully authoritative — Flutter never
  // computes trays / percentLaying / closingStock / dayAge.

  // GET /layers/kpis -> { totalBirds, eggsToday, traysToday, avgLayingRate, feedToday, mortalityToday }
  static Future<Map<String, dynamic>> getLayersKpis() async =>
      _asMap(await _get('/layers/kpis'));

  // GET /layers/houses -> [{ id, name, capacity, color }]
  static Future<List<dynamic>> getLayersHouses() async =>
      _asList(await _get('/layers/houses'));

  // GET /layers/snapshot -> [{ houseId, name, color, capacity, currentStock, eggsToday, trays, percentLaying, feedKg, lastEntryDate }]
  static Future<List<dynamic>> getLayersSnapshot() async =>
      _asList(await _get('/layers/snapshot'));

  // GET /layers/trend?days=7 -> [{ date, eggsCollected, percentLaying }]
  static Future<List<dynamic>> getLayersTrend({int days = 7}) async =>
      _asList(await _get('/layers/trend?days=$days'));

  // GET /layers/production/:houseId?days=7 -> { house, records: [...] }
  static Future<Map<String, dynamic>> getLayersProductionForHouse(
    String houseId, {
    int days = 7,
  }) async =>
      _asMap(await _get('/layers/production/$houseId?days=$days'));

  // POST /layers/production body: { houseId, openingStock, eggsCollected, feedKg?, deadRemoved?, remarks?, date? }
  // Server computes trays / percentLaying / closingStock / dayAge.
  // Server also auto-decrements the crate-stock consumable by the
  // delta in crates submitted (egg log → inventory link).
  static Future<Map<String, dynamic>> createLayerProductionEntry(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/layers/production', body: data));

  // ============== FINANCE (/api/finance) ==============
  //
  // CEO-level consolidated dashboard. The payload combines KPI rollups,
  // a per-unit revenue donut slice, and the unit P&L table — all live.

  static Future<Map<String, dynamic>> getFinanceDashboard({
    int? month,
    int? year,
  }) async {
    final params = <String>[];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _asMap(await _get('/finance/dashboard$qs'));
  }

  // ============== REPORTS CATALOG (/api/reports/catalog) ==============
  //
  // Enterprise reports: /catalog lists what the user can access,
  // /catalog/:key generates the report DTO, /catalog/:key.csv streams a
  // CSV download of the first table section.

  static Future<List<dynamic>> getReportsCatalog() async =>
      _asList(await _get('/reports/catalog'));

  static Future<Map<String, dynamic>> getReport(String key) async =>
      _asMap(await _get('/reports/catalog/$key'));

  static Uri reportCsvUri(String key) =>
      _uri('/reports/catalog/$key.csv');

  // ============== REMINDERS (/api/reminders) ==============
  //
  // Reminders are virtual — composed by the backend from existing source
  // tables on every request. `syntheticId` is the stable key for
  // mark-done / snooze / undo (URL-encoded since it contains colons).

  static Future<List<dynamic>> getReminders({
    String? unit,
    String? status,
  }) async {
    final params = <String>[];
    if (unit != null) params.add('unit=${Uri.encodeQueryComponent(unit)}');
    if (status != null) params.add('status=${Uri.encodeQueryComponent(status)}');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _asList(await _get('/reminders$qs'));
  }

  static Future<Map<String, dynamic>> getReminderKpis() async =>
      _asMap(await _get('/reminders/kpis'));

  static Future<Map<String, dynamic>> markReminderDone(
    String syntheticId,
  ) async {
    final id = Uri.encodeComponent(syntheticId);
    return _asMap(await _post('/reminders/$id/done'));
  }

  static Future<Map<String, dynamic>> snoozeReminder(
    String syntheticId,
    int days,
  ) async {
    final id = Uri.encodeComponent(syntheticId);
    return _asMap(
      await _post('/reminders/$id/snooze', body: {'days': days}),
    );
  }

  static Future<void> undoReminder(String syntheticId) async {
    final id = Uri.encodeComponent(syntheticId);
    await _post('/reminders/$id/undo');
  }

  // ============== LAYERS INVENTORY (/api/layers/inventory) ==============

  // Composite payload: items + KPIs + alerts. Drives the Inventory pill
  // header strip and the categorized item list in one round-trip.
  static Future<Map<String, dynamic>> getLayersInventorySummary() async =>
      _asMap(await _get('/layers/inventory/summary'));

  static Future<List<dynamic>> getLayersInventory() async =>
      _asList(await _get('/layers/inventory'));

  static Future<Map<String, dynamic>> createLayersInventoryItem(
    Map<String, dynamic> body,
  ) async =>
      _asMap(_unwrap(await _post('/layers/inventory', body: body)));

  static Future<Map<String, dynamic>> updateLayersInventoryItem(
    String id,
    Map<String, dynamic> body,
  ) async =>
      _asMap(_unwrap(await _patch('/layers/inventory/$id', body: body)));

  static Future<void> deleteLayersInventoryItem(String id) async {
    await _delete('/layers/inventory/$id');
  }

  // -------- legacy (kept so the old /layers screen route still compiles).
  //          The paths below no longer exist on the backend.
  static Future<List<dynamic>> getEggRecords({String? houseId, String? date}) async {
    final params = <String>[];
    if (houseId != null) params.add('houseId=$houseId');
    if (date != null) params.add('date=$date');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _asList(await _get('/layers$qs'));
  }

  static Future<Map<String, dynamic>> getEggRecord(String id) async =>
      _asMap(await _get('/layers/$id'));

  static Future<Map<String, dynamic>> createEggRecord(
          Map<String, dynamic> data) async =>
      _asMap(await _post('/layers', body: data));

  static Future<Map<String, dynamic>> updateEggRecord(
          String id, Map<String, dynamic> data) async =>
      _asMap(await _put('/layers/$id', body: data));

  static Future<void> deleteEggRecord(String id) async {
    await _delete('/layers/$id');
  }

  // ============== PIGGERY (/api/piggery) ==============
  //
  // Daily piggery dashboard. Backend computes all derived values
  // (pigletsMTD, farrowingDue, trend buckets) — Flutter never derives.

  // GET /piggery/kpis -> { totalPigs, totalSows, pigletsMTD, farrowingDue }
  static Future<Map<String, dynamic>> getPiggeryKpis() async =>
      _asMap(await _get('/piggery/kpis'));

  // GET /piggery/sows?search=&house=&status= -> sow rows
  static Future<List<dynamic>> getPiggerySows({
    String? search,
    String? house,
    String? status,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (house != null && house.isNotEmpty) params['house'] = house;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final qs = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return _asList(await _get('/piggery/sows$qs'));
  }

  // GET /piggery/houses
  static Future<List<dynamic>> getPiggeryHouses() async =>
      _asList(await _get('/piggery/houses'));

  // GET /piggery/boars
  static Future<List<dynamic>> getPiggeryBoars() async =>
      _asList(await _get('/piggery/boars'));

  // GET /piggery/litters
  static Future<List<dynamic>> getPiggeryLitters() async =>
      _asList(await _get('/piggery/litters'));

  // GET /piggery/nursery
  static Future<List<dynamic>> getPiggeryNursery() async =>
      _asList(await _get('/piggery/nursery'));

  // GET /piggery/fattening (House E)
  static Future<List<dynamic>> getPiggeryFattening() async =>
      _asList(await _get('/piggery/fattening'));

  // GET /piggery/finishing (House F)
  static Future<List<dynamic>> getPiggeryFinishing() async =>
      _asList(await _get('/piggery/finishing'));

  // GET /piggery/farrowing?limit=
  static Future<List<dynamic>> getPiggeryFarrowing({int limit = 50}) async =>
      _asList(await _get('/piggery/farrowing?limit=$limit'));

  // ---- Litter CRUD ----
  static Future<Map<String, dynamic>> createPiggeryLitter(
          Map<String, dynamic> body) async =>
      _asMap(_unwrap(await _post('/piggery/litters', body: body)));
  static Future<Map<String, dynamic>> updatePiggeryLitter(
          String id, Map<String, dynamic> body) async =>
      _asMap(await _patch('/piggery/litters/$id', body: body));
  static Future<void> deletePiggeryLitter(String id) async {
    await _delete('/piggery/litters/$id');
  }

  // ---- Nursery group CRUD ----
  static Future<Map<String, dynamic>> createPiggeryNursery(
          Map<String, dynamic> body) async =>
      _asMap(_unwrap(await _post('/piggery/nursery', body: body)));
  static Future<Map<String, dynamic>> updatePiggeryNursery(
          String id, Map<String, dynamic> body) async =>
      _asMap(await _patch('/piggery/nursery/$id', body: body));
  static Future<void> deletePiggeryNursery(String id) async {
    await _delete('/piggery/nursery/$id');
  }

  // ---- Fatten pen CRUD (House E + F) ----
  static Future<Map<String, dynamic>> createPiggeryPen(
          Map<String, dynamic> body) async =>
      _asMap(_unwrap(await _post('/piggery/pens', body: body)));
  static Future<Map<String, dynamic>> updatePiggeryPen(
          String id, Map<String, dynamic> body) async =>
      _asMap(await _patch('/piggery/pens/$id', body: body));
  static Future<void> deletePiggeryPen(String id) async {
    await _delete('/piggery/pens/$id');
  }

  // GET /piggery/inventory
  static Future<List<dynamic>> getPiggeryInventory() async =>
      _asList(await _get('/piggery/inventory'));
  static Future<Map<String, dynamic>> createPiggeryInventoryItem(
          Map<String, dynamic> body) async =>
      _asMap(_unwrap(await _post('/piggery/inventory', body: body)));
  static Future<Map<String, dynamic>> updatePiggeryInventoryItem(
          String id, Map<String, dynamic> body) async =>
      _asMap(_unwrap(await _patch('/piggery/inventory/$id', body: body)));
  static Future<void> deletePiggeryInventoryItem(String id) async {
    await _delete('/piggery/inventory/$id');
  }

  // GET /piggery/trend?months=6 -> [{ month, piglets }]
  static Future<List<dynamic>> getPiggeryTrend({int months = 6}) async =>
      _asList(await _get('/piggery/trend?months=$months'));

  // POST /piggery/farrowing
  // Body: { sowId, pigletsBorn, pigletsAlive, pigletsDead, date? }
  static Future<Map<String, dynamic>> logFarrowing(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/piggery/farrowing', body: data));

  // POST /piggery/pigs (CEO/PIGGERY_MANAGER) — register a new pig
  static Future<Map<String, dynamic>> createPig(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/piggery/pigs', body: data));

  // PATCH /piggery/pigs/:id (CEO/PIGGERY_MANAGER)
  // Body: { status?, dueDate?, litterCount? } — null clears status/dueDate
  static Future<Map<String, dynamic>> updatePig(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(await _patch('/piggery/pigs/$id', body: patch));

  // DELETE /piggery/pigs/:id (soft delete) — CEO/PIGGERY_MANAGER
  static Future<void> deletePig(String id) async {
    await _delete('/piggery/pigs/$id');
  }

  // ============== FEEDLOT (/api/feedlot) ==============
  //
  // Backend computes ADG, daysOnFeed, daysLeft, status for every bull
  // returned. Flutter never derives those values.

  // GET /feedlot/kpis -> { bullsOnFeed, avgDaysOnFeed, doopersFlock, lambsThisMonth }
  static Future<Map<String, dynamic>> getFeedlotKpis() async =>
      _asMap(await _get('/feedlot/kpis'));

  // GET /feedlot/bulls -> [{ id, tag, breed, entryDate, entryWeight, currentWeight, adg, daysOnFeed, daysLeft, status }]
  static Future<List<dynamic>> getFeedlotBulls() async =>
      _asList(await _get('/feedlot/bulls'));

  // POST /feedlot/bulls (CEO/VET)
  // Body: { tag, breed, entryDate, entryWeight }
  static Future<Map<String, dynamic>> createBull(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/feedlot/bulls', body: data));

  // POST /feedlot/weights (CEO/VET)
  // Body: { bullId, weight, date? }
  static Future<Map<String, dynamic>> logBullWeight(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/feedlot/weights', body: data));

  // PATCH /feedlot/bulls/:id (CEO/VET)
  // Body: { breed?, currentWeight? } — currentWeight changes are audited.
  static Future<Map<String, dynamic>> updateBull(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(await _patch('/feedlot/bulls/$id', body: patch));

  // DELETE /feedlot/bulls/:id (soft) — CEO/VET
  static Future<void> deleteBull(String id) async {
    await _delete('/feedlot/bulls/$id');
  }

  // POST /feedlot/bulls/:id/sell (CEO/VET)
  // Body: { saleDate?, soldWeightKg, salePrice, buyerName, buyerPhone?,
  //         paymentMethod?, saleNotes? }
  // Backend auto-creates a Revenue row (ANIMAL_SALES, Feedlot) in the
  // same transaction so the finance cashflow updates atomically.
  static Future<Map<String, dynamic>> sellBull(
    String id,
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/feedlot/bulls/$id/sell', body: data));

  // POST /feedlot/sheep/:id/sell (CEO/VET) — mirror of sellBull.
  // Same auto-Revenue side-effect but unit Doopers. Weight is optional
  // for sheep since lambs aren't always weighed at sale.
  static Future<Map<String, dynamic>> sellSheep(
    String id,
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/feedlot/sheep/$id/sell', body: data));

  // GET /feedlot/sheep -> [{ id, tag, category, entryDate, entryWeight }]
  static Future<List<dynamic>> getFeedlotSheep() async =>
      _asList(await _get('/feedlot/sheep'));

  // POST /feedlot/sheep (CEO/VET) — register one tagged dooper
  // Body: { tag, category, entryDate, entryWeight? }
  static Future<Map<String, dynamic>> createSheep(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/feedlot/sheep', body: data));

  // PATCH /feedlot/sheep/:id (CEO/VET) — update category and/or
  // currentWeight. ADG is recomputed server-side on every read.
  static Future<Map<String, dynamic>> updateSheep(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(await _patch('/feedlot/sheep/$id', body: patch));

  // DELETE /feedlot/sheep/:id (soft) — CEO/VET
  static Future<void> deleteSheep(String id) async {
    await _delete('/feedlot/sheep/$id');
  }

  // POST /feedlot/lambing (CEO/VET)
  // Body: { lambsBorn, date? }
  static Future<Map<String, dynamic>> logLambing(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/feedlot/lambing', body: data));

  // GET /feedlot/lambing?month=current  ('current' or 'YYYY-MM')
  static Future<List<dynamic>> getFeedlotLambing({
    String month = 'current',
  }) async =>
      _asList(await _get('/feedlot/lambing?month=$month'));

  // ============== HEALTH & VACCINES (/api/health) ==============
  //
  // Cross-unit health dashboard. Backend is fully authoritative — Flutter
  // never computes vaccine status, due dates, brooder age, compliance,
  // or treatment day-counts.

  // GET /health/kpis -> { vaccinesDue7d, underTreatment, underTreatmentByUnit, complianceRate }
  static Future<Map<String, dynamic>> getHealthKpis() async =>
      _asMap(await _get('/health/kpis'));

  // GET /health/vaccinations -> [{ vaccine, unit, animals, lastDone, nextDue, status, ... }]
  // `unit` filters server-side to a single HealthUnit (e.g. 'Dairy',
  // 'Layers'). The Dairy module's vaccination pill consumes this.
  static Future<List<dynamic>> getHealthVaccinations({String? unit}) async {
    final qs = unit == null ? '' : '?unit=${Uri.encodeQueryComponent(unit)}';
    return _asList(await _get('/health/vaccinations$qs'));
  }

  // POST /health/vaccinations body: { protocolId, animalCount, administeredAt, nextDueOverride?, notes? }
  static Future<Map<String, dynamic>> createHealthVaccination(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/health/vaccinations', body: data));

  // GET /health/protocols -> [{ id, name, unit, type, species }]  (CEO/VET/ADMIN)
  static Future<List<dynamic>> getHealthProtocols() async =>
      _asList(await _get('/health/protocols'));

  // GET /health/treatments?activeOnly=true -> [{ id, tag, unit, diagnosis, medication, startDate, status, statusLabel, ... }]
  static Future<List<dynamic>> getHealthTreatments({
    bool activeOnly = true,
  }) async =>
      _asList(await _get('/health/treatments?activeOnly=$activeOnly'));

  // POST /health/treatments body: { tag, unit, diagnosis, medication, startDate, attendingVet?, notes? }
  static Future<Map<String, dynamic>> createHealthTreatment(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/health/treatments', body: data));

  // PATCH /health/treatments/:id body: { diagnosis?, medication?, status?, endDate?, notes? }
  static Future<Map<String, dynamic>> updateHealthTreatment(
    String id,
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _patch('/health/treatments/$id', body: data));

  // GET /health/protocol-reference -> { chicks: [...], calves: [...], piglets: [...] }
  static Future<Map<String, dynamic>> getHealthProtocolReference() async =>
      _asMap(await _get('/health/protocol-reference'));

  // ============== STAFF & LABOUR (/api/staff) ==============
  //
  // HR-focused module. The User table is the source of truth; staff are just
  // users with HR fields populated. The legacy `Worker` model is preserved
  // for animal-husbandry house assignments but no longer surfaced here.

  // GET /staff/dashboard -> { totalStaff, presentToday, absentToday,
  //                          monthlyPayroll, attendance, tasks, payroll }
  static Future<Map<String, dynamic>> getStaffDashboard() async =>
      _asMap(await _get('/staff/dashboard'));

  // GET /staff -> [{ id, fullName, email, role, ... }]
  static Future<List<dynamic>> getStaffList() async =>
      _asList(await _get('/staff'));

  // POST /staff (CEO/ADMIN) -> { staff, tempPassword }
  // Renamed from `createStaff` to avoid collision with the older
  // `/auth/admin/users` helper that already uses that name.
  static Future<Map<String, dynamic>> createStaffMember(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/staff', body: data));

  // PATCH /staff/:id (CEO/ADMIN)
  static Future<Map<String, dynamic>> updateStaff(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(await _patch('/staff/$id', body: patch));

  // DELETE /staff/:id (soft — sets isActive=false; CEO/ADMIN)
  static Future<void> deactivateStaff(String id) async {
    await _delete('/staff/$id');
  }

  // POST /staff/attendance — admin marks attendance for a user
  static Future<Map<String, dynamic>> markStaffAttendance(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/staff/attendance', body: data));

  // POST /staff/tasks — assign a task
  static Future<Map<String, dynamic>> createStaffTask(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/staff/tasks', body: data));

  // PATCH /staff/tasks/:id — update status / fields
  static Future<Map<String, dynamic>> updateStaffTask(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(await _patch('/staff/tasks/$id', body: patch));

  // DELETE /staff/tasks/:id
  static Future<void> deleteStaffTask(String id) async {
    await _delete('/staff/tasks/$id');
  }

  // POST /staff/tasks/:id/reassign — swap a task to a new assignee with
  // an audit row. Body: { toUserId, reason, duration?, effectiveDate?,
  //                       notes?, approvalRequired? }
  static Future<Map<String, dynamic>> reassignStaffTask(
    String id,
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/staff/tasks/$id/reassign', body: data));

  // PATCH /staff/workers/:id/availability — flip a worker's status to
  // SICK_LEAVE / OFF_DAY / etc. so the assignment UI greys them out.
  static Future<Map<String, dynamic>> setWorkerAvailability(
    String workerId,
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _patch('/staff/workers/$workerId/availability', body: data));

  // POST /layers/brooder/occurrences — log a brooder incident
  static Future<Map<String, dynamic>> logBrooderOccurrence(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/layers/brooder/occurrences', body: data));

  // GET /layers/brooder/occurrences?brooderId=...
  static Future<List<dynamic>> getBrooderOccurrences(String brooderId) async =>
      _asList(await _get('/layers/brooder/occurrences?brooderId=$brooderId'));

  // GET /layers/brooder/occurrences/weekly?brooderId=...
  static Future<Map<String, dynamic>> getBrooderWeeklyReport(
    String brooderId,
  ) async =>
      _asMap(
        await _get('/layers/brooder/occurrences/weekly?brooderId=$brooderId'),
      );

  // POST /layers/brooder/allocations (CEO, LAYERS_MANAGER)
  // Body: { brooderId, type: 'POL_SALE'|'REPLACEMENT', birds, description, reason? }
  static Future<Map<String, dynamic>> createAllocationPlan(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/layers/brooder/allocations', body: data));

  // GET /layers/brooder/allocations/history?brooderId=...
  static Future<List<dynamic>> getAllocationHistory(String brooderId) async =>
      _asList(
        await _get(
          '/layers/brooder/allocations/history?brooderId=$brooderId',
        ),
      );

  // POST /staff/payroll/process (ADMIN/CEO) — marks all rows PAID
  static Future<Map<String, dynamic>> processStaffPayroll() async =>
      _asMap(await _post('/staff/payroll/process'));

  // ============== PAYROLL ADJUSTMENTS (/api/staff/payroll/adjustments) ==============
  //
  // Advances, bonuses, penalties, overtime. The Payroll dashboard
  // already nests adjustments inside each row (`PayrollRow.adjustments`)
  // so the table reads them straight from /staff/dashboard. These
  // endpoints are write-paths only.

  static Future<List<dynamic>> listPayrollAdjustments({
    String? userId,
    int? month,
    int? year,
    String? status,
  }) async {
    final params = <String>[];
    if (userId != null) params.add('userId=${Uri.encodeQueryComponent(userId)}');
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    if (status != null) params.add('status=${Uri.encodeQueryComponent(status)}');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _asList(await _get('/staff/payroll/adjustments$qs'));
  }

  static Future<Map<String, dynamic>> createPayrollAdjustment(
    Map<String, dynamic> body,
  ) async =>
      _asMap(await _post('/staff/payroll/adjustments', body: body));

  static Future<Map<String, dynamic>> updatePayrollAdjustment(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(await _patch('/staff/payroll/adjustments/$id', body: patch));

  static Future<void> deletePayrollAdjustment(String id) async {
    await _delete('/staff/payroll/adjustments/$id');
  }

  // ============== NGUSHISH (/api/ngushish) ==============
  //
  // Horticulture / irrigation / fodder. Unlike the older modules, these
  // endpoints wrap responses in a {success, message, data} envelope, so
  // every method here unwraps `data` before returning.

  static dynamic _unwrap(dynamic raw) {
    if (raw is Map && raw.containsKey('data')) return raw['data'];
    return raw;
  }

  // GET /ngushish/dashboard
  static Future<Map<String, dynamic>> getNgushishDashboard() async =>
      _asMap(_unwrap(await _get('/ngushish/dashboard')));

  // ---- Ngushish inventory CRUD ----
  static Future<List<dynamic>> getNgushishInventory() async =>
      _asList(_unwrap(await _get('/ngushish/inventory')));
  static Future<Map<String, dynamic>> createNgushishInventoryItem(
          Map<String, dynamic> body) async =>
      _asMap(_unwrap(await _post('/ngushish/inventory', body: body)));
  static Future<Map<String, dynamic>> updateNgushishInventoryItem(
          String id, Map<String, dynamic> body) async =>
      _asMap(_unwrap(await _patch('/ngushish/inventory/$id', body: body)));
  static Future<void> deleteNgushishInventoryItem(String id) async {
    await _delete('/ngushish/inventory/$id');
  }

  // GET /ngushish/crops?search=&status=&irrigated=&page=&limit=
  // Returns { items: [...], pagination: {...} }
  static Future<Map<String, dynamic>> getNgushishCrops({
    String? search,
    String? status,
    bool? irrigated,
    int page = 1,
    int limit = 20,
  }) async {
    final qs = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.isNotEmpty) qs['search'] = search;
    if (status != null && status.isNotEmpty) qs['status'] = status;
    if (irrigated != null) qs['irrigated'] = irrigated ? 'true' : 'false';
    final query = qs.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _asMap(_unwrap(await _get('/ngushish/crops?$query')));
  }

  // GET /ngushish/crops/:id
  static Future<Map<String, dynamic>> getNgushishCropById(String id) async =>
      _asMap(_unwrap(await _get('/ngushish/crops/$id')));

  // POST /ngushish/crops
  static Future<Map<String, dynamic>> createNgushishCrop(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/ngushish/crops', body: data)));

  // PATCH /ngushish/crops/:id
  static Future<Map<String, dynamic>> updateNgushishCrop(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(_unwrap(await _patch('/ngushish/crops/$id', body: patch)));

  // DELETE /ngushish/crops/:id (soft)
  static Future<void> deleteNgushishCrop(String id) async {
    await _delete('/ngushish/crops/$id');
  }

  // POST /ngushish/harvests
  static Future<Map<String, dynamic>> createNgushishHarvest(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/ngushish/harvests', body: data)));

  // GET /ngushish/harvests?cropId=&from=&to=&page=&limit=
  static Future<Map<String, dynamic>> getNgushishHarvests({
    String? cropId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 50,
  }) async {
    final qs = <String, String>{'page': '$page', 'limit': '$limit'};
    if (cropId != null) qs['cropId'] = cropId;
    if (from != null) qs['from'] = from.toIso8601String();
    if (to != null) qs['to'] = to.toIso8601String();
    final query = qs.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _asMap(_unwrap(await _get('/ngushish/harvests?$query')));
  }

  // POST /ngushish/dispatches
  static Future<Map<String, dynamic>> createNgushishDispatch(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/ngushish/dispatches', body: data)));

  // GET /ngushish/dispatches
  static Future<Map<String, dynamic>> getNgushishDispatches({
    String? cropId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 50,
  }) async {
    final qs = <String, String>{'page': '$page', 'limit': '$limit'};
    if (cropId != null) qs['cropId'] = cropId;
    if (from != null) qs['from'] = from.toIso8601String();
    if (to != null) qs['to'] = to.toIso8601String();
    final query = qs.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _asMap(_unwrap(await _get('/ngushish/dispatches?$query')));
  }

  // POST /ngushish/irrigation
  static Future<Map<String, dynamic>> createNgushishIrrigation(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/ngushish/irrigation', body: data)));

  // GET /ngushish/irrigation
  static Future<Map<String, dynamic>> getNgushishIrrigation({
    String? cropId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 50,
  }) async {
    final qs = <String, String>{'page': '$page', 'limit': '$limit'};
    if (cropId != null) qs['cropId'] = cropId;
    if (from != null) qs['from'] = from.toIso8601String();
    if (to != null) qs['to'] = to.toIso8601String();
    final query = qs.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _asMap(_unwrap(await _get('/ngushish/irrigation?$query')));
  }

  // ============== FEEDS (/api/feeds) ==============
  //
  // Same envelope as Ngushish: backend returns {success, message, data} so
  // we reuse `_unwrap`. Status (CRITICAL/LOW/ADEQUATE) and daysLeft come
  // pre-computed from /materials — never re-derived here.

  // GET /feeds/dashboard
  static Future<Map<String, dynamic>> getFeedsDashboard() async =>
      _asMap(_unwrap(await _get('/feeds/dashboard')));

  // GET /feeds/materials?search=&status=&category=&page=&limit=
  // Returns { items: [...], pagination: {...} }
  static Future<Map<String, dynamic>> getFeedMaterials({
    String? search,
    String? status,
    String? category,
    int page = 1,
    int limit = 50,
  }) async {
    final qs = <String, String>{'page': '$page', 'limit': '$limit'};
    if (search != null && search.isNotEmpty) qs['search'] = search;
    if (status != null && status.isNotEmpty) qs['status'] = status;
    if (category != null && category.isNotEmpty) qs['category'] = category;
    final query = qs.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _asMap(_unwrap(await _get('/feeds/materials?$query')));
  }

  // GET /feeds/materials/:id
  static Future<Map<String, dynamic>> getFeedMaterialById(String id) async =>
      _asMap(_unwrap(await _get('/feeds/materials/$id')));

  // POST /feeds/materials
  static Future<Map<String, dynamic>> createFeedMaterial(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/feeds/materials', body: data)));

  // PATCH /feeds/materials/:id (metadata only — stock/dailyUse aren't
  // patchable here; use /deliveries and /consumption respectively).
  static Future<Map<String, dynamic>> updateFeedMaterial(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(_unwrap(await _patch('/feeds/materials/$id', body: patch)));

  // DELETE /feeds/materials/:id (soft).
  static Future<void> deleteFeedMaterial(String id) async {
    await _delete('/feeds/materials/$id');
  }

  // POST /feeds/deliveries — atomically bumps stockOnHandKg.
  static Future<Map<String, dynamic>> createFeedDelivery(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/feeds/deliveries', body: data)));

  // GET /feeds/deliveries
  static Future<Map<String, dynamic>> getFeedDeliveries({
    String? materialId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 50,
  }) async {
    final qs = <String, String>{'page': '$page', 'limit': '$limit'};
    if (materialId != null) qs['materialId'] = materialId;
    if (from != null) qs['from'] = from.toIso8601String();
    if (to != null) qs['to'] = to.toIso8601String();
    final query = qs.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _asMap(_unwrap(await _get('/feeds/deliveries?$query')));
  }

  // POST /feeds/consumption — atomically updates dailyUseKg.
  static Future<Map<String, dynamic>> createFeedConsumption(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/feeds/consumption', body: data)));

  // POST /feeds/consumption/bulk — array of {materialId, quantityUsedKg,
  // durationDays, notes?} entries. All-or-nothing transaction.
  static Future<Map<String, dynamic>> createFeedConsumptionBulk(
    List<Map<String, dynamic>> entries,
  ) async =>
      _asMap(_unwrap(
        await _post('/feeds/consumption/bulk', body: {'entries': entries}),
      ));

  // GET /feeds/bulk-feed
  static Future<List<dynamic>> getBulkFeed() async =>
      _asList(_unwrap(await _get('/feeds/bulk-feed')));

  // PATCH /feeds/bulk-feed/:id
  static Future<Map<String, dynamic>> updateBulkFeed(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      _asMap(_unwrap(await _patch('/feeds/bulk-feed/$id', body: patch)));

  // GET /feeds/distribution — latest row per livestock unit.
  static Future<List<dynamic>> getFeedDistribution() async =>
      _asList(_unwrap(await _get('/feeds/distribution')));

  // POST /feeds/distribution — upsert keyed on livestockUnit.
  static Future<Map<String, dynamic>> upsertFeedDistribution(
    Map<String, dynamic> data,
  ) async =>
      _asMap(_unwrap(await _post('/feeds/distribution', body: data)));

  // ============== DAIRY OPS (Phase 4 + 5) ==============
  //
  // Worker-centric milk-logging endpoints introduced in the v4.1
  // refactor. Backend computes 7-day averages + below-average flags.

  // GET /dairy/houses/overview — used by the Houses overview grid.
  static Future<List<dynamic>> getDairyHousesOverview() async =>
      _asList(await _get('/dairy/houses/overview'));

  // (`getDairyWorkers` and `getCowsByWorker` already exist above — they
  // were stubs returning [], the backend now serves real data.)

  // GET /dairy/milk/sessions/today — per-worker / per-session view with
  // entries, trailing-7d averages, and below-avg flags.
  static Future<Map<String, dynamic>> getDairyTodaySessions({
    double? threshold,
  }) async {
    final qs = threshold == null ? '' : '?threshold=$threshold';
    return _asMap(await _get('/dairy/milk/sessions/today$qs'));
  }

  // GET /dairy/milk/summary/today — gross / net (calf + household
  // deductions applied).
  static Future<Map<String, dynamic>> getDairyTodayNet() async =>
      _asMap(await _get('/dairy/milk/summary/today'));

  // PATCH /dairy/config/deductions — admin-set the calf + household
  // deductions used by the session summary. Pass calfDeduction = 0 to
  // revert the override and use the live count of calving events.
  // Body: { calfDeduction?, householdDeduct? }.
  static Future<Map<String, dynamic>> updateMilkDeductions(
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _patch('/dairy/config/deductions', body: data));

  // POST /dairy/milk/sessions — atomic bulk submit. Idempotent on
  // (cow, date, session): re-submitting overwrites the prior litres.
  // Returns the refreshed today-sessions slice in `data`.
  static Future<Map<String, dynamic>> submitDairyMilkSession({
    required String workerId,
    required String session, // 'AM' | 'MID' | 'PM'
    DateTime? date,
    required List<Map<String, dynamic>> entries,
  }) async {
    final body = <String, dynamic>{
      'workerId': workerId,
      'session': session,
      'entries': entries,
    };
    if (date != null) body['date'] = date.toIso8601String();
    return _asMap(await _post('/dairy/milk/sessions', body: body));
  }

  // GET /dairy/calves — flat list of CALVING records joined with the dam
  // (and, when matched, the calf cow). Backend computes ageDays + stage.
  static Future<List<dynamic>> getDairyCalves() async =>
      _asList(await _get('/dairy/calves'));

  // POST /dairy/calves/:id/dispose — record a calf disposition (sold,
  // died, transferred…). Body matches calfDispositionSchema on the
  // server: { type, date?, party?, amount?, receipt?, witness?, notes? }.
  // PDF receipt for sales is generated client-side from the same data.
  static Future<Map<String, dynamic>> disposeCalf(
    String recordId,
    Map<String, dynamic> data,
  ) async =>
      _asMap(await _post('/dairy/calves/$recordId/dispose', body: data));

  // GET /dairy/milk/trend/daily — N days of milk totals (default 7).
  // Each row: { date, dow, litres }. Drives the bar chart pill.
  static Future<List<dynamic>> getDailyMilkTrend({int days = 7}) async =>
      _asList(await _get('/dairy/milk/trend/daily?days=$days'));

  // ============== DAIRY INVENTORY ==============

  static Future<List<dynamic>> getDairyInventory() async =>
      _asList(await _get('/dairy/inventory'));

  static Future<Map<String, dynamic>> createDairyInventoryItem(
    Map<String, dynamic> body,
  ) async =>
      _asMap(_unwrap(await _post('/dairy/inventory', body: body)));

  static Future<Map<String, dynamic>> updateDairyInventoryItem(
    String id,
    Map<String, dynamic> body,
  ) async =>
      _asMap(_unwrap(await _patch('/dairy/inventory/$id', body: body)));

  static Future<void> deleteDairyInventoryItem(String id) async {
    await _delete('/dairy/inventory/$id');
  }

  // ============== FEEDLOT INVENTORY ==============

  static Future<List<dynamic>> getFeedlotInventory() async =>
      _asList(await _get('/feedlot/inventory'));

  static Future<Map<String, dynamic>> createFeedlotInventoryItem(
    Map<String, dynamic> body,
  ) async =>
      _asMap(_unwrap(await _post('/feedlot/inventory', body: body)));

  static Future<Map<String, dynamic>> updateFeedlotInventoryItem(
    String id,
    Map<String, dynamic> body,
  ) async =>
      _asMap(_unwrap(await _patch('/feedlot/inventory/$id', body: body)));

  static Future<void> deleteFeedlotInventoryItem(String id) async {
    await _delete('/feedlot/inventory/$id');
  }

  // ============== UPLOADS (/api/uploads) ==============
  //
  // Cow image upload. Pass the raw bytes from a file picker; the
  // server stores under /uploads/cows/<uuid>.<ext> and returns the
  // public path which the UI prepends with `assetUrl()` to render.
  static Future<String> uploadCowImage({
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final uri = _uri('/uploads/cows');
    final headers = await _headers(auth: true);
    headers.remove('Content-Type'); // multipart sets its own boundary

    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(headers);
    req.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
      contentType: _parseContentType(contentType),
    ));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    final decoded = _decode(resp);
    final data = (decoded is Map && decoded['data'] is Map)
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : <String, dynamic>{};
    final url = data['imageUrl'];
    if (url is String && url.isNotEmpty) return url;
    throw ApiException('Upload succeeded but no imageUrl returned');
  }

  // Resolve a relative `/uploads/...` path to an absolute URL the
  // Flutter Image widget can fetch. Pass-through for absolute URLs
  // (e.g. the dicebear placeholders the seed uses).
  static String assetUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$base$path';
  }

  // http.MultipartFile expects MediaType from the http_parser package
  // (transitively available via http). We construct it from the
  // content-type string the file picker reports.
  static MediaType? _parseContentType(String ct) {
    final parts = ct.split('/');
    if (parts.length != 2) return null;
    return MediaType(parts[0], parts[1]);
  }
}
