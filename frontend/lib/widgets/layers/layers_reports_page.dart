// Layers Reports dashboard.
//
// Standalone page accessible from the Reports catalog (egg-records entry
// has dashboardKey: "layers"). Mirrors the Dairy Reports page pattern:
//   • Filter bar pinned at top  (Period + House pills, own local state)
//   • Production analytics body (KPIs · previous-period delta · daily chart
//                                · per-house breakdown)
//   • "Download PDF" in the app-bar action

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_report.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/layers_report_pdf.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';

class LayersReportsPage extends StatefulWidget {
  const LayersReportsPage({super.key});

  @override
  State<LayersReportsPage> createState() => _LayersReportsPageState();
}

class _LayersReportsPageState extends State<LayersReportsPage> {
  static const _primary = Color(0xFF27500A);
  static const _bg = Color(0xFFF5F4F0);
  static const _txt2 = Color(0xFF6B7770);

  // Filter state — independent of the main Layers Unit page.
  _Period _period = _Period.month;
  DateTimeRange? _customRange;
  String? _houseId;

  // House options for the filter pills.
  List<_HouseOption> _houses = const [];
  bool _housesLoaded = false;

  Future<LayersProductionReport>? _future;

  @override
  void initState() {
    super.initState();
    _loadHouses();
    _future = _fetch();
  }

