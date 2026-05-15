// 7-day trends card — milk (litres/day) + eggs (crates/day), shown as
// two stacked line charts inside one card. Stacking instead of dual-
// axis keeps each line readable since milk (300–2000 L) and eggs
// (100–700 crates) sit on very different scales.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models/dashboard_overview.dart';
import '../../core/util/responsive.dart';

class TrendsCard extends StatelessWidget {
  const TrendsCard({
    super.key,
    required this.milkPoints,
    required this.eggsPoints,
  });

  final List<MilkTrendPoint> milkPoints;
  final List<EggsTrendPoint> eggsPoints;

  static const _milkColor = Color(0xFF27500A);
  static const _eggsColor = Color(0xFFEF9F27);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '7-DAY PRODUCTION TRENDS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _LegendDot(color: _milkColor, label: 'Milk (L)'),
              const SizedBox(width: 14),
              _LegendDot(color: _eggsColor, label: 'Eggs (crates)'),
            ],
          ),
          const SizedBox(height: 14),
          _TrendBlock(
            label: 'MILK — LITRES',
            color: _milkColor,
            days: [for (final p in milkPoints) p.day],
            values: [for (final p in milkPoints) p.value],
            emptyMessage: 'No milk records in the last 7 days',
          ),
          const SizedBox(height: 18),
          _TrendBlock(
            label: 'EGGS — CRATES',
            color: _eggsColor,
            days: [for (final p in eggsPoints) p.day],
            values: [for (final p in eggsPoints) p.value],
            emptyMessage: 'No egg records in the last 7 days',
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _TrendBlock extends StatelessWidget {
  const _TrendBlock({
    required this.label,
    required this.color,
    required this.days,
    required this.values,
    required this.emptyMessage,
  });
  final String label;
  final Color color;
  final List<String> days;
  final List<int> values;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final hasData = values.any((v) => v > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: chartHeight(context, base: 160, maxPx: 220),
          child: hasData
              ? _LineChart(days: days, values: values, color: color)
              : Center(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.days,
    required this.values,
    required this.color,
  });
  final List<String> days;
  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i].toDouble()),
    ];
    final maxV = values.fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    final minV = values.fold<int>(values.first, (a, b) => a < b ? a : b).toDouble();
    final pad = ((maxV - minV).abs() * 0.15).clamp(20.0, 200.0);
    final yMin = (minV - pad).clamp(0, double.infinity).toDouble();
    final yMax = maxV + pad;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (values.length - 1).toDouble(),
        minY: yMin,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0x14000000),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    days[i],
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) =>
                  FlDotCirclePainter(radius: 3, color: color),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }
}
