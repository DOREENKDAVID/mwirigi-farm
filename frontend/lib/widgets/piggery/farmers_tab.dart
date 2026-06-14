import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';
import 'dispatch_confirm_dialog.dart';
import 'log_fc_dispatch_dialog.dart';

/// Farmers Choice tab in the Piggery page.
///
/// Layout (top → bottom):
///   1. PENDING REQUESTS — approve / reject individual pen requests
///   2. READY TO DISPATCH — accumulated approved batches (tappable to confirm)
///   3. DISPATCH HISTORY — completed DispatchLog entries
class FarmersTab extends StatefulWidget {
  const FarmersTab({super.key});

  @override
  State<FarmersTab> createState() => _FarmersTabState();
}

class _FarmersTabState extends State<FarmersTab> {
  static const _primary = Color(0xFF27500A);

  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final results = await Future.wait([
      ApiService.getReleaseRequests(status: 'PENDING'),
      ApiService.getPendingDispatches(),
      ApiService.getDispatchLogs(),
    ]);
    return _Data(
      pending: (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .map(PenReleaseRequest.fromJson)
          .toList(),
      batches: (results[1] as List)
          .whereType<Map<String, dynamic>>()
          .map(PendingDispatchBatch.fromJson)
          .toList(),
      history: (results[2] as List)
          .whereType<Map<String, dynamic>>()
          .map(DispatchLogEntry.fromJson)
          .toList(),
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _approve(PenReleaseRequest req) async {
    try {
      await ApiService.approveReleaseRequest(req.id);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pen ${req.penLabel} approved — added to dispatch batch')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _reject(PenReleaseRequest req) async {
    String? notes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Reject request — Pen ${req.penLabel}'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => notes = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ApiService.rejectReleaseRequest(req.id, notes: notes);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pen ${req.penLabel} request rejected — pen restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openDispatch(PendingDispatchBatch batch) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DispatchConfirmDialog(batch: batch),
    );
    if (done == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispatch confirmed — revenue recorded')),
        );
      }
    }
  }

  Future<void> _openManualDispatch() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LogFcDispatchDialog(),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final data    = snap.data;

        if (loading && data == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return _ErrorCard(
            message: snap.error.toString(),
            onRetry: _reload,
          );
        }

        final d = data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Pending requests ──────────────────────────────────────
            if (d.pending.isNotEmpty) ...[
              _SectionHeader(
                title: 'PENDING REQUESTS',
                badge: '${d.pending.length}',
                badgeColor: const Color(0xFFE24B4A),
              ),
              const SizedBox(height: 8),
              ...d.pending.map((req) => _RequestCard(
                req: req,
                onApprove: () => _approve(req),
                onReject:  () => _reject(req),
              )),
              const SizedBox(height: 20),
            ],

            // ── 2. Ready to dispatch ────────────────────────────────────
            if (d.batches.isNotEmpty) ...[
              _SectionHeader(
                title: 'READY TO DISPATCH',
                badge: '${d.batches.length}',
                badgeColor: _primary,
              ),
              const SizedBox(height: 8),
              ...d.batches.map((batch) => _BatchCard(
                batch: batch,
                onTap: () => _openDispatch(batch),
              )),
              const SizedBox(height: 20),
            ],

            // ── Manual dispatch button ──────────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '🚚  FARMERS CHOICE DISPATCH LOG',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _primary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _openManualDispatch,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log dispatch'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              d.history.isEmpty
                  ? 'No dispatches logged yet.'
                  : '${d.history.length} dispatch${d.history.length == 1 ? '' : 'es'} '
                    '· ${d.history.fold<int>(0, (s, r) => s + r.count)} head moved',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            const SizedBox(height: 12),

            // ── 3. Dispatch history ─────────────────────────────────────
            if (loading)
              const LinearProgressIndicator(minHeight: 2)
            else if (d.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No FC dispatches yet. Pen release requests will appear above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
              )
            else
              _HistoryTable(rows: d.history),
          ],
        );
      },
    );
  }
}

