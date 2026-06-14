import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';
import 'edit_sow_dialog.dart';
import 'release_pig_dialog.dart';

/// Sow Register card. Search input + 6-column table. Pencil/trash icons
/// open the edit dialog and delete-confirm flow respectively.
class SowRegisterTable extends StatelessWidget {
  const SowRegisterTable({
    super.key,
    required this.sows,
    required this.searchController,
    required this.onSearchChanged,
    required this.onChanged,
    this.refreshing = false,
  });

  final List<Sow> sows;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  /// Called after a successful edit / delete so the parent can refresh
  /// KPIs + the chart alongside the table itself.
  final VoidCallback onChanged;
  /// When true, render a thin progress bar at the top of the table to
  /// signal an in-flight refresh without dropping the existing rows.
  final bool refreshing;

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
            'SOW REGISTER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search sows…',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (refreshing)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0x14000000),
              ),
            ),
          const SizedBox(height: 14),
          if (sows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No sows match.',
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
                  DataColumn(label: Text('TAG')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('LITTER #'), numeric: true),
                  DataColumn(label: Text('LAST FARROWED')),
                  DataColumn(label: Text('DUE DATE')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final s in sows)
                    DataRow(cells: [
                      DataCell(Text(
                        s.tag,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                      DataCell(_StatusPill(status: s.status)),
                      DataCell(Text('${s.litterCount}')),
                      DataCell(Text(_fmtDate(s.lastFarrowed))),
                      DataCell(Text(_fmtDate(s.dueDate))),
                      DataCell(_SowRowActions(sow: s, onChanged: onChanged)),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy').format(d);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final PigStatus? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const Text('—');
    final (Color bg, Color fg) = switch (status!) {
      PigStatus.lactating =>
        (const Color(0xFFE1F5EE), const Color(0xFF0F6E56)),
      PigStatus.gestating =>
        (const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
      PigStatus.farrowingSoon =>
        (const Color(0xFFFCEBEB), const Color(0xFF501313)),
      PigStatus.weaned =>
        (const Color(0xFFEAF3DE), const Color(0xFF27500A)),
      PigStatus.dry =>
        (const Color(0xFFEEEEEE), const Color(0xFF6B7770)),
      PigStatus.service =>
        (const Color(0xFFFCEBEB), const Color(0xFFC0392B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status!.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _SowRowActions extends StatelessWidget {
  const _SowRowActions({required this.sow, required this.onChanged});

  final Sow sow;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditSowDialog(sow: sow),
    );
    if (saved == true) {
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sow.tag} updated')),
        );
      }
    }
  }

  Future<void> _release(BuildContext context) async {
    final released = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReleasePigDialog(
        pigId: sow.id,
        pigTag: sow.tag,
        category: 'SOW',
      ),
    );
    if (released == true) {
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sow.tag} released')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete sow'),
        content: Text(
          'Delete ${sow.tag}? This is a soft delete — the row is hidden '
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
      await ApiService.deletePig(sow.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sow.tag} deleted')),
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
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: Colors.black54),
      padding: EdgeInsets.zero,
      tooltip: 'Actions',
      onSelected: (v) {
        if (v == 'edit') _edit(context);
        if (v == 'release') _release(context);
        if (v == 'delete') _delete(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit',    child: Text('Edit Sow')),
        PopupMenuItem(value: 'release', child: Text('Release / Sell')),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Color(0xFFE24B4A))),
        ),
      ],
    );
  }
}
