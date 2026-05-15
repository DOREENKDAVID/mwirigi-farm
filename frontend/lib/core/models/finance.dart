// Finance dashboard payload — `/api/finance/dashboard`.
//
// Shape:
//   { period: { month, year, label },
//     kpis: { revenue, expenses, netProfit, marginPct, bestUnit },
//     revenueByUnit: [{ unit, color, amount, pct }],
//     pnl: [{ unit, color, revenue, expenses, profit, marginPct }] }

class FinanceDashboard {
  FinanceDashboard({
    required this.period,
    required this.kpis,
    required this.revenueByUnit,
    required this.pnl,
  });

  final FinancePeriod period;
  final FinanceKpis kpis;
  final List<RevenueSlice> revenueByUnit;
  final List<UnitPnl> pnl;

  factory FinanceDashboard.fromJson(Map<String, dynamic> j) =>
      FinanceDashboard(
        period: FinancePeriod.fromJson(
          (j['period'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        kpis: FinanceKpis.fromJson(
          (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        revenueByUnit: ((j['revenueByUnit'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => RevenueSlice.fromJson(m.cast<String, dynamic>()))
            .toList(),
        pnl: ((j['pnl'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => UnitPnl.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );
}

class FinancePeriod {
  FinancePeriod({required this.month, required this.year, required this.label});
  final int month;
  final int year;
  final String label;

  factory FinancePeriod.fromJson(Map<String, dynamic> j) => FinancePeriod(
        month: _toInt(j['month']),
        year: _toInt(j['year']),
        label: (j['label'] ?? '').toString(),
      );
}

class FinanceKpis {
  FinanceKpis({
    required this.revenue,
    required this.expenses,
    required this.netProfit,
    required this.marginPct,
    this.bestUnit,
  });
  final double revenue;
  final double expenses;
  final double netProfit;
  final double marginPct;
  final BestUnit? bestUnit;

  factory FinanceKpis.fromJson(Map<String, dynamic> j) => FinanceKpis(
        revenue: _toDouble(j['revenue']),
        expenses: _toDouble(j['expenses']),
        netProfit: _toDouble(j['netProfit']),
        marginPct: _toDouble(j['marginPct']),
        bestUnit: j['bestUnit'] is Map
            ? BestUnit.fromJson(
                (j['bestUnit'] as Map).cast<String, dynamic>())
            : null,
      );
}

class BestUnit {
  BestUnit({required this.unit, required this.revenuePct});
  final String unit;
  final double revenuePct;

  factory BestUnit.fromJson(Map<String, dynamic> j) => BestUnit(
        unit: (j['unit'] ?? '').toString(),
        revenuePct: _toDouble(j['revenuePct']),
      );
}

class RevenueSlice {
  RevenueSlice({
    required this.unit,
    required this.color,
    required this.amount,
    required this.pct,
  });
  final String unit;
  final String color;
  final double amount;
  final double pct;

  factory RevenueSlice.fromJson(Map<String, dynamic> j) => RevenueSlice(
        unit: (j['unit'] ?? '').toString(),
        color: (j['color'] ?? '#6B7770').toString(),
        amount: _toDouble(j['amount']),
        pct: _toDouble(j['pct']),
      );
}

class UnitPnl {
  UnitPnl({
    required this.unit,
    required this.color,
    required this.revenue,
    required this.expenses,
    required this.profit,
    required this.marginPct,
  });
  final String unit;
  final String color;
  final double revenue;
  final double expenses;
  final double profit;
  final double marginPct;

  factory UnitPnl.fromJson(Map<String, dynamic> j) => UnitPnl(
        unit: (j['unit'] ?? '').toString(),
        color: (j['color'] ?? '#6B7770').toString(),
        revenue: _toDouble(j['revenue']),
        expenses: _toDouble(j['expenses']),
        profit: _toDouble(j['profit']),
        marginPct: _toDouble(j['marginPct']),
      );
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