// ── Data container ─────────────────────────────────────────────────────────

class _Data {
  _Data({required this.pending, required this.batches, required this.history});
  final List<PenReleaseRequest>   pending;
  final List<PendingDispatchBatch> batches;
  final List<DispatchLogEntry>     history;
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.badge,
    required this.badgeColor,
  });
  final String title;
  final String badge;
  final Color  badgeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            letterSpacing: 0.6, color: Colors.black54,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badge,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Pending request card ───────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.req,
    required this.onApprove,
    required this.onReject,
  });
  final PenReleaseRequest req;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFFD84B), width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Pen badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Pen\n${req.penLabel}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF8A5A0A),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${req.count} pigs · ${req.category}${req.ageRange != null ? ' · ${req.ageRange}' : ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'House ${req.house} · Requested ${df.format(req.requestedAt)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
          // Action buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF27500A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(80, 32),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: const Text('Approve'),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE24B4A),
                  side: const BorderSide(color: Color(0xFFE24B4A)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(80, 32),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pending dispatch batch card ────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch, required this.onTap});
  final PendingDispatchBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pensLabel = batch.pens.join(', ');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF3E8),
          border: Border.all(color: const Color(0xFF27500A), width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: Color(0xFF27500A), size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${batch.totalCount} pigs · ${batch.category}',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF27500A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pens: $pensLabel${batch.ageRange != null ? ' · ${batch.ageRange}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to confirm dispatch →',
                    style: TextStyle(
                      fontSize: 11, color: Color(0xFF27500A), fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF27500A)),
          ],
        ),
      ),
    );
  }
}

// ── Dispatch history table ─────────────────────────────────────────────────

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.rows});
  final List<DispatchLogEntry> rows;

  static const _hdr  = Color(0xFFEEF3E8);
  static const _txt2 = Color(0xFF6B7770);

  @override
  Widget build(BuildContext context) {
    final df  = DateFormat('d MMM yy');
    final sorted = rows.toList()..sort((a, b) => b.date.compareTo(a.date));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 80,
        ),
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 56,
          columnSpacing: 16,
          horizontalMargin: 6,
          headingRowColor: WidgetStateProperty.resolveWith((_) => _hdr),
          headingTextStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: _txt2, letterSpacing: 0.05,
          ),
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Reference')),
            DataColumn(label: Text('Pens')),
            DataColumn(label: Text('Count'), numeric: true),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Age')),
            DataColumn(label: Text('Driver')),
            DataColumn(label: Text('Amount'), numeric: true),
          ],
          rows: [
            for (final r in sorted)
              DataRow(cells: [
                DataCell(Text(df.format(r.date), style: const TextStyle(fontSize: 12))),
                DataCell(_RefPill(text: r.ref ?? '—', hasRevenue: r.hasRevenue)),
                DataCell(Text(r.pens, style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                  '${r.count}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF27500A)),
                )),
                DataCell(Text(r.category, style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.ageRange ?? '—', style: const TextStyle(fontSize: 12, color: _txt2))),
                DataCell(Text(r.driver ?? '—', style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                  r.amount != null ? 'KES ${r.amount!.toStringAsFixed(0)}' : '—',
                  style: const TextStyle(fontSize: 12),
                )),
              ]),
          ],
        ),
      ),
    );
  }
}

class _RefPill extends StatelessWidget {
  const _RefPill({required this.text, required this.hasRevenue});
  final String text;
  final bool   hasRevenue;

  @override
  Widget build(BuildContext context) {
    final bg     = hasRevenue ? const Color(0xFFE7F0DD) : const Color(0xFFFCEDC8);
    final border = hasRevenue ? const Color(0xFFB6CFA0) : const Color(0xFFE6C58A);
    final fg     = hasRevenue ? const Color(0xFF27500A) : const Color(0xFF8A5A0A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace', fontSize: 11,
          fontWeight: FontWeight.w700, color: fg,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.replaceFirst('Exception: ', ''),
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
