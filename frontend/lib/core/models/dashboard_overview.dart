// Mirrors the GET /api/dashboard/overview response. The backend computes
// every value (percentages, day labels, status strings) — Flutter only
// renders.

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

class GoalProgress {
  GoalProgress({
    required this.label,
    required this.current,
    required this.target,
    required this.percentage,
  });

  /// Display label for the bar (e.g. "Milk production").
  final String label;
  final num current;
  final num target;
  /// 0..999 (server clamps high values to 999).
  final int percentage;

  factory GoalProgress.fromJson(String label, Map<String, dynamic> j) {
    return GoalProgress(
      label: label,
      current: _toNum(j['current']),
      target: _toNum(j['target']),
      percentage: _toInt(j['percentage']),
    );
  }
}

enum AlertType {
  danger('danger'),
  warning('warning'),
  info('info');

  const AlertType(this.wire);
  final String wire;

  static AlertType fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return AlertType.info;
  }
}

class DashboardAlert {
  DashboardAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
  });

  final int id;
  final AlertType type;
  final String title;
  final String message;

  factory DashboardAlert.fromJson(Map<String, dynamic> j) {
    return DashboardAlert(
      id: _toInt(j['id']),
      type: AlertType.fromWire(j['type']?.toString()),
      title: (j['title'] ?? '').toString(),
      message: (j['message'] ?? '').toString(),
    );
  }
}

class MilkTrendPoint {
  MilkTrendPoint({required this.day, required this.value});

  /// Short day label e.g. "Mon".
  final String day;
  final int value;

  factory MilkTrendPoint.fromJson(Map<String, dynamic> j) {
    return MilkTrendPoint(
      day: (j['day'] ?? '').toString(),
      value: _toInt(j['value']),
    );
  }
}

class EggsTrendPoint {
  EggsTrendPoint({required this.day, required this.value});

  /// Short day label e.g. "Mon".
  final String day;
  /// Daily egg crates (eggs / 30, rounded).
  final int value;

  factory EggsTrendPoint.fromJson(Map<String, dynamic> j) {
    return EggsTrendPoint(
      day: (j['day'] ?? '').toString(),
      value: _toInt(j['value']),
    );
  }
}

class UnitPerformanceRow {
  UnitPerformanceRow({
    required this.unit,
    required this.manager,
    required this.metric,
    required this.today,
    required this.average,
    required this.average30d,
    required this.status,
  });

  final String unit;
  final String manager;
  final String metric;
  /// Pre-formatted strings from the server (e.g. "847 L", "—").
  final String today;
  final String average;
  /// 30-day rolling average, pre-formatted. Server returns "—" when
  /// the metric doesn't make sense over a longer window (e.g. bulls
  /// on feed — a head count, not a rate).
  final String average30d;
  /// Pre-formatted status (e.g. "42% of target").
  final String status;

  factory UnitPerformanceRow.fromJson(Map<String, dynamic> j) {
    return UnitPerformanceRow(
      unit: (j['unit'] ?? '').toString(),
      manager: (j['manager'] ?? '—').toString(),
      metric: (j['metric'] ?? '').toString(),
      today: (j['today'] ?? '—').toString(),
      average: (j['average'] ?? '—').toString(),
      average30d: (j['average30d'] ?? '—').toString(),
      status: (j['status'] ?? '').toString(),
    );
  }
}

/// One headline metric inside [OverviewScope]. The `previous` value
/// is the same-length window immediately before the active one, and
/// `deltaPct` is `null` (not 0) when the previous window had no data,
/// so the UI can show "—" instead of a misleading 0%.
class ScopeMetric {
  ScopeMetric({
    required this.current,
    required this.previous,
    required this.unit,
    this.deltaPct,
  });

  final num current;
  final num previous;
  final String unit;
  final double? deltaPct;

  factory ScopeMetric.fromJson(Map<String, dynamic> j) => ScopeMetric(
        current: (j['current'] is num) ? j['current'] as num : 0,
        previous: (j['previous'] is num) ? j['previous'] as num : 0,
        unit: (j['unit'] ?? '').toString(),
        deltaPct: j['deltaPct'] == null
            ? null
            : (j['deltaPct'] is num
                ? (j['deltaPct'] as num).toDouble()
                : double.tryParse(j['deltaPct'].toString())),
      );
}

