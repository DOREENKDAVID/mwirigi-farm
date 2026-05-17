import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_database.g.dart';

/// Local mirror of the server `Cow` row. Only the fields the UI actually
/// renders or sends back are mirrored — extended optional columns can
/// be added later without a migration since SQLite is forgiving.
///
/// `serverId` is null until the row has been synced (offline-created
/// cows start with serverId = null and tag = their chosen tag; the
/// sync engine fills serverId on success). `pendingSync` flags rows
/// whose latest local state has not yet reached the server.
@DataClassName('LocalCowData')
class LocalCows extends Table {
  TextColumn get id => text()(); // local UUID, primary key
  TextColumn get serverId => text().nullable()();
  TextColumn get tag => text()();
  TextColumn get nickname => text().nullable()();
  TextColumn get breed => text().nullable()();
  TextColumn get breedOrigin => text().nullable()();
  TextColumn get status => text()();
  TextColumn get statusReason => text().nullable()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get workerId => text().nullable()();
  TextColumn get workerName => text().nullable()();
  TextColumn get houseId => text().nullable()();
  TextColumn get houseName => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get acquisitionType => text().nullable()();
  TextColumn get healthNotes => text().nullable()();
  RealColumn get todayLitres => real().withDefault(const Constant(0))();
  RealColumn get weekAvg => real().withDefault(const Constant(0))();
  IntColumn get calvesLifetime => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  /// Set when the cow has been released; tombstones it from the active
  /// list without an actual delete (preserves milk history references).
  DateTimeColumn get releasedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per queued mutation that needs to reach the server.
/// Ordered by `createdAt` so retries respect causal ordering (a cow
/// edit must come after its create).
@DataClassName('PendingSyncActionData')
class PendingSyncActions extends Table {
  TextColumn get id => text()(); // local UUID, primary key
  /// e.g. "/dairy/cows" — the relative path under /api.
  TextColumn get endpoint => text()();
  /// HTTP verb: POST | PUT | PATCH | DELETE.
  TextColumn get method => text()();
  /// JSON-encoded request body.
  TextColumn get payload => text()();
  /// Entity name this action mutates (Cow, Bull, BrooderOccurrence...).
  /// Used to map success responses back to the matching local row.
  TextColumn get entity => text()();
  /// Local id of the row this action belongs to (so we can flip
  /// pendingSync = false / patch serverId once the action succeeds).
  TextColumn get localRowId => text().nullable()();
  /// User who originated the action — written to the AuditLog by the
  /// server once it reaches it, but kept locally too so we can show
  /// "queued by X" in the Sync Status page.
  TextColumn get actorId => text().nullable()();
  /// PENDING | IN_FLIGHT | FAILED. Successful actions are deleted from
  /// the table outright; we never need to read the "DONE" state back.
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  /// Last error message — surfaced on the Sync Status page so a user
  /// can see why something is stuck.
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Singleton tracker for the last successful full sync per entity.
/// Drives the "Last synced 2 min ago" line on the Sync Status page.
@DataClassName('SyncStateData')
class SyncStates extends Table {
  TextColumn get entity => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}

@DriftDatabase(tables: [LocalCows, PendingSyncActions, SyncStates])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_open());

  // Bump this when the schema changes.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // Future migrations go here. Keep them additive.
      );

  static QueryExecutor _open() => driftDatabase(
        name: 'mwirigi_farm_offline',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );
}
