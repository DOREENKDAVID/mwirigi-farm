import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/health.dart';
import 'status_badge.dart';

/// "Annual herd-vaccine calendar" — interactive 12-month grid.
///
/// Behaviour:
///   • Default selected month = today's month (always reset on rebuild so no
///     stale selection survives navigation).
///   • Tapping any tile selects that month and instantly updates the detail
///     panel below the grid — no re-fetch required; data is already in [rows].
///   • Detail panel filters rows by:
///       1. ANNUAL protocols whose allowedMonths includes the selected month.
///       2. Any row whose lastDoneAt falls within selected month/year.
///       3. Any row whose nextDueAt falls within selected month/year.
///     De-duplicated by row id so a row matching multiple criteria appears once.
class HerdCalendar extends StatefulWidget {
  const HerdCalendar({super.key, required this.rows, required this.today});

  final List<VaccinationRow> rows;
  final DateTime today;

  @override
  State<HerdCalendar> createState() => _HerdCalendarState();
}

class _HerdCalendarState extends State<HerdCalendar> {
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    // Always reset to the current month — prevents stale selection from
    // a previous navigation session.
    _selectedMonth = widget.today.month;
  }

  // On parent rebuild (e.g. pull-to-refresh returns new data) keep
  // selection in sync with today if it was still on the default.
  @override
  void didUpdateWidget(HerdCalendar old) {
    super.didUpdateWidget(old);
    if (old.today.month != widget.today.month &&
        _selectedMonth == old.today.month) {
      _selectedMonth = widget.today.month;
    }
  }

  List<VaccinationRow> get _monthRows {
    final year = widget.today.year;
    final seen = <String>{};
    final out = <VaccinationRow>[];

    void add(VaccinationRow r) {
      if (seen.add(r.id)) out.add(r);
    }

    for (final r in widget.rows) {
      // 1. ANNUAL protocol windows include selected month.
      if (r.type == 'ANNUAL' && r.allowedMonths.contains(_selectedMonth)) {
        add(r);
        continue;
      }
      // 2. Administered (lastDoneAt) in selected month/year.
      final done = r.lastDoneAt;
      if (done != null && done.month == _selectedMonth && done.year == year) {
        add(r);
        continue;
      }
      // 3. Due (nextDueAt) in selected month/year.
      final due = r.nextDueAt;
      if (due != null && due.month == _selectedMonth && due.year == year) {
        add(r);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final calendar = _buildCalendar(widget.rows);
    final headerSubtitle = _buildSubtitle(calendar);
    final nextUpLine = _buildNextUp(calendar, widget.today);
    final monthOfToday = widget.today.month;
    final year = widget.today.year;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '📆 Annual herd-vaccine calendar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF27500A),
                  ),
                ),
              ),
              Text(
                DateFormat('MMM yyyy').format(widget.today),
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headerSubtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 880
                  ? 12
                  : constraints.maxWidth >= 560
                      ? 6
                      : 4;
              const spacing = 8.0;
              final tileWidth =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var m = 1; m <= 12; m += 1)
                    SizedBox(
                      width: tileWidth,
                      child: _MonthTile(
                        month: m,
                        vaccines: calendar[m] ?? const [],
                        isCurrent: m == monthOfToday,
                        isSelected: m == _selectedMonth,
                        onTap: () => setState(() => _selectedMonth = m),
                      ),
                    ),
                ],
              );
            },
          ),
          if (nextUpLine != null) ...[
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Next up: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: nextUpLine),
                ],
              ),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0x14000000)),
          const SizedBox(height: 14),
          _SelectedMonthPanel(
            month: _selectedMonth,
            year: year,
            rows: _monthRows,
            isCurrent: _selectedMonth == monthOfToday,
          ),
        ],
      ),
    );
  }

  /// month → vaccines locked to that month (ANNUAL rows only).
  static Map<int, List<VaccinationRow>> _buildCalendar(
    List<VaccinationRow> rows,
  ) {
    final out = <int, List<VaccinationRow>>{};
    for (final r in rows) {
      if (r.type != 'ANNUAL') continue;
      for (final m in r.allowedMonths) {
        (out[m] ??= []).add(r);
      }
    }
    return out;
  }

  static String _buildSubtitle(Map<int, List<VaccinationRow>> calendar) {
    if (calendar.isEmpty) return 'No annual herd vaccines configured.';
    final byVaccine = <String, List<int>>{};
    calendar.forEach((m, rows) {
      for (final r in rows) {
        (byVaccine[r.vaccine] ??= []).add(m);
      }
    });
    final parts = byVaccine.entries.map((e) {
      final months = (e.value..sort()).map(_monthShort).join('/');
      return '${e.key} ($months)';
    });
    return 'Per vet protocol, whole-herd vaccines are locked to specific '
        'months: ${parts.join(', ')}.';
  }

  static String? _buildNextUp(
    Map<int, List<VaccinationRow>> calendar,
    DateTime today,
  ) {
    if (calendar.isEmpty) return null;
    final upcoming = <_NextUp>[];
    for (var offset = 1; offset <= 12; offset += 1) {
      final m = ((today.month - 1 + offset) % 12) + 1;
      final list = calendar[m];
      if (list == null || list.isEmpty) continue;
      for (final v in list) {
        upcoming.add(
          _NextUp(
            months: offset,
            monthLabel: _monthShort(m),
            name: v.vaccine,
          ),
        );
      }
      if (upcoming.length >= 2) break;
    }
    if (upcoming.isEmpty) return null;
    return upcoming
        .take(2)
        .map((u) =>
            '${u.name} — in ${u.months} ${u.months == 1 ? "month" : "months"} (${u.monthLabel})')
        .join(' · ');
  }

  static String _monthShort(int m) =>
      DateFormat('MMM').format(DateTime(2026, m, 1));
}