/// Period-scoped overview block. Carries the resolved label + range
/// plus four headline metrics, each with current/previous/delta. Only
/// present when the request included a `period` query param.
class OverviewScope {
  OverviewScope({
    required this.label,
    required this.start,
    required this.end,
    required this.milk,
    required this.eggs,
    required this.piglets,
    required this.treatments,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final ScopeMetric milk;
  final ScopeMetric eggs;
  final ScopeMetric piglets;
  final ScopeMetric treatments;

  factory OverviewScope.fromJson(Map<String, dynamic> j) => OverviewScope(
        label: (j['label'] ?? '').toString(),
        start:
            DateTime.tryParse((j['start'] ?? '').toString()) ?? DateTime.now(),
        end: DateTime.tryParse((j['end'] ?? '').toString()) ?? DateTime.now(),
        milk: ScopeMetric.fromJson(
            (j['milk'] as Map?)?.cast<String, dynamic>() ?? const {}),
        eggs: ScopeMetric.fromJson(
            (j['eggs'] as Map?)?.cast<String, dynamic>() ?? const {}),
        piglets: ScopeMetric.fromJson(
            (j['piglets'] as Map?)?.cast<String, dynamic>() ?? const {}),
        treatments: ScopeMetric.fromJson(
            (j['treatments'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

class DashboardOverview {
  DashboardOverview({
    required this.milkToday,
    required this.milkTarget,
    required this.eggCrates,
    required this.eggTarget,
    required this.pigletsMTD,
    required this.pigletTarget,
    required this.activeAlerts,
    required this.goals,
    required this.alerts,
    required this.milkTrend,
    required this.eggsTrend,
    required this.unitPerformance,
    this.scope,
  });

  // Top-line KPIs.
  final int milkToday;
  final int milkTarget;
  final int eggCrates;
  final int eggTarget;
  final int pigletsMTD;
  final int pigletTarget;
  final int activeAlerts;

  /// Ordered list of progress goals (matches the HTML order).
  final List<GoalProgress> goals;
  final List<DashboardAlert> alerts;
  final List<MilkTrendPoint> milkTrend;
  /// Daily egg crates over the last 7 days, oldest first. Same shape as
  /// [milkTrend] but in crates/day.
  final List<EggsTrendPoint> eggsTrend;
  final List<UnitPerformanceRow> unitPerformance;
  /// Period-scoped headline block. Present only when the request
  /// passed a `period` query param. UI hides itself when null so the
  /// default "today + 7-day" Overview surface is unaffected.
  final OverviewScope? scope;

  factory DashboardOverview.fromJson(Map<String, dynamic> j) {
    final rawGoals =
        (j['goals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final goalLabels = const {
      'milkProduction': 'Milk production',
      'eggCrates': 'Egg crates',
      'piglets': 'Piglets / month',
      'layersFlock': 'Layers flock',
      'feedlotThroughput': 'Feedlot throughput',
    };
    final goals = <GoalProgress>[];
    for (final key in goalLabels.keys) {
      final v = rawGoals[key];
      if (v is Map) {
        goals.add(
          GoalProgress.fromJson(
            goalLabels[key]!,
            v.cast<String, dynamic>(),
          ),
        );
      }
    }

    return DashboardOverview(
      milkToday: _toInt(j['milkToday']),
      milkTarget: _toInt(j['milkTarget']),
      eggCrates: _toInt(j['eggCrates']),
      eggTarget: _toInt(j['eggTarget']),
      pigletsMTD: _toInt(j['pigletsMTD']),
      pigletTarget: _toInt(j['pigletTarget']),
      activeAlerts: _toInt(j['activeAlerts']),
      goals: goals,
      alerts: ((j['alerts'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => DashboardAlert.fromJson(m.cast<String, dynamic>()))
          .toList(),
      milkTrend: ((j['milkTrend'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => MilkTrendPoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
      eggsTrend: ((j['eggsTrend'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => EggsTrendPoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
      unitPerformance: ((j['unitPerformance'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) =>
                UnitPerformanceRow.fromJson(m.cast<String, dynamic>()),
          )
          .toList(),
      scope: j['scope'] is Map
          ? OverviewScope.fromJson((j['scope'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}
