// Feedlot & Doopers domain models.
//
// Source endpoints:
//   GET  /api/feedlot/kpis    → FeedlotKpis
//   GET  /api/feedlot/bulls   → List<BullView>  (computed columns from server)
//   GET  /api/feedlot/lambing → List<LambingPoint>
//   POST /api/feedlot/bulls   → create bull
//   POST /api/feedlot/weights → log weight
//   POST /api/feedlot/sheep   → register sheep (category + count)
//   POST /api/feedlot/lambing → log lambing event
//
// Per project rule, NO computation happens in Flutter. ADG, daysOnFeed,
// daysLeft and status all come from the API.

enum SheepCategory {
  ewe('EWE', 'Ewe'),
  ram('RAM', 'Ram'),
  lamb('LAMB', 'Lamb');

  const SheepCategory(this.wire, this.label);
  final String wire;
  final String label;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

num _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
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

class FeedlotKpis {
  FeedlotKpis({
    required this.bullsOnFeed,
    required this.avgDaysOnFeed,
    required this.doopersFlock,
    required this.lambsThisMonth,
  });

  final int bullsOnFeed;
  final int avgDaysOnFeed;
  final int doopersFlock;
  final int lambsThisMonth;

  factory FeedlotKpis.fromJson(Map<String, dynamic> j) {
    return FeedlotKpis(
      bullsOnFeed: _toInt(j['bullsOnFeed']),
      avgDaysOnFeed: _toInt(j['avgDaysOnFeed']),
      doopersFlock: _toInt(j['doopersFlock']),
      lambsThisMonth: _toInt(j['lambsThisMonth']),
    );
  }
}

class BullView {
  BullView({
    required this.id,
    required this.tag,
    required this.breed,
    required this.entryDate,
    required this.entryWeight,
    required this.currentWeight,
    required this.adg,
    required this.daysOnFeed,
    required this.daysLeft,
    required this.status,
  });

  final String id;
  final String tag;
  final String breed;
  final DateTime entryDate;
  final num entryWeight;
  final num currentWeight;
  final num adg;
  final int daysOnFeed;
  /// Signed integer; negative = overdue.
  final int daysLeft;
  /// "On feed", "13 days left", "Due today", "Overdue 5d", etc.
  final String status;

  factory BullView.fromJson(Map<String, dynamic> j) {
    return BullView(
      id: (j['id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      breed: (j['breed'] ?? '').toString(),
      entryDate: _parseDate(j['entryDate']) ?? DateTime.now(),
      entryWeight: _toNum(j['entryWeight']),
      currentWeight: _toNum(j['currentWeight']),
      adg: _toNum(j['adg']),
      daysOnFeed: _toInt(j['daysOnFeed']),
      daysLeft: _toInt(j['daysLeft']),
      status: (j['status'] ?? '').toString(),
    );
  }
}

class SheepView {
  SheepView({
    required this.id,
    required this.tag,
    required this.category,
    required this.entryDate,
    this.entryWeight,
    this.currentWeight,
    this.adg,
    required this.daysOnFeed,
  });

  final String id;
  final String tag;
  final SheepCategory category;
  final DateTime entryDate;
  final num? entryWeight;
  final num? currentWeight;
  /// Server-computed average daily gain. Null when either weight is
  /// missing or the sheep was registered today (daysOnFeed == 0).
  final num? adg;
  final int daysOnFeed;

  factory SheepView.fromJson(Map<String, dynamic> j) {
    final cat = (j['category'] ?? '').toString();
    final mapped = SheepCategory.values.firstWhere(
      (c) => c.wire == cat,
      orElse: () => SheepCategory.ewe,
    );
    return SheepView(
      id: (j['id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      category: mapped,
      entryDate: _parseDate(j['entryDate']) ?? DateTime.now(),
      entryWeight: j['entryWeight'] == null ? null : _toNum(j['entryWeight']),
      currentWeight:
          j['currentWeight'] == null ? null : _toNum(j['currentWeight']),
      adg: j['adg'] == null ? null : _toNum(j['adg']),
      daysOnFeed: _toInt(j['daysOnFeed']),
    );
  }
}

class LambingPoint {
  LambingPoint({required this.date, required this.lambsBorn});

  final DateTime date;
  final int lambsBorn;

  factory LambingPoint.fromJson(Map<String, dynamic> j) {
    return LambingPoint(
      date: _parseDate(j['date']) ?? DateTime.now(),
      lambsBorn: _toInt(j['lambsBorn']),
    );
  }
}
