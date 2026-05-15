import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers.dart';
import '../../core/util/responsive.dart';

/// "Production trend — last 7 days" card. Two lines:
///   - Eggs collected (left axis, green)
///   - % Laying        (right axis, brown)
///
/// fl_chart doesn't have a native dual-axis API; the two lines share one
/// y-axis but we draw them at very different scales by normalising %Laying
/// onto the same numeric range as eggs (×eggsMax/100). Tick labels for both
/// scales are drawn on left and right sides.
class ProductionTrendChart extends StatelessWidget {
  const ProductionTrendChart({super.key, required this.points});

  final List<TrendPoint> points;

  static const _eggsColor = Color(0xFF27500A);
  static const _layingColor = Color(0xFF854F0B);

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
            'PRODUCTION TREND — LAST 7 DAYS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartHeight(context, base: 220),
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No production data',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  )
                : _Chart(points: points),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: _eggsColor, label: 'Eggs'),
              const SizedBox(width: 16),
              _LegendDot(color: _layingColor, label: '% Laying'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    const eggsColor = ProductionTrendChart._eggsColor;
    const layingColor = ProductionTrendChart._layingColor;

    final eggsValues = points.map((p) => p.eggsCollected.toDouble()).toList();
    final eggsMax = eggsValues.fold<double>(0, (a, b) => a > b ? a : b);
    final eggsMin = eggsValues.fold<double>(eggsMax, (a, b) => a < b ? a : b);
    final eggsRangeMax = eggsMax + ((eggsMax - eggsMin).abs() * 0.1).clamp(50, 5000);
    final eggsRangeMin = (eggsMin - 50).clamp(0, double.infinity).toDouble();

    final eggsSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].eggsCollected.toDouble()),
    ];

    // Map %Laying (0..100) onto the eggs y-range so both lines render on
    // the same axis. The right-side ticks decode back to %.
    final layingSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(
          i.toDouble(),
          eggsRangeMin +
              (points[i].percentLaying.toDouble() / 100) *
                  (eggsRangeMax - eggsRangeMin),
        ),
    ];

    String pctFromY(double y) {
      final pct =
          ((y - eggsRangeMin) / (eggsRangeMax - eggsRangeMin)) * 100;
      return '${pct.round()}';
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: eggsRangeMin,
        maxY: eggsRangeMax,
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
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, _) => Text(
                NumberFormat.compact().format(value),
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) => Text(
                pctFromY(value),
                style: const TextStyle(
                  fontSize: 10,
                  color: layingColor,
                ),
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
                    DateFormat('d MMM').format(points[i].date),
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
            spots: eggsSpots,
            isCurved: true,
            color: eggsColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) =>
                  FlDotCirclePainter(radius: 3, color: eggsColor),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: eggsColor.withValues(alpha: 0.07),
            ),
          ),
          LineChartBarData(
            spots: layingSpots,
            isCurved: true,
            color: layingColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) =>
                  FlDotCirclePainter(radius: 3, color: layingColor),
            ),
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
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
