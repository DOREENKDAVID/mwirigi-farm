// Models for the unified Layers Unit dashboard.
//
// Source endpoint: GET /api/layers-unit
// Response shape: { layers, brooder, production, vaccination, allocation }
//
// All derived state (brooder.status, house.phasingOut, vaccination.status)
// is computed server-side. Flutter only renders.

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

/// One layer house's view state. `phasingOut` is server-derived.
class LayerHouseView {
  LayerHouseView({
    required this.id,
    required this.name,
    required this.color,
    required this.capacity,
    required this.birdCount,
    required this.flockAgeDays,
    required this.cratesToday,
    required this.feedKg,
    required this.phasingOut,
    required this.status,
    this.householdUsed = 0,
    this.availableEggs = 0,
  });

  final String id;
  final String name;
  final String color; // hex like "#27500A"
  final int capacity;
  final int birdCount;
  final int flockAgeDays;
  final num cratesToday;
  final num feedKg;
  final bool phasingOut;
  final String status; // PHASING_OUT | CONTINUING
  final int householdUsed;
  final int availableEggs;

  factory LayerHouseView.fromJson(Map<String, dynamic> j) {
    final eggsToday = _toInt(j['eggsToday'] ?? (_toNum(j['cratesToday']) * 30).round());
    final household = _toInt(j['householdUsed']);
    return LayerHouseView(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      color: (j['color'] ?? '#27500A').toString(),
      capacity: _toInt(j['capacity']),
      birdCount: _toInt(j['birdCount']),
      flockAgeDays: _toInt(j['flockAgeDays']),
      cratesToday: _toNum(j['cratesToday']),
      feedKg: _toNum(j['feedKg']),
      phasingOut: j['phasingOut'] == true,
      status: (j['status'] ?? 'CONTINUING').toString(),
      householdUsed: household,
      availableEggs: _toInt(j['availableEggs'] ?? (eggsToday - household).clamp(0, double.maxFinite).round()),
    );
  }
}

/// Layers section: KPI totals + per-house breakdown.
class LayersSection {
  LayersSection({
    required this.totalBirds,
    required this.cratesToday,
    required this.mortalityToday,
    required this.houses,
    this.householdUsedToday = 0,
    this.availableEggsToday = 0,
  });

  final int totalBirds;
  final num cratesToday;
  final int mortalityToday;
  final List<LayerHouseView> houses;
  final int householdUsedToday;
  final int availableEggsToday;

  num get availableTraysToday => availableEggsToday / 30;

  factory LayersSection.fromJson(Map<String, dynamic> j) {
    final hl = (j['houses'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => LayerHouseView.fromJson(m.cast<String, dynamic>()))
        .toList();
    final householdSum = _toInt(
      j['householdUsedToday'] ?? hl.fold<int>(0, (s, h) => s + h.householdUsed),
    );
    final availableSum = _toInt(
      j['availableEggsToday'] ?? hl.fold<int>(0, (s, h) => s + h.availableEggs),
    );
    return LayersSection(
      totalBirds: _toInt(j['totalBirds']),
      cratesToday: _toNum(j['cratesToday']),
      mortalityToday: _toInt(j['mortalityToday']),
      houses: hl,
      householdUsedToday: householdSum,
      availableEggsToday: availableSum,
    );
  }
}

/// Brooder section. status is server-derived (REARING / READY_TO_TRANSFER /
/// TRANSFERRED) — never store-of-truth.
class BrooderSection {
  BrooderSection({
    required this.id,
    required this.label,
    required this.population,
    required this.mortality,
    required this.receivedDate,
    required this.transferDate,
    required this.actualTransferDate,
    required this.targetDays,
    required this.ageDays,
    required this.daysRemaining,
    required this.progressPercent,
    required this.status,
  });

  final String id;
  final String? label;
  final int population;
  final int mortality;
  final DateTime receivedDate;
  final DateTime transferDate;
  final DateTime? actualTransferDate;
  final int targetDays;
  final int ageDays;
  final int daysRemaining;
  final int progressPercent;
  final String status;

