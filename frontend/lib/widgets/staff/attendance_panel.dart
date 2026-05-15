import 'package:flutter/material.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';
import 'add_staff_dialog.dart';

/// "Attendance — today" card. Search box on top, list of staff cards below
/// with avatar + name + role/department subtitle and a Mark present /
/// Mark absent toggle.
class AttendancePanel extends StatefulWidget {
  const AttendancePanel({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  final List<AttendanceEntry> entries;
  final VoidCallback onChanged;

  @override
  State<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<AttendancePanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggle(AttendanceEntry e) async {
    final next = e.status == AttendanceStatus.present
        ? AttendanceStatus.absent
        : AttendanceStatus.present;
    try {
      await ApiService.markStaffAttendance({
        'userId': e.userId,
        'status': next.wire,
      });
      widget.onChanged();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openAddStaff() async {
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddStaffDialog(),
    );
    if (added == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? widget.entries
        : widget.entries
            .where((e) =>
                e.fullName.toLowerCase().contains(q) ||
                (e.department ?? '').toLowerCase().contains(q))
            .toList();

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
                  'ATTENDANCE — TODAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openAddStaff,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add staff'),
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
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search staff…',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No staff match.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            )
          else
            for (final e in filtered) ...[
              _StaffRow(entry: e, onToggle: () => _toggle(e)),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.entry, required this.onToggle});

  final AttendanceEntry entry;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isPresent = entry.status == AttendanceStatus.present;
    final isAbsent = entry.status == AttendanceStatus.absent;
    final initials = entry.fullName
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    final (Color statusBg, Color statusFg) = isPresent
        ? (const Color(0xFFEAF3DE), const Color(0xFF27500A))
        : isAbsent
            ? (const Color(0xFFFCEBEB), const Color(0xFF501313))
            : (const Color(0xFFFAEEDA), const Color(0xFF854F0B));

    final btnBg = isPresent ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final btnFg = isPresent ? const Color(0xFF27500A) : const Color(0xFFE24B4A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF27500A),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fullName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_roleLabel(entry.role)} · ${entry.department ?? "—"}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Material(
                color: btnBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: btnFg.withValues(alpha: 0.4)),
                ),
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      isPresent ? 'Mark absent' : 'Mark present',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: btnFg,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _roleLabel(String wire) {
    switch (wire) {
      case 'CEO':
        return 'CEO';
      case 'ADMIN':
        return 'Admin';
      case 'DAIRY_MANAGER':
        return 'Dairy Manager';
      case 'LAYERS_MANAGER':
        return 'Layers Manager';
      case 'PIGGERY_MANAGER':
        return 'Piggery Manager';
      case 'FEEDLOT_MANAGER':
        return 'Feedlot Manager';
      case 'STORE_MANAGER':
        return 'Store Manager';
      case 'VET':
        return 'Vet';
      case 'WORKER':
        return 'Worker';
      case 'ICT':
        return 'ICT';
      default:
        return wire;
    }
  }
}
