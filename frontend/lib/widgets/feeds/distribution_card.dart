import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feeds.dart';
import 'edit_distribution_dialog.dart';

/// "Daily distribution by unit" card. Mirrors the HTML mockup's 4-column
/// table (Unit, Concentrate, Silage, Napier). Falls back to a card list
/// on narrow screens so the columns don't wrap awkwardly. Each row has
/// a pencil edit icon that opens [EditDistributionDialog].
class DistributionCard extends StatelessWidget {
  const DistributionCard({
    super.key,
    required this.rows,
    this.onChanged,
  });
  final List<FeedDistribution> rows;
  /// Called after a successful edit so the parent can refresh.
  final VoidCallback? onChanged;

  Future<void> _openEdit(BuildContext context, FeedDistribution entry) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditDistributionDialog(entry: entry),
    );
    if (saved == true) {
      onChanged?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Distribution updated — ${entry.unitLabel}')),
        );
      }
    }
  }

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
            'DAILY DISTRIBUTION BY UNIT',
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
                  'No distribution records yet.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (ctx, c) {
                final wide = c.maxWidth >= 520;
                return wide
                    ? _Table(rows: rows, onEdit: (e) => _openEdit(ctx, e))
                    : _List(rows: rows, onEdit: (e) => _openEdit(ctx, e));
              },
            ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.onEdit});
  final List<FeedDistribution> rows;
  final ValueChanged<FeedDistribution> onEdit;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return SingleChildScrollView(
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
          DataColumn(label: Text('UNIT')),
          DataColumn(label: Text('CONCENTRATE'), numeric: true),
          DataColumn(label: Text('SILAGE'), numeric: true),
          DataColumn(label: Text('NAPIER'), numeric: true),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(r.unitLabel)),
              DataCell(Text(_kg(fmt, r.concentrateKg))),
              DataCell(Text(_kg(fmt, r.silageKg))),
              DataCell(Text(_kg(fmt, r.napierKg))),
              DataCell(IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: const Color(0xFF27500A),
                onPressed: () => onEdit(r),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              )),
            ]),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.rows, required this.onEdit});
  final List<FeedDistribution> rows;
  final ValueChanged<FeedDistribution> onEdit;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _RowTile(entry: rows[i], fmt: fmt, onEdit: onEdit),
          if (i < rows.length - 1)
            const Divider(height: 1, color: Color(0x14000000)),
        ],
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.entry,
    required this.fmt,
    required this.onEdit,
  });
  final FeedDistribution entry;
  final NumberFormat fmt;
  final ValueChanged<FeedDistribution> onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.unitLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: const Color(0xFF27500A),
                onPressed: () => onEdit(entry),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Pill(label: 'Concentrate', value: _kg(fmt, entry.concentrateKg)),
              ),
              Expanded(
                child: _Pill(label: 'Silage', value: _kg(fmt, entry.silageKg)),
              ),
              Expanded(
                child: _Pill(label: 'Napier', value: _kg(fmt, entry.napierKg)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }
}

String _kg(NumberFormat fmt, double v) {
  if (v == 0) return '—';
  return '${fmt.format(v)} kg';
}
