import 'package:flutter/material.dart';

import '../../core/models/dashboard_overview.dart';

/// "Unit performance snapshot" table. All cell values come pre-formatted
/// from the server.
class UnitPerformanceTable extends StatelessWidget {
  const UnitPerformanceTable({super.key, required this.rows});

  final List<UnitPerformanceRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'UNIT PERFORMANCE SNAPSHOT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No unit metrics available.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('UNIT')),
                  DataColumn(label: Text('MANAGER')),
                  DataColumn(label: Text('KEY METRIC')),
                  DataColumn(label: Text('TODAY'), numeric: true),
                  DataColumn(label: Text('7-DAY AVG'), numeric: true),
                  DataColumn(label: Text('30-DAY AVG'), numeric: true),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text(
                        r.unit,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )),
                      DataCell(Text(r.manager)),
                      DataCell(Text(r.metric)),
                      DataCell(Text(r.today)),
                      DataCell(Text(r.average)),
                      DataCell(Text(r.average30d)),
                      DataCell(_StatusPill(text: r.status)),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    // Color the pill from the percentage in the status string when present.
    final pctMatch = RegExp(r'(\d+)%').firstMatch(text);
    final pct = pctMatch == null ? null : int.tryParse(pctMatch.group(1)!);

    final (Color bg, Color fg) = pct == null
        // Non-percentage states ("Empty", "—") get a neutral pill.
        ? (const Color(0xFFE1F5EE), const Color(0xFF0F6E56))
        : pct >= 80
            ? (const Color(0xFFE1F5EE), const Color(0xFF0F6E56))
            : pct >= 50
                ? (const Color(0xFFEAF3DE), const Color(0xFF27500A))
                : pct >= 30
                    ? (const Color(0xFFFAEEDA), const Color(0xFF854F0B))
                    : (const Color(0xFFFCEBEB), const Color(0xFF501313));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
