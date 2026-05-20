// =====================================================================
// LayersProductionAnalyticsCard
// =====================================================================
// Production pill body. Period + house filters at the top (shared
// PeriodFilterPanel + HouseFilterPills), a KPI strip with previous-
// period deltas, and a daily crates bar chart below. Reads filter
// state from the app-level PeriodFilterController so the selection
// persists across tabs.
//
// Doesn't touch the legacy daily-entry form / today + 7-day endpoints
// — the analytics endpoint (`/api/layers/reports/production`) is a
// separate path so this is purely additive.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/layers_report.dart';
import '../../core/service/analytics_cache.dart';
import '../../core/service/api_service.dart';
import '../../core/state/period_filter_controller.dart';
import '../../core/util/period.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import '../shared/house_filter_pills.dart';
import '../shared/period_filter_panel.dart';

class LayersProductionAnalyticsCard extends StatefulWidget {
  const LayersProductionAnalyticsCard({super.key});

  @override
  State<LayersProductionAnalyticsCard> createState() =>
      _LayersProductionAnalyticsCardState();
}

class _LayersProductionAnalyticsCardState
    extends State<LayersProductionAnalyticsCard> {
  // One cache per card instance. Keyed by the filter signature so
  // flicking between Today and Yesterday and back is instant on the
  // second hit, and tap-to-cancel debounce prevents request floods.
  final _cache = AnalyticsCache();

  Future<LayersProductionReport>? _future;
  List<HouseFilterOption> _houseOptions = const [];
  bool _houseOptionsLoaded = false;

  // Track the last-applied filter signature so we don't re-fetch on
  // every Provider rebuild — only when the relevant values change.
  String? _lastSig;

  @override
  void initState() {
    super.initState();
    _loadHouses();
    // Defer the first fetch until didChangeDependencies sees the
    // PeriodFilterController.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<PeriodFilterController>();
    final sig = _signature(controller);
    if (sig != _lastSig) {
      _lastSig = sig;
      _future = _load(controller);
    }
  }

  Future<void> _loadHouses() async {
    try {
      final raw = await ApiService.getLayersHouses();
      if (!mounted) return;
      setState(() {
        _houseOptions = raw
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((m) => HouseFilterOption(
                  id: (m['id'] ?? '').toString(),
                  label: (m['name'] ?? '').toString(),
                ))
            .where((h) => h.id.isNotEmpty)
            .toList();
        _houseOptionsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _houseOptionsLoaded = true);
    }
  }

  String _signature(PeriodFilterController c) {
    final s = c.customStart?.toIso8601String() ?? '';
    final e = c.customEnd?.toIso8601String() ?? '';
    return 'layers|${c.period.wire}|${c.houseId ?? ''}|$s|$e';
  }

  Future<LayersProductionReport> _load(PeriodFilterController c) {
    if (!c.isReady) {
      // Custom range without both dates — return a placeholder
      // future that resolves to an empty report. The UI shows the
      // empty state instead of erroring.
      return Future.value(_emptyReport(c));
    }
    final sig = _signature(c);
    return _cache.run<LayersProductionReport>(sig, () async {
      final raw = await ApiService.getLayersProductionReport(
        houseId: c.houseId,
        period: c.period.wire,
        startDate:
            c.period == PeriodPreset.custom ? c.customStart : null,
        endDate: c.period == PeriodPreset.custom ? c.customEnd : null,
      );
      return LayersProductionReport.fromJson(raw);
    });
  }

  LayersProductionReport _emptyReport(PeriodFilterController c) {
    final now = DateTime.now();
    return LayersProductionReport(
      period: LayersReportPeriodWindow(
        label: 'Pick a custom range',
        start: now,
        end: now,
        prevStart: now,
        prevEnd: now,
      ),
      totals: LayersReportTotals(
        eggs: 0,
        crates: 0,
        dead: 0,
        feedKg: 0,
        activeBirds: 0,
      ),
      previousTotals: LayersReportPreviousTotals(
        eggs: 0,
        crates: 0,
        dead: 0,
        feedKg: 0,
      ),
      delta: LayersReportDelta(
        crates: null,
        eggs: null,
        dead: null,
        feedKg: null,
      ),
      daily: const [],
      houses: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PeriodFilterController>();
    // Refetch whenever the controller's relevant signature changes.
    final sig = _signature(controller);
    if (sig != _lastSig) {
      _lastSig = sig;
      _future = _load(controller);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeriodFilterPanel(
          selectedPeriod: controller.period,
          onChanged: controller.setPeriod,
          customStartDate: controller.customStart,
          customEndDate: controller.customEnd,
          onCustomRangeSelected: controller.setCustomRange,
          title: 'Period',
        ),
        const SizedBox(height: 10),
        if (_houseOptionsLoaded && _houseOptions.isNotEmpty)
          HouseFilterPills(
            options: _houseOptions,
            selectedId: controller.houseId,
            onChanged: controller.setHouseId,
            allLabel: 'All houses',
          ),
        const SizedBox(height: 12),
        FutureBuilder<LayersProductionReport>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return _ErrorBlock(
                message:
                    snap.error.toString().replaceFirst('Exception: ', ''),
                onRetry: () => setState(() {
                  _cache.clear();
                  _future = _load(controller);
                }),
              );
            }
            final r = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PeriodLabel(report: r),
                const SizedBox(height: 8),
                _KpiStrip(report: r),
                const SizedBox(height: 12),
                _ChartCard(report: r),
                if (r.houses.length > 1) ...[
                  const SizedBox(height: 12),
                  _HousesBreakdown(houses: r.houses),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Header label ──────────────────────────────────────────────────────

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel({required this.report});
  final LayersProductionReport report;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        'FOR THIS PERIOD · ${report.period.label} · '
        '${fmt.format(report.period.start)} → ${fmt.format(report.period.end)}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF27500A),
        ),
      ),
    );
  }
}

