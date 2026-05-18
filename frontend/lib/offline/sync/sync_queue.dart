import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/service/api_service.dart';
import '../connectivity/connectivity_service.dart';
import '../database/local_database.dart';

/// Snapshot of the queue's external state, fed to the global banner
/// and the Sync Status page. Cheap to construct and stream so widgets
/// can rebuild on every transition.
class SyncQueueState {
  const SyncQueueState({
    required this.pending,
    required this.inFlight,
    required this.failed,
    required this.syncing,
    this.lastError,
    this.lastSyncedAt,
  });

  final int pending;
  final int inFlight;
  final int failed;
  final bool syncing;
  final String? lastError;
  final DateTime? lastSyncedAt;

  static const empty = SyncQueueState(
    pending: 0,
    inFlight: 0,
    failed: 0,
    syncing: false,
  );
}

/// Result returned by entity-specific success handlers. Lets a
/// repository map the server response back to the local row that
/// triggered the queued action (e.g. patch in the serverId returned
/// by POST /dairy/cows).
typedef OnSuccess = Future<void> Function(
  PendingSyncActionData action,
  dynamic responseBody,
);

/// Singleton FIFO queue that drains itself whenever (a) a new action
/// is added while online, (b) connectivity returns from offline to
/// online, or (c) someone presses the Retry button on the Sync Status
/// page. Actions stay in the local database until they succeed — an
/// app restart picks the queue back up exactly where it left off.
class SyncQueue {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  late LocalDatabase _db;
  final Map<String, OnSuccess> _onSuccess = {};
  final _stateController = StreamController<SyncQueueState>.broadcast();
  StreamSubscription<bool>? _connSub;
  bool _draining = false;
  SyncQueueState _state = SyncQueueState.empty;

  /// 5xx and network errors back off exponentially: 1s, 2s, 4s, … up
  /// to a 5-minute ceiling. 4xx errors (other than auth) are marked
  /// FAILED and skipped — the user has to fix the data or delete the
  /// action from the Sync Status page.
  static const _baseBackoff = Duration(seconds: 1);
  static const _maxBackoff = Duration(minutes: 5);

  SyncQueueState get state => _state;
  Stream<SyncQueueState> get stateStream => _stateController.stream;

  /// Register a per-entity success hook. The repository for each
  /// entity calls this once at app boot so the queue can route
  /// successful responses back to local rows without knowing the
  /// schema itself.
  void registerSuccessHandler(String entity, OnSuccess handler) {
    _onSuccess[entity] = handler;
  }

  /// Wire up the DB + connectivity listener. Idempotent.
  Future<void> start(LocalDatabase db) async {
    _db = db;
    if (_connSub != null) return;
    _connSub = ConnectivityService.instance.stream.listen((online) {
      if (online) _drain();
    });
    await _refreshState();
    if (ConnectivityService.instance.isOnline) {
      // Catch up on anything left over from a previous run.
      unawaited(_drain());
    }
  }

  /// Enqueue a mutation. The caller has already written its
  /// optimistic local state — this just records the intent. Returns
  /// the inserted row's id so a repository can attach more context if
  /// it needs to (e.g. update the localRowId on a follow-up action).
  Future<String> enqueue({
    required String id,
    required String endpoint,
    required String method,
    required String entity,
    Map<String, dynamic>? payload,
    String? localRowId,
    String? actorId,
  }) async {
    await _db.into(_db.pendingSyncActions).insertOnConflictUpdate(
          PendingSyncActionsCompanion(
            id: Value(id),
            endpoint: Value(endpoint),
            method: Value(method.toUpperCase()),
            payload: Value(jsonEncode(payload ?? const {})),
            entity: Value(entity),
            localRowId: Value(localRowId),
            actorId: Value(actorId),
            syncStatus: const Value('PENDING'),
            retryCount: const Value(0),
          ),
        );
    await _refreshState();
    if (ConnectivityService.instance.isOnline) {
      unawaited(_drain());
    }
    return id;
  }

  /// Manually retry every FAILED row. Called by the Retry button.
  Future<void> retryFailed() async {
    await (_db.update(_db.pendingSyncActions)
          ..where((t) => t.syncStatus.equals('FAILED')))
        .write(const PendingSyncActionsCompanion(
      syncStatus: Value('PENDING'),
      retryCount: Value(0),
      lastError: Value(null),
    ));
    await _refreshState();
    if (ConnectivityService.instance.isOnline) {
      unawaited(_drain());
    }
  }

  /// Drop a row from the queue. Used on the Sync Status page when a
  /// user decides to abandon a permanently-broken action.
  Future<void> discard(String id) async {
    await (_db.delete(_db.pendingSyncActions)..where((t) => t.id.equals(id)))
        .go();
    await _refreshState();
  }

  /// Wipe every FAILED row at once. Useful when a role mismatch
  /// caused several actions to permanently fail and the user wants
  /// to start clean rather than discard each row individually.
  Future<int> discardFailed() async {
    final n = await (_db.delete(_db.pendingSyncActions)
          ..where((t) => t.syncStatus.equals('FAILED')))
        .go();
    await _refreshState();
    return n;
  }

