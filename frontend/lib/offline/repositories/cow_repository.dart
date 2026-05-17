import 'package:drift/drift.dart' show Value, OrderingTerm, InsertMode;
import 'package:uuid/uuid.dart';

import '../../core/models/cow.dart';
import '../../core/service/api_service.dart';
import '../connectivity/connectivity_service.dart';
import '../database/local_database.dart';
import '../sync/sync_queue.dart';

/// Result of a write — surfaced to the UI so it can show a different
/// toast depending on whether the change reached the server.
enum WriteResult {
  /// Server accepted the change synchronously (online write succeeded).
  syncedNow,

  /// Saved locally and queued for the next sync window. The optimistic
  /// row is already visible — the queue will retry until it lands.
  savedOffline,
}

/// Local-first cow store. Reads come from Drift; mutations are written
/// locally first, then either dispatched immediately (when online and
/// reachable) or queued (otherwise). On any network failure the call
/// still returns success — the row is in the local DB, so the UI never
/// has to revert.
class CowRepository {
  CowRepository._();
  static final CowRepository instance = CowRepository._();

  static const _entity = 'Cow';
  final _uuid = const Uuid();
  late LocalDatabase _db;

  Future<void> init(LocalDatabase db) async {
    _db = db;
    SyncQueue.instance.registerSuccessHandler(_entity, _onActionSynced);
  }

  // ---------- Reads ----------

