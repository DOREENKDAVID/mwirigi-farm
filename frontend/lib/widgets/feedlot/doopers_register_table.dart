import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';
import 'edit_dooper_dialog.dart';

/// Doopers Register card. One row per non-deleted sheep with edit + delete
/// actions. Editing exposes `category` and `currentWeight`; the server
/// recomputes ADG and days-on-feed on every read.
class DoopersRegisterTable extends StatelessWidget {
  const DoopersRegisterTable({
    super.key,
    required this.sheep,
    required this.onChanged,
  });

  final List<SheepView> sheep;
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
            'DOOPERS REGISTER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (sheep.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No doopers registered yet.',
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
                  DataColumn(label: Text('CATEGORY')),
                  DataColumn(label: Text('ENTRY DATE')),
                  DataColumn(label: Text('ENTRY WT'), numeric: true),
                  DataColumn(label: Text('CURRENT WT'), numeric: true),
                  DataColumn(label: Text('ADG'), numeric: true),
                  DataColumn(label: Text('DAYS'), numeric: true),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final s in sheep) _row(context, s),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, SheepView s) {
    return DataRow(cells: [
      DataCell(Text(
        s.tag,
        style: const TextStyle(fontWeight: FontWeight.w600),
      )),
      DataCell(_CategoryPill(category: s.category)),
      DataCell(Text(DateFormat('d MMM yyyy').format(s.entryDate))),
      DataCell(Text(
        s.entryWeight == null ? '—' : '${s.entryWeight!.toStringAsFixed(0)} kg',
      )),
      DataCell(Text(
        s.currentWeight == null
            ? '—'
            : '${s.currentWeight!.toStringAsFixed(0)} kg',
      )),
      DataCell(Text(s.adg == null ? '—' : s.adg!.toStringAsFixed(2))),
      DataCell(Text('${s.daysOnFeed}')),
      DataCell(_DooperActions(sheep: s, onChanged: onChanged)),
    ]);
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});
  final SheepCategory category;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (category) {
      SheepCategory.ewe =>
        (const Color(0xFFEAF3DE), const Color(0xFF27500A)),
      SheepCategory.ram =>
        (const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
      SheepCategory.lamb =>
        (const Color(0xFFE1F5EE), const Color(0xFF0F6E56)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _DooperActions extends StatelessWidget {
  const _DooperActions({required this.sheep, required this.onChanged});

  final SheepView sheep;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditDooperDialog(sheep: sheep),
    );
    if (saved == true) {
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sheep.tag} updated')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete dooper'),
        content: Text(
          'Delete ${sheep.tag}? This is a soft delete — the row is hidden '
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
      await ApiService.deleteSheep(sheep.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sheep.tag} deleted')),
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