  factory BrooderSection.fromJson(Map<String, dynamic> j) {
    return BrooderSection(
      id: (j['id'] ?? '').toString(),
      label: j['label']?.toString(),
      population: _toInt(j['population']),
      mortality: _toInt(j['mortality']),
      receivedDate: _parseDate(j['receivedDate']) ?? DateTime.now(),
      transferDate: _parseDate(j['transferDate']) ?? DateTime.now(),
      actualTransferDate: _parseDate(j['actualTransferDate']),
      targetDays: _toInt(j['targetDays']),
      ageDays: _toInt(j['ageDays']),
      daysRemaining: _toInt(j['daysRemaining']),
      progressPercent: _toInt(j['progressPercent']),
      status: (j['status'] ?? 'REARING').toString(),
    );
  }
}

/// One day in the 7-day production trend.
class ProductionPoint {
  ProductionPoint({
    required this.date,
    required this.eggsCollected,
    required this.cratesCollected,
    required this.percentLaying,
  });

  final DateTime date;
  final int eggsCollected;
  final num cratesCollected;
  final num percentLaying;

  factory ProductionPoint.fromJson(Map<String, dynamic> j) {
    return ProductionPoint(
      date: _parseDate(j['date']) ?? DateTime.now(),
      eggsCollected: _toInt(j['eggsCollected']),
      cratesCollected: _toNum(j['cratesCollected']),
      percentLaying: _toNum(j['percentLaying']),
    );
  }
}

/// One step in the brooder vaccination protocol — overlaid with completion
/// records. status: DONE | DUE_NOW | OVERDUE | UPCOMING (server-computed).
class VaccinationStep {
  VaccinationStep({
    required this.name,
    required this.dayOffset,
    required this.windowDays,
    required this.milestone,
    required this.scheduledDate,
    required this.doneDate,
    required this.status,
  });

  final String name;
  final int dayOffset;
  final int windowDays;
  final bool milestone;
  final DateTime scheduledDate;
  final DateTime? doneDate;
  final String status;

  factory VaccinationStep.fromJson(Map<String, dynamic> j) {
    return VaccinationStep(
      name: (j['name'] ?? '').toString(),
      dayOffset: _toInt(j['dayOffset']),
      windowDays: _toInt(j['windowDays']),
      milestone: j['milestone'] == true,
      scheduledDate: _parseDate(j['scheduledDate']) ?? DateTime.now(),
      doneDate: _parseDate(j['doneDate']),
      status: (j['status'] ?? 'UPCOMING').toString(),
    );
  }
}

/// One row of the brooder allocation plan.
class AllocationRow {
  AllocationRow({
    required this.id,
    required this.type,
    required this.birds,
    required this.description,
    required this.cycleId,
    required this.createdAt,
  });

  final String id;
  final String type; // POL_SALE | REPLACEMENT
  final int birds;
  final String description;
  final String cycleId;
  final DateTime createdAt;

  factory AllocationRow.fromJson(Map<String, dynamic> j) {
    return AllocationRow(
      id: (j['id'] ?? '').toString(),
      type: (j['type'] ?? 'POL_SALE').toString(),
      birds: _toInt(j['birds']),
      description: (j['description'] ?? '').toString(),
      cycleId: (j['cycleId'] ?? '').toString(),
      createdAt: _parseDate(j['createdAt']) ?? DateTime.now(),
    );
  }
}

/// Top-level wrapper. One round-trip → full Layers Unit dashboard.
class LayersUnit {
  LayersUnit({
    required this.layers,
    required this.brooder,
    required this.production,
    required this.vaccination,
    required this.allocation,
  });

  final LayersSection layers;
  final BrooderSection? brooder;
  final List<ProductionPoint> production;
  final List<VaccinationStep> vaccination;
  final List<AllocationRow> allocation;

  factory LayersUnit.fromJson(Map<String, dynamic> j) {
    final brooderJson = j['brooder'];
    return LayersUnit(
      layers: LayersSection.fromJson(
        (j['layers'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      brooder: brooderJson is Map
          ? BrooderSection.fromJson(brooderJson.cast<String, dynamic>())
          : null,
      production: (j['production'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ProductionPoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
      vaccination: (j['vaccination'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => VaccinationStep.fromJson(m.cast<String, dynamic>()))
          .toList(),
      allocation: (j['allocation'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => AllocationRow.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}
