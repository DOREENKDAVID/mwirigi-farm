import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import 'attendance_panel.dart';
import 'employee_list.dart';
import 'payroll_summary_table.dart';
import 'staff_pill_tabs.dart';
import 'staff_roster_by_unit_card.dart';
import 'task_assignments_table.dart';

/// Staff & Labour module body. Pill-driven navigation matching the v4.2
/// HTML mockup:
///   Overview   — KPIs + glanceable attendance/tasks/payroll summary
///   Attendance — full attendance panel (search · mark · add staff)
///   Tasks      — full task assignments table
///   Payroll    — full payroll summary table
class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  Future<StaffDashboard>? _future;
  StaffTab _active = StaffTab.overview;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StaffDashboard> _load() async {
    final raw = await ApiService.getStaffDashboard();
    return StaffDashboard.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<StaffDashboard>(
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
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              const _PageHeader(),
              const SizedBox(height: 16),
              _KpiRow(data: data),
              const SizedBox(height: 16),
              StaffPillTabs(
                selected: _active,
                onSelect: (t) => setState(() => _active = t),
              ),
              const SizedBox(height: 16),
              ..._tabBody(data),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Pill body dispatch ----------------

  List<Widget> _tabBody(StaffDashboard data) {
    switch (_active) {
      case StaffTab.overview:
        // Light overview: a glanceable summary of each section, with
        // "Open <section>" buttons that switch the user to the focused
        // pill. Heavy widgets (full attendance list, task table,
        // payroll table) live behind their own pills.
        return [
          _AttendanceSummaryCard(
            data: data,
            onOpen: () => setState(() => _active = StaffTab.attendance),
          ),
          const SizedBox(height: 16),
          _TasksSummaryCard(
            data: data,
            onOpen: () => setState(() => _active = StaffTab.tasks),
          ),
          const SizedBox(height: 16),
          _PayrollSummaryCard(
            data: data,
            onOpen: () => setState(() => _active = StaffTab.payroll),
          ),
        ];
      case StaffTab.employees:
        return [
          EmployeeList(onChanged: _refresh),
        ];
      case StaffTab.attendance:
        return [
          AttendancePanel(
            entries: data.attendance,
            onChanged: _refresh,
          ),
        ];
      case StaffTab.tasks:
        return [
          // Permanent roster — everyone's unit + daily rate. Anomalies
          // (missing unit / missing rate) are flagged so they can be
          // corrected before payroll runs.
          StaffRosterByUnitCard(payroll: data.payroll),
          const SizedBox(height: 16),
          // Ad-hoc daily task assignments stack on top of the permanent
          // roster. "+ Assign task" lives inside this widget.
          TaskAssignmentsTable(
            tasks: data.tasks,
            staff: data.attendance,
            onChanged: _refresh,
          ),
        ];
      case StaffTab.payroll:
        return [
          PayrollSummaryTable(
            payroll: data.payroll,
            onChanged: _refresh,
          ),
        ];
    }
  }
}

// =====================================================================
// Header
// =====================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3DE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('👨‍🌾', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff & Labour',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _StaffPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Attendance · Tasks · Payroll',
                style: TextStyle(
                  fontSize: 12,
                  color: _StaffPageState._txt2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// KPI row
// =====================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.data});
  final StaffDashboard data;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final pct = data.totalStaff > 0
        ? ((data.presentToday / data.totalStaff) * 100).round()
        : 0;

    final cards = <Widget>[
      KpiCard(
        label: 'Total staff',
        value: fmt.format(data.totalStaff),
        sub: 'All units',
      ),
      KpiCard(
        label: 'Present today',
        value: fmt.format(data.presentToday),
        sub: '$pct% attendance',
        trendColor: const Color(0xFF27500A),
      ),
      KpiCard(
        label: 'Absent',
        value: fmt.format(data.absentToday),
        sub: 'Of expected ${data.totalStaff}',
        trendColor: const Color(0xFFE24B4A),
      ),
      KpiCard(
        label: 'Monthly payroll',
        value: 'KSh ${_compact(data.monthlyPayroll)}',
        sub: '${_monthLabel(data.payroll.month, data.payroll.year)} estimate',
      ),
    ];

    return KpiGrid(children: cards);
  }

  static String _compact(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).round()}K';
    return n.round().toString();
  }

  static String _monthLabel(int month, int year) =>
      DateFormat('MMM yyyy').format(DateTime(year, month));
}

