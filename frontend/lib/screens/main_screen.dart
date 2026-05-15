import 'package:flutter/material.dart';

import '../core/util/responsive.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dairy/dairy_page.dart';
import '../widgets/dashboard/overview_page.dart';
import '../widgets/feedlot/feedlot_page.dart';
import '../widgets/feeds/feeds_page.dart';
import '../widgets/finance/finance_page.dart';
import '../widgets/health/health_page.dart';
import '../widgets/layers/layers_page.dart';
import '../widgets/ngushish/ngushish_page.dart';
import '../widgets/piggery/piggery_page.dart';
import '../widgets/reminders/reminders_page.dart';
import '../widgets/reports/reports_page.dart';
import '../widgets/staff/staff_page.dart';
import '../widgets/top_bar.dart';

/// Top-level shell shown after login.
///
/// Holds: a left Drawer (FarmSection list), a custom top bar (FarmTopBar),
/// and a body that swaps based on the selected section. Other modules
/// (Dairy / Piggery / Layers / etc.) currently render a "Coming soon"
/// placeholder — only Overview is wired in this phase.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  FarmSection _selected = FarmSection.overview;
  bool _simulating = false;

  void _handleSelect(FarmSection s) {
    if (s == _selected) return;
    setState(() => _selected = s);
  }

  void _toggleSimulate() {
    // UI-only at this phase. Wired up so the button shows feedback;
    // real simulation logic belongs in a later session once trend
    // endpoints exist on the backend.
    setState(() => _simulating = !_simulating);
  }

  @override
  Widget build(BuildContext context) {
    // On tablets and larger, render the drawer as a permanent left
    // sidebar (NavigationRail-style) rather than a slide-out drawer.
    // Mobile keeps the slide-out drawer accessible via the AppBar
    // hamburger.
    final wide = isTabletForm(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: FarmTopBar(
        title: farmSectionTitle(_selected),
        simulating: _simulating,
        onToggleSimulate: _toggleSimulate,
        // Hide the hamburger menu when the sidebar is permanent.
        showMenuButton: !wide,
      ),
      drawer: wide
          ? null
          : AppDrawer(
              selected: _selected,
              onSelect: _handleSelect,
            ),
      body: SafeArea(
        top: false, // AppBar already accounts for the status bar.
        child: wide
            ? Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: AppDrawer(
                      selected: _selected,
                      onSelect: _handleSelect,
                      embedded: true,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0x14000000)),
                  Expanded(child: _bodyFor(_selected)),
                ],
              )
            : _bodyFor(_selected),
      ),
    );
  }

  Widget _bodyFor(FarmSection s) {
    switch (s) {
      case FarmSection.overview:
        return const OverviewPage();
      case FarmSection.dairy:
        return const DairyPage();
      case FarmSection.layers:
        return const LayersPage();
      case FarmSection.piggery:
        return const PiggeryPage();
      case FarmSection.feedlot:
        return const FeedlotPage();
      case FarmSection.staff:
        return const StaffPage();
      case FarmSection.health:
        return const HealthPage();
      case FarmSection.ngushish:
        return const NgushishPage();
      case FarmSection.feeds:
        return const FeedsPage();
      case FarmSection.reminders:
        return const RemindersPage();
      case FarmSection.reports:
        return const ReportsPage();
      case FarmSection.finance:
        return const FinancePage();
    }
  }
}
