import 'package:flutter/material.dart';

/// Pill-style tab navigation for the Ngushish page. Mirrors the
/// Dairy / Layers / Feedlot / Piggery / Health pill pattern.
///
/// Pills (in display order):
///   • Overview     — blocks tiles + crop portfolio + immediate actions
///   • Blocks       — full crop register with status filter + search
///   • Harvest      — harvest planner table (sorted by status + due date)
///   • Revenue      — estimated harvest value (financial projection)
///   • Inventory    — inputs · equipment · agrochemicals card
///   • Observations — recent field notes (placeholder)
enum NgushishTab {
  overview('Overview', '📊'),
  blocks('Blocks', '🌿'),
  harvest('Harvest', '🌾'),
  revenue('Revenue', '💰'),
  inventory('Inventory', '📦'),
  observations('Observations', '📝');

  const NgushishTab(this.label, this.emoji);
  final String label;
  final String emoji;
}

class NgushishPillTabs extends StatelessWidget {
  const NgushishPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final NgushishTab selected;
  final ValueChanged<NgushishTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in NgushishTab.values) ...[
            _Pill(
              emoji: t.emoji,
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != NgushishTab.values.last) const SizedBox(width: 8),
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
    final bg = selected ? NgushishPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? NgushishPillTabs._primary
        : const Color(0x33000000);
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