// =====================================================================
// Overview summary cards — light glance into each section + "Open"
// =====================================================================

class _OverviewSectionCard extends StatelessWidget {
  const _OverviewSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.onOpen,
    required this.openLabel,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Widget body;
  final VoidCallback onOpen;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _StaffPageState._primary,
                        letterSpacing: 0.04,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _StaffPageState._txt3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: _StaffPageState._primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(openLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  const _AttendanceSummaryCard({required this.data, required this.onOpen});
  final StaffDashboard data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final present = data.attendance
        .where((s) => s.status == AttendanceStatus.present)
        .length;
    // Half-day stands in for the HTML mockup's "Late" bucket — the
    // backend collapses lateness into half-day attendance.
    final late = data.attendance
        .where((s) => s.status == AttendanceStatus.halfDay)
        .length;
    final absent = data.attendance
        .where((s) => s.status == AttendanceStatus.absent)
        .length;
    return _OverviewSectionCard(
      icon: '📋',
      title: 'ATTENDANCE — TODAY',
      subtitle: '${data.attendance.length} staff on the register',
      onOpen: onOpen,
      openLabel: 'Manage →',
      body: Row(
        children: [
          Expanded(
            child: _StatusTile(
              count: present,
              label: 'Present',
              color: const Color(0xFF27500A),
              bg: const Color(0xFFEFF5E6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatusTile(
              count: late,
              label: 'Late',
              color: const Color(0xFF8A5A0A),
              bg: const Color(0xFFFCEDC8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatusTile(
              count: absent,
              label: 'Absent',
              color: const Color(0xFFC4393B),
              bg: const Color(0xFFFADBD8),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.count,
    required this.label,
    required this.color,
    required this.bg,
  });
  final int count;
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksSummaryCard extends StatelessWidget {
  const _TasksSummaryCard({required this.data, required this.onOpen});
  final StaffDashboard data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tasks = data.tasks;
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final pending = tasks.where((t) => t.status == TaskStatus.pending).length;
    final inProgress =
        tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final highPri = tasks
        .where((t) =>
            t.priority == TaskPriority.high && t.status != TaskStatus.done)
        .length;

    return _OverviewSectionCard(
      icon: '✅',
      title: 'TASK ASSIGNMENTS — TODAY',
      subtitle: '${tasks.length} task${tasks.length == 1 ? '' : 's'} on the board',
      onOpen: onOpen,
      openLabel: 'Open board →',
      body: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip(
            label: 'Done',
            count: done,
            color: const Color(0xFF27500A),
            bg: const Color(0xFFEFF5E6),
          ),
          _Chip(
            label: 'In progress',
            count: inProgress,
            color: const Color(0xFF185FA5),
            bg: const Color(0xFFE0EAF7),
          ),
          _Chip(
            label: 'Pending',
            count: pending,
            color: const Color(0xFF8A5A0A),
            bg: const Color(0xFFFCEDC8),
          ),
          if (highPri > 0)
            _Chip(
              label: 'High priority open',
              count: highPri,
              color: const Color(0xFFC4393B),
              bg: const Color(0xFFFADBD8),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });
  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollSummaryCard extends StatelessWidget {
  const _PayrollSummaryCard({required this.data, required this.onOpen});
  final StaffDashboard data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMM yyyy').format(
      DateTime(data.payroll.year, data.payroll.month),
    );
    return _OverviewSectionCard(
      icon: '💳',
      title: 'PAYROLL — $monthLabel',
      subtitle: '${data.payroll.rows.length} staff · '
          '${data.payroll.rows.where((r) => r.status == PayrollStatus.paid).length} paid · '
          '${data.payroll.rows.where((r) => r.status != PayrollStatus.paid).length} pending',
      onOpen: onOpen,
      openLabel: 'Approve / export →',
      body: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Estimated monthly gross',
                style: TextStyle(
                  fontSize: 12,
                  color: _StaffPageState._txt2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'KSh ${NumberFormat.decimalPattern().format(data.monthlyPayroll.round())}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _StaffPageState._primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Error
// =====================================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 40, color: Color(0xFFE24B4A)),
        const SizedBox(height: 12),
        Text(
          'Could not load staff data',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
