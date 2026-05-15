import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/health.dart';
import 'status_badge.dart';

/// "Active treatments" table — 6 cols on desktop, card list on mobile.
/// Columns: Tag · Unit · Diagnosis · Treatment · Start · Status · Actions
///
/// Both `statusLabel` ("Day 2" / "Improving") and the status enum value
/// (used for pill colour) come from the backend.
class ActiveTreatmentsTable extends StatefulWidget {
  const ActiveTreatmentsTable({
    super.key,
    required this.rows,
    required this.onAdd,
  });

  final List<TreatmentRow> rows;
  final VoidCallback onAdd;

  @override
  State<ActiveTreatmentsTable> createState() => _ActiveTreatmentsTableState();
}

class _ActiveTreatmentsTableState extends State<ActiveTreatmentsTable> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TreatmentRow> get _filtered {
    if (_query.isEmpty) return widget.rows;
    final q = _query.toLowerCase();
    return widget.rows
        .where((r) =>
            r.tag.toLowerCase().contains(q) ||
            r.unit.toLowerCase().contains(q) ||
            r.diagnosis.toLowerCase().contains(q) ||
            r.medication.toLowerCase().contains(q))
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ACTIVE TREATMENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onAdd,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side:
                      const BorderSide(color: Color(0xFF27500A), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(
                  Icons.add,
                  size: 14,
                  color: Color(0xFF27500A),
                ),
                label: const Text(
                  'Add treatment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF27500A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SearchBar(
            controller: _searchController,
            hint: 'Search treatments…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No active treatments.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 760) {
                  return _DesktopTable(rows: filtered);
                }
                return _MobileCards(rows: filtered);
              },
            ),
        ],
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.rows});
  final List<TreatmentRow> rows;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(1.0), // Tag
        1: FlexColumnWidth(1.0), // Unit
        2: FlexColumnWidth(1.8), // Diagnosis
        3: FlexColumnWidth(2.2), // Treatment
        4: FlexColumnWidth(1.4), // Start
        5: FlexColumnWidth(1.2), // Status
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x14000000))),
          ),
          children: [
            _Th('Tag'),
            _Th('Unit'),
            _Th('Diagnosis'),
            _Th('Treatment'),
            _Th('Start'),
            _Th('Status'),
          ],
        ),
        for (final r in rows)
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0F000000))),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _TagPill(tag: r.tag),
              ),
              _Td(r.unit),
              _Td(r.diagnosis),
              _Td(r.medication),
              _Td(fmt.format(r.startDate)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadgeWithLabel(
                    status: r.status,
                    label: r.statusLabel,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MobileCards extends StatelessWidget {
  const _MobileCards({required this.rows});
  final List<TreatmentRow> rows;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
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
                    _TagPill(tag: r.tag),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.unit,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    StatusBadgeWithLabel(
                      status: r.status,
                      label: r.statusLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  r.diagnosis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.medication,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  'Started ${fmt.format(r.startDate)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
          if (r != rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});
  final String tag;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF27500A),
        ),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
  const _Td(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF222222)),
      ),
    );
  }
}
