import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';
import 'edit_employee_dialog.dart';
import 'release_worker_dialog.dart';

/// Employees tab — full staff directory (active + released) with filter
/// pills by status, department, and a search bar.
class EmployeeList extends StatefulWidget {
  const EmployeeList({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<EmployeeList> createState() => _EmployeeListState();
}

class _EmployeeListState extends State<EmployeeList> {
  static const _primary = Color(0xFF27500A);

  Future<List<Staff>>? _future;
  _StatusFilter _statusFilter = _StatusFilter.active;
  String? _deptFilter;
  String _query = '';

  final _searchController = TextEditingController();

  static const _departments = [
    'Dairy', 'Layers', 'Piggery', 'Feedlot', 'Admin', 'Feeds', 'Ngushish',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Staff>> _load() async {
    final raw = await ApiService.getStaffList(includeReleased: true);
    return raw
        .whereType<Map>()
        .map((m) => Staff.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
    widget.onChanged();
  }

  List<Staff> _filtered(List<Staff> all) {
    return all.where((s) {
      // Status filter
      switch (_statusFilter) {
        case _StatusFilter.active:
          if (s.employmentStatus != EmploymentStatus.active) return false;
        case _StatusFilter.released:
          if (s.employmentStatus != EmploymentStatus.released) return false;
        case _StatusFilter.all:
          break;
      }
      // Dept filter
      if (_deptFilter != null && s.department != _deptFilter) return false;
      // Search
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!s.fullName.toLowerCase().contains(q) &&
            !(s.department ?? '').toLowerCase().contains(q) &&
            !(s.role.toLowerCase().contains(q)) &&
            !(s.jobTitle ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Staff>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorView(
            message: snap.error.toString().replaceFirst('Exception: ', ''),
            onRetry: _refresh,
          );
        }
        final all = snap.data ?? const [];
        final visible = _filtered(all);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  const Text(
                    'EMPLOYEES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3DE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${visible.length} / ${all.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
              _SearchBar(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              // Filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Status pills
                    for (final f in _StatusFilter.values) ...[
                      _Pill(
                        label: f.label,
                        active: _statusFilter == f,
                        accent: f.accent,
                        onTap: () => setState(() => _statusFilter = f),
                      ),
                      const SizedBox(width: 6),
                    ],
                    const SizedBox(width: 8),
                    // Dept pills
                    _Pill(
                      label: 'All depts',
                      active: _deptFilter == null,
                      onTap: () => setState(() => _deptFilter = null),
                    ),
                    for (final d in _departments) ...[
                      const SizedBox(width: 6),
                      _Pill(
                        label: d,
                        active: _deptFilter == d,
                        onTap: () => setState(() => _deptFilter = d),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No employees match the current filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth >= 760) {
                      return _DesktopTable(
                        rows: visible,
                        onEdit: _openEdit,
                        onRelease: _openRelease,
                      );
                    }
                    return _MobileCards(
                      rows: visible,
                      onEdit: _openEdit,
                      onRelease: _openRelease,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEdit(Staff s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => EditEmployeeDialog(staff: s),
    );
    if (ok == true) await _refresh();
  }

  Future<void> _openRelease(Staff s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ReleaseWorkerDialog(staff: s),
    );
    if (ok == true) await _refresh();
  }
}

// ── Enums ──────────────────────────────────────────────────────────────

enum _StatusFilter {
  active('Active', Color(0xFF27500A)),
  released('Released', Color(0xFFB52C2B)),
  all('All', null);

  const _StatusFilter(this.label, this.accent);
  final String label;
  final Color? accent;
}

// ── Desktop table ──────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.rows,
    required this.onEdit,
    required this.onRelease,
  });
  final List<Staff> rows;
  final ValueChanged<Staff> onEdit;
  final ValueChanged<Staff> onRelease;

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(2.2), // Name
        1: FlexColumnWidth(1.4), // Department
        2: FlexColumnWidth(1.6), // Role / Title
        3: FlexColumnWidth(1.2), // Start date
        4: FlexColumnWidth(1.4), // Status
        5: FixedColumnWidth(88),  // Actions
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x14000000))),
          ),
          children: [
            _Th('Name'),
            _Th('Department'),
            _Th('Role / Title'),
            _Th('Start date'),
            _Th('Status'),
            SizedBox.shrink(),
          ],
        ),
        for (final s in rows)
          TableRow(
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0x0F000000))),
            ),
            children: [
              _Td(s.fullName, bold: true),
              _Td(s.department ?? '—', muted: s.department == null),
              _Td(s.jobTitle ?? s.role),
              _Td(_fmtDate(s.createdAt)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _StatusBadge(
                    status: s.employmentStatus,
                    releaseDate: s.releaseDate),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _ActionButtons(
                  staff: s,
                  onEdit: () => onEdit(s),
                  onRelease: () => onRelease(s),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Mobile cards ───────────────────────────────────────────────────────

class _MobileCards extends StatelessWidget {
  const _MobileCards({
    required this.rows,
    required this.onEdit,
    required this.onRelease,
  });
  final List<Staff> rows;
  final ValueChanged<Staff> onEdit;
  final ValueChanged<Staff> onRelease;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final s in rows) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _StatusBadge(
                        status: s.employmentStatus,
                        releaseDate: s.releaseDate),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.jobTitle ?? s.role}${s.department != null ? ' · ${s.department}' : ''}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                if (s.releaseDate != null) ...[
                  Text(
                    'Released ${_fmtDate(s.releaseDate)} · ${_reasonLabel(s.releaseReason)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFB52C2B)),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionButtons(
                      staff: s,
                      onEdit: () => onEdit(s),
                      onRelease: () => onRelease(s),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (s != rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.staff,
    required this.onEdit,
    required this.onRelease,
  });
  final Staff staff;
  final VoidCallback onEdit;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16),
          tooltip: 'Edit employee',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 16,
          color: const Color(0xFF27500A),
          onPressed: onEdit,
        ),
        if (staff.employmentStatus == EmploymentStatus.active) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, size: 16),
            tooltip: 'Release worker',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 16,
            color: const Color(0xFFB52C2B),
            onPressed: onRelease,
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.releaseDate});
  final EmploymentStatus status;
  final DateTime? releaseDate;

  @override
  Widget build(BuildContext context) {
    final isActive = status == EmploymentStatus.active;
    final bg =
        isActive ? const Color(0xFFEAF3DE) : const Color(0xFFFEE2E2);
    final fg =
        isActive ? const Color(0xFF27500A) : const Color(0xFFB52C2B);
    final label = isActive
        ? 'Active'
        : releaseDate != null
            ? 'Released ${_fmtDate(releaseDate)}'
            : 'Released';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar(
      {required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4F0),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search employees…',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Colors.black38),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 14,
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    final bg = active ? (accent ?? primary) : Colors.white;
    final fg = active ? Colors.white : Colors.black87;
    final border = active ? (accent ?? primary) : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.bold = false, this.muted = false});
  final String text;
  final bool bold;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: muted ? Colors.black38 : const Color(0xFF222222),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return DateFormat('d MMM yyyy').format(d);
}

String _reasonLabel(String? r) {
  switch (r) {
    case 'CONTRACT_ENDED':
      return 'Contract ended';
    case 'RESIGNED':
      return 'Resigned';
    case 'DISMISSED':
      return 'Dismissed';
    case 'RETIRED':
      return 'Retired';
    case 'SEASONAL_ENDED':
      return 'Seasonal work ended';
    default:
      return r ?? 'Other';
  }
}
