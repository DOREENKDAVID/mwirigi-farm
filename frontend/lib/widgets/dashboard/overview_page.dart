import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/dashboard_overview.dart';
import '../../core/service/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardOverview> _load() async {
    final raw = await ApiService.getDashboardOverview();
    return DashboardOverview.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
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
        ? (data.milkToday / data.milkTarget * 100).round()
        : 0;
    final eggPct = data.eggTarget > 0
        ? (data.eggCrates / data.eggTarget * 100).round()
        : 0;
    final pigPct = data.pigletTarget > 0
        ? (data.pigletsMTD / data.pigletTarget * 100).round()
        : 0;

    final cards = <Widget>[
      KpiCard(
        label: 'Milk today',
        value: '${fmt.format(data.milkToday)} L',
        sub: 'Target: ${fmt.format(data.milkTarget)} L/day',
        trend: '$milkPct% of target',
        trendColor: _pctColor(milkPct),
      ),
      KpiCard(
        label: 'Egg crates',
        value: fmt.format(data.eggCrates),
        sub: 'Target: ${fmt.format(data.eggTarget)}/day',
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
