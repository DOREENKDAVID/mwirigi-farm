import 'package:flutter/material.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';

/// Manage availability for the dairy worker roster. Renders one row
/// per worker with a status chip + note field; tapping a chip cycles
/// open a dropdown so a manager can flag someone as sick / off-duty
/// / on vacation. Saves immediately on selection (PATCH
/// /api/staff/workers/:id/availability) — no separate "Save" button,
/// so a user can flip statuses fluidly across the whole roster.
class WorkerAvailabilityDialog extends StatefulWidget {
  const WorkerAvailabilityDialog({super.key, required this.workers});

  final List<DairyWorkerSummary> workers;

  @override
  State<WorkerAvailabilityDialog> createState() =>
      _WorkerAvailabilityDialogState();
}

class _WorkerAvailabilityDialogState extends State<WorkerAvailabilityDialog> {
  late List<DairyWorkerSummary> _rows;
  // workerId → in-flight flag so we can show a tiny spinner per row
  // without blocking the whole dialog.
  final Map<String, bool> _saving = {};
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _rows = List.of(widget.workers);
  }

  Future<void> _setStatus(
    DairyWorkerSummary w,
    WorkerAvailability next, {
    String? note,
  }) async {
    if (next == w.availability && note == null) return;
    setState(() => _saving[w.id] = true);
    try {
      await ApiService.setWorkerAvailability(w.id, {
        'availabilityStatus': next.wire,
        if (note != null) 'availabilityNote': note,
      });
      if (!mounted) return;
      setState(() {
        final i = _rows.indexWhere((r) => r.id == w.id);
        if (i != -1) {
          _rows[i] = DairyWorkerSummary(
            id: w.id,
            name: w.name,
            cowCount: w.cowCount,
            role: w.role,
            houseName: w.houseName,
            availability: next,
            availabilityNote: note ?? w.availabilityNote,
          );
        }
        _saving[w.id] = false;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving[w.id] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.manage_accounts, color: Color(0xFF1976D2), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Worker availability',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 480,
        child: ListView.separated(
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _WorkerRow(
            worker: _rows[i],
            saving: _saving[_rows[i].id] == true,
            onChangeStatus: (status) => _setStatus(_rows[i], status),
            onChangeNote: (note) =>
                _setStatus(_rows[i], _rows[i].availability, note: note),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _WorkerRow extends StatefulWidget {
  const _WorkerRow({
    required this.worker,
    required this.saving,
    required this.onChangeStatus,
    required this.onChangeNote,
  });

  final DairyWorkerSummary worker;
  final bool saving;
  final ValueChanged<WorkerAvailability> onChangeStatus;
  final ValueChanged<String> onChangeNote;

  @override
  State<_WorkerRow> createState() => _WorkerRowState();
}

class _WorkerRowState extends State<_WorkerRow> {
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.worker.availabilityNote ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    final pillColor = w.availability.isAvailable
        ? const Color(0xFFEAF3DE)
        : const Color(0xFFFCEBEB);
    final pillFg = w.availability.isAvailable
        ? const Color(0xFF27500A)
        : const Color(0xFF501313);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${w.cowCount} cow${w.cowCount == 1 ? '' : 's'}'
                      '${w.houseName != null ? ' · ${w.houseName}' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.saving)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<WorkerAvailability>(
                  tooltip: 'Change availability',
                  onSelected: widget.onChangeStatus,
                  itemBuilder: (_) => [
                    for (final s in WorkerAvailability.values)
                      PopupMenuItem(value: s, child: Text(s.label)),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          w.availability.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: pillFg,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 14, color: pillFg),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (!w.availability.isAvailable) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              onSubmitted: widget.onChangeNote,
              decoration: InputDecoration(
                hintText: 'Optional note (e.g. "Back Mon 19 May")',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, size: 16),
                  onPressed: () => widget.onChangeNote(_note.text.trim()),
                ),
                hintStyle: const TextStyle(fontSize: 12),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
