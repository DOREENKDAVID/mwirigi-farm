import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_unit.dart';
import '../../core/util/responsive.dart';

/// "7-day production" line chart for the unified Layers Unit dashboard.
/// Single line in crates per day — matches the HTML mockup which only
/// shows a single curve in the right column.
class SevenDayChart extends StatelessWidget {
  const SevenDayChart({super.key, required this.points});
  final List<ProductionPoint> points;

  static const _line = Color(0xFF27500A);

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
            '7-DAY PRODUCTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartHeight(context, base: 200),
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No production data yet',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  )
                : _Chart(points: points),
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points});
  final List<ProductionPoint> points;

  @override
  Widget build(BuildContext context) {
    const color = SevenDayChart._line;

    final values = points.map((p) => p.cratesCollected.toDouble()).toList();
    final dataMax = values.fold<double>(0, (a, b) => a > b ? a : b);
    final dataMin = values.fold<double>(dataMax, (a, b) => a < b ? a : b);
    final range = (dataMax - dataMin).abs();
    final maxY = dataMax + (range * 0.1).clamp(5, 60);
    final minY = (dataMin - (range * 0.1).clamp(5, 60))
        .clamp(0, double.infinity)
        .toDouble();

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].cratesCollected.toDouble()),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
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
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                value.round().toString(),
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
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('E').format(points[i].date),
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
