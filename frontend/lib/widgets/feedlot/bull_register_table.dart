import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';
import 'edit_bull_dialog.dart';
import 'sell_bull_dialog.dart';

/// Bull Feedlot Register card. 9-column table mirroring the HTML mockup
/// plus an Actions column with edit (PATCH) and delete (soft) icons.
class BullRegisterTable extends StatelessWidget {
  const BullRegisterTable({
    super.key,
    required this.bulls,
    required this.onChanged,
  });

  final List<BullView> bulls;
  /// Called after a successful edit / delete so the parent can refresh
  /// KPIs alongside the table itself.
  final VoidCallback onChanged;

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
            'BULL FEEDLOT REGISTER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (bulls.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No bulls in the feedlot yet.',
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
                  DataColumn(label: Text('TAG')),
                  DataColumn(label: Text('BREED')),
                  DataColumn(label: Text('ENTRY DATE')),
                  DataColumn(label: Text('ENTRY WT'), numeric: true),
                  DataColumn(label: Text('CURRENT WT'), numeric: true),
                  DataColumn(label: Text('ADG'), numeric: true),
                  DataColumn(label: Text('DAYS'), numeric: true),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final b in bulls) _row(context, b),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, BullView b) {
    return DataRow(cells: [
      DataCell(Text(
        b.tag,
        style: const TextStyle(fontWeight: FontWeight.w600),
      )),
      DataCell(Text(b.breed)),
      DataCell(Text(DateFormat('d MMM yyyy').format(b.entryDate))),
      DataCell(Text('${b.entryWeight.toStringAsFixed(0)} kg')),
      DataCell(Text('${b.currentWeight.toStringAsFixed(0)} kg')),
      DataCell(Text(b.adg.toStringAsFixed(2))),
      DataCell(Text('${b.daysOnFeed}')),
      DataCell(_StatusPill(status: b.status, daysLeft: b.daysLeft)),
      DataCell(_BullActionIcons(bull: b, onChanged: onChanged)),
    ]);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.daysLeft});
  final String status;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = status == 'On feed'
        ? (const Color(0xFFEAF3DE), const Color(0xFF27500A))
        : daysLeft < 0 || status == 'Due today'
            ? (const Color(0xFFFCEBEB), const Color(0xFF501313))
            : (const Color(0xFFFAEEDA), const Color(0xFF854F0B));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _BullActionIcons extends StatelessWidget {
  const _BullActionIcons({required this.bull, required this.onChanged});

  final BullView bull;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditBullDialog(bull: bull),
    );
    if (saved == true) {
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bull.tag} updated')),
        );
      }
    }
  }

  Future<void> _sell(BuildContext context) async {
    final sold = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SellBullDialog(bull: bull),
    );
    if (sold == true) {
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bull.tag} sold and archived')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete bull'),
        content: Text(
          'Delete ${bull.tag}? This is a soft delete — the row is hidden '
          'but the database keeps the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4A),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteBull(bull.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bull.tag} deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          onPressed: () => _edit(context),
          icon: const Icon(Icons.edit_outlined, size: 16),
          color: const Color(0xFF27500A),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          tooltip: 'Sell',
          onPressed: () => _sell(context),
          icon: const Icon(Icons.point_of_sale, size: 16),
          color: const Color(0xFF2E7D32),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_outline, size: 16),
          color: const Color(0xFFE24B4A),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}
