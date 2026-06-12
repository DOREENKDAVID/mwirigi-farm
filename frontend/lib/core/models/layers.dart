// Models for the Layers daily-production module.
//
// Source endpoints:
//   GET  /api/layers/kpis                       → LayersKpis (top KPI cards)
//   GET  /api/layers/houses                     → List<LayerHouse>
//   GET  /api/layers/snapshot                   → List<SnapshotRow>
//   GET  /api/layers/trend?days=7               → List<TrendPoint>
//   GET  /api/layers/production/:houseId?days=7 → ProductionHistory
//   POST /api/layers/production                 → LayerProduction (computed)

num _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

class LayersKpis {
  LayersKpis({
    required this.totalBirds,
    required this.eggsToday,
    required this.traysToday,
    required this.avgLayingRate,
    required this.feedToday,
    required this.mortalityToday,
  });

  final int totalBirds;
  final int eggsToday;
  final num traysToday;
  /// 0..1 (e.g. 0.81 = 81%). Capped server-side at 1.0.
  final num avgLayingRate;
  final num feedToday;
  final int mortalityToday;

  factory LayersKpis.fromJson(Map<String, dynamic> j) {
    return LayersKpis(
      totalBirds: _toInt(j['totalBirds']),
      eggsToday: _toInt(j['eggsToday']),
      traysToday: _toNum(j['traysToday']),
      avgLayingRate: _toNum(j['avgLayingRate']),
      feedToday: _toNum(j['feedToday']),
      mortalityToday: _toInt(j['mortalityToday']),
    );
  }
}

class LayerHouse {
  LayerHouse({
    required this.id,
    required this.name,
    required this.capacity,
    required this.color,
  });

  final String id;
  final String name;
  final int capacity;
  final String color; // hex like "#27500A"

  factory LayerHouse.fromJson(Map<String, dynamic> j) {
    return LayerHouse(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      capacity: _toInt(j['capacity']),
      color: (j['color'] ?? '#27500A').toString(),
    );
  }
}

/// One row in the per-house "last 7 days" history table.
/// Trays / percentLaying / closingStock are computed server-side.
class LayerProduction {
  LayerProduction({
    required this.id,
    required this.date,
    required this.openingStock,
    required this.eggsCollected,
    required this.trays,
    required this.percentLaying,
    required this.feedKg,
    required this.deadRemoved,
    required this.closingStock,
    required this.dayAge,
    this.householdUsed = 0,
    this.remarks,
  });

  final String id;
  final DateTime date;
  final int openingStock;
  final int eggsCollected;
  final num trays;
  final num percentLaying;
  final num feedKg;
  final int deadRemoved;
  final int closingStock;
  final int dayAge;
  final int householdUsed;
  final String? remarks;

  int get availableEggs => (eggsCollected - householdUsed).clamp(0, eggsCollected);

  factory LayerProduction.fromJson(Map<String, dynamic> j) {
    return LayerProduction(
      id: (j['id'] ?? '').toString(),
      date: _parseDate(j['date']) ?? DateTime.now(),
      openingStock: _toInt(j['openingStock']),
      eggsCollected: _toInt(j['eggsCollected']),
      trays: _toNum(j['trays']),
      percentLaying: _toNum(j['percentLaying']),
      feedKg: _toNum(j['feedKg']),
      deadRemoved: _toInt(j['deadRemoved']),
      closingStock: _toInt(j['closingStock']),
      dayAge: _toInt(j['dayAge']),
      householdUsed: _toInt(j['householdUsed']),
      remarks: j['remarks']?.toString(),
    );
  }
}

class ProductionHistory {
  ProductionHistory({required this.house, required this.records});
  final LayerHouse house;
  final List<LayerProduction> records;

  factory ProductionHistory.fromJson(Map<String, dynamic> j) {
    final recs = (j['records'] as List? ?? [])
        .whereType<Map>()
        .map((m) => LayerProduction.fromJson(m.cast<String, dynamic>()))
        .toList();
    return ProductionHistory(
      house: LayerHouse.fromJson(
        (j['house'] as Map? ?? {}).cast<String, dynamic>(),
      ),
      records: recs,
    );
  }
}

/// One row in the "All houses — today's snapshot" table.
class SnapshotRow {
  SnapshotRow({
    required this.houseId,
    required this.name,
    required this.color,
    required this.capacity,
    required this.currentStock,
    required this.eggsToday,
    required this.trays,
    required this.percentLaying,
    required this.feedKg,
    this.lastEntryDate,
  });

  final String houseId;
  final String name;
  final String color;
  final int capacity;
  final int currentStock;
  final int eggsToday;
  final num trays;
  final num percentLaying;
  final num feedKg;
  final DateTime? lastEntryDate;

  factory SnapshotRow.fromJson(Map<String, dynamic> j) {
    return SnapshotRow(
      houseId: (j['houseId'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      color: (j['color'] ?? '#27500A').toString(),
      capacity: _toInt(j['capacity']),
      currentStock: _toInt(j['currentStock']),
      eggsToday: _toInt(j['eggsToday']),
      trays: _toNum(j['trays']),
      percentLaying: _toNum(j['percentLaying']),
      feedKg: _toNum(j['feedKg']),
      lastEntryDate: _parseDate(j['lastEntryDate']),
    );
  }
}

class TrendPoint {
  TrendPoint({
    required this.date,
    required this.eggsCollected,
    required this.percentLaying,
  });

  final DateTime date;
  final int eggsCollected;
  final num percentLaying;

  factory TrendPoint.fromJson(Map<String, dynamic> j) {
    return TrendPoint(
      date: _parseDate(j['date']) ?? DateTime.now(),
      eggsCollected: _toInt(j['eggsCollected']),
      percentLaying: _toNum(j['percentLaying']),
    );
  }
}
