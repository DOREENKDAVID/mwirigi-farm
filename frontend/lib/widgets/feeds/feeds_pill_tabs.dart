import 'package:flutter/material.dart';

/// Pill-style tab navigation for the Feeds Management page. Mirrors
/// the Dairy / Layers / Staff pill pattern — same green-pill row,
/// horizontal scroll, 150 ms transition.
///
/// Pills (in display order, matching the v4.2 mockup):
///   • Overview      — KPIs · alerts · quick actions · light previews
///   • Raw Materials — full raw-material inventory (search · status · CRUD)
///   • Deliveries    — dedicated deliveries management (placeholder v1)
///   • Factory       — feed production batches (placeholder v1)
///   • Bulk Feed     — silage / Napier / maize-for-silage cards
///   • Distribution  — per-unit daily feed allocation cards
///   • Inventory     — feeds-factory warehouse inventory (placeholder v1)
///   • Analytics     — trend / cost / depletion charts (placeholder v1)
enum FeedsTab {
  overview('Overview', '🌾'),
  rawMaterials('Raw Materials', '📦'),
  deliveries('Deliveries', '🚚'),
  factory('Factory', '🏭'),
  bulk('Bulk Feed', '🌱'),
  distribution('Distribution', '🐄'),
  inventory('Inventory', '📂'),
  analytics('Analytics', '📊');

  const FeedsTab(this.label, this.emoji);
  final String label;
  final String emoji;
}

class FeedsPillTabs extends StatelessWidget {
  const FeedsPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final FeedsTab selected;
  final ValueChanged<FeedsTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in FeedsTab.values) ...[
            _Pill(
              emoji: t.emoji,
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != FeedsTab.values.last) const SizedBox(width: 8),
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
    final bg = selected ? FeedsPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? FeedsPillTabs._primary
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
