import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/health.dart';

/// "Annual herd-vaccine calendar" — 12 month tiles with the vaccine
/// label for each locked month. Today's month is highlighted with a
/// "NOW" badge.
///
/// All data is derived from the vaccination rows the backend already
/// returns: rows with type=ANNUAL contribute their `allowedMonths` to
/// the calendar tiles. The frontend never decides which months a
/// vaccine belongs to.
class HerdCalendar extends StatelessWidget {
  const HerdCalendar({super.key, required this.rows, required this.today});

  final List<VaccinationRow> rows;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final calendar = _buildCalendar(rows);
    final headerSubtitle = _buildSubtitle(calendar);
    final nextUpLine = _buildNextUp(calendar, today);
    final monthOfToday = today.month;

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
                DateFormat('MMM yyyy').format(today),
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headerSubtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 880
                  ? 12
                  : constraints.maxWidth >= 560
                      ? 6
                      : 4;
              final spacing = 8.0;
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
              style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  /// month → vaccines locked to that month (from ANNUAL rows only).
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
    if (calendar.isEmpty) {
      return 'No annual herd vaccines configured.';
    }
    // Group by vaccine name → list of months.
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
    return 'Per vet protocol, whole-herd vaccines are locked to specific months: ${parts.join(', ')}.';
  }

  static String? _buildNextUp(
    Map<int, List<VaccinationRow>> calendar,
    DateTime today,
  ) {
    if (calendar.isEmpty) return null;
    // Find the next month (strictly after today's month) that has a vaccine.
    final upcoming = <_NextUp>[];
    for (var offset = 1; offset <= 12; offset += 1) {
      final m = ((today.month - 1 + offset) % 12) + 1;
      final list = calendar[m];
      if (list == null || list.isEmpty) continue;
      for (final v in list) {
        upcoming.add(_NextUp(months: offset, monthLabel: _monthShort(m), name: v.vaccine));
      }
      if (upcoming.length >= 2) break;
    }
    if (upcoming.isEmpty) return null;
    return upcoming
        .take(2)
        .map((u) => '${u.name} — in ${u.months} ${u.months == 1 ? "month" : "months"} (${u.monthLabel})')
        .join(' · ');
  }

  static String _monthShort(int m) =>
      DateFormat('MMM').format(DateTime(2026, m, 1));
}

class _NextUp {
  _NextUp({required this.months, required this.monthLabel, required this.name});
  final int months;
  final String monthLabel;
  final String name;
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.month,
    required this.vaccines,
    required this.isCurrent,
  });

  final int month;
  final List<VaccinationRow> vaccines;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final has = vaccines.isNotEmpty;
    final monthLabel = DateFormat('MMM').format(DateTime(2026, month, 1));
    final shortName = vaccines.isEmpty
        ? '—'
        : vaccines.map((v) => _shortVaccine(v.vaccine)).join(' · ');

    final bg = isCurrent
        ? Colors.white
        : has
            ? const Color(0xFFFFF1DD)
            : const Color(0xFFEDEDED);
    final borderColor = isCurrent
        ? const Color(0xFF27500A)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
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
                  color: isCurrent ? const Color(0xFF27500A) : Colors.black54,
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
    );
  }

  static String _shortVaccine(String name) {
    // "Lumpy Skin Disease" → "Lumpy Skin"; everything else → first 2 words.
    if (name.toLowerCase().contains('lumpy')) return 'Lumpy Skin';
    final parts = name.split(' ');
    if (parts.length <= 2) return name;
    return parts.take(2).join(' ');
  }
}
