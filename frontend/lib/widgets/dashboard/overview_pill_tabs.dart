import 'package:flutter/material.dart';

/// Pill-style tab navigation for the CEO Overview page. Mirrors the
/// Dairy / Layers / Feedlot / Piggery pill pattern.
///
///   • Snapshot  — compact Goals + Alerts roll-up (the CEO's daily glance)
///   • Goals     — full 5-year goal progress bars
///   • Alerts    — upcoming & overdue from active protocols
///   • Trends    — 7-day milk trend (egg + piglet trends added later)
///   • Units     — per-unit performance snapshot table
enum OverviewTab {
  snapshot('Snapshot', '📊'),
  goals('Goals', '🎯'),
  alerts('Alerts', '🔔'),
  trends('Trends', '📈'),
  units('Units', '🏠');

  const OverviewTab(this.label, this.emoji);
  final String label;
  final String emoji;
}

class OverviewPillTabs extends StatelessWidget {
  const OverviewPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final OverviewTab selected;
  final ValueChanged<OverviewTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in OverviewTab.values) ...[
            _Pill(
              emoji: t.emoji,
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != OverviewTab.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? OverviewPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border =
        selected ? OverviewPillTabs._primary : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A27500A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
