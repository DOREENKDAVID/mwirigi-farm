import 'package:flutter/material.dart';

/// Pill-style tab navigation for the Layers Unit page. Mirrors the
/// Dairy `DairyPillTabs` so the cross-module experience feels uniform —
/// users see the same horizontal pill row across modules.
///
/// Each tab swaps the body content below the pills inline (no fixed
/// TabBarView height), which plays better on mobile where the heavy
/// brooder/houses sections would otherwise dominate the first screen.
enum LayersTab {
  overview('Overview'),
  eggs('Eggs'),
  brooder('Brooder'),
  houses('Houses'),
  production('Production'),
  sales('💰 Sales'),
  vaccination('Vaccination'),
  reminders('Reminders'),
  inventory('Inventory'),
  allocation('Allocation');

  const LayersTab(this.label);
  final String label;
}

class LayersPillTabs extends StatelessWidget {
  const LayersPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final LayersTab selected;
  final ValueChanged<LayersTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in LayersTab.values) ...[
            _Pill(
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != LayersTab.values.last) const SizedBox(width: 8),
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
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? LayersPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? LayersPillTabs._primary
        : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}
