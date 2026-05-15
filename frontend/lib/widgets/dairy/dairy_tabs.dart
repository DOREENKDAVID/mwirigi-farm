import 'package:flutter/material.dart';

/// Pill-style tab navigation for the Dairy Unit page. Mirrors the
/// layers `SectionTabs` pattern so the overall app feels consistent —
/// users see the same horizontal pill row across modules.
///
/// Each tab is a pill button: tap to swap the body content. The
/// selected pill fills with the primary color, others stay outlined.
///
/// Designed to be placed under the page's KPI row; the KPIs stay
/// pinned (always-visible context) while only the body below the
/// tabs swaps.
enum DairyTab {
  overview('Overview'),
  milk('Milk'),
  houses('Houses'),
  cows('Cows'),
  reproduction('Reproduction'),
  calves('Calves'),
  vaccination('Vaccination'),
  reminders('Reminders'),
  inventory('Inventory'),
  dailyMilk('Daily milk');

  const DairyTab(this.label);
  final String label;
}

class DairyPillTabs extends StatelessWidget {
  const DairyPillTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final DairyTab selected;
  final ValueChanged<DairyTab> onSelect;

  static const _primary = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    // Horizontally scrollable on small screens — wrapping pills break
    // the visual grouping, so we let it scroll instead.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in DairyTab.values) ...[
            _Pill(
              label: t.label,
              selected: selected == t,
              onTap: () => onSelect(t),
            ),
            if (t != DairyTab.values.last) const SizedBox(width: 8),
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
    final bg = selected ? DairyPillTabs._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? DairyPillTabs._primary
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
