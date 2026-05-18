// Dairy operations domain models — backs the milk-logging workflow
// (session tabs · worker bar · cow grid) and the Houses overview grid.
//
// Source endpoints:
//   GET  /api/dairy/houses/overview        → List<DairyHouseOverview>
//   GET  /api/dairy/workers                → List<DairyWorker>
//   GET  /api/dairy/milk/sessions/today    → TodaySessions
//   GET  /api/dairy/milk/summary/today     → DayNetSummary
//   POST /api/dairy/milk/sessions          → submit a session (returns refreshed today-view)
//
// Per project convention, the backend computes all derived state
// (per-session totals, below-avg flagging, day net). Flutter only renders.

import 'package:flutter/material.dart';

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? _toDoubleNullable(dynamic v) {
  if (v == null) return null;
  return _toDouble(v);
}

// Session enum — matches the backend SessionType (AM | MID | PM).
enum MilkSession {
  // Order here drives the order of pills in the session tab row.
  // Dawn is the 3am milking, AM the 9am, Midday the 12pm, PM the 5pm.
  dawn('DAWN', 'Dawn'),
  am('AM', 'AM'),
  mid('MID', 'Midday'),
  pm('PM', 'PM');

  const MilkSession(this.wire, this.label);
  final String wire;
  final String label;

  static MilkSession fromWire(String s) =>
      MilkSession.values.firstWhere(
        (m) => m.wire == s,
        orElse: () => MilkSession.am,
      );
}

class DairyHouseOverview {
  DairyHouseOverview({
    required this.id,
    required this.name,
    required this.color,
    required this.totalCows,
    required this.milkingCount,
    required this.litresToday,
    required this.workers,
    required this.status,
  });

  final String id;
  final String name;
  final String color;
  final int totalCows;
  final int milkingCount;
  final double litresToday;
  final List<({String id, String name})> workers;
  final String status; // EMPTY · DRY · PARTIAL · ALL_MILKING · MATERNITY

  Color parsedColor() {
    final s = color.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0x27500A;
    return Color(0xFF000000 | v);
  }

