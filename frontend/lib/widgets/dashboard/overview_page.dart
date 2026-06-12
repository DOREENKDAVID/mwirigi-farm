import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/dashboard_overview.dart';
import '../../core/service/api_service.dart';
import '../../core/util/period.dart';
import '../shared/period_filter_panel.dart';
import 'alerts_card.dart';
import 'goals_card.dart';
import 'kpi_card.dart';
import 'kpi_grid.dart';
import 'overview_pill_tabs.dart';
import 'trends_card.dart';
import 'unit_performance_table.dart';

/// CEO Overview — pill-driven layout matching the rest of the app.
///
/// Composition top → bottom:
///   • Page header (icon · title · subtitle)
///   • 4 KPI cards (pinned across pills)
///   • Pill row (5 sections)
///   • Body for the active pill
///
/// Backed by GET /api/dashboard/overview — every value (KPIs, goal
/// percentages, alerts, trend, unit rows) comes from the backend
/// aggregator.
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  Future<DashboardOverview>? _future;
  OverviewTab _active = OverviewTab.snapshot;

  // Global time-period filter. Drives the period-scoped KPI strip
  // (scope block on the response) — defaults to "This month" so the
  // strip is populated on first paint. Today/7-day widgets below are
  // not affected by this selection; they keep their own semantics.
  PeriodPreset _period = PeriodPreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardOverview> _load() async {
    final raw = await ApiService.getDashboardOverview(
      period: _period.wire,
      startDate:
          _period == PeriodPreset.custom ? _customStart : null,
      endDate: _period == PeriodPreset.custom ? _customEnd : null,
    );
    return DashboardOverview.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _onPeriodChanged(PeriodPreset p) {
    // For non-custom presets, refetch immediately. Custom is gated on
    // both dates being set; the panel only emits `custom` after the
    // date-range picker returns with a valid window.
    if (p == PeriodPreset.custom &&
        (_customStart == null || _customEnd == null)) {
      return;
    }
    setState(() {
      _period = p;
      _future = _load();
    });
  }

  void _onCustomRangeSelected(DateTime start, DateTime end) {
    _customStart = start;
    _customEnd = end;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<DashboardOverview>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              const _PageHeader(),
              const SizedBox(height: 16),
              // Global time-period filter — drives the scope KPI strip
              // below. Today's KPIs and the 7-day trend stay as-is so
              // existing widgets that read them are unaffected.
              PeriodFilterPanel(
                selectedPeriod: _period,
                onChanged: _onPeriodChanged,
                customStartDate: _customStart,
                customEndDate: _customEnd,
                onCustomRangeSelected: _onCustomRangeSelected,
              ),
              if (data.scope != null) ...[
                const SizedBox(height: 12),
                _ScopeKpiStrip(scope: data.scope!),
              ],
              const SizedBox(height: 16),
              _KpiRow(data: data),
              const SizedBox(height: 16),
              OverviewPillTabs(
                selected: _active,
                onSelect: (t) => setState(() => _active = t),
              ),
              const SizedBox(height: 16),
              ..._tabBody(data),
            ],
          );
        },
      ),
    );
  }

  // ----------------- Pill body dispatch -----------------

  List<Widget> _tabBody(DashboardOverview data) {
    switch (_active) {
      case OverviewTab.snapshot:
        return [
          _GoalsAndAlerts(goals: data.goals, alerts: data.alerts),
        ];
      case OverviewTab.goals:
        return [GoalsCard(goals: data.goals)];
      case OverviewTab.alerts:
        return [AlertsCard(alerts: data.alerts)];
      case OverviewTab.trends:
        return [
          TrendsCard(
            milkPoints: data.milkTrend,
            eggsPoints: data.eggsTrend,
          ),
        ];
      case OverviewTab.units:
        return [UnitPerformanceTable(rows: data.unitPerformance)];
    }
  }
}

// =====================================================================
// Page header (icon · title · subtitle)
// =====================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3DE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🏡', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CEO Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _OverviewPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Today’s headline numbers · 5-year goals · alerts · trends',
                style: TextStyle(
                  fontSize: 12,
                  color: _OverviewPageState._txt2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// KPI row (pinned across pills)
// =====================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.data});
  final DashboardOverview data;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final milkPct = data.milkTarget > 0
        ? (data.milkSold / data.milkTarget * 100).round()
        : 0;
    final eggPct = data.eggTarget > 0
        ? (data.cratesSold / data.eggTarget * 100).round()
        : 0;
    final pigPct = data.pigletTarget > 0
        ? (data.pigletsMTD / data.pigletTarget * 100).round()
        : 0;

    final cards = <Widget>[
      KpiCard(
        label: 'Milk sold',
        value: '${fmt.format(data.milkSold)} L',
        sub: 'Gross ${fmt.format(data.milkToday)} L · target ${fmt.format(data.milkTarget)} L',
        trend: '$milkPct% of target',
        trendColor: _pctColor(milkPct),
      ),
      KpiCard(
        label: 'Crates sold',
        value: fmt.format(data.cratesSold),
        sub: 'Gross ${fmt.format(data.eggCrates)} · target ${fmt.format(data.eggTarget)}/day',
        trend: '$eggPct% of target',
        trendColor: _pctColor(eggPct),
      ),
      KpiCard(
        label: 'Piglets MTD',
        value: fmt.format(data.pigletsMTD),
        sub: 'Target: ${fmt.format(data.pigletTarget)}/month',
        trend: '$pigPct% of target',
        trendColor: _pctColor(pigPct),
      ),
      KpiCard(
        label: 'Active alerts',
        value: '${data.activeAlerts}',
        // Red headline when there's anything to act on so the tile
        // reads as an alarm at a glance, not as just another KPI.
        valueColor: data.activeAlerts == 0
            ? const Color(0xFF0F6E56)
            : const Color(0xFFE24B4A),
        sub:
            data.activeAlerts == 0 ? 'All clear' : 'Require attention',
        trend: data.activeAlerts == 0 ? 'No action needed' : '⚠ Action needed',
        trendColor: data.activeAlerts == 0
            ? const Color(0xFF0F6E56)
            : const Color(0xFFE24B4A),
      ),
    ];

    return KpiGrid(children: cards);
  }

  static Color _pctColor(int pct) {
    if (pct >= 80) return const Color(0xFF0F6E56);
    if (pct >= 50) return const Color(0xFF27500A);
    if (pct >= 30) return const Color(0xFF854F0B);
    return const Color(0xFF501313);
  }
}

