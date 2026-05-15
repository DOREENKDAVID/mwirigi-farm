import 'package:flutter/material.dart';

/// Pill-style tab navigation for the Piggery page. Mirrors the Dairy /
/// Layers / Feedlot pill pattern.
///
/// 18 sections from the v4.2 mockup. Pills marked "(stub)" in the
/// piggery page show pointer cards into other modules or "coming soon"
/// placeholders pending v2 backend wiring.
enum PiggeryTab {
  overview('Overview', '📊'),
  houses('Houses', '🏠'),
  sows('Sows', '🐖'),
  boars('Boars', '🐗'),
  litters('Litters', '👶'),
  nursery('Nursery', '🍼'),
  fattening('Fattening', '⚖️'),
  finishing('Finishing', '⚡'),
  breeding('Breeding', '🧬'),
  farrowing('Farrowing', '📋'),
  health('Health', '💉'),
  vaccination('Vaccination', '🩹'),
  feed('Feed', '🌾'),
  inventory('Inventory', '📦'),
  staff('Staff', '👥'),
  reports('Reports', '📄'),
  observations('Observations', '📝'),
  settings('Settings', '⚙️');

  const PiggeryTab(this.label, this.emoji);
  final String label;
  final String emoji;
}

class PiggeryPillTabs extends StatelessWidget {
  const PiggeryPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final PiggeryTab selected;
  final ValueChanged<PiggeryTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in PiggeryTab.values) ...[
            _Pill(
              emoji: t.emoji,
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != PiggeryTab.values.last) const SizedBox(width: 8),
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
    final bg = selected ? PiggeryPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border =
        selected ? PiggeryPillTabs._primary : const Color(0x33000000);
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
