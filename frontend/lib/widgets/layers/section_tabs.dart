import 'package:flutter/material.dart';

import '../../core/models/layers.dart' as legacy;
import '../../core/models/layers_unit.dart';
import '../../core/service/api_service.dart';
import 'allocation_plan.dart';
import 'brooder_house_card.dart';
import 'daily_entry_form.dart';
import 'eggs_tab_section.dart';
import 'last_7_days_table.dart';
import 'layer_house_card.dart';
import 'layers_inventory_card.dart';
import 'layers_pill_tabs.dart';
import 'layers_production_analytics_card.dart';
import '../reminders/unit_reminders_card.dart';
import 'seven_day_chart.dart';
import 'vaccination_timeline.dart';

/// Pill-driven section navigation for the Layers Unit page. Mirrors
/// the Dairy pill pattern — KPI strip stays pinned above, each pill
/// swaps the body content inline (no bounded TabBarView), and the
/// Overview pill stays light so it doesn't dominate mobile screens.
///
/// Pills:
///   Overview     — 7-day chart + houses table (compact)
///   Brooder      — full brooder card (mini-KPIs + progress + timeline + allocation)
///   Houses       — layer houses table at full width
///   Production   — 7-day chart + last-7-days table + daily-entry form
///   Vaccination  — vaccination timeline standalone
///   Allocation   — allocation plan standalone
///
/// `onSubmittedDailyEntry` propagates the daily-entry form's success back
/// to the parent so it can refresh the unit fetch.
class LayersSectionTabs extends StatefulWidget {
  const LayersSectionTabs({
    super.key,
    required this.unit,
    required this.history,
    required this.onSubmittedDailyEntry,
  });

  final LayersUnit unit;
  final legacy.ProductionHistory? history;
  final VoidCallback onSubmittedDailyEntry;

  @override
  State<LayersSectionTabs> createState() => _LayersSectionTabsState();
}

class _LayersSectionTabsState extends State<LayersSectionTabs> {
  LayersTab _active = LayersTab.overview;

  /// Fetches the production history for a single house and opens the
  /// DailyEntryForm in a modal bottom sheet. Replaces the form that
  /// used to live under the Production pill — now any house can be
  /// logged directly from its card.
  Future<void> _openDailyEntryFor(LayerHouseView view) async {
    final house = legacy.LayerHouse(
      id: view.id,
      name: view.name,
      capacity: view.capacity,
      color: view.color,
    );

    // Show a loading sheet while the API resolves so the user gets
    // immediate visual feedback even on slow links.
    final messenger = ScaffoldMessenger.of(context);
    List<legacy.LayerProduction> records;
    try {
      final raw = await ApiService.getLayersProductionForHouse(view.id);
      final history = legacy.ProductionHistory.fromJson(
        raw.cast<String, dynamic>(),
      );
      records = history.records;
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not load production history: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F4F0),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  DailyEntryForm(
                    house: house,
                    records: records,
                    onSubmitted: () {
                      Navigator.of(sheetCtx).pop();
                      widget.onSubmittedDailyEntry();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayersPillTabs(
          selected: _active,
          onSelect: (t) => setState(() => _active = t),
        ),
        const SizedBox(height: 16),
        ..._body(),
      ],
    );
  }

  List<Widget> _body() {
    final unit = widget.unit;
    switch (_active) {
      case LayersTab.overview:
        // Light overview: chart + house cards. The brooder card
        // (heaviest section) lives behind the Brooder pill so phones
        // don't have to scroll past it on first paint.
        return [
          SevenDayChart(points: unit.production),
          const SizedBox(height: 16),
          LayerHousesGrid(houses: unit.layers.houses, compact: true),
        ];
      case LayersTab.eggs:
        return [
          EggsTabSection(
            unit: unit,
            history: widget.history,
            onChanged: widget.onSubmittedDailyEntry,
          ),
        ];
      case LayersTab.brooder:
        final brooder = unit.brooder;
        if (brooder == null) {
          return const [
            _EmptyTab(
              icon: Icons.egg_outlined,
              message: 'No active brooder batch.',
            ),
          ];
        }
        return [
          BrooderHouseCard(
            brooder: brooder,
            vaccination: unit.vaccination,
            allocation: unit.allocation,
            onChanged: widget.onSubmittedDailyEntry,
          ),
        ];
      case LayersTab.houses:
        if (unit.layers.houses.isEmpty) {
          return const [
            _EmptyTab(
              icon: Icons.home_outlined,
              message: 'No layer houses configured.',
            ),
          ];
        }
        return [
          LayerHousesGrid(
            houses: unit.layers.houses,
            // Tapping a house's "Log entry" button opens the daily
            // entry form for THAT house. We fetch the house-specific
            // production history on demand and open the form in a
            // modal sheet.
            onLogEntry: _openDailyEntryFor,
          ),
        ];
      case LayersTab.production:
        // Period-scoped analytics is the primary surface here; the
        // legacy 7-day chart + last-7-days table sit below as a
        // pinned quick-glance / historical drill-down.
        return [
          const LayersProductionAnalyticsCard(),
          const SizedBox(height: 18),
          SevenDayChart(points: unit.production),
          const SizedBox(height: 16),
          if (widget.history != null)
            Last7DaysTable(
              houseName: widget.history!.house.name,
              records: widget.history!.records,
            ),
        ];
      case LayersTab.vaccination:
        if (unit.vaccination.isEmpty) {
          return const [
            _EmptyTab(
              icon: Icons.vaccines_outlined,
              message: 'No vaccination protocol available.',
            ),
          ];
        }
        return [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0x14000000)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'VACCINATION SCHEDULE (PER VET PROTOCOL)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                VaccinationTimeline(steps: unit.vaccination),
              ],
            ),
          ),
        ];
      case LayersTab.inventory:
        return const [LayersInventoryCard()];
      case LayersTab.reminders:
        return const [UnitRemindersCard(unit: 'Layers')];
      case LayersTab.allocation:
        if (unit.allocation.isEmpty) {
          return const [
            _EmptyTab(
              icon: Icons.swap_horiz_outlined,
              message: 'No allocation plan recorded yet.',
            ),
          ];
        }
        return [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0x14000000)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ALLOCATION PLAN WHEN CHICKS REACH 3 MONTHS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                // Pass the brooder id so the History + Revise action
                // pair shows up here too — without it the buttons hide
                // (they short-circuit on `canEdit = brooderId != null`).
                // When there's no active brooder cohort the plan is
                // still readable, just not editable from this pill.
                AllocationPlan(
                  rows: unit.allocation,
                  brooderId: unit.brooder?.id,
                ),
              ],
            ),
          ),
        ];
    }
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: const Color(0xFFAAAAAA)),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
