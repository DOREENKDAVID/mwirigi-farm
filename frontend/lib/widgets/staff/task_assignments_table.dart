import 'package:flutter/material.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';
import 'assign_task_dialog.dart';
import 'reassign_task_dialog.dart';

/// Task assignments table. 6 columns:
///   Assigned · Unit · Task · Priority · Status · Actions
///
/// Edit pencil cycles through statuses (PENDING → IN_PROGRESS → DONE → PENDING)
/// with a single tap. The dropdown-edit pattern would be richer but this
/// matches the HTML mockup's compact action column.
class TaskAssignmentsTable extends StatelessWidget {
  const TaskAssignmentsTable({
    super.key,
    required this.tasks,
    required this.staff,
    required this.onChanged,
  });

  final List<TaskRow> tasks;
  final List<AttendanceEntry> staff;
  final VoidCallback onChanged;

  Future<void> _openAssignTask(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignTaskDialog(staff: staff),
    );
    if (saved == true) {
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned')),
        );
      }
    }
  }

  Future<void> _openReassign(BuildContext context, TaskRow t) async {
    final reassigned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReassignTaskDialog(task: t, staff: staff),
    );
    if (reassigned == true) {
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.title} reassigned')),
        );
      }
    }
  }

  Future<void> _cycleStatus(BuildContext context, TaskRow t) async {
    const order = [
      TaskStatus.pending,
      TaskStatus.inProgress,
      TaskStatus.done,
    ];
    final next = order[(order.indexOf(t.status) + 1) % order.length];
    try {
      await ApiService.updateStaffTask(t.id, {'status': next.wire});
      onChanged();
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

  Future<void> _delete(BuildContext context, TaskRow t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete task'),
        content: Text('Delete "${t.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlg).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dlg).pop(true),
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
      await ApiService.deleteStaffTask(t.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
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
                  'TASK ASSIGNMENTS — TODAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openAssignTask(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign task'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF27500A),
                  side: const BorderSide(color: Color(0x33000000)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No tasks assigned today.',
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
                  DataColumn(label: Text('ASSIGNED')),
                  DataColumn(label: Text('UNIT')),
                  DataColumn(label: Text('TASK')),
                  DataColumn(label: Text('PRIORITY')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final t in tasks)
                    DataRow(cells: [
                      DataCell(Text(t.assignedToName)),
                      DataCell(Text(t.unit)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Text(
                            t.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(_PriorityPill(priority: t.priority)),
                      DataCell(_StatusPill(status: t.status)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Cycle status',
                            onPressed: () => _cycleStatus(context, t),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            color: const Color(0xFF27500A),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reassign',
                            onPressed: () => _openReassign(context, t),
                            icon: const Icon(Icons.swap_horiz, size: 16),
                            color: const Color(0xFF1976D2),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _delete(context, t),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            color: const Color(0xFFE24B4A),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (priority) {
      TaskPriority.high =>
        (const Color(0xFFFCEBEB), const Color(0xFF501313)),
      TaskPriority.medium =>
        (const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
      TaskPriority.low =>
        (const Color(0xFFE6F1FB), const Color(0xFF185FA5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      TaskStatus.done =>
        (const Color(0xFFEAF3DE), const Color(0xFF27500A)),
      TaskStatus.inProgress =>
        (const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
      TaskStatus.pending =>
        (const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
