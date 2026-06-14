import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/health.dart';
import 'status_badge.dart';

/// "Vaccination schedule" table — 7 columns on wide layouts, card view
/// on mobile per the user spec ("convert rows into cards on mobile").
///
/// Columns: Vaccine · Unit · Animals · Last done · Next due · Status · Actions
///
/// All status / lastDone / nextDue strings come from the backend; the
/// widget only renders.
///
/// [onEdit] is called with the row when the user taps the edit button.
/// Only rows with source=="DB" and a lastRecordId show the edit button.
class VaccinationScheduleTable extends StatefulWidget {
  const VaccinationScheduleTable({
    super.key,
    required this.rows,
    this.onEdit,
  });
  final List<VaccinationRow> rows;
  final ValueChanged<VaccinationRow>? onEdit;

  @override
  State<VaccinationScheduleTable> createState() =>
      _VaccinationScheduleTableState();
}

class _VaccinationScheduleTableState extends State<VaccinationScheduleTable> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VaccinationRow> get _filtered {
    if (_query.isEmpty) return widget.rows;
    final q = _query.toLowerCase();
    return widget.rows
        .where((r) =>
            r.vaccine.toLowerCase().contains(q) ||
            r.unit.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'VACCINATION SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          _SearchBar(
            controller: _searchController,
            hint: 'Search vaccines or units…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No vaccinations match your search.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 760) {
                  return _DesktopTable(rows: filtered, onEdit: widget.onEdit);
                }
                return _MobileCards(rows: filtered, onEdit: widget.onEdit);
              },
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4F0),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(fontSize: 13, color: Colors.black38),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 14,
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
        ],
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.rows, this.onEdit});
  final List<VaccinationRow> rows;
  final ValueChanged<VaccinationRow>? onEdit;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(2.4), // Vaccine
        1: FlexColumnWidth(1.2), // Unit
        2: FlexColumnWidth(1.0), // Animals
        3: FlexColumnWidth(1.6), // Last done
        4: FlexColumnWidth(1.7), // Next due
        5: FlexColumnWidth(1.6), // Status
        6: FixedColumnWidth(48), // Actions
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x14000000))),
          ),
          children: [
            _Th('Vaccine'),
            _Th('Unit'),
            _Th('Animals'),
            _Th('Last done'),
            _Th('Next due'),
            _Th('Status'),
            SizedBox.shrink(),
          ],
        ),
        for (final r in rows)
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0F000000))),
            ),
            children: [
              _Td(r.vaccine, bold: true),
              _Td(r.unit),
              _Td(fmt.format(r.animals)),
              _Td(r.lastDone ?? '—', muted: r.lastDone == null),
              _Td(r.nextDue ?? '—', muted: r.nextDue == null),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(status: r.status),
                ),
              ),
              // Edit button on every row (creates first record if none logged)
              if (onEdit != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: r.lastRecordId == null
                        ? 'Log first vaccination'
                        : 'Edit record',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    color: const Color(0xFF27500A),
                    onPressed: () => onEdit!(r),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
      ],
    );
  }
}

class _MobileCards extends StatelessWidget {
  const _MobileCards({required this.rows, this.onEdit});
  final List<VaccinationRow> rows;
  final ValueChanged<VaccinationRow>? onEdit;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Column(
      children: [
        for (final r in rows) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.vaccine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    StatusBadge(status: r.status),
                    if (onEdit != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: r.lastRecordId == null
                            ? 'Log first vaccination'
                            : 'Edit record',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 16,
                        color: const Color(0xFF27500A),
                        onPressed: () => onEdit!(r),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${r.unit} · ${fmt.format(r.animals)} animals',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                _MetaPair(label: 'Last done', value: r.lastDone ?? '—'),
                _MetaPair(label: 'Next due', value: r.nextDue ?? '—'),
              ],
            ),
          ),
          if (r != rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MetaPair extends StatelessWidget {
  const _MetaPair({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
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
  const _Td(this.text, {this.bold = false, this.muted = false});
  final String text;
  final bool bold;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: muted ? Colors.black38 : const Color(0xFF222222),
        ),
      ),
    );
  }
}
