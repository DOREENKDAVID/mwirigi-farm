import 'package:flutter/material.dart';

/// Small pill widget used by the vaccination + treatment tables.
/// Colors mirror the HTML mockup's `tag-g` / `tag-a` / `tag-r` / `tag-t`
/// classes so the operational density of the page is preserved.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  /// One of: DONE | DUE_SOON | DUE_NOW | DUE_WINDOW_OPEN | UPCOMING |
  /// OVERDUE | ACTIVE | IMPROVING | RECOVERED | CANCELLED.
  final String status;

  @override
  Widget build(BuildContext context) {
    final p = _palette(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        p.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: p.fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Pill used for the treatment "Day N" / "Improving" cell — same shape,
/// caller provides the label text directly so the day count comes from
/// the backend's `statusLabel` field.
class StatusBadgeWithLabel extends StatelessWidget {
  const StatusBadgeWithLabel({
    super.key,
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = _palette(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: p.fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PillPalette {
  const _PillPalette({
    required this.fg,
    required this.bg,
    required this.label,
  });
  final Color fg;
  final Color bg;
  final String label;
}

_PillPalette _palette(String status) {
  switch (status) {
    case 'DONE':
      return const _PillPalette(
        fg: Color(0xFF27500A),
        bg: Color(0xFFEFF5E6),
        label: 'Done',
      );
    case 'DUE_NOW':
      return const _PillPalette(
        fg: Color(0xFFB52C2B),
        bg: Color(0xFFFEEBEB),
        label: 'Due now',
      );
    case 'DUE_WINDOW_OPEN':
      return const _PillPalette(
        fg: Color(0xFF854F0B),
        bg: Color(0xFFFFF1DD),
        label: 'Due window open',
      );
    case 'DUE_SOON':
      return const _PillPalette(
        fg: Color(0xFF854F0B),
        bg: Color(0xFFFFF1DD),
        label: 'Due soon',
      );
    case 'OVERDUE':
      return const _PillPalette(
        fg: Color(0xFFB52C2B),
        bg: Color(0xFFFEEBEB),
        label: 'Overdue',
      );
    case 'UPCOMING':
      return const _PillPalette(
        fg: Color(0xFF555555),
        bg: Color(0xFFEDEDED),
        label: 'Upcoming',
      );
    case 'ACTIVE':
      return const _PillPalette(
        fg: Color(0xFF854F0B),
        bg: Color(0xFFFFF1DD),
        label: 'Active',
      );
    case 'IMPROVING':
      return const _PillPalette(
        fg: Color(0xFF105D5C),
        bg: Color(0xFFE6F1F0),
        label: 'Improving',
      );
    case 'RECOVERED':
      return const _PillPalette(
        fg: Color(0xFF27500A),
        bg: Color(0xFFEFF5E6),
        label: 'Recovered',
      );
    case 'CANCELLED':
      return const _PillPalette(
        fg: Color(0xFF555555),
        bg: Color(0xFFEDEDED),
        label: 'Cancelled',
      );
    default:
      return _PillPalette(
        fg: const Color(0xFF555555),
        bg: const Color(0xFFEDEDED),
        label: status,
      );
  }
}
