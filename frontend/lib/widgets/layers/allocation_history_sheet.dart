import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// Audit-log viewer for a brooder's allocation plan history. Renders
/// each AuditLog row with actor, timestamp, action, and the snapshot
/// fields (type, birds, description) so a reviewer can trace every
/// revision back to who made it and why.
class AllocationHistorySheet extends StatefulWidget {
  const AllocationHistorySheet({super.key, required this.brooderId});

  final String brooderId;

  @override
  State<AllocationHistorySheet> createState() => _AllocationHistorySheetState();
}

class _AllocationHistorySheetState extends State<AllocationHistorySheet> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAllocationHistory(widget.brooderId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18, color: Color(0xFF27500A)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Allocation plan history',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Could not load history: ${snap.error.toString().replaceFirst('Exception: ', '')}',
                        style: const TextStyle(color: Color(0xFF854F0B)),
                      ),
                    );
                  }
                  final rows = snap.data ?? const [];
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'No history yet. Edits will appear here.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (_, i) => _Entry(row: rows[i] as Map),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.row});
  final Map row;

  @override
  Widget build(BuildContext context) {
    final action = row['action']?.toString() ?? 'UPDATE';
    final reason = row['reason']?.toString();
    final actor = row['actor'] is Map
        ? (row['actor']['userName']?.toString() ?? 'Unknown')
        : 'System';
    final createdAt = DateTime.tryParse(row['createdAt']?.toString() ?? '');
    final fmt = DateFormat('d MMM yyyy • HH:mm');

    Map<String, dynamic>? snapshot;
    final raw = row['snapshot'];
    if (raw is String && raw.isNotEmpty) {
      try {
        snapshot = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        snapshot = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ActionPill(action: action),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                actor,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              createdAt != null ? fmt.format(createdAt) : '',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        if (snapshot != null) ...[
          const SizedBox(height: 6),
          _SnapshotRow(snapshot: snapshot),
        ],
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '“$reason”',
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.black54,
            ),
          ),
        ],
      ],
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.snapshot});
  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final type = snapshot['type']?.toString() ?? '';
    final birds = snapshot['birds']?.toString() ?? '';
    final desc = snapshot['description']?.toString() ?? '';
    final label = type == 'POL_SALE'
        ? 'POL sale'
        : type == 'REPLACEMENT'
            ? 'Replacement'
            : type;
    return Text(
      '$label · $birds birds — $desc',
      style: const TextStyle(fontSize: 12, color: Colors.black87),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.action});
  final String action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (action) {
      'CREATE' => (const Color(0xFFEAF3DE), const Color(0xFF27500A)),
      'UPDATE' => (const Color(0xFFEEF4FB), const Color(0xFF1976D2)),
      'DELETE' => (const Color(0xFFFCEBEB), const Color(0xFF501313)),
      _ => (const Color(0xFFEFEDE6), const Color(0xFF666666)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        action,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}