  factory DairyHouseOverview.fromJson(Map<String, dynamic> j) =>
      DairyHouseOverview(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        color: (j['color'] ?? '#27500A').toString(),
        totalCows: _toInt(j['totalCows']),
        milkingCount: _toInt(j['milkingCount']),
        litresToday: _toDouble(j['litresToday']),
        workers: ((j['workers'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => (
                  id: (m['id'] ?? '').toString(),
                  name: (m['name'] ?? '').toString(),
                ))
            .toList(),
        status: (j['status'] ?? 'EMPTY').toString(),
      );
}

/// Operational availability flag on a Worker. AVAILABLE is the default;
/// any other value greys the worker out in task / shift pickers.
enum WorkerAvailability {
  available('AVAILABLE', 'Available'),
  sickLeave('SICK_LEAVE', 'Sick leave'),
  offDay('OFF_DAY', 'Off day'),
  vacation('VACATION', 'Vacation'),
  emergency('EMERGENCY', 'Emergency'),
  otherUnavailable('OTHER_UNAVAILABLE', 'Other (unavailable)');

  const WorkerAvailability(this.wire, this.label);
  final String wire;
  final String label;

  bool get isAvailable => this == WorkerAvailability.available;

  static WorkerAvailability fromWire(String? s) {
    if (s == null) return WorkerAvailability.available;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return WorkerAvailability.available;
  }
}

class DairyWorkerSummary {
  DairyWorkerSummary({
    required this.id,
    required this.name,
    required this.cowCount,
    this.role,
    this.houseName,
    this.availability = WorkerAvailability.available,
    this.availabilityNote,
  });
  final String id;
  final String name;
  final int cowCount;
  final String? role;
  final String? houseName;
  final WorkerAvailability availability;
  final String? availabilityNote;

  factory DairyWorkerSummary.fromJson(Map<String, dynamic> j) {
    final house = j['house'];
    return DairyWorkerSummary(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      cowCount: _toInt(j['cowCount']),
      role: j['role']?.toString(),
      houseName: house is Map ? house['name']?.toString() : null,
      availability: WorkerAvailability.fromWire(
        j['availabilityStatus']?.toString(),
      ),
      availabilityNote: j['availabilityNote']?.toString(),
    );
  }
}

class SessionProgress {
  SessionProgress({required this.logged, required this.total});
  final int logged;
  final int total;
  factory SessionProgress.fromJson(Map<String, dynamic>? j) {
    if (j == null) return SessionProgress(logged: 0, total: 0);
    return SessionProgress(
      logged: _toInt(j['logged']),
      total: _toInt(j['total']),
    );
  }
}

class CowSessionView {
  CowSessionView({
    required this.id,
    required this.tag,
    required this.breed,
    required this.status,
    required this.entries,
    required this.avg,
    required this.flagged,
    this.nickname,
    this.houseId,
  });

  final String id;
  final String tag;
  /// Local name shown to workers in the milk-logging grid. Set to the
  /// tag if no nickname exists, so callers can use `nickname ?? tag`.
  final String? nickname;
  final String breed;
  final String status;
  final String? houseId;

  /// Convenience: prefers the nickname, falls back to the tag.
  String get displayName =>
      (nickname == null || nickname!.isEmpty) ? tag : nickname!;

  /// Today's reading per session — null when not yet logged.
  final Map<MilkSession, double?> entries;

  /// Trailing-7-day average per session (server-computed).
  final Map<MilkSession, double> avg;

  /// Whether today's reading falls below the avg × threshold (auto-flag).
  final Map<MilkSession, bool> flagged;

  factory CowSessionView.fromJson(Map<String, dynamic> j) {
    Map<MilkSession, T> bySession<T>(
      Map<String, dynamic>? raw,
      T Function(dynamic) parse,
    ) {
      final out = <MilkSession, T>{};
      for (final s in MilkSession.values) {
        out[s] = parse(raw?[s.wire]);
      }
      return out;
    }

    return CowSessionView(
      id: (j['id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      nickname: j['nickname']?.toString(),
      breed: (j['breed'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      houseId: j['houseId']?.toString(),
      entries: bySession<double?>(
        (j['entries'] as Map?)?.cast<String, dynamic>(),
        _toDoubleNullable,
      ),
      avg: bySession<double>(
        (j['avg'] as Map?)?.cast<String, dynamic>(),
        _toDouble,
      ),
      flagged: bySession<bool>(
        (j['flagged'] as Map?)?.cast<String, dynamic>(),
        (v) => v == true,
      ),
    );
  }
}

class WorkerSessionView {
  WorkerSessionView({
    required this.id,
    required this.name,
    required this.cowCount,
    required this.progress,
    required this.totals,
    required this.cows,
  });

  final String id;
  final String name;
  final int cowCount;
  final Map<MilkSession, SessionProgress> progress;
  final Map<MilkSession, double> totals;
  final List<CowSessionView> cows;

  /// Sum of AM + MID + PM totals for this worker.
  double get dayTotal =>
      totals.values.fold<double>(0, (a, b) => a + b);

  factory WorkerSessionView.fromJson(Map<String, dynamic> j) {
    final progressRaw =
        (j['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totalsRaw =
        (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};

    final progress = <MilkSession, SessionProgress>{
      for (final s in MilkSession.values)
        s: SessionProgress.fromJson(
          (progressRaw[s.wire] as Map?)?.cast<String, dynamic>(),
        ),
    };
    final totals = <MilkSession, double>{
      for (final s in MilkSession.values) s: _toDouble(totalsRaw[s.wire]),
    };

    return WorkerSessionView(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      cowCount: _toInt(j['cowCount']),
      progress: progress,
      totals: totals,
      cows: ((j['cows'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => CowSessionView.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TodaySessions {
  TodaySessions({
    required this.belowAvgThreshold,
    required this.workers,
  });
  final double belowAvgThreshold;
  final List<WorkerSessionView> workers;

  /// Aggregated totals across every worker — used by the manager view
  /// "AM=0/N, MID=0/N, PM=0/N" header counts.
  Map<MilkSession, SessionProgress> get aggregateProgress {
    final out = <MilkSession, SessionProgress>{};
    for (final s in MilkSession.values) {
      var logged = 0;
      var total = 0;
      for (final w in workers) {
        logged += w.progress[s]?.logged ?? 0;
        total += w.progress[s]?.total ?? 0;
      }
      out[s] = SessionProgress(logged: logged, total: total);
    }
    return out;
  }

  factory TodaySessions.fromJson(Map<String, dynamic> j) {
    return TodaySessions(
      belowAvgThreshold: _toDouble(j['belowAvgThreshold']),
      workers: ((j['workers'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) =>
              WorkerSessionView.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class DayNetSummary {
  DayNetSummary({
    required this.sessions,
    required this.calfDeduction,
    required this.calfCount,
    required this.calfOverridden,
    required this.householdDeduction,
    required this.dayGross,
    required this.dayNet,
  });

  final Map<MilkSession, double> sessions;
  /// Total litres deducted for calves. Either auto = `calfCount * 1L`
  /// or a manual override saved on FarmConfig.
  final double calfDeduction;
  /// Live count of CALVING events in the last 120 days. Surfaced as
  /// a hint next to the override field so a manager can see what the
  /// auto-detect would say.
  final int calfCount;
  /// True when FarmConfig has a non-zero override for the calf deduction.
  final bool calfOverridden;
  final double householdDeduction;
  final double dayGross;
  final double dayNet;

  double get totalDeductions => calfDeduction + householdDeduction;

  factory DayNetSummary.fromJson(Map<String, dynamic> j) {
    final sessRaw = (j['sessions'] as Map?)?.cast<String, dynamic>() ?? {};
    final dedRaw =
        (j['deductions'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DayNetSummary(
      sessions: {
        for (final s in MilkSession.values)
          s: _toDouble(sessRaw[s.wire]),
      },
      calfDeduction: _toDouble(dedRaw['calf']),
      calfCount: _toInt(dedRaw['calfCount']),
      calfOverridden: dedRaw['calfOverridden'] == true,
      householdDeduction: _toDouble(dedRaw['household']),
      dayGross: _toDouble(j['dayGross']),
      dayNet: _toDouble(j['dayNet']),
    );
  }
}

// ===================================================
// Calves register
// ===================================================

class CalvesDamSummary {
  CalvesDamSummary({
    required this.id,
    required this.tag,
    this.nickname,
    this.breed,
    this.houseName,
    this.houseColor,
    this.workerName,
  });
  final String id;
  final String tag;
  final String? nickname;
  final String? breed;
  final String? houseName;
  final String? houseColor;
  final String? workerName;

  String get displayName =>
      (nickname == null || nickname!.isEmpty) ? tag : nickname!;

  factory CalvesDamSummary.fromJson(Map<String, dynamic> j) =>
      CalvesDamSummary(
        id: (j['id'] ?? '').toString(),
        tag: (j['tag'] ?? '').toString(),
        nickname: j['nickname']?.toString(),
        breed: j['breed']?.toString(),
        houseName: j['houseName']?.toString(),
        houseColor: j['houseColor']?.toString(),
        workerName: j['workerName']?.toString(),
      );
}

class CalvesCalfSummary {
  CalvesCalfSummary({
    required this.id,
    required this.tag,
    this.nickname,
    this.breed,
    this.imageUrl,
    this.status,
    this.houseName,
    this.houseColor,
    this.workerName,
  });
  final String id;
  final String tag;
  final String? nickname;
  final String? breed;
  final String? imageUrl;
  final String? status;
  final String? houseName;
  final String? houseColor;
  final String? workerName;

  String get displayName =>
      (nickname == null || nickname!.isEmpty) ? tag : nickname!;

  factory CalvesCalfSummary.fromJson(Map<String, dynamic> j) =>
      CalvesCalfSummary(
        id: (j['id'] ?? '').toString(),
        tag: (j['tag'] ?? '').toString(),
        nickname: j['nickname']?.toString(),
        breed: j['breed']?.toString(),
        imageUrl: j['imageUrl']?.toString(),
        status: j['status']?.toString(),
        houseName: j['houseName']?.toString(),
        houseColor: j['houseColor']?.toString(),
        workerName: j['workerName']?.toString(),
      );
}

class CalfRecord {
  CalfRecord({
    required this.id,
    required this.eventDate,
    required this.ageDays,
    required this.stage,
    this.calfTag,
    this.calfSex,
    this.calfBirthWeightKg,
    this.calvingEase,
    this.calvingFate,
    this.sireCode,
    this.notes,
    this.dam,
    this.calf,
  });

  final String id;
  final DateTime eventDate;
  final int ageDays;
  final String stage; // Newborn / Calf / Weaner / Heifer/Steer
  final String? calfTag;
  final String? calfSex; // "M" | "F"
  final double? calfBirthWeightKg;
  final int? calvingEase; // 1..5
  final String? calvingFate;
  final String? sireCode;
  final String? notes;
  final CalvesDamSummary? dam;
  final CalvesCalfSummary? calf;

  factory CalfRecord.fromJson(Map<String, dynamic> j) => CalfRecord(
        id: (j['id'] ?? '').toString(),
        eventDate: DateTime.tryParse((j['eventDate'] ?? '').toString()) ??
            DateTime.now(),
        ageDays: _toInt(j['ageDays']),
        stage: (j['stage'] ?? '').toString(),
        calfTag: j['calfTag']?.toString(),
        calfSex: j['calfSex']?.toString(),
        calfBirthWeightKg: _toDoubleNullable(j['calfBirthWeightKg']),
        calvingEase: j['calvingEase'] is num
            ? (j['calvingEase'] as num).toInt()
            : (j['calvingEase'] is String
                ? int.tryParse(j['calvingEase'] as String)
                : null),
        calvingFate: j['calvingFate']?.toString(),
        sireCode: j['sireCode']?.toString(),
        notes: j['notes']?.toString(),
        dam: j['dam'] is Map
            ? CalvesDamSummary.fromJson(
                (j['dam'] as Map).cast<String, dynamic>())
            : null,
        calf: j['calf'] is Map
            ? CalvesCalfSummary.fromJson(
                (j['calf'] as Map).cast<String, dynamic>())
            : null,
      );
}

// ===================================================
// Dairy unit inventory
// ===================================================

class DairyInventoryItem {
  DairyInventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.unit,
    this.location,
    this.condition,
    this.notes,
  });

  final String id;
  final String name;
  final String category; // Bedding · Equipment · Veterinary
  final double quantity;
  final String? unit;
  final String? location;
  final String? condition;
  final String? notes;

  factory DairyInventoryItem.fromJson(Map<String, dynamic> j) =>
      DairyInventoryItem(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        quantity: _toDouble(j['quantity']),
        unit: j['unit']?.toString(),
        location: j['location']?.toString(),
        condition: j['condition']?.toString(),
        notes: j['notes']?.toString(),
      );
}
