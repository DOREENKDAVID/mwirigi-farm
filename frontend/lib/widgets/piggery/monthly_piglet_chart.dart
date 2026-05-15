import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/util/responsive.dart';

/// "Monthly piglet offtake" bar chart. One bar per month from the
/// `/api/piggery/trend` payload, oldest → newest left to right.
class MonthlyPigletChart extends StatelessWidget {
  const MonthlyPigletChart({super.key, required this.points});

  final List<MonthlyPigletPoint> points;

  static const _barColor = Color(0xFFEF9F27);

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
            'MONTHLY PIGLET OFFTAKE',
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
                      'No farrowing records yet',
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
  final List<MonthlyPigletPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(0, (a, b) => a > b.piglets ? a : b.piglets);
    // Round the y-axis up to a clean number for breathing room.
    final yMax = maxValue == 0 ? 10.0 : ((maxValue / 20).ceil() * 20).toDouble();
    final interval = yMax / 5;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
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
              interval: interval,
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
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                final monthDate = points[i].monthDate;
                final label = monthDate == null
                    ? points[i].month
                    : DateFormat('MMM').format(monthDate);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
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
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].piglets.toDouble(),
                  color: MonthlyPigletChart._barColor,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
