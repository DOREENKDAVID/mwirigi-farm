// =====================================================================
// PeriodFilterPanel — shared time-period selector
// =====================================================================
//
// Reusable filter card used by CEO Overview, Layers production views,
// the Dairy milk panel, and any future analytics surface. One widget,
// one wire-format (matches `backend/src/utils/period.js`), so the
// same pill selection means the same window everywhere.
//
// Visual style is adapted from the dashboard-card screenshot the
// user shared: compact rounded card, label + icon header, wrap of
// pill buttons, active pill in farm-green. The dark theme of the
// reference was a layout/spacing reference — colours follow our
// existing farm-green palette to stay consistent with the rest of
// the app.
//
// Contract:
//   * Stateless. Parent owns the selection and rebuilds on change.
//   * `onChanged(PeriodPreset)` fires for every pill tap (incl. custom).
//   * `customStartDate` / `customEndDate` are required when the parent
//     wants to surface the custom range as the active selection.
//   * Tapping the `Custom` pill opens `showDateRangePicker`. The
//     panel calls `onCustomRangeSelected(start, end)` with the result,
//     then also emits `onChanged(custom)` so a single tap is enough.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/util/period.dart';

class PeriodFilterPanel extends StatelessWidget {
  const PeriodFilterPanel({
    super.key,
    required this.selectedPeriod,
    required this.onChanged,
    this.customStartDate,
    this.customEndDate,
    this.onCustomRangeSelected,
    this.compact = false,
    this.title = 'Period',
  });

  /// Active preset. Drives which pill is filled.
  final PeriodPreset selectedPeriod;

  /// Tap callback for every pill (including custom). The parent is
  /// expected to setState with the new value so the panel rebuilds.
  final ValueChanged<PeriodPreset> onChanged;

  /// Custom range, surfaced as the label inside the Custom pill when
  /// both are non-null and the active preset is `custom`.
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  /// Fired with the result of `showDateRangePicker` when the user picks
  /// a custom window. The parent should persist both dates AND set
  /// `selectedPeriod` to `PeriodPreset.custom` (the panel emits
  /// `onChanged(custom)` for you, so you only need to remember the
  /// dates).
  final void Function(DateTime start, DateTime end)? onCustomRangeSelected;

  /// When true, drops the title + icon header for tight layouts (e.g.
  /// nested inside a tab body that already has its own heading). Pill
  /// padding stays the same so tap targets don't shrink.
  final bool compact;

  /// Header text. Override for surfaces that want "Filter by date" or
  /// similar phrasing.
  final String title;

  // ── Palette ───────────────────────────────────────────────────────
  // Farm-green primary; soft-green active fill; calm card surface +
  // outline so the panel reads as a slot below the app bar, not a
  // primary surface.
  static const _primary    = Color(0xFF27500A);
  static const _activeBg   = Color(0xFF27500A);
  static const _activeFg   = Colors.white;
  static const _inactiveBg = Color(0xFFFFFFFF);
  static const _inactiveFg = Color(0xFF1F2D14);
  static const _border     = Color(0x14000000);
  static const _txt2       = Color(0xFF6B7770);
  static const _cardBg     = Color(0xFFF5F4F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 10 : 12,
        14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: _primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$title:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                _ActiveRangeBadge(
                  period: selectedPeriod,
                  customStart: customStartDate,
                  customEnd: customEndDate,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in PeriodPreset.values)
                _Pill(
                  label: _labelFor(p),
                  selected: selectedPeriod == p,
                  onTap: () => _handleTap(context, p),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _labelFor(PeriodPreset p) {
    if (p == PeriodPreset.custom &&
        customStartDate != null &&
        customEndDate != null) {
      final fmt = DateFormat('d MMM');
      return '${fmt.format(customStartDate!)} – ${fmt.format(customEndDate!)}';
    }
    return p.label;
  }

  Future<void> _handleTap(BuildContext context, PeriodPreset p) async {
    if (p != PeriodPreset.custom) {
      onChanged(p);
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
      initialDateRange:
          customStartDate != null && customEndDate != null
              ? DateTimeRange(start: customStartDate!, end: customEndDate!)
              : DateTimeRange(
                  start: now.subtract(const Duration(days: 30)),
                  end: now,
                ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _inactiveFg,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    onCustomRangeSelected?.call(picked.start, picked.end);
    onChanged(PeriodPreset.custom);
  }
}

// ─── Pill ─────────────────────────────────────────────────────────────

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
    final bg = selected
        ? PeriodFilterPanel._activeBg
        : PeriodFilterPanel._inactiveBg;
    final fg = selected
        ? PeriodFilterPanel._activeFg
        : PeriodFilterPanel._inactiveFg;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? PeriodFilterPanel._activeBg
                : const Color(0x22000000),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1F27500A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─── Right-aligned summary chip in the header row ──────────────────

class _ActiveRangeBadge extends StatelessWidget {
  const _ActiveRangeBadge({
    required this.period,
    this.customStart,
    this.customEnd,
  });
  final PeriodPreset period;
  final DateTime? customStart;
  final DateTime? customEnd;

  @override
  Widget build(BuildContext context) {
    final range = resolveRange(
      period: period,
      customStart: customStart,
      customEnd: customEnd,
    );
    return Flexible(
      child: Text(
        range.formattedRange(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: PeriodFilterPanel._txt2,
        ),
      ),
    );
  }
}
