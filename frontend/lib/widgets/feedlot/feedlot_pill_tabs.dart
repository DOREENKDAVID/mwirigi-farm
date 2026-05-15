import 'package:flutter/material.dart';

/// Pill-style tab navigation for the Feedlot & Doopers page. Mirrors
/// the Dairy / Layers / Staff / Feeds pill pattern.
///
/// Pills (in display order, matching the v4.2 mockup):
///   • Overview     — KPIs · capacity progress · glance at bulls/doopers
///   • Bulls        — full feedlot tag registry (SOP rules preserved)
///   • Doppers      — sheep flock register
///   • Health       — vaccinations · deworming · treatments (deferred v1)
///   • Feeding      — ration types · cost trends (deferred v1)
///   • Breeding     — sire / dam / conception (deferred v1)
///   • Inventory    — feed / meds / equipment (deferred v1)
///   • Weights      — ADG · growth charts (deferred v1)
///   • Sales        — buyers · prices · profit (deferred v1)
///   • Reports      — printable PDF / CSV (deferred v1)
///   • Observations — pinned notes · priorities (deferred v1)
enum FeedlotTab {
  overview('Overview', '📊'),
  bulls('Bulls', '🐂'),
  doppers('Doppers', '🐑'),
  health('Health', '💉'),
  feeding('Feeding', '🌾'),
  breeding('Breeding', '🧬'),
  inventory('Inventory', '📦'),
  weights('Weights', '⚖️'),
  sales('Sales', '💰'),
  reports('Reports', '📄'),
  observations('Observations', '📝');

  const FeedlotTab(this.label, this.emoji);
  final String label;
  final String emoji;
}

class FeedlotPillTabs extends StatelessWidget {
  const FeedlotPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final FeedlotTab selected;
  final ValueChanged<FeedlotTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in FeedlotTab.values) ...[
            _Pill(
              emoji: t.emoji,
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != FeedlotTab.values.last) const SizedBox(width: 8),
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
    final bg = selected ? FeedlotPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? FeedlotPillTabs._primary
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
