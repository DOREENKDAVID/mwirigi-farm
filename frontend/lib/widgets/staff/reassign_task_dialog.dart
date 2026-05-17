import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/staff.dart';
import '../../core/models/task_reassignment.dart';
import '../../core/service/api_service.dart';

/// Swap a task from its current assignee to a replacement. The
/// previous assignee is auto-filled (read-only). Posts to
/// /api/staff/tasks/:id/reassign; the server records an audit row
/// AND updates Task.assignedToId in a single transaction.
class ReassignTaskDialog extends StatefulWidget {
  const ReassignTaskDialog({
    super.key,
    required this.task,
    required this.staff,
  });

  final TaskRow task;
  final List<AttendanceEntry> staff;

  @override
  State<ReassignTaskDialog> createState() => _ReassignTaskDialogState();
}

class _ReassignTaskDialogState extends State<ReassignTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  String? _toUserId;
  TaskReassignmentReason? _reason;
  TaskReassignmentDuration _duration = TaskReassignmentDuration.today;
  DateTime _effectiveDate = DateTime.now();
  bool _approvalRequired = false;
  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  // Exclude the current assignee from the replacement dropdown so a
  // user can't "swap" a task to its existing owner.
  List<AttendanceEntry> get _replacements => widget.staff
      .where((s) => s.userId != widget.task.assignedToId)
      .toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && mounted) setState(() => _effectiveDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await ApiService.reassignStaffTask(widget.task.id, {
        'toUserId': _toUserId,
        'reason': _reason!.wire,
        'duration': _duration.wire,
        'effectiveDate': _effectiveDate.toIso8601String(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'approvalRequired': _approvalRequired,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d, y');
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.swap_horiz, color: Color(0xFF1976D2), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Reassign task',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x331976D2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Currently with ${widget.task.assignedToName} · ${widget.task.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1F4365),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _label('REPLACEMENT STAFF *'),
                DropdownButtonFormField<String>(
                  initialValue: _toUserId,
                  isExpanded: true,
                  decoration: _inputDec(),
                  items: [
                    for (final s in _replacements)
                      DropdownMenuItem(value: s.userId, child: Text(s.fullName)),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _toUserId = v),
                  validator: (v) =>
                      v == null ? 'Replacement is required' : null,
                ),
                const SizedBox(height: 14),
                _label('REASON *'),
                DropdownButtonFormField<TaskReassignmentReason>(
                  initialValue: _reason,
                  isExpanded: true,
                  decoration: _inputDec(),
                  items: [
                    for (final r in TaskReassignmentReason.values)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _reason = v),
                  validator: (v) => v == null ? 'Reason is required' : null,
                ),
                const SizedBox(height: 14),
                _row([
                  _field('EFFECTIVE DATE', InkWell(
                    onTap: _submitting ? null : _pickDate,
                    child: InputDecorator(
                      decoration: _inputDec(),
                      child: Row(
                        children: [
                          Expanded(child: Text(fmt.format(_effectiveDate))),
                          const Icon(Icons.event, size: 18, color: Colors.black54),
                        ],
                      ),
                    ),
                  )),
                  _field('DURATION', DropdownButtonFormField<TaskReassignmentDuration>(
                    initialValue: _duration,
                    isExpanded: true,
                    decoration: _inputDec(),
                    items: [
                      for (final d in TaskReassignmentDuration.values)
                        DropdownMenuItem(value: d, child: Text(d.label)),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _duration = v ?? _duration),
                  )),
                ]),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _approvalRequired,
                  title: const Text(
                    'Approval required',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Mark this swap as pending CEO/manager approval',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _approvalRequired = v),
                ),
                _label('NOTES'),
                TextFormField(
                  controller: _notes,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: _inputDec(
                    hint: 'Optional — context for HR / payroll, e.g. expected return date',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
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
          label: const Text('Reassign'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _row(List<Widget> children) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 12),
          ],
        ],
      );

  Widget _field(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_label(label), child],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Colors.black54,
          ),
        ),
      );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFEFEDE6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
      );
}