// ── KPI strip ─────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.report});
  final LayersProductionReport report;

  String _fmtCrates(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _deltaLabel(double? d) {
    if (d == null) return '— vs previous';
    final sign = d >= 0 ? '+' : '';
    return '$sign${d.toStringAsFixed(1)}% vs previous';
  }

  Color _deltaColor(double? d, {required bool downIsGood}) {
    if (d == null) return const Color(0xFF6B7770);
    final good = downIsGood ? d <= 0 : d >= 0;
    return good ? const Color(0xFF1D9E75) : const Color(0xFFC4393B);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return KpiGrid(children: [
      KpiCard(
        label: 'Crates',
        value: _fmtCrates(report.totals.crates),
        sub: '${fmt.format(report.totals.eggs)} eggs',
        trend: _deltaLabel(report.delta.crates),
        trendColor: _deltaColor(report.delta.crates, downIsGood: false),
      ),
      KpiCard(
        label: 'Active birds',
        value: fmt.format(report.totals.activeBirds),
        sub: 'Latest closing stock',
      ),
      KpiCard(
        label: 'Mortality',
        value: fmt.format(report.totals.dead),
        sub: 'vs ${fmt.format(report.previousTotals.dead)} last period',
        trend: _deltaLabel(report.delta.dead),
        // Fewer dead = better → green when ↓.
        trendColor: _deltaColor(report.delta.dead, downIsGood: true),
      ),
      KpiCard(
        label: 'Feed (kg)',
        value: report.totals.feedKg.toStringAsFixed(1),
        sub:
            'vs ${report.previousTotals.feedKg.toStringAsFixed(1)} last period',
        trend: _deltaLabel(report.delta.feedKg),
        trendColor: _deltaColor(report.delta.feedKg, downIsGood: false),
      ),
    ]);
  }
}

// ── Daily chart ───────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.report});
  final LayersProductionReport report;

  static const _primary = Color(0xFF27500A);
  static const _bar = Color(0xFF7DA567);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY CRATES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _primary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: report.daily.isEmpty
                ? const Center(
                    child: Text(
                      'No records in this period.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF99A39B),
                      ),
                    ),
                  )
                : _DailyBars(daily: report.daily),
          ),
        ],
      ),
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily});
  final List<LayersDailyPoint> daily;

  @override
  Widget build(BuildContext context) {
    final maxV = daily.fold<double>(0, (m, p) => p.crates > m ? p.crates : m);
    final yMax = (maxV <= 0 ? 4.0 : (maxV * 1.15)).ceilToDouble();
    final step = (daily.length / 10).ceil().clamp(1, 30);

    return LayoutBuilder(
      builder: (context, c) {
        // When the window is wide (many days), allow horizontal scroll
        // so bars stay legible instead of compressing into hairlines.
        final desiredWidth = daily.length * 22.0;
        final scrolls = desiredWidth > c.maxWidth;
        final chart = SizedBox(
          width: scrolls ? desiredWidth : c.maxWidth,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: yMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: Color(0xFFE6EBE0),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: (yMax / 4).clamp(1, double.infinity),
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF99A39B),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= daily.length) {
                        return const SizedBox.shrink();
                      }
                      if (i % step != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          daily[i].dow,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF99A39B),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < daily.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: daily[i].crates,
                        color: _ChartCard._bar,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
        if (!scrolls) return chart;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: chart,
        );
      },
    );
  }
}

// ── Per-house breakdown ───────────────────────────────────────────────

class _HousesBreakdown extends StatelessWidget {
  const _HousesBreakdown({required this.houses});
  final List<LayersHouseSummary> houses;

  @override
  Widget build(BuildContext context) {
    final maxCrates =
        houses.fold<double>(0, (m, h) => h.crates > m ? h.crates : m);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PER HOUSE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF27500A),
            ),
          ),
          const SizedBox(height: 8),
          for (final h in houses)
            _HouseBar(house: h, maxCrates: maxCrates),
        ],
      ),
    );
  }
}

class _HouseBar extends StatelessWidget {
  const _HouseBar({required this.house, required this.maxCrates});
  final LayersHouseSummary house;
  final double maxCrates;

  @override
  Widget build(BuildContext context) {
    final pct = maxCrates > 0 ? (house.crates / maxCrates).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  house.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${house.crates.toStringAsFixed(1)} crates',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF27500A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: pct,
              backgroundColor: const Color(0xFFEFEDE6),
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF7DA567)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load production report.\n$message',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A5A0A),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
