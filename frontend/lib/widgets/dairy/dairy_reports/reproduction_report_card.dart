import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/dairy_report.dart';
import 'report_widgets.dart';

class ReproductionReportCard extends StatelessWidget {
  const ReproductionReportCard({super.key, required this.report});
  final ReproductionReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final df = DateFormat('d MMM yy');
    final pregRate = r.pregnancyRate == null
        ? '—'
        : '${r.pregnancyRate!.toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportKpiGrid(cells: [
          ReportKpi(
            label: 'AI DONE',
            value: '${r.totals.aiCount}',
            sub:
                '${r.period.label} · ${df.format(r.period.start)} → ${df.format(r.period.end)}',
          ),
          ReportKpi(
            label: 'PREGNANCIES',
            value: '${r.totals.pregnanciesConfirmed}',
            sub: '${r.totals.pendingChecks} pending check',
            color: const Color(0xFF1D9E75),
          ),
          ReportKpi(
            label: 'CALVINGS',
            value: '${r.totals.calvings}',
            sub: '${r.totals.expectedCalvings} expected ahead',
          ),
          ReportKpi(
            label: 'PREG. RATE',
            value: pregRate,
            sub: r.conceptionRate == null
                ? 'Of decided checks'
                : 'Conception ${r.conceptionRate!.toStringAsFixed(1)}%',
            color: const Color(0xFFAC7B0F),
          ),
        ]),
        const SizedBox(height: 10),
        ReportDeltaStrip(
          delta: r.totals.deltaPct,
          previousLabel: '${r.totals.prevAiCount} AI',
          currentLabel: '${r.totals.aiCount} AI',
        ),
        const SizedBox(height: 10),

        // AI / Calving trend — two compact line charts side by side
        // on tablets, stacked on phones.
        LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 560;
            final ai = ReportSection(
              title: 'AI TREND',
              child: SizedBox(
                height: 140,
                child: _CountLineChart(
                  points: r.aiTrend,
                  color: reportPrimary,
                ),
              ),
            );
            final calvings = ReportSection(
              title: 'CALVING TREND',
              child: SizedBox(
                height: 140,
                child: _CountLineChart(
                  points: r.calvingTrend,
                  color: const Color(0xFFAC7B0F),
                ),
              ),
            );
            if (stacked) {
              return Column(
                children: [
                  ai,
                  const SizedBox(height: 10),
                  calvings,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: ai),
                const SizedBox(width: 10),
                Expanded(child: calvings),
              ],
            );
          },
        ),
        const SizedBox(height: 10),

        ReportSection(
          title: 'UPCOMING CALVINGS',
          child: r.upcomingCalvings.isEmpty
              ? const _Empty(text: 'No expected calvings on file.')
              : Column(
                  children: [
                    for (final u in r.upcomingCalvings.take(8))
                      _UpcomingRow(item: u),
                  ],
                ),
        ),
        const SizedBox(height: 10),

        ReportSection(
          title: 'RECENT REPRO EVENTS',
          child: r.recentEvents.isEmpty
              ? const _Empty(text: 'No reproduction events in this period.')
              : Column(
                  children: [
                    for (final e in r.recentEvents.take(10))
                      _RecentEventRow(event: e),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CountLineChart extends StatelessWidget {
  const _CountLineChart({required this.points, required this.color});
  final List<ReportDailyCount> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _Empty(text: 'No data for this period.');
    }
    final maxY = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final yMax = (maxY <= 0 ? 4 : (maxY + 1)).toDouble();
    final step = (points.length / 8).ceil().clamp(1, 30);
    return LineChart(
      LineChartData(
        minY: 0,
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
                style:
                    const TextStyle(fontSize: 10, color: reportTxt3),
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
                if (i % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    points[i].dow,
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
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.08),
            ),
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].count.toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});
  final UpcomingCalving item;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yy');
    final days = item.daysOut;
    final urgent = days != null && days <= 7;
    final tagColor =
        urgent ? const Color(0xFFC4393B) : const Color(0xFFAC7B0F);
    final tagBg = urgent
        ? const Color(0xFFFCEDEC)
        : const Color(0xFFFCEDC8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tag ?? '—',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: reportPrimary,
                  ),
                ),
                if (item.nickname != null && item.nickname!.isNotEmpty)
                  Text(
                    item.nickname!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: reportTxt2,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              item.expectedCalvingDate == null
                  ? '—'
                  : df.format(item.expectedCalvingDate!),
              style: const TextStyle(fontSize: 12, color: reportTxt2),
            ),
          ),
          ReportTag(
            text: days == null
                ? '—'
                : (days >= 0 ? 'in ${days}d' : '${-days}d late'),
            bg: tagBg,
            fg: tagColor,
          ),
        ],
      ),
    );
  }
}

class _RecentEventRow extends StatelessWidget {
  const _RecentEventRow({required this.event});
  final ReproductionEvent event;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final isAi = event.eventType == 'AI';
    final tagBg = isAi
        ? const Color(0xFFEAF3DE)
        : const Color(0xFFFCEDC8);
    final tagFg = isAi
        ? reportPrimary
        : const Color(0xFFAC7B0F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReportTag(
            text: isAi ? 'AI' : 'CALVING',
            bg: tagBg,
            fg: tagFg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.cowTag ?? '—'}'
                  '${event.cowNickname == null ? '' : ' · ${event.cowNickname}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    df.format(event.eventDate),
                    if (event.sireCode != null && event.sireCode!.isNotEmpty)
                      'sire ${event.sireCode}',
                    if (event.calfSex != null && event.calfTag != null)
                      '${event.calfSex == 'F' ? '♀' : '♂'} ${event.calfTag}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: reportTxt2),
                ),
              ],
            ),
          ),
          if (event.pregnancyStatus != null)
            Text(
              event.pregnancyStatus!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: event.pregnancyStatus == 'CONFIRMED'
                    ? const Color(0xFF1D9E75)
                    : event.pregnancyStatus == 'PENDING'
                        ? const Color(0xFFAC7B0F)
                        : reportTxt3,
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
