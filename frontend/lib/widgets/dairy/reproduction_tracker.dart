import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/reproduction.dart';
import '../../core/service/api_service.dart';
import 'log_ai_calving_dialog.dart';

/// "Reproduction tracker" card. One row per cow with reproduction history.
/// Columns (in order, must not be renamed):
///   Tag · Last AI date · Pregnancy · Expected calving · Calves (lifetime)
///
/// Empty state: a single row spanning all 5 columns reading
/// "No reproduction records yet."
class ReproductionTracker extends StatefulWidget {
  const ReproductionTracker({super.key});

  @override
  State<ReproductionTracker> createState() => _ReproductionTrackerState();
}

class _ReproductionTrackerState extends State<ReproductionTracker> {
  Future<List<ReproductionRow>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ReproductionRow>> _load() async {
    final res = await ApiService.getReproductionRows();
    final raw = res['rows'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ReproductionRow.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LogAiCalvingDialog(),
    );
    if (saved == true) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reproduction event logged')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'REPRODUCTION TRACKER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _openDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Log AI / Calving'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<ReproductionRow>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _InlineError(
                  message: snap.error
                      .toString()
                      .replaceFirst('Exception: ', ''),
                  onRetry: _refresh,
                );
              }
              final rows = snap.data ?? const <ReproductionRow>[];
              return _ReproTable(rows: rows, onChanged: _refresh);
            },
          ),
        ],
      ),
    );
  }
}

class _ReproTable extends StatelessWidget {
  const _ReproTable({required this.rows, required this.onChanged});
  final List<ReproductionRow> rows;

  /// Caller refreshes the table after edit / delete succeeds.
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 28,
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.black54,
        ),
        dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
        columns: const [
          DataColumn(label: Text('TAG')),
          DataColumn(label: Text('LAST AI DATE')),
          DataColumn(label: Text('PREGNANCY')),
          DataColumn(label: Text('EXPECTED CALVING')),
          DataColumn(label: Text('CALVES (LIFETIME)'), numeric: true),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: rows.isEmpty
            ? const [
                DataRow(cells: [
                  DataCell(_EmptyMessageCell()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                ]),
              ]
            : [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(_TagPill(tag: r.tag)),
                    DataCell(Text(_fmtDate(r.lastAiDate))),
                    DataCell(_PregnancyTag(status: r.pregnancyStatus)),
                    DataCell(Text(_fmtDate(r.expectedCalvingDate))),
                    DataCell(Text('${r.lifetimeCalvesCount}')),
                    DataCell(_RowActions(row: r, onChanged: onChanged)),
                  ]),
              ],
      ),
    );
  }

  static String _fmtDate(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy').format(d);
}

// Row actions for the reproduction tracker. Both buttons operate on the
// cow's MOST RECENT AI record (the one driving the row's surface
// fields):
//
//   ✎ Edit   → small dialog to PATCH pregnancy status + check date
//   🗑 Delete → confirm, then DELETE the record (soft delete on the
//                backend; calf history is unaffected since it's
//                separate CALVING records).
class _RowActions extends StatefulWidget {
  const _RowActions({required this.row, required this.onChanged});
  final ReproductionRow row;
  final Future<void> Function() onChanged;

  @override
  State<_RowActions> createState() => _RowActionsState();
}

class _RowActionsState extends State<_RowActions> {
  bool _busy = false;

  Future<String?> _resolveLatestAiId() async {
    final raw = await ApiService.getReproductionHistory(widget.row.cowId);
    final events = (raw['events'] as List? ?? raw['rows'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .where((m) => m['eventType'] == 'AI')
        .toList();
    if (events.isEmpty) return null;
    events.sort((a, b) =>
        (b['eventDate']?.toString() ?? '').compareTo(a['eventDate']?.toString() ?? ''));
    return events.first['id']?.toString();
  }

  Future<void> _edit() async {
    if (widget.row.lastAiDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No AI record on this cow.')),
      );
      return;
    }
    setState(() => _busy = true);
    final id = await _resolveLatestAiId();
    if (!mounted) return;
    setState(() => _busy = false);
    if (id == null) return;

    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _EditAiDialog(initialStatus: widget.row.pregnancyStatus),
    );
    if (result == null) return;
    try {
      await ApiService.updateReproductionRecord(id, {
        'pregnancyStatus': result.status.wire,
        if (result.checkDate != null)
          'pregnancyCheckDate': result.checkDate!.toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.row.tag}: AI record updated')),
      );
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete latest AI record?'),
        content: Text(
          'Removes the most recent AI for ${widget.row.tag}. '
          'Soft delete — calving history is unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final id = await _resolveLatestAiId();
      if (id == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No AI record found.')),
        );
        return;
      }
      await ApiService.deleteReproductionRecord(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.row.tag}: AI record removed')),
      );
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit AI record',
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: _edit,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          tooltip: 'Delete AI record',
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
            color: Color(0xFFB42318),
          ),
          onPressed: _delete,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

class _EditResult {
  _EditResult({required this.status, this.checkDate});
  final PregnancyStatus status;
  final DateTime? checkDate;
}

class _EditAiDialog extends StatefulWidget {
  const _EditAiDialog({this.initialStatus});
  final PregnancyStatus? initialStatus;

  @override
  State<_EditAiDialog> createState() => _EditAiDialogState();
}

class _EditAiDialogState extends State<_EditAiDialog> {
  late PregnancyStatus _status;
  DateTime? _checkDate;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? PregnancyStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Edit AI record',
        style: TextStyle(
          color: Color(0xFF27500A),
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pregnancy status',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<PregnancyStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: [
                for (final s in PregnancyStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pregnancy check date (optional)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _checkDate ?? now,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 1),
                );
                if (picked != null && mounted) {
                  setState(() => _checkDate = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  suffixIcon: _checkDate == null
                      ? const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                          color: Color(0xFF555555),
                        )
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _checkDate = null),
                        ),
                ),
                child: Text(
                  _checkDate == null
                      ? 'dd/mm/yyyy'
                      : dateFmt.format(_checkDate!),
                  style: TextStyle(
                    color: _checkDate == null
                        ? const Color(0xFF999999)
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _EditResult(status: _status, checkDate: _checkDate),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF27500A),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyMessageCell extends StatelessWidget {
  const _EmptyMessageCell();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'No reproduction records yet.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(10),
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

class _PregnancyTag extends StatelessWidget {
  const _PregnancyTag({required this.status});
  final PregnancyStatus? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const Text('—');
    final (Color bg, Color fg) = switch (status!) {
      PregnancyStatus.pending => (const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
      PregnancyStatus.confirmed => (const Color(0xFFE1F5EE), const Color(0xFF0F6E56)),
      PregnancyStatus.open => (const Color(0xFFEAF3DE), const Color(0xFF27500A)),
      PregnancyStatus.aborted => (const Color(0xFFFCEBEB), const Color(0xFF501313)),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE24B4A)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
