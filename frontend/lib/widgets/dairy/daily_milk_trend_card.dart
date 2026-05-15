// "Daily milk — 7 days" bar chart card. One bar per day, day-of-week
// labels on the X axis, litres on the Y axis. Mirrors the v4.2 HTML
// mockup's chart styling — green olive bars on a white card.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/service/api_service.dart';
import '../../core/util/responsive.dart';

class DailyMilkTrendCard extends StatefulWidget {
  const DailyMilkTrendCard({super.key, this.days = 7});
  final int days;

  @override
  State<DailyMilkTrendCard> createState() => _DailyMilkTrendCardState();
}

class _DailyMilkTrendCardState extends State<DailyMilkTrendCard> {
  static const _primary = Color(0xFF27500A);
  static const _bar = Color(0xFF7DA567);
  static const _grid = Color(0xFFE6EBE0);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  late Future<List<_TrendPoint>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_TrendPoint>> _load() async {
    final raw = await ApiService.getDailyMilkTrend(days: widget.days);
    return raw
        .whereType<Map>()
        .map((m) => _TrendPoint.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: FutureBuilder<List<_TrendPoint>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return SizedBox(
              height: chartHeight(context, base: 320, maxPx: 360),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: _reload,
            );
          }
          final points = snap.data ?? const <_TrendPoint>[];
          final hasData = points.any((p) => p.litres > 0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'DAILY MILK — ${widget.days} DAYS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: _primary,
                    ),
                  ),
                  const Spacer(),
                  if (hasData)
                    Text(
                      'Total ${_fmt(points.fold<double>(0, (a, p) => a + p.litres))} L',
                      style: const TextStyle(fontSize: 11, color: _txt3),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _reload,
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: chartHeight(context, base: 320, maxPx: 360),
                child: hasData
                    ? _buildChart(points)
                    : const _EmptyState(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChart(List<_TrendPoint> points) {
    // Compute a "nice" Y-axis range so bars fill most of the height
    // without bumping the top label. Floor/ceil to the nearest 10.
    final maxY = points.map((p) => p.litres).reduce((a, b) => a > b ? a : b);
    final minY = points.map((p) => p.litres).reduce((a, b) => a < b ? a : b);
    final padTop = (maxY - minY) * 0.18;
    final niceMax = ((maxY + padTop) / 10).ceil() * 10.0;
    final niceMin =
        minY < 50 ? 0.0 : ((minY - padTop).clamp(0, double.infinity) ~/ 10) * 10.0;
    final interval = ((niceMax - niceMin) / 7).clamp(1, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        // Tighter group spacing so bars sit closer together on mobile.
        // Pairs with the wider per-bar width below.
        groupsSpace: 8,
        maxY: niceMax,
        minY: niceMin.toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval.toDouble(),
          getDrawingHorizontalLine: (_) => const FlLine(
            color: _grid,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval.toDouble(),
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _fmt(value),
                  style: const TextStyle(fontSize: 11, color: _txt2),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].dow,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _txt2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1F4008),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${points[group.x.toInt()].dow}\n${_fmt(rod.toY)} L',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].litres,
                  // Wider bars + tight groupsSpace yields the dense look
                  // requested for mobile.
                  width: 44,
                  color: _bar,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _TrendPoint {
  _TrendPoint({required this.date, required this.dow, required this.litres});
  final String date;
  final String dow;
  final double litres;

  factory _TrendPoint.fromJson(Map<String, dynamic> j) {
    final raw = j['litres'];
    final litres = raw is num
        ? raw.toDouble()
        : (raw is String ? (double.tryParse(raw) ?? 0) : 0).toDouble();
    return _TrendPoint(
      date: (j['date'] ?? '').toString(),
      dow: (j['dow'] ?? '').toString(),
      litres: litres,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No milk records in the last 7 days.',
        style: TextStyle(fontSize: 13, color: Color(0xFF6B7770)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load 7-day milk trend.\n$message',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