  Future<void> _loadHouses() async {
    try {
      final raw = await ApiService.getLayersHouses();
      if (!mounted) return;
      setState(() {
        _houses = raw
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((m) => _HouseOption(
                  id: (m['id'] ?? '').toString(),
                  name: (m['name'] ?? '').toString(),
                ))
            .where((h) => h.id.isNotEmpty)
            .toList();
        _housesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _housesLoaded = true);
    }
  }

  Future<LayersProductionReport> _fetch() async {
    final raw = await ApiService.getLayersProductionReport(
      houseId: _houseId,
      period: _period == _Period.custom ? 'custom' : _period.wire,
      startDate: _period == _Period.custom ? _customRange?.start : null,
      endDate: _period == _Period.custom ? _customRange?.end : null,
    );
    return LayersProductionReport.fromJson(raw);
  }

  void _refetch() => setState(() => _future = _fetch());

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _period = _Period.custom;
    });
    _refetch();
  }

  Future<void> _downloadPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await (_future ?? _fetch());
      final houseLabel = _houseId == null
          ? null
          : _houses.where((h) => h.id == _houseId).firstOrNull?.name;
      await previewLayersReportPdf(
        report: report,
        periodLabel: _period == _Period.custom ? _customLabel() : _period.label,
        houseLabel: houseLabel,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
            'PDF export failed: ${e.toString().replaceFirst('Exception: ', '')}'),
      ));
    }
  }

  String _customLabel() {
    if (_customRange == null) return 'Custom';
    final fmt = DateFormat('d MMM');
    return '${fmt.format(_customRange!.start)} → ${fmt.format(_customRange!.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Layers Reports'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _downloadPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Download PDF'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(child: _buildFilterBar()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            sliver: SliverToBoxAdapter(child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pillRow(
            label: 'Period',
            children: [
              for (final p in _Period.values)
                _Pill(
                  label: p == _Period.custom && _customRange != null
                      ? _customLabel()
                      : p.label,
                  selected: _period == p,
                  onTap: () async {
                    if (p == _Period.custom) {
                      await _pickCustomRange();
                    } else {
                      setState(() {
                        _period = p;
                        _customRange = null;
                      });
                      _refetch();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          _pillRow(
            label: 'House',
            children: [
              _Pill(
                label: 'All houses',
                selected: _houseId == null,
                onTap: () {
                  setState(() => _houseId = null);
                  _refetch();
                },
              ),
              if (_housesLoaded)
                for (final h in _houses)
                  _Pill(
                    label: h.name,
                    selected: _houseId == h.id,
                    onTap: () {
                      setState(() => _houseId = h.id);
                      _refetch();
                    },
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillRow({required String label, required List<Widget> children}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _txt2,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return FutureBuilder<LayersProductionReport>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _ErrorCard(
            message: snap.error.toString(),
            onRetry: _refetch,
          );
        }
        return _ProductionBody(report: snap.data!);
      },
    );
  }
}

// ── Production body ───────────────────────────────────────────────────

class _ProductionBody extends StatelessWidget {
  const _ProductionBody({required this.report});
  final LayersProductionReport report;

  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  String _fmtCrates(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _deltaLabel(double? d) {
    if (d == null) return '— vs previous';
    final sign = d >= 0 ? '+' : '';
    return '$sign${d.toStringAsFixed(1)}% vs previous';
  }

  Color _deltaColor(double? d, {required bool downIsGood}) {
    if (d == null) return _txt2;
    final good = downIsGood ? d <= 0 : d >= 0;
    return good ? const Color(0xFF1D9E75) : const Color(0xFFC4393B);
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    final periodFmt = DateFormat('d MMM yy');
    final crateDelta = r.delta.crates;
    final deltaColor = _deltaColor(crateDelta, downIsGood: false);
    final deltaText = _deltaLabel(crateDelta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Period label
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'FOR THIS PERIOD · ${r.period.label} · '
            '${periodFmt.format(r.period.start)} → ${periodFmt.format(r.period.end)}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _primary,
            ),
          ),
        ),

        // KPI strip
        KpiGrid(children: [
          KpiCard(
            label: 'Crates',
            value: _fmtCrates(r.totals.crates),
            sub: '${NumberFormat.decimalPattern().format(r.totals.eggs)} eggs',
            trend: _deltaLabel(r.delta.crates),
            trendColor: _deltaColor(r.delta.crates, downIsGood: false),
          ),
          KpiCard(
            label: 'Active birds',
            value: NumberFormat.decimalPattern().format(r.totals.activeBirds),
            sub: 'Latest closing stock',
          ),
          KpiCard(
            label: 'Mortality',
            value: NumberFormat.decimalPattern().format(r.totals.dead),
            sub: 'vs ${NumberFormat.decimalPattern().format(r.previousTotals.dead)} last period',
            trend: _deltaLabel(r.delta.dead),
            trendColor: _deltaColor(r.delta.dead, downIsGood: true),
          ),
          KpiCard(
            label: 'Feed (kg)',
            value: r.totals.feedKg.toStringAsFixed(1),
            sub: 'vs ${r.previousTotals.feedKg.toStringAsFixed(1)} last period',
            trend: _deltaLabel(r.delta.feedKg),
            trendColor: _deltaColor(r.delta.feedKg, downIsGood: false),
          ),
        ]),
        const SizedBox(height: 12),

        // Previous-period comparison strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Row(
            children: [
              Icon(
                crateDelta == null
                    ? Icons.remove
                    : crateDelta >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                color: deltaColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deltaText,
                      style: TextStyle(
                        color: deltaColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Previous: ${_fmtCrates(r.previousTotals.crates)} crates'
                      ' · This period: ${_fmtCrates(r.totals.crates)} crates',
                      style: const TextStyle(fontSize: 11, color: _txt2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Daily crates chart
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: _txt2,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: r.daily.isEmpty
                    ? const Center(
                        child: Text(
                          'No records for this period.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF99A39B)),
                        ),
                      )
                    : _DailyCratesChart(daily: r.daily),
              ),
            ],
          ),
        ),

        // Per-house breakdown
        if (r.houses.length > 1) ...[
          const SizedBox(height: 12),
          _HousesBreakdown(houses: r.houses),
        ],
      ],
    );
  }
}

class _DailyCratesChart extends StatelessWidget {
  const _DailyCratesChart({required this.daily});
  final List<LayersDailyPoint> daily;

  static const _bar = Color(0xFF7DA567);
  static const _grid = Color(0xFFE6EBE0);

  @override
  Widget build(BuildContext context) {
    final maxV =
        daily.fold<double>(0, (m, p) => p.crates > m ? p.crates : m);
    final yMax = (maxV <= 0 ? 4.0 : maxV * 1.15).ceilToDouble();
    final step = (daily.length / 12).ceil().clamp(1, 30);

    return LayoutBuilder(
      builder: (context, c) {
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
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: _grid, strokeWidth: 1),
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
                          fontSize: 10, color: Color(0xFF99A39B)),
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
                              fontSize: 10, color: Color(0xFF99A39B)),
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
                        color: _bar,
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
          for (final h in houses) _HouseBar(house: h, maxCrates: maxCrates),
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
    final pct =
        maxCrates > 0 ? (house.crates / maxCrates).clamp(0.0, 1.0) : 0.0;
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
                      fontSize: 13, fontWeight: FontWeight.w700),
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

// ── Period enum ───────────────────────────────────────────────────────

enum _Period {
  today('Today', 'today'),
  yesterday('Yesterday', 'yesterday'),
  week('This Week', 'this_week'),
  lastWeek('Last Week', 'last_week'),
  month('This Month', 'this_month'),
  lastMonth('Last Month', 'last_month'),
  quarter('Quarter', 'this_quarter'),
  year('This Year', 'this_year'),
  custom('Custom', 'custom');

  const _Period(this.label, this.wire);
  final String label;
  final String wire;
}

// ── House option ──────────────────────────────────────────────────────

class _HouseOption {
  const _HouseOption({required this.id, required this.name});
  final String id;
  final String name;
}

// ── Pill widget ───────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF27500A) : Colors.white;
    final fg = selected ? Colors.white : const Color(0xFF27500A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF27500A)
                : const Color(0x22000000),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Persistent header delegate ────────────────────────────────────────

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({required this.child});
  final Widget child;

  static const double _height = 110;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext c, double shrinkOffset, bool overlapsContent) =>
      SizedBox(height: _height, child: child);

  @override
  bool shouldRebuild(_FilterHeaderDelegate old) => old.child != child;
}

// ── Error card ────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load report.\n'
              '${message.replaceFirst('Exception: ', '')}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
