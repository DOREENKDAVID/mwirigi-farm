// "Staff roster by unit" card — the permanent who-works-where view that
// sits at the top of the Tasks pill. One tile per unit, listing each
// staff member with their role and daily rate. Daily totals per unit
// + the grand total are computed from the payroll data so the numbers
// match what payroll will actually pay out.
//
// Ad-hoc daily task assignments still go through the "+ Assign task"
// button on the TaskAssignmentsTable below this card.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/staff.dart';

class StaffRosterByUnitCard extends StatelessWidget {
  const StaffRosterByUnitCard({super.key, required this.payroll});

  final PayrollSummary payroll;

  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  // Unit-tile styling. Order matters — defines the rendering sequence.
  static const _units = <_UnitStyle>[
    _UnitStyle('Dairy',   '🐄', Color(0xFFEFF5E0), Color(0xFF27500A)),
    _UnitStyle('Piggery', '🐷', Color(0xFFFCEDD8), Color(0xFF8A5A0A)),
    _UnitStyle('Layers',  '🥚', Color(0xFFE8F4EA), Color(0xFF0F6E56)),
    _UnitStyle('Feedlot', '🐂', Color(0xFFF5F1E8), Color(0xFF6B4E1E)),
    _UnitStyle('Feeds',   '🌾', Color(0xFFEEF5E0), Color(0xFF4D6B1E)),
    _UnitStyle('Ngushish', '🌱', Color(0xFFEFF5E0), Color(0xFF27500A)),
    _UnitStyle('All units', '🩺', Color(0xFFE6F0F8), Color(0xFF185FA5)),
  ];

  @override
  Widget build(BuildContext context) {
    // Roster is a DAILY-rate view. Monthly-only staff (CEO, ICT Admin)
    // are tracked separately on the payroll table and don't belong on
    // this card — including them would double-count on the daily total.
    final rows = payroll.rows
        .where((r) => (r.dailyRate ?? 0) > 0 || r.salaryType == 'DAILY')
        .toList();
    final fmt = NumberFormat.decimalPattern();

    // Group rows by unit. Unknown units fall under "All units" so a
    // farm vet who covers everywhere still surfaces.
    final byUnit = <String, List<PayrollRow>>{};
    for (final r in rows) {
      final key = _normalizeUnit(r.unit);
      byUnit.putIfAbsent(key, () => []).add(r);
    }

    final grandTotal =
        rows.fold<num>(0, (sum, r) => sum + (r.dailyRate ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('👨‍🌾', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'STAFF ROSTER BY UNIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: _primary,
                  ),
                ),
              ),
              Text(
                '${rows.length} staff · KSh ${fmt.format(grandTotal.round())}/day total',
                style: const TextStyle(fontSize: 11, color: _txt3),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Every staff member's unit and rate at a glance. Anomalies "
            '(missing unit, missing rate) are flagged so they can be '
            'corrected before payroll runs.',
            style: TextStyle(fontSize: 11, color: _txt2, height: 1.4),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 960
                  ? 3
                  : c.maxWidth >= 600
                      ? 2
                      : 1;
              final tileWidth = (c.maxWidth - 12 * (cols - 1)) / cols;

              // Build the tiles in the canonical order, skipping units
              // with no staff.
              final tiles = <Widget>[];
              for (final style in _units) {
                final unitRows = byUnit[style.name] ?? const <PayrollRow>[];
                if (unitRows.isEmpty) continue;
                tiles.add(SizedBox(
                  width: tileWidth,
                  child: _UnitTile(style: style, rows: unitRows),
                ));
              }
              // Any units the server returns that we don't have styling
              // for — render under a default scheme so nothing is lost.
              for (final entry in byUnit.entries) {
                if (_units.any((u) => u.name == entry.key)) continue;
                tiles.add(SizedBox(
                  width: tileWidth,
                  child: _UnitTile(
                    style: _UnitStyle(
                      entry.key,
                      '🏷️',
                      const Color(0xFFFAFAF7),
                      const Color(0xFF6B7770),
                    ),
                    rows: entry.value,
                  ),
                ));
              }
              return Wrap(spacing: 12, runSpacing: 12, children: tiles);
            },
          ),
        ],
      ),
    );
  }

  static String _normalizeUnit(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'All units';
    // Server sometimes returns lowercase or alternate names — fold the
    // common variants so they group together.
    final lower = t.toLowerCase();
    if (lower.startsWith('dairy')) return 'Dairy';
    if (lower.startsWith('pig')) return 'Piggery';
    if (lower.startsWith('layer')) return 'Layers';
    if (lower.startsWith('feedlot')) return 'Feedlot';
    if (lower.startsWith('feed')) return 'Feeds';
    if (lower.startsWith('ngush')) return 'Ngushish';
    if (lower.contains('all') || lower.contains('vet') || lower.contains('health')) {
      return 'All units';
    }
    return t;
  }
}

class _UnitStyle {
  const _UnitStyle(this.name, this.emoji, this.bg, this.accent);
  final String name;
  final String emoji;
  final Color bg;
  final Color accent;
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.style, required this.rows});
  final _UnitStyle style;
  final List<PayrollRow> rows;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final total = rows.fold<num>(0, (s, r) => s + (r.dailyRate ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(style.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      style.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: style.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rows.length} staff · KSh ${fmt.format(total.round())}/day total',
                      style: TextStyle(
                        fontSize: 11,
                        color: style.accent.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            _RosterLine(row: r, accent: style.accent),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _RosterLine extends StatelessWidget {
  const _RosterLine({required this.row, required this.accent});
  final PayrollRow row;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final missingRate = row.dailyRate == null || row.dailyRate == 0;
    final missingUnit = row.unit.trim().isEmpty;
    final hasAnomaly = missingRate || missingUnit;

    // Prefer the descriptive jobTitle ("Dairy Worker", "Piggery
     // Manager (A·B·C·EM)") over the raw enum role.
    final roleLabel = (row.jobTitle?.isNotEmpty ?? false)
        ? row.jobTitle!
        : row.role;

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1A1A18),
          height: 1.45,
        ),
        children: [
          TextSpan(
            text: row.name,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: hasAnomaly ? const Color(0xFFC4393B) : accent,
            ),
          ),
          const TextSpan(text: ' — '),
          TextSpan(text: roleLabel),
          TextSpan(
            text: missingRate
                ? '  (no rate)'
                : '  (KSh ${fmt.format(row.dailyRate!.round())})',
            style: TextStyle(
              color: missingRate
                  ? const Color(0xFFC4393B)
                  : const Color(0xFF99A39B),
              fontWeight: missingRate ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