  /// Top-level drain. Walks pending rows in createdAt order so a cow
  /// create lands before any edits that depend on its serverId.
  Future<void> _drain() async {
    if (_draining) return;
    if (!ConnectivityService.instance.isOnline) return;
    _draining = true;
    try {
      while (true) {
        if (!ConnectivityService.instance.isOnline) break;
        final next = await (_db.select(_db.pendingSyncActions)
              ..where((t) => t.syncStatus.equals('PENDING'))
              ..orderBy([
                (t) => OrderingTerm(expression: t.createdAt),
              ])
              ..limit(1))
            .getSingleOrNull();
        if (next == null) break;

        await _markInFlight(next.id);
        await _refreshState();
        final ok = await _attempt(next);
        if (!ok) break; // back off; drain again later
      }
    } finally {
      _draining = false;
      await _refreshState();
    }
  }

  Future<bool> _attempt(PendingSyncActionData action) async {
    try {
      final payload = action.payload.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(action.payload) as Map).cast<String, dynamic>();
      final response = await ApiService.rawRequest(
        method: action.method,
        path: action.endpoint,
        body: payload,
      );
      await _onSuccessful(action, response);
      return true;
    } on ApiException catch (e) {
      // Treat duplicate-create as already-synced: the local optimistic
      // row matches the server side, so just remove the queue entry
      // and let the repository's next refresh pull the canonical id.
      if (_looksLikeDuplicate(e)) {
        await _onSuccessful(action, null);
        return true;
      }
      // 4xx (other than auth) means the request is permanently bad —
      // do not retry. 5xx + network errors get exponential backoff.
      final status = e.statusCode ?? 0;
      final permanent = status >= 400 && status < 500 && status != 401;
      await _markFailed(action, e.message, permanent: permanent);
      if (permanent) return true; // keep draining other actions
      await _backoff(action.retryCount);
      return false; // pause; ConnectivityService or retry button resumes
    } catch (e) {
      await _markFailed(action, e.toString(), permanent: false);
      await _backoff(action.retryCount);
      return false;
    }
  }

  bool _looksLikeDuplicate(ApiException e) {
    final s = e.message.toLowerCase();
    return s.contains('already exists') ||
        s.contains('already sold') ||
        s.contains('already released') ||
        s.contains('already assigned');
  }

  Future<void> _onSuccessful(
    PendingSyncActionData action,
    dynamic response,
  ) async {
    final handler = _onSuccess[action.entity];
    if (handler != null) {
      try {
        await handler(action, response);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[sync] success handler for ${action.entity} threw: $e');
        }
      }
    }
    await (_db.delete(_db.pendingSyncActions)
          ..where((t) => t.id.equals(action.id)))
        .go();
    await _db.into(_db.syncStates).insertOnConflictUpdate(
          SyncStatesCompanion(
            entity: Value(action.entity),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> _markInFlight(String id) async {
    await (_db.update(_db.pendingSyncActions)..where((t) => t.id.equals(id)))
        .write(PendingSyncActionsCompanion(
      syncStatus: const Value('IN_FLIGHT'),
      lastAttemptAt: Value(DateTime.now()),
    ));
  }

  Future<void> _markFailed(
    PendingSyncActionData a,
    String error, {
    required bool permanent,
  }) async {
    await (_db.update(_db.pendingSyncActions)..where((t) => t.id.equals(a.id)))
        .write(PendingSyncActionsCompanion(
      syncStatus: Value(permanent ? 'FAILED' : 'PENDING'),
      retryCount: Value(a.retryCount + 1),
      lastError: Value(error),
      lastAttemptAt: Value(DateTime.now()),
    ));
  }

  Future<void> _backoff(int retryCount) async {
    final factor = math.pow(2, math.min(retryCount, 8)).toInt();
    final delay = _baseBackoff * factor;
    final clamped = delay > _maxBackoff ? _maxBackoff : delay;
    await Future.delayed(clamped);
  }

  Future<void> _refreshState() async {
    final pending = await _count(syncStatus: 'PENDING');
    final inFlight = await _count(syncStatus: 'IN_FLIGHT');
    final failed = await _count(syncStatus: 'FAILED');
    final last = await (_db.select(_db.syncStates)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastSyncedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
    _state = SyncQueueState(
      pending: pending,
      inFlight: inFlight,
      failed: failed,
      syncing: inFlight > 0,
      lastSyncedAt: last?.lastSyncedAt,
    );
    _stateController.add(_state);
  }

  Future<int> _count({required String syncStatus}) async {
    final rows = await (_db.select(_db.pendingSyncActions)
          ..where((t) => t.syncStatus.equals(syncStatus)))
        .get();
    return rows.length;
  }

  /// Read all queue rows for the Sync Status page.
  Future<List<PendingSyncActionData>> listAll() async {
    return (_db.select(_db.pendingSyncActions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .get();
  }
}
