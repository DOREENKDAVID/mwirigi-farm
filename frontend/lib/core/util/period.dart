// =====================================================================
// PeriodPreset — global time-period selection
// =====================================================================
// One source of truth, mirroring `backend/src/utils/period.js`. Any
// preset added on either side must be added on the other so the wire
// label stays stable.
//
// Every analytics-style endpoint that takes a `period` query param
// uses these wire-values. The frontend's PeriodFilterPanel renders
// from this enum so adding a preset is one line in two places.

import 'package:intl/intl.dart';

enum PeriodPreset {
  today('today', 'Today'),
  yesterday('yesterday', 'Yesterday'),
  thisWeek('week', 'This Week'),
  lastWeek('lastWeek', 'Last Week'),
  thisMonth('month', 'This Month'),
  lastMonth('lastMonth', 'Last Month'),
  quarter('quarter', 'This Quarter'),
  year('annual', 'This Year'),
  custom('custom', 'Custom');

  const PeriodPreset(this.wire, this.label);

  /// The string sent to the backend as `?period=…`.
  final String wire;
  /// The short label rendered on the filter pill.
  final String label;

  static PeriodPreset fromWire(String wire) =>
      PeriodPreset.values.firstWhere(
        (p) => p.wire == wire,
        orElse: () => PeriodPreset.thisMonth,
      );
}

/// Resolved date range for a preset. Mirrors the backend's
/// `resolveRange()` output so the UI can show "Oct 1 → Oct 15"
/// without round-tripping the server.
class ResolvedRange {
  ResolvedRange({
    required this.start,
    required this.end,
    required this.prevStart,
    required this.prevEnd,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final DateTime prevStart;
  final DateTime prevEnd;
  final String label;

  String formattedRange() {
    final fmt = DateFormat('d MMM yy');
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return fmt.format(start);
    }
    return '${fmt.format(start)} → ${fmt.format(end)}';
  }
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Frontend-side `resolveRange`. Used for UI labels and any client
/// computations that don't need to round-trip the server.
ResolvedRange resolveRange({
  required PeriodPreset period,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final now = DateTime.now();
  final today = _startOfDay(now);
  DateTime start;
  DateTime end;
  String label;

  switch (period) {
    case PeriodPreset.today:
      start = _startOfDay(today);
      end = _endOfDay(today);
      label = 'Today';
      break;
    case PeriodPreset.yesterday:
      final y = today.subtract(const Duration(days: 1));
      start = _startOfDay(y);
      end = _endOfDay(y);
      label = 'Yesterday';
      break;
    case PeriodPreset.thisWeek:
      end = _endOfDay(today);
      start = _startOfDay(today.subtract(const Duration(days: 6)));
      label = 'This week';
      break;
    case PeriodPreset.lastWeek:
      end = _endOfDay(today.subtract(const Duration(days: 7)));
      start = _startOfDay(today.subtract(const Duration(days: 13)));
      label = 'Last week';
      break;
    case PeriodPreset.thisMonth:
      start = DateTime(today.year, today.month, 1);
      end = _endOfDay(today);
      label = 'This month';
      break;
    case PeriodPreset.lastMonth:
      start = DateTime(today.year, today.month - 1, 1);
      // Day 0 of current month == last day of previous month.
      end = _endOfDay(DateTime(today.year, today.month, 0));
      label = 'Last month';
      break;
    case PeriodPreset.quarter:
      final qStart = (today.month - 1) ~/ 3 * 3;
      start = DateTime(today.year, qStart + 1, 1);
      end = _endOfDay(today);
      label = 'This quarter';
      break;
    case PeriodPreset.year:
      start = DateTime(today.year, 1, 1);
      end = _endOfDay(today);
      label = 'This year';
      break;
    case PeriodPreset.custom:
      if (customStart == null || customEnd == null) {
        // Fall back to "today" so the panel never crashes on a half-
        // configured custom range; the UI guards against this by
        // requiring both dates before applying the selection.
        start = _startOfDay(today);
        end = _endOfDay(today);
        label = 'Custom (today)';
      } else {
        start = _startOfDay(customStart);
        end = _endOfDay(customEnd);
        label = 'Custom range';
      }
      break;
  }

  final lenMs = end.difference(start).inMilliseconds;
  final prevEnd = _endOfDay(start.subtract(const Duration(milliseconds: 1)));
  final prevStart =
      _startOfDay(prevEnd.subtract(Duration(milliseconds: lenMs)));
  return ResolvedRange(
    start: start,
    end: end,
    prevStart: prevStart,
    prevEnd: prevEnd,
    label: label,
  );
}
