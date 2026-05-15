// Compact KPI payload returned by GET /api/dairy/summary.

class DairySummary {
  DairySummary({
    required this.totalCows,
    required this.milkingToday,
    required this.milkToday,
    required this.avgPerCow,
  });

  final int totalCows;
  final int milkingToday;
  final num milkToday;
  final num avgPerCow;

  factory DairySummary.fromJson(Map<String, dynamic> j) {
    return DairySummary(
      totalCows: _toInt(j['totalCows']),
      milkingToday: _toInt(j['milkingToday']),
      milkToday: _toNum(j['milkToday']),
      avgPerCow: _toNum(j['avgPerCow']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }
}
