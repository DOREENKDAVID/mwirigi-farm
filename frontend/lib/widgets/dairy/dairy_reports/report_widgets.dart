// Shared building blocks for the Dairy Reports cards.
//
// KPI grid + cells, "vs previous period" strip, and section card frame
// are pulled out so each report card can compose them rather than
// re-declaring tight typography rules every time.

import 'package:flutter/material.dart';

const reportPrimary = Color(0xFF27500A);
const reportTxt2    = Color(0xFF6B7770);
const reportTxt3    = Color(0xFF99A39B);
const reportBar     = Color(0xFF7DA567);
const reportGrid    = Color(0xFFE6EBE0);
const reportBorder  = Color(0x14000000);

class ReportKpi {
  const ReportKpi({
    required this.label,
    required this.value,
    required this.sub,
    this.suffix,
    this.color = reportPrimary,
  });
  final String label;
  final String value;
  final String? suffix;
  final String sub;
  final Color color;
}

/// Responsive KPI strip. Two-up on phones, four-up on tablet+.
class ReportKpiGrid extends StatelessWidget {
  const ReportKpiGrid({super.key, required this.cells});
  final List<ReportKpi> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 4 : 2;
        final width = (c.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final cell in cells)
              SizedBox(width: width, child: _Cell(cell)),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.k);
  final ReportKpi k;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: reportBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            k.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: reportTxt3,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  k.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: k.color,
                    height: 1.05,
                  ),
                ),
              ),
              if (k.suffix != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    k.suffix!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: k.color,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            k.sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: reportTxt2, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// "Vs previous period" trend strip. Used at the top of every report.
/// Pass `delta=null` when the previous window had zero records (the
/// UI then shows "—" instead of a misleading 0%).
class ReportDeltaStrip extends StatelessWidget {
  const ReportDeltaStrip({
    super.key,
    required this.delta,
    required this.previousLabel,
    required this.currentLabel,
  });
  final double? delta;
  final String previousLabel;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    final color = delta == null
        ? reportTxt2
        : delta! >= 0
            ? const Color(0xFF1D9E75)
            : const Color(0xFFC4393B);
    final icon = delta == null
        ? Icons.remove
        : delta! >= 0
            ? Icons.trending_up
            : Icons.trending_down;
    final text = delta == null
        ? '— vs previous'
        : '${delta! >= 0 ? '+' : ''}${delta!.toStringAsFixed(1)}% vs previous';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: reportBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Previous: $previousLabel · This period: $currentLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: reportTxt2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard white card container for a section of a report.
class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: reportBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: reportTxt2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Small status chip used in tables.
class ReportTag extends StatelessWidget {
  const ReportTag({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
  });
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