// =====================================================================
// Selected-month detail panel
// =====================================================================

class _SelectedMonthPanel extends StatelessWidget {
  const _SelectedMonthPanel({
    required this.month,
    required this.year,
    required this.rows,
    required this.isCurrent,
  });

  final int month;
  final int year;
  final List<VaccinationRow> rows;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(year, month, 1));
    final done = rows.where((r) => r.status == 'DONE').length;
    final overdue = rows.where((r) => r.status == 'OVERDUE').length;
    final due = rows
        .where((r) => ['DUE_NOW', 'DUE_WINDOW_OPEN', 'DUE_SOON'].contains(r.status))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              monthLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF27500A),
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF27500A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (rows.isNotEmpty)
              _SummaryChips(done: done, due: due, overdue: overdue),
          ],
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No vaccinations scheduled or administered this month.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          )
        else
          for (final r in rows) ...[
            _VaccineDetailRow(row: r),
            if (r != rows.last) const SizedBox(height: 6),
          ],
      ],
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.done,
    required this.due,
    required this.overdue,
  });
  final int done;
  final int due;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        if (done > 0)
          _Chip(label: '$done done', color: const Color(0xFF27500A)),
        if (due > 0)
          _Chip(label: '$due due', color: const Color(0xFF854F0B)),
        if (overdue > 0)
          _Chip(label: '$overdue overdue', color: const Color(0xFFB52C2B)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _VaccineDetailRow extends StatelessWidget {
  const _VaccineDetailRow({required this.row});
  final VaccinationRow row;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final doneStr = row.lastDoneAt != null ? fmt.format(row.lastDoneAt!) : null;
    final dueStr = row.nextDue;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.vaccine,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.unit} · ${row.animals} animals',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                if (doneStr != null || dueStr != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    children: [
                      if (doneStr != null)
                        _MetaLabel(label: 'Done', value: doneStr),
                      if (dueStr != null)
                        _MetaLabel(label: 'Next due', value: dueStr),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: row.status),
        ],
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontSize: 10, color: Colors.black38),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// _MonthTile — now interactive
// =====================================================================

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.month,
    required this.vaccines,
    required this.isCurrent,
    required this.isSelected,
    required this.onTap,
  });

  final int month;
  final List<VaccinationRow> vaccines;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = vaccines.isNotEmpty;
    final monthLabel = DateFormat('MMM').format(DateTime(2026, month, 1));
    final shortName = vaccines.isEmpty
        ? '—'
        : vaccines.map((v) => _shortVaccine(v.vaccine)).join(' · ');

    // Visual hierarchy:
    //   selected current  → green fill + green border + NOW badge
    //   selected other    → light green fill + green border
    //   current (not sel) → white + green border + NOW badge
    //   has vaccines      → amber fill
    //   empty             → light grey
    final Color bg;
    final Color borderColor;
    final double borderWidth;

    if (isSelected && isCurrent) {
      bg = const Color(0xFFD6EAC8);
      borderColor = const Color(0xFF27500A);
      borderWidth = 2;
    } else if (isSelected) {
      bg = const Color(0xFFE8F5E1);
      borderColor = const Color(0xFF27500A);
      borderWidth = 2;
    } else if (isCurrent) {
      bg = Colors.white;
      borderColor = const Color(0xFF27500A);
      borderWidth = 2;
    } else if (has) {
      bg = const Color(0xFFFFF1DD);
      borderColor = Colors.transparent;
      borderWidth = 1;
    } else {
      bg = const Color(0xFFEDEDED);
      borderColor = Colors.transparent;
      borderWidth = 1;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(
                  monthLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: (isCurrent || isSelected)
                        ? const Color(0xFF27500A)
                        : Colors.black54,
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    top: -16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27500A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'NOW',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              shortName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                color: has ? const Color(0xFF854F0B) : Colors.black38,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortVaccine(String name) {
    if (name.toLowerCase().contains('lumpy')) return 'Lumpy Skin';
    final parts = name.split(' ');
    if (parts.length <= 2) return name;
    return parts.take(2).join(' ');
  }
}

// =====================================================================
// Internal data helpers
// =====================================================================

class _NextUp {
  _NextUp({
    required this.months,
    required this.monthLabel,
    required this.name,
  });
  final int months;
  final String monthLabel;
  final String name;
}
