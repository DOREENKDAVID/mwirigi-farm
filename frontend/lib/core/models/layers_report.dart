// Layers Production analytics report. Backs the new Production pill
// dashboard — period-scoped totals + previous-period delta + daily
// graph buckets + per-house breakdown.

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double? _toDoubleNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime _toDate(dynamic v) =>
    DateTime.tryParse((v ?? '').toString()) ?? DateTime.now();

class LayersReportPeriodWindow {
  LayersReportPeriodWindow({
    required this.label,
    required this.start,
    required this.end,
    required this.prevStart,
    required this.prevEnd,
  });
  final String label;
  final DateTime start;
  final DateTime end;
  final DateTime prevStart;
  final DateTime prevEnd;

  factory LayersReportPeriodWindow.fromJson(Map<String, dynamic> j) =>
      LayersReportPeriodWindow(
        label: (j['label'] ?? '').toString(),
        start: _toDate(j['start']),
        end: _toDate(j['end']),
        prevStart: _toDate(j['prevStart']),
        prevEnd: _toDate(j['prevEnd']),
      );
}

class LayersReportTotals {
  LayersReportTotals({
    required this.eggs,
    required this.crates,
    required this.dead,
    required this.feedKg,
    required this.activeBirds,
  });
  final int eggs;
  final double crates;
  final int dead;
  final double feedKg;
  final int activeBirds;

  factory LayersReportTotals.fromJson(Map<String, dynamic> j) =>
      LayersReportTotals(
        eggs: _toInt(j['eggs']),
        crates: _toDouble(j['crates']),
        dead: _toInt(j['dead']),
        feedKg: _toDouble(j['feedKg']),
        activeBirds: _toInt(j['activeBirds']),
      );
}

class LayersReportPreviousTotals {
  LayersReportPreviousTotals({
    required this.eggs,
    required this.crates,
    required this.dead,
    required this.feedKg,
  });
  final int eggs;
  final double crates;
  final int dead;
  final double feedKg;

  factory LayersReportPreviousTotals.fromJson(Map<String, dynamic> j) =>
      LayersReportPreviousTotals(
        eggs: _toInt(j['eggs']),
        crates: _toDouble(j['crates']),
        dead: _toInt(j['dead']),
        feedKg: _toDouble(j['feedKg']),
      );
}

class LayersReportDelta {
  LayersReportDelta({
    required this.crates,
    required this.eggs,
    required this.dead,
    required this.feedKg,
  });
  final double? crates;
  final double? eggs;
  final double? dead;
  final double? feedKg;

  factory LayersReportDelta.fromJson(Map<String, dynamic> j) =>
      LayersReportDelta(
        crates: _toDoubleNullable(j['crates']),
        eggs: _toDoubleNullable(j['eggs']),
        dead: _toDoubleNullable(j['dead']),
        feedKg: _toDoubleNullable(j['feedKg']),
      );
}

class LayersDailyPoint {
  LayersDailyPoint({
    required this.date,
    required this.dow,
    required this.eggs,
    required this.crates,
    required this.dead,
    required this.feedKg,
  });
  final String date;
  final String dow;
  final int eggs;
  final double crates;
  final int dead;
  final double feedKg;

  factory LayersDailyPoint.fromJson(Map<String, dynamic> j) => LayersDailyPoint(
        date: (j['date'] ?? '').toString(),
        dow: (j['dow'] ?? '').toString(),
        eggs: _toInt(j['eggs']),
        crates: _toDouble(j['crates']),
        dead: _toInt(j['dead']),
        feedKg: _toDouble(j['feedKg']),
      );
}

class LayersHouseSummary {
  LayersHouseSummary({
    required this.houseId,
    required this.name,
    required this.color,
    required this.crates,
    required this.eggs,
    required this.dead,
  });
  final String houseId;
  final String name;
  final String color;
  final double crates;
  final int eggs;
  final int dead;

  factory LayersHouseSummary.fromJson(Map<String, dynamic> j) =>
      LayersHouseSummary(
        houseId: (j['houseId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        color: (j['color'] ?? '#27500A').toString(),
        crates: _toDouble(j['crates']),
        eggs: _toInt(j['eggs']),
        dead: _toInt(j['dead']),
      );
}

class LayersProductionReport {
  LayersProductionReport({
    required this.period,
    required this.totals,
    required this.previousTotals,
    required this.delta,
    required this.daily,
    required this.houses,
    this.best,
    this.lowest,
  });
  final LayersReportPeriodWindow period;
  final LayersReportTotals totals;
  final LayersReportPreviousTotals previousTotals;
  final LayersReportDelta delta;
  final List<LayersDailyPoint> daily;
  final List<LayersHouseSummary> houses;
  final LayersHouseSummary? best;
  final LayersHouseSummary? lowest;

  factory LayersProductionReport.fromJson(Map<String, dynamic> j) =>
      LayersProductionReport(
        period: LayersReportPeriodWindow.fromJson(
            (j['period'] as Map).cast<String, dynamic>()),
        totals: LayersReportTotals.fromJson(
            (j['totals'] as Map).cast<String, dynamic>()),
        previousTotals: LayersReportPreviousTotals.fromJson(
            (j['previousTotals'] as Map).cast<String, dynamic>()),
        delta: LayersReportDelta.fromJson(
            (j['delta'] as Map).cast<String, dynamic>()),
        daily: ((j['daily'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => LayersDailyPoint.fromJson(m.cast<String, dynamic>()))
            .toList(),
        houses: ((j['houses'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                LayersHouseSummary.fromJson(m.cast<String, dynamic>()))
            .toList(),
        best: j['best'] is Map
            ? LayersHouseSummary.fromJson(
                (j['best'] as Map).cast<String, dynamic>())
            : null,
        lowest: j['lowest'] is Map
            ? LayersHouseSummary.fromJson(
                (j['lowest'] as Map).cast<String, dynamic>())
            : null,
      );
}