// =====================================================================
// Snapshot pill body — Goals + Alerts side-by-side on wide, stacked
// =====================================================================

class _GoalsAndAlerts extends StatelessWidget {
  const _GoalsAndAlerts({required this.goals, required this.alerts});

  final List<GoalProgress> goals;
  final List<DashboardAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final goalsCard = GoalsCard(goals: goals);
    final alertsCard = AlertsCard(alerts: alerts);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 880) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: goalsCard),
              const SizedBox(width: 16),
              Expanded(child: alertsCard),
            ],
          );
        }
        return Column(
          children: [
            goalsCard,
            const SizedBox(height: 16),
            alertsCard,
          ],
        );
      },
    );
  }
}

// =====================================================================
// Error
// =====================================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 40, color: Color(0xFFE24B4A)),
        const SizedBox(height: 12),
        Text(
          'Could not load overview',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

// =====================================================================
// _ScopeKpiStrip — period-scoped headline strip
// =====================================================================
//
// Renders one card per metric (Milk · Eggs · Piglets · Treatments)
// with the value resolved for the active period plus a vs-previous
// delta pill. Sits above the existing today/7-day KPI row so a user
// can compare "this month" against "last month" without losing sight
// of today's operational numbers.
//
// Reuses the same KpiCard primitive the rest of the page uses so the
// visual rhythm doesn't break — only the data source changes.

class _ScopeKpiStrip extends StatelessWidget {
  const _ScopeKpiStrip({required this.scope});
  final OverviewScope scope;

  static const _primary = Color(0xFF27500A);

  String _fmtCount(num v) {
    if (v is int) return NumberFormat.decimalPattern().format(v);
    if (v == v.toInt()) {
      return NumberFormat.decimalPattern().format(v.toInt());
    }
    return v.toStringAsFixed(1);
  }

  String _fmtValue(ScopeMetric m) {
    final num = _fmtCount(m.current);
    return m.unit.isEmpty ? num : '$num ${m.unit}';
  }

  // Treatments going down is good (fewer sick animals). Everything
  // else, up is good. The trend pill colour follows that semantic.
  Color _deltaColor(double? delta, {required bool downIsGood}) {
    if (delta == null) return const Color(0xFF6B7770);
    final good = downIsGood ? delta <= 0 : delta >= 0;
    return good ? const Color(0xFF1D9E75) : const Color(0xFFC4393B);
  }

  String _deltaLabel(double? delta) {
    if (delta == null) return '— vs previous';
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}% vs previous';
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final periodLabel =
        '${scope.label} · ${df.format(scope.start)} → ${df.format(scope.end)}';

    final cards = <Widget>[
      KpiCard(
        label: 'Milk',
        value: _fmtValue(scope.milk),
        sub: 'vs ${_fmtCount(scope.milk.previous)} L last period',
        trend: _deltaLabel(scope.milk.deltaPct),
        trendColor: _deltaColor(scope.milk.deltaPct, downIsGood: false),
      ),
      KpiCard(
        label: 'Egg crates',
        value: _fmtValue(scope.eggs),
        sub: 'vs ${_fmtCount(scope.eggs.previous)} last period',
        trend: _deltaLabel(scope.eggs.deltaPct),
        trendColor: _deltaColor(scope.eggs.deltaPct, downIsGood: false),
      ),
      KpiCard(
        label: 'Piglets born',
        value: _fmtValue(scope.piglets),
        sub: 'vs ${_fmtCount(scope.piglets.previous)} last period',
        trend: _deltaLabel(scope.piglets.deltaPct),
        trendColor:
            _deltaColor(scope.piglets.deltaPct, downIsGood: false),
      ),
      KpiCard(
        label: 'Treatments',
        value: _fmtValue(scope.treatments),
        sub: 'vs ${_fmtCount(scope.treatments.previous)} last period',
        trend: _deltaLabel(scope.treatments.deltaPct),
        // Fewer treatments = healthier herd → green when ↓.
        trendColor:
            _deltaColor(scope.treatments.deltaPct, downIsGood: true),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'FOR THIS PERIOD · $periodLabel',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _primary,
            ),
          ),
        ),
        KpiGrid(children: cards),
      ],
    );
  }
}
