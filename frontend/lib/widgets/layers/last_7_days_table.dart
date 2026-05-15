import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers.dart';

/// Per-house "last 7 days" table.
/// Columns mirror the HTML mockup exactly, in this order:
///   Date · Age (d) · Opening · Eggs · Trays · % Lay · Feed (kg) · Dead · Closing
class Last7DaysTable extends StatelessWidget {
  const Last7DaysTable({
    super.key,
    required this.houseName,
    required this.records,
  });

  final String houseName;
  final List<LayerProduction> records;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  '${houseName.toUpperCase()} — LAST 7 DAYS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAEEDA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Auto-logged',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF854F0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No entries yet for this house.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 22,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('AGE (D)'), numeric: true),
                  DataColumn(label: Text('OPENING'), numeric: true),
                  DataColumn(label: Text('EGGS'), numeric: true),
                  DataColumn(label: Text('TRAYS'), numeric: true),
                  DataColumn(label: Text('% LAY'), numeric: true),
                  DataColumn(label: Text('FEED (KG)'), numeric: true),
                  DataColumn(label: Text('DEAD'), numeric: true),
                  DataColumn(label: Text('CLOSING'), numeric: true),
                ],
                // Newest first.
                rows: [
                  for (final r in records.reversed) _row(r),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DataRow _row(LayerProduction r) {
    final fmt = NumberFormat.decimalPattern();
    final pct = r.percentLaying;
    final pctColor = pct >= 80
        ? const Color(0xFF27500A)
        : pct >= 70
            ? const Color(0xFF854F0B)
            : const Color(0xFFA32D2D);
    return DataRow(cells: [
      DataCell(Text(DateFormat('d MMM').format(r.date))),
      DataCell(Text('${r.dayAge}')),
      DataCell(Text(fmt.format(r.openingStock))),
      DataCell(Text(fmt.format(r.eggsCollected))),
      DataCell(Text(r.trays.toStringAsFixed(1))),
      DataCell(Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(color: pctColor, fontWeight: FontWeight.w600),
      )),
      DataCell(Text(r.feedKg.toStringAsFixed(1))),
      DataCell(Text('${r.deadRemoved}')),
      DataCell(Text(fmt.format(r.closingStock))),
    ]);
  }
}