  /// Local snapshot of the active herd. Excludes released rows so the
  /// dairy table doesn't need to filter again.
  Future<List<Cow>> listLocal() async {
    final rows = await (_db.select(_db.localCows)
          ..where((t) => t.releasedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.tag)]))
        .get();
    return rows.map(_toCow).toList();
  }

  /// Pull from the server and overwrite the local mirror. Should be
  /// called on app boot and after the queue drains so reads stay
  /// fresh. Falls back silently when offline — listLocal still works.
  Future<void> refreshFromServer() async {
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final raw = await ApiService.getCows();
      await _db.batch((b) {
        // We don't blow away rows that still have pendingSync = true;
        // those are local-only and haven't reached the server yet.
        b.deleteWhere(_db.localCows, (t) => t.pendingSync.equals(false));
        for (final dynamic m in raw) {
          if (m is! Map) continue;
          final cow = Cow.fromJson(m.cast<String, dynamic>());
          b.insert(
            _db.localCows,
            _cowToCompanion(cow, pendingSync: false),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    } catch (_) {
      // Swallow — refresh is best-effort. The local cache is still the
      // truth from the UI's perspective.
    }
  }

  Stream<List<Cow>> watchLocal() {
    final query = (_db.select(_db.localCows)
          ..where((t) => t.releasedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.tag)]))
        .watch();
    return query.map((rows) => rows.map(_toCow).toList());
  }

  // ---------- Writes ----------

  /// Create a cow. Writes a local row immediately (so the UI updates
  /// without waiting) then either dispatches POST /dairy/cows or
  /// queues it. Returns syncedNow on online success, savedOffline on
  /// queue. Never throws on network failure.
  Future<WriteResult> createCow({
    required Map<String, dynamic> payload,
    required String actorId,
  }) async {
    final localId = _uuid.v4();
    // Best-effort projection of the payload into our local schema.
    // The full row will be re-projected from the server response if
    // the call succeeds online.
    await _db.into(_db.localCows).insert(
          LocalCowsCompanion.insert(
            id: localId,
            tag: payload['tag'] as String,
            nickname: Value(payload['nickname'] as String?),
            breed: Value(payload['breed'] as String?),
            breedOrigin: Value(payload['breedOrigin'] as String?),
            status: payload['status'] as String,
            statusReason: Value(payload['statusReason'] as String?),
            dateOfBirth: Value(
              payload['dateOfBirth'] is String
                  ? DateTime.tryParse(payload['dateOfBirth'])
                  : null,
            ),
            workerId: Value(payload['workerId'] as String?),
            houseId: Value(payload['houseId'] as String?),
            imageUrl: Value(payload['imageUrl'] as String?),
            acquisitionType: Value(payload['acquisitionType'] as String?),
            healthNotes: Value(payload['healthNotes'] as String?),
            pendingSync: const Value(true),
          ),
        );

    return _dispatchOrQueue(
      method: 'POST',
      endpoint: '/dairy/cows',
      payload: payload,
      localRowId: localId,
      actorId: actorId,
      onSyncedInline: (resp) => _hydrateLocalFromServer(localId, resp),
    );
  }

  Future<WriteResult> updateCow({
    required String tag,
    required Map<String, dynamic> payload,
    required String actorId,
  }) async {
    final existing = await (_db.select(_db.localCows)
          ..where((t) => t.tag.equals(tag))
          ..limit(1))
        .getSingleOrNull();
    final localId = existing?.id ?? _uuid.v4();
    final companion = _payloadToCompanion(payload).copyWith(
      id: Value(localId),
      tag: Value(tag),
      pendingSync: const Value(true),
      updatedAt: Value(DateTime.now()),
    );
    await _db
        .into(_db.localCows)
        .insert(companion, mode: InsertMode.insertOrReplace);

    return _dispatchOrQueue(
      method: 'PUT',
      endpoint: '/dairy/cows/tag/$tag',
      payload: payload,
      localRowId: localId,
      actorId: actorId,
      onSyncedInline: (resp) => _hydrateLocalFromServer(localId, resp),
    );
  }

  Future<WriteResult> releaseCow({
    required String tag,
    required Map<String, dynamic> payload,
    required String actorId,
  }) async {
    // Tombstone locally so the cow disappears from the herd table
    // immediately. If the queued action ends up rejected later, the
    // next refreshFromServer brings the row back.
    await (_db.update(_db.localCows)..where((t) => t.tag.equals(tag))).write(
      LocalCowsCompanion(
        releasedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    final local = await (_db.select(_db.localCows)
          ..where((t) => t.tag.equals(tag))
          ..limit(1))
        .getSingleOrNull();
    return _dispatchOrQueue(
      method: 'POST',
      endpoint: '/dairy/cows/tag/$tag/release',
      payload: payload,
      localRowId: local?.id,
      actorId: actorId,
    );
  }

  // ---------- Internals ----------

  Future<WriteResult> _dispatchOrQueue({
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String? localRowId,
    required String actorId,
    Future<void> Function(dynamic response)? onSyncedInline,
  }) async {
    if (ConnectivityService.instance.isOnline) {
      try {
        final resp = await ApiService.rawRequest(
          method: method,
          path: endpoint,
          body: payload,
        );
        if (onSyncedInline != null) await onSyncedInline(resp);
        if (localRowId != null) {
          await (_db.update(_db.localCows)
                ..where((t) => t.id.equals(localRowId)))
              .write(const LocalCowsCompanion(pendingSync: Value(false)));
        }
        return WriteResult.syncedNow;
      } catch (_) {
        // fall through to queue
      }
    }
    await SyncQueue.instance.enqueue(
      id: _uuid.v4(),
      endpoint: endpoint,
      method: method,
      entity: _entity,
      payload: payload,
      localRowId: localRowId,
      actorId: actorId,
    );
    return WriteResult.savedOffline;
  }

  /// Called by SyncQueue when a queued cow action finally lands. We
  /// flip pendingSync off and (for creates) hydrate the local row
  /// with the server's canonical id + computed fields.
  Future<void> _onActionSynced(
    PendingSyncActionData action,
    dynamic responseBody,
  ) async {
    final localRowId = action.localRowId;
    if (localRowId == null) return;
    if (responseBody is Map) {
      await _hydrateLocalFromServer(
        localRowId,
        responseBody.cast<String, dynamic>(),
      );
    } else {
      await (_db.update(_db.localCows)..where((t) => t.id.equals(localRowId)))
          .write(const LocalCowsCompanion(pendingSync: Value(false)));
    }
  }

  Future<void> _hydrateLocalFromServer(
    String localId,
    dynamic response,
  ) async {
    if (response is! Map) return;
    final m = response.cast<String, dynamic>();
    final cow = Cow.fromJson(m);
    await (_db.update(_db.localCows)..where((t) => t.id.equals(localId)))
        .write(
      LocalCowsCompanion(
        serverId: Value(cow.id),
        tag: Value(cow.tag),
        nickname: Value(cow.nickname),
        breed: Value(cow.breed.wire),
        breedOrigin: Value(cow.breedOrigin),
        status: Value(cow.status.wire),
        statusReason: Value(cow.statusReason),
        dateOfBirth: Value(cow.dateOfBirth),
        workerId: Value(cow.workerId),
        workerName: Value(cow.workerName),
        houseId: Value(cow.houseId),
        houseName: Value(cow.houseName),
        imageUrl: Value(cow.imageUrl),
        acquisitionType: Value(cow.acquisitionType),
        healthNotes: Value(cow.healthNotes),
        todayLitres: Value(cow.todayLitres.toDouble()),
        weekAvg: Value(cow.weekAvg.toDouble()),
        calvesLifetime: Value(cow.calvesLifetime),
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Cow _toCow(LocalCowData r) {
    return Cow(
      id: r.serverId ?? r.id,
      tag: r.tag,
      breed: Breed.fromWire(r.breed) ?? Breed.crossbreed,
      dateOfBirth: r.dateOfBirth ?? DateTime.now(),
      status: CowStatus.fromWire(r.status) ?? CowStatus.milking,
      statusReason: r.statusReason,
      todayLitres: r.todayLitres,
      weekAvg: r.weekAvg,
      calvesLifetime: r.calvesLifetime,
      nickname: r.nickname,
      imageUrl: r.imageUrl,
      breedOrigin: r.breedOrigin,
      acquisitionType: r.acquisitionType,
      healthNotes: r.healthNotes,
      workerId: r.workerId,
      workerName: r.workerName,
      houseId: r.houseId,
      houseName: r.houseName,
    );
  }

  LocalCowsCompanion _cowToCompanion(Cow c, {required bool pendingSync}) {
    return LocalCowsCompanion(
      id: Value(c.id),
      serverId: Value(c.id),
      tag: Value(c.tag),
      nickname: Value(c.nickname),
      breed: Value(c.breed.wire),
      breedOrigin: Value(c.breedOrigin),
      status: Value(c.status.wire),
      statusReason: Value(c.statusReason),
      dateOfBirth: Value(c.dateOfBirth),
      workerId: Value(c.workerId),
      workerName: Value(c.workerName),
      houseId: Value(c.houseId),
      houseName: Value(c.houseName),
      imageUrl: Value(c.imageUrl),
      acquisitionType: Value(c.acquisitionType),
      healthNotes: Value(c.healthNotes),
      todayLitres: Value(c.todayLitres.toDouble()),
      weekAvg: Value(c.weekAvg.toDouble()),
      calvesLifetime: Value(c.calvesLifetime),
      pendingSync: Value(pendingSync),
    );
  }

  LocalCowsCompanion _payloadToCompanion(Map<String, dynamic> payload) {
    return LocalCowsCompanion(
      nickname: Value(payload['nickname'] as String?),
      breed: Value(payload['breed'] as String?),
      breedOrigin: Value(payload['breedOrigin'] as String?),
      status: Value(payload['status'] as String? ?? 'MILKING'),
      statusReason: Value(payload['statusReason'] as String?),
      dateOfBirth: Value(
        payload['dateOfBirth'] is String
            ? DateTime.tryParse(payload['dateOfBirth'])
            : null,
      ),
      workerId: Value(payload['workerId'] as String?),
      houseId: Value(payload['houseId'] as String?),
      imageUrl: Value(payload['imageUrl'] as String?),
      acquisitionType: Value(payload['acquisitionType'] as String?),
      healthNotes: Value(payload['healthNotes'] as String?),
    );
  }
}
