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

// Group keys — also used as the open/closed state map keys.
const _gCore = 'CORE';
const _gAnimals = 'ANIMALS';
const _gOperations = 'OPERATIONS';
const _gReports = 'REPORTS';
const _gFinance = 'FINANCE';
const _gStaff = 'STAFF';

const List<_NavItem> _items = [
  _NavItem(FarmSection.overview, Icons.dashboard_outlined, 'Overview (CEO)', _gCore, emoji: '📊'),
  _NavItem(FarmSection.dairy, Icons.water_drop_outlined, 'Dairy', _gAnimals, emoji: '🐄'),
  _NavItem(FarmSection.layers, Icons.egg_outlined, 'Layers', _gAnimals, emoji: '🥚'),
  _NavItem(FarmSection.piggery, Icons.pets_outlined, 'Piggery', _gAnimals, emoji: '🐷'),
  _NavItem(FarmSection.feedlot, Icons.grass_outlined, 'Feedlot', _gAnimals, emoji: '🐂'),
  _NavItem(FarmSection.feeds, Icons.inventory_2_outlined, 'Feeds', _gOperations, emoji: '🌾'),
  _NavItem(FarmSection.health, Icons.medical_services_outlined, 'Health', _gOperations, emoji: '💉'),
  _NavItem(FarmSection.ngushish, Icons.eco_outlined, 'Ngushish', _gOperations, emoji: '🥕'),
  _NavItem(FarmSection.reminders, Icons.notifications_outlined, 'Reminders', _gOperations, emoji: '🔔'),
  _NavItem(FarmSection.reports, Icons.description_outlined, 'Reports', _gReports, emoji: '📊'),
  _NavItem(FarmSection.finance, Icons.payments_outlined, 'Finance', _gFinance, emoji: '💰'),
  _NavItem(FarmSection.staff, Icons.groups_outlined, 'Staff', _gStaff, emoji: '👨‍🌾'),
];

class AppDrawer extends StatefulWidget {
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
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Group expand/collapse state. Core is always open (single item).
  // Animals starts open since it's the most-used group. Operations,
  // Reports, Finance, Staff start collapsed to reduce visual clutter
  // on a mobile drawer.
  final Map<String, bool> _open = {
    _gCore: true,
    _gAnimals: true,
    _gOperations: false,
    _gReports: false,
    _gFinance: false,
    _gStaff: false,
  };

  @override
  void initState() {
    super.initState();
    _ensureSelectedVisible();
  }

  @override
  void didUpdateWidget(covariant AppDrawer old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _ensureSelectedVisible();
  }

  /// Auto-expand the group that contains the currently-selected
  /// section so the user never opens the drawer to find the active
  /// item hidden behind a collapsed header.
  void _ensureSelectedVisible() {
    final group = _items
        .firstWhere(
          (i) => i.section == widget.selected,
          orElse: () => _items.first,
        )
        .group;
    if (_open[group] != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _open[group] = true);
      });
    }
  }

  Map<String, List<_NavItem>> _grouped() {
    final out = <String, List<_NavItem>>{};
    for (final item in _items) {
      out.putIfAbsent(item.group, () => []).add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    final groups = _grouped();

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
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final group in groups.entries)
                  _GroupSection(
                    title: group.key,
                    items: group.value,
                    selected: widget.selected,
                    // Single-item groups (Core, Reports, Finance,
                    // Staff) skip the collapse affordance — there's
                    // nothing to hide. They must always render their
                    // tile regardless of the _open[] default so the
                    // single nav item stays clickable.
                    collapsible: group.value.length > 1,
                    expanded: group.value.length <= 1
                        ? true
                        : (_open[group.key] ?? true),
                    onToggle: () {
                      setState(() {
                        _open[group.key] = !(_open[group.key] ?? false);
                      });
                    },
                    onSelect: (s) {
                      widget.onSelect(s);
                      // Only dismiss when used as a slide-out drawer;
                      // the embedded tablet sidebar stays mounted.
                      if (!widget.embedded) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Container(color: primary, child: body);
    }
    return Drawer(backgroundColor: primary, child: body);
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.title,
    required this.items,
    required this.selected,
    required this.collapsible,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final String title;
  final List<_NavItem> items;
  final FarmSection selected;
  final bool collapsible;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<FarmSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final header = InkWell(
      onTap: collapsible ? onToggle : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0x99FFFFFF),
                ),
              ),
            ),
            if (collapsible)
              AnimatedRotation(
                turns: expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.expand_more,
                  size: 16,
                  color: Color(0x99FFFFFF),
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items)
                      _NavTile(
                        item: item,
                        active: item.section == selected,
                        onTap: () => onSelect(item.section),
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
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
