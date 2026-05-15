import 'package:flutter/material.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';

/// "Assign Task" modal. Backend takes `assignedToId` (UUID), so the
/// "Assigned to" field is a dropdown of registered staff rather than the
/// HTML mockup's free-text input — same UX intent, less foot-gun.
///
///   Row 1:  [ Assigned to (dropdown) ]   [ Unit (dropdown) ]
///           [ Task description (full width) ]
///   Row 2:  [ Priority ]                 [ Due time ]
///   Assign · Cancel
class AssignTaskDialog extends StatefulWidget {
  const AssignTaskDialog({super.key, required this.staff});

  /// Staff list to show in the assignee dropdown.
  final List<AttendanceEntry> staff;

  @override
  State<AssignTaskDialog> createState() => _AssignTaskDialogState();
}

class _AssignTaskDialogState extends State<AssignTaskDialog> {
  static const _units = <String>[
    'Dairy',
    'Layers',
    'Piggery',
    'Feedlot',
    'Feeds',
    'Ngushish',
    'Health',
  ];

  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  String? _assigneeId;
  String _unit = 'Dairy';
  TaskPriority _priority = TaskPriority.high;
  TimeOfDay? _dueTime;
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _dueTime = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_assigneeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an assignee')),
      );
      return;
    }

    DateTime? dueDate;
    if (_dueTime != null) {
      final now = DateTime.now();
      dueDate = DateTime(
        now.year,
        now.month,
        now.day,
        _dueTime!.hour,
        _dueTime!.minute,
      );
    }

    setState(() => _submitting = true);
    try {
      await ApiService.createStaffTask({
        'assignedToId': _assigneeId,
        'unit': _unit,
        'title': _descController.text.trim(),
        'priority': _priority.wire,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
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
    const primary = Color(0xFF27500A);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Assign Task',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create a task for a staff member',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _assigneeId,
                        decoration: const InputDecoration(
                          labelText: 'Assigned to',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final s in widget.staff)
                            DropdownMenuItem(
                              value: s.userId,
                              child: Text(s.fullName),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _assigneeId = v),
                        validator: (v) =>
                            v == null ? 'Pick an assignee' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final u in _units)
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _unit = v ?? _unit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Task description *',
                    hintText: 'e.g. Check PM milking session',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length < 2) return 'Task description is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TaskPriority>(
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final p in TaskPriority.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) =>
                                setState(() => _priority = v ?? _priority),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _submitting ? null : _pickTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due time',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.access_time, size: 18),
                          ),
                          child: Text(
                            _dueTime == null
                                ? '--:--'
                                : _dueTime!.format(context),
                            style: TextStyle(
                              color: _dueTime == null
                                  ? Colors.black45
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: primary),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}
