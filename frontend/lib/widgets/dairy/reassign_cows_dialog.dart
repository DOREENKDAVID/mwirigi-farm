import 'package:flutter/material.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';

/// Bulk-reassign a worker's entire herd to a replacement. Triggered
/// from WorkerAvailabilityDialog the moment a worker is flipped to
/// SICK_LEAVE / OFF_DAY / VACATION / EMERGENCY / OTHER_UNAVAILABLE
/// while they still have cows assigned — without this step the herd
/// sits unassigned for the next milking session.
///
/// The replacement dropdown is restricted to AVAILABLE workers,
/// excluding the source worker. On confirm the dialog POSTs to
/// /api/dairy/workers/:fromId/reassign-cows and returns the count of
/// reassigned cows so the parent can refetch its data.
class ReassignCowsDialog extends StatefulWidget {
  const ReassignCowsDialog({
    super.key,
    required this.fromWorker,
    required this.allWorkers,
  });

  /// The worker who just went unavailable. Their cows are the ones
  /// being moved out.
  final DairyWorkerSummary fromWorker;

  /// Current dairy roster — the dialog filters this for AVAILABLE
  /// targets, excluding `fromWorker`.
  final List<DairyWorkerSummary> allWorkers;

  @override
  State<ReassignCowsDialog> createState() => _ReassignCowsDialogState();
}

class _ReassignCowsDialogState extends State<ReassignCowsDialog> {
  String? _toWorkerId;
  bool _submitting = false;
  String? _error;

  List<DairyWorkerSummary> get _candidates => widget.allWorkers
      .where((w) =>
          w.id != widget.fromWorker.id && w.availability.isAvailable)
      .toList();

  Future<void> _submit() async {
    final toId = _toWorkerId;
    if (toId == null) {
      setState(() => _error = 'Pick a replacement worker first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final n = await ApiService.reassignWorkerCows(
        fromWorkerId: widget.fromWorker.id,
        toWorkerId: toId,
      );
      if (!mounted) return;
      // Return the count so the parent can show a confirmation toast.
      Navigator.of(context).pop(n);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final from = widget.fromWorker;
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.swap_horiz, color: Color(0xFF1976D2), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reassign cows',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAEEDA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x55854F0B)),
              ),
              child: Text(
                '${from.name} is now ${from.availability.label.toLowerCase()}. '
                'Move their ${from.cowCount} cow${from.cowCount == 1 ? '' : 's'} '
                'to an available worker so the next milking session is covered.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF854F0B)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'REPLACEMENT WORKER *',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            if (candidates.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No other workers are AVAILABLE right now. Flip someone '
                  'back to Available first, then reassign.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7A2A1F)),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _toWorkerId,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFEFEDE6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  for (final w in candidates)
                    DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        '${w.name} · ${w.cowCount} cow${w.cowCount == 1 ? '' : 's'}',
                      ),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (v) => setState(() {
                          _toWorkerId = v;
                          _error = null;
                        }),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFB42318)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: (candidates.isEmpty || _submitting) ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.swap_horiz, size: 16),
          label: Text(
            from.cowCount == 0
                ? 'Confirm'
                : 'Reassign ${from.cowCount} cow${from.cowCount == 1 ? '' : 's'}',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
