// =====================================================================
// HouseFilterPills — shared house/scope selector
// =====================================================================
//
// Companion to [PeriodFilterPanel]. Renders a horizontally-scrolling
// row of pills: "All houses" + one pill per supplied house. Tapping
// the active pill clears the filter (back to "All"). Stateless —
// the parent owns the selected id and rebuilds on change. Matches
// the visual rhythm of the existing dairy / layers pill rows so the
// filter bar reads as a coherent group when stacked under a
// PeriodFilterPanel.

import 'package:flutter/material.dart';

/// Plain-data house tuple. The widget doesn't care which module the
/// row came from — Layers, Dairy, Piggery can all feed this.
class HouseFilterOption {
  const HouseFilterOption({
    required this.id,
    required this.label,
    this.emoji,
  });

  final String id;
  final String label;
  /// Optional leading emoji (e.g. 🤰 for Maternity). Renders inline
  /// before the label when present.
  final String? emoji;
}

class HouseFilterPills extends StatelessWidget {
  const HouseFilterPills({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onChanged,
    this.allLabel = 'All houses',
    this.compact = false,
  });

  /// House list — typically sourced from `/api/<module>/houses`.
  final List<HouseFilterOption> options;

  /// Active selection. `null` = "All houses".
  final String? selectedId;

  /// Tap callback. The widget already implements tap-active-to-reset:
  /// when the caller passes the same id that's currently selected, we
  /// emit `null` to clear instead. Parents just persist what they
  /// receive.
  final ValueChanged<String?> onChanged;

  /// Label for the "everything" pill. Override when the surface uses
  /// different terminology (e.g. "All layer houses").
  final String allLabel;

  /// Slightly tighter padding when nested below a PeriodFilterPanel.
  final bool compact;

  static const _activeBg   = Color(0xFF27500A);
  static const _activeFg   = Colors.white;
  static const _inactiveBg = Color(0xFFFFFFFF);
  static const _inactiveFg = Color(0xFF1F2D14);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
      child: Row(
        children: [
          _Pill(
            label: allLabel,
            selected: selectedId == null,
            onTap: () => onChanged(null),
          ),
          for (final h in options) ...[
            const SizedBox(width: 6),
            _Pill(
              label: h.label,
              emoji: h.emoji,
              selected: selectedId == h.id,
              // Tap-active-to-reset: if the user taps the pill that's
              // already active, the row clears back to "All". Saves a
              // separate clear button and matches the dairy module's
              // existing tap-toggle behaviour.
              onTap: () => onChanged(selectedId == h.id ? null : h.id),
            ),
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
    this.emoji,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? HouseFilterPills._activeBg
        : HouseFilterPills._inactiveBg;
    final fg = selected
        ? HouseFilterPills._activeFg
        : HouseFilterPills._inactiveFg;
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
                ? HouseFilterPills._activeBg
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
            ],
            Text(
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
          ],
        ),
      ),
    );
  }
}
