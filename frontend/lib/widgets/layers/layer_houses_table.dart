import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_unit.dart';

/// "Layer houses (Day 360)" table. 5 columns:
///   House · Birds · Crates today · Feed (kg) · Status (Phasing out / Continuing)
///
/// Phasing-out is server-derived (no boolean stored) — see layersUnit
/// service: ageDays >= 360 OR birdCount < capacity * 0.9.
class LayerHousesTable extends StatelessWidget {
  const LayerHousesTable({super.key, required this.houses});
  final List<LayerHouseView> houses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title(),
          const SizedBox(height: 14),
          if (houses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No layer houses recorded.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            _HousesTable(houses: houses),
          const SizedBox(height: 10),
          const _PhasingOutLegend(),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'LAYER HOUSES',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.black54,
      ),
    );
  }
}

class _HousesTable extends StatelessWidget {
  const _HousesTable({required this.houses});
  final List<LayerHouseView> houses;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.0),
        4: FlexColumnWidth(1.4),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x14000000)),
            ),
          ),
          children: [
            _Th('House'),
            _Th('Birds'),
            _Th('Crates today'),
            _Th('Feed (kg)'),
            _Th('Status'),
          ],
        ),
        for (final h in houses)
          TableRow(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x0F000000)),
              ),
            ),
            children: [
              _Td(h.name, bold: true),
              _Td(fmt.format(h.birdCount)),
              _Td(_formatNum(h.cratesToday)),
              _Td(_formatNum(h.feedKg)),
              _StatusCell(phasingOut: h.phasingOut),
            ],
          ),
      ],
    );
  }

  static String _formatNum(num n) {
    if (n == n.roundToDouble()) {
      return NumberFormat.decimalPattern().format(n.toInt());
    }
    return n.toStringAsFixed(1);
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.bold = false});
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: const Color(0xFF222222),
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.phasingOut});
  final bool phasingOut;

  @override
  Widget build(BuildContext context) {
    final color = phasingOut ? const Color(0xFF854F0B) : const Color(0xFF27500A);
    final bg = phasingOut ? const Color(0xFFFFF1DD) : const Color(0xFFEFF5E6);
    final icon = phasingOut ? Icons.warning_amber_rounded : Icons.check_circle_outline;
    final label = phasingOut ? 'Phasing out' : 'Continuing';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhasingOutLegend extends StatelessWidget {
  const _PhasingOutLegend();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Phasing out: end-of-lay birds will be culled/sold and replaced by '
      'pullets from the brooder when they reach 3 months.',
      style: TextStyle(
        fontSize: 11,
        color: Color(0xFF888888),
        height: 1.5,
      ),
    );
  }
}
