import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Identifiers for the 10 top-level sections shown in the sidebar.
///
/// Kept as an enum (not raw ints) so the body switcher in MainScreen
/// stays exhaustive when new sections are added.
enum FarmSection {
  overview,
  dairy,
  piggery,
  layers,
  feedlot,
  feeds,
  health,
  ngushish,
  reminders,
  reports,
  finance,
  staff,
}

class _NavItem {
  const _NavItem(this.section, this.icon, this.label, this.group, {this.emoji});
  final FarmSection section;
  final IconData icon;
  final String label;
  final String group;
  // When set, the drawer renders this emoji instead of [icon].
  final String? emoji;
}

/// Human-readable label for the AppBar title. Exposed as a top-level helper
/// so MainScreen and any future caller share one source of truth.
String farmSectionTitle(FarmSection s) {
  switch (s) {
    case FarmSection.overview:
      return 'CEO Overview';
    case FarmSection.dairy:
      return 'Dairy Unit';
    case FarmSection.piggery:
      return 'Piggery Unit';
    case FarmSection.layers:
      return 'Layers Unit';
    case FarmSection.feedlot:
      return 'Feedlot & Doopers';
    case FarmSection.feeds:
      return 'Feeds Management';
    case FarmSection.health:
      return 'Health & Vaccines';
    case FarmSection.ngushish:
      return 'Ngushish Farm';
    case FarmSection.reminders:
      return 'Reminders';
    case FarmSection.reports:
      return 'Reports & Exports';
    case FarmSection.finance:
      return 'Financial Dashboard';
    case FarmSection.staff:
      return 'Staff & Labour';
  }
}

const List<_NavItem> _items = [
  _NavItem(FarmSection.overview, Icons.dashboard_outlined, 'Overview (CEO)', 'Core', emoji: '📊'),
  _NavItem(FarmSection.dairy, Icons.water_drop_outlined, 'Dairy', 'Core', emoji: '🐄'),
  _NavItem(FarmSection.layers, Icons.egg_outlined, 'Layers', 'Core', emoji: '🥚'),
  _NavItem(FarmSection.piggery, Icons.pets_outlined, 'Piggery', 'Core', emoji: '🐷'),
  _NavItem(FarmSection.feedlot, Icons.grass_outlined, 'Feedlot', 'Core', emoji: '🐂'),
  _NavItem(FarmSection.feeds, Icons.inventory_2_outlined, 'Feeds', 'Operations', emoji: '🌾'),
  _NavItem(FarmSection.health, Icons.medical_services_outlined, 'Health', 'Operations', emoji: '💉'),
  _NavItem(FarmSection.ngushish, Icons.eco_outlined, 'Ngushish', 'Operations', emoji: '🥕'),
  _NavItem(FarmSection.reminders, Icons.notifications_outlined, 'Reminders', 'Operations', emoji: '🔔'),
  _NavItem(FarmSection.reports, Icons.description_outlined, 'Reports', 'Reports', emoji: '📊'),
  _NavItem(FarmSection.finance, Icons.payments_outlined, 'Finance', 'Reports', emoji: '💰'),
  _NavItem(FarmSection.staff, Icons.groups_outlined, 'Staff', 'Reports', emoji: '👨‍🌾'),
];

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    this.embedded = false,
  });

  final FarmSection selected;
  final ValueChanged<FarmSection> onSelect;
  /// When true the drawer renders as a permanent sidebar (no Drawer
  /// chrome, no Navigator.pop on tap). Used by the tablet layout in
  /// MainScreen.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

    final groups = <String, List<_NavItem>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }

    final Widget body = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            color: Colors.white,
            alignment: Alignment.centerLeft,
            child: const BrandLogo(height: 56, maxWidth: 220),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Text(
              'Farm Management System',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFB8C8A8),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                for (final group in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 16, 6),
                    child: Text(
                      group.key.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Color(0x80FFFFFF),
                      ),
                    ),
                  ),
                  for (final item in group.value)
                    _NavTile(
                      item: item,
                      active: item.section == selected,
                      onTap: () {
                        onSelect(item.section);
                        // Only dismiss when used as a slide-out drawer;
                        // the embedded tablet sidebar stays mounted.
                        if (!embedded) Navigator.of(context).pop();
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return Container(color: primary, child: body);
    }
    return Drawer(backgroundColor: primary, child: body);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: active ? const Color(0x33FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0x33FFFFFF)
                        : const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: item.emoji != null
                      ? Text(
                          item.emoji!,
                          style: const TextStyle(fontSize: 15, height: 1),
                        )
                      : Icon(item.icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? Colors.white
                          : const Color(0xCCFFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
