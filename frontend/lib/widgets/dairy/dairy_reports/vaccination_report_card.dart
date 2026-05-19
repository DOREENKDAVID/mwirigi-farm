import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/dairy_report.dart';
import 'report_widgets.dart';

class VaccinationReportCard extends StatelessWidget {
  const VaccinationReportCard({super.key, required this.report});
  final VaccinationReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final df = DateFormat('d MMM yy');
    final coverage = r.totals.coveragePct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportKpiGrid(cells: [
          ReportKpi(
            label: 'DONE',
            value: '${r.totals.completed}',
            sub:
                '${r.period.label} · ${df.format(r.period.start)} → ${df.format(r.period.end)}',
            color: const Color(0xFF1D9E75),
          ),
          ReportKpi(
            label: 'UPCOMING',
            value: '${r.totals.upcoming}',
            sub: 'Due in 30 days',
            color: const Color(0xFFAC7B0F),
          ),
          ReportKpi(
            label: 'OVERDUE',
            value: '${r.totals.overdue}',
            sub: 'Action needed',
            color: const Color(0xFFC4393B),
          ),
          ReportKpi(
            label: 'COVERAGE',
            value: coverage == null
                ? '—'
                : '${coverage.toStringAsFixed(0)}%',
            sub: '${r.totals.activeCows} active cows',
          ),
        ]),
        const SizedBox(height: 10),
        ReportDeltaStrip(
          delta: r.totals.deltaPct,
          previousLabel: '${r.totals.prev} done',
          currentLabel: '${r.totals.completed} done',
        ),
        const SizedBox(height: 10),

        ReportSection(
          title: 'MONTHLY TREND',
          child: SizedBox(
            height: 160,
            child: _MonthlyBars(points: r.monthlyTrend),
          ),
        ),
        const SizedBox(height: 10),

        ReportSection(
          title: 'UPCOMING / OVERDUE',
          child: r.upcomingVaccinations.isEmpty
              ? const _Empty(
                  text:
                      'All dairy protocols are on schedule — nothing due soon.')
              : Column(
                  children: [
                    for (final s in r.upcomingVaccinations.take(8))
                      _ScheduleRow(s: s),
                  ],
                ),
        ),
        const SizedBox(height: 10),

        ReportSection(
          title: 'RECENT VACCINATIONS',
          trailing: Text(
            'Source: Health module',
            style: const TextStyle(fontSize: 10, color: reportTxt3),
          ),
          child: r.recentVaccinations.isEmpty
              ? const _Empty(text: 'No vaccinations recorded in this period.')
              : Column(
                  children: [
                    for (final v in r.recentVaccinations.take(10))
                      _RecentRow(v: v),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.points});
  final List<VaccinationMonthPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _Empty(text: 'No vaccinations in this period.');
    }
    final maxV = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final yMax = (maxV <= 0 ? 4 : (maxV + 1)).toDouble();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: reportGrid, strokeWidth: 1),
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
              reservedSize: 26,
              interval: (yMax / 4).clamp(1, double.infinity),
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: reportTxt3),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                // yyyy-MM → "Mon yy"
                final parts = points[i].month.split('-');
                if (parts.length != 2) return const SizedBox.shrink();
                final year = int.tryParse(parts[0]) ?? 0;
                final month = int.tryParse(parts[1]) ?? 1;
                final label = DateFormat('MMM yy')
                    .format(DateTime(year, month, 1));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: reportTxt3,
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
                  toY: points[i].count.toDouble(),
                  color: const Color(0xFF378ADD),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.s});
  final VaccinationSchedule s;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yy');
    final overdue = s.status == 'OVERDUE';
    final tagBg = overdue
        ? const Color(0xFFFCEDEC)
        : const Color(0xFFFCEDC8);
    final tagFg =
        overdue ? const Color(0xFFC4393B) : const Color(0xFFAC7B0F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  s.lastAdministeredAt == null
                      ? 'Never administered'
                      : 'Last: ${df.format(s.lastAdministeredAt!)}',
                  style:
                      const TextStyle(fontSize: 11, color: reportTxt2),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ReportTag(
                text: overdue
                    ? '${s.daysUntilDue.abs()}d late'
                    : 'in ${s.daysUntilDue}d',
                bg: tagBg,
                fg: tagFg,
              ),
              const SizedBox(height: 3),
              Text(
                s.nextDueAt == null ? '—' : df.format(s.nextDueAt!),
                style: const TextStyle(fontSize: 10, color: reportTxt3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.v});
  final RecentVaccination v;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yy');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Text('💉', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.vaccine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${v.animalCount} animal${v.animalCount == 1 ? '' : 's'} · ${df.format(v.administeredAt)}',
                  style:
                      const TextStyle(fontSize: 11, color: reportTxt2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: reportTxt3),
          ),
        ),
      );
}
