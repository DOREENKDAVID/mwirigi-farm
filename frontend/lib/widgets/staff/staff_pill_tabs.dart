import 'package:flutter/material.dart';

/// Pill-style tab navigation for the Staff & Labour page. Mirrors the
/// `DairyPillTabs` / `LayersPillTabs` so the cross-module experience
/// stays consistent — same green-pill row, same horizontal scroll on
/// narrow screens.
///
/// Sections (matches the v4.2 HTML mockup):
///   • Overview    — KPIs + a glanceable summary of attendance, tasks,
///                   and the payroll-month estimate
///   • Attendance  — full attendance panel (search · mark present /
///                   absent · add staff)
///   • Tasks       — full task assignments table
///   • Payroll     — full payroll summary table + Approve / Export
enum StaffTab {
  overview('Overview'),
  employees('👥 Employees'),
  attendance('Attendance'),
  tasks('Tasks'),
  payroll('Payroll');

  const StaffTab(this.label);
  final String label;
}

class StaffPillTabs extends StatelessWidget {
  const StaffPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final StaffTab selected;
  final ValueChanged<StaffTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in StaffTab.values) ...[
            _Pill(
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != StaffTab.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? StaffPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? StaffPillTabs._primary
        : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}
