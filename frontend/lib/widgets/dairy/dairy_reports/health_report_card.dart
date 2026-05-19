import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/dairy_report.dart';
import 'report_widgets.dart';

class HealthReportCard extends StatelessWidget {
  const HealthReportCard({super.key, required this.report});
  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final df = DateFormat('d MMM yy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportKpiGrid(cells: [
          ReportKpi(
            label: 'SICK ANIMALS',
            value: '${r.totals.sick}',
            sub:
                '${r.period.label} · ${df.format(r.period.start)} → ${df.format(r.period.end)}',
            color: const Color(0xFFC4393B),
          ),
          ReportKpi(
            label: 'ACTIVE CASES',
            value: '${r.totals.active}',
            sub: '${r.totals.recovered} recovered',
            color: const Color(0xFFAC7B0F),
          ),
          ReportKpi(
            label: 'RECOVERED',
            value: '${r.totals.recovered}',
            sub: 'In this period',
            color: const Color(0xFF1D9E75),
          ),
          ReportKpi(
            label: 'CRITICAL',
            value: '${r.totals.critical}',
            sub: 'Severe-tagged cases',
            color: const Color(0xFFC4393B),
          ),
        ]),
        const SizedBox(height: 10),
        ReportDeltaStrip(
          delta: r.totals.deltaPct,
          previousLabel: '${r.totals.prev} cases',
          currentLabel: '${r.totals.sick} cases',
        ),
        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 560;
            final diseases = ReportSection(
              title: 'TOP DIAGNOSES',
              child: r.diseases.isEmpty
                  ? const _Empty(text: 'No cases recorded.')
                  : SizedBox(
                      height: 180,
                      child: _DiseaseBarChart(rows: r.diseases),
                    ),
            );
            final houses = ReportSection(
              title: 'ACTIVE BY HOUSE',
              child: r.houseBreakdown.isEmpty
                  ? const _Empty(text: 'No active cases.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final h in r.houseBreakdown.take(8))
                          _HouseRow(row: h, totalActive: r.totals.active),
                      ],
                    ),
            );
            return stacked
                ? Column(
                    children: [
                      diseases,
                      const SizedBox(height: 10),
                      houses,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: diseases),
                      const SizedBox(width: 10),
                      Expanded(child: houses),
                    ],
                  );
          },
        ),
        const SizedBox(height: 10),

        ReportSection(
          title: 'PENDING CASES',
          child: r.pendingCases.isEmpty
              ? const _Empty(text: 'No pending cases — herd is clean.')
              : Column(
                  children: [
                    for (final c in r.pendingCases.take(12))
                      _CaseRow(item: c),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DiseaseBarChart extends StatelessWidget {
  const _DiseaseBarChart({required this.rows});
  final List<DiseaseFrequency> rows;

  @override
  Widget build(BuildContext context) {
    final maxV = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);
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
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= rows.length) {
                  return const SizedBox.shrink();
                }
                final label = rows[i].diagnosis;
                final short = label.length > 10
                    ? '${label.substring(0, 9)}…'
                    : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    short,
                    style: const TextStyle(
                      fontSize: 9,
                      color: reportTxt3,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rows[i].count.toDouble(),
                  color: const Color(0xFFC4393B),
                  width: 12,
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

class _HouseRow extends StatelessWidget {
  const _HouseRow({required this.row, required this.totalActive});
  final HouseHealthCount row;
  final int totalActive;

  @override
  Widget build(BuildContext context) {
    final pct = totalActive > 0 ? row.count / totalActive : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.houseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${row.count}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC4393B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: pct.clamp(0, 1),
              backgroundColor: const Color(0xFFEFEDE6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFC4393B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.item});
  final PendingCase item;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final color = _statusColor(item.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.tag}'
                  '${item.nickname == null ? '' : ' · ${item.nickname}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item.diagnosis} · ${item.medication}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: reportTxt2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ReportTag(
                text: item.status,
                bg: color.withValues(alpha: 0.12),
                fg: color,
              ),
              const SizedBox(height: 3),
              Text(
                'since ${df.format(item.startDate)}',
                style: const TextStyle(fontSize: 10, color: reportTxt3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ACTIVE':
        return const Color(0xFFC4393B);
      case 'IMPROVING':
        return const Color(0xFFAC7B0F);
      case 'RECOVERED':
        return const Color(0xFF1D9E75);
      default:
        return reportTxt2;
    }
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
