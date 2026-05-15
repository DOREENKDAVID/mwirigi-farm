import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers.dart';

/// "All houses — today's snapshot" table at the bottom of the page.
/// Columns mirror the HTML mockup:
///   House · Capacity · Current stock · Eggs today · Trays · % Laying · Feed (kg)
/// Plus a TOTAL row showing summed capacity.
class SnapshotTable extends StatelessWidget {
  const SnapshotTable({super.key, required this.rows});

  final List<SnapshotRow> rows;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final totalCapacity = rows.fold<int>(0, (s, r) => s + r.capacity);

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
            "ALL HOUSES — TODAY'S SNAPSHOT",
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
                  'No layer houses configured yet.',
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
                  DataColumn(label: Text('HOUSE')),
                  DataColumn(label: Text('CAPACITY'), numeric: true),
                  DataColumn(label: Text('CURRENT STOCK'), numeric: true),
                  DataColumn(label: Text('EGGS TODAY'), numeric: true),
                  DataColumn(label: Text('TRAYS'), numeric: true),
                  DataColumn(label: Text('% LAYING'), numeric: true),
                  DataColumn(label: Text('FEED (KG)'), numeric: true),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text(
                        r.name,
                        style: TextStyle(
                          color: _hexToColor(r.color),
                          fontWeight: FontWeight.w700,
                        ),
                      )),
                      DataCell(Text(fmt.format(r.capacity))),
                      DataCell(Text(fmt.format(r.currentStock))),
                      DataCell(Text(fmt.format(r.eggsToday))),
                      DataCell(Text(r.trays.toStringAsFixed(1))),
                      DataCell(Text('${r.percentLaying.toStringAsFixed(1)}%')),
                      DataCell(Text(r.feedKg.toStringAsFixed(1))),
                    ]),
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFFFAFAF7)),
                    cells: [
                      const DataCell(Text(
                        'TOTAL',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      )),
                      DataCell(Text(
                        fmt.format(totalCapacity),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      )),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color _hexToColor(String hex) {
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF27500A);
}
