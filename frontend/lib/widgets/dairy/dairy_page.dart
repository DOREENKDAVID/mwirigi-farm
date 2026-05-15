import 'package:flutter/material.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/models/dairy_summary.dart';
import '../../core/service/api_service.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import 'calves_register_card.dart';
import 'cow_records_table.dart';
import 'daily_milk_trend_card.dart';
import 'dairy_day_totals_card.dart';
import 'dairy_inventory_card.dart';
import 'dairy_tabs.dart';
import 'dairy_vaccination_card.dart';
import '../reminders/unit_reminders_card.dart';
import 'houses_overview_grid.dart';
import 'milk_logging_panel.dart';
import 'reproduction_tracker.dart';

/// Dairy module body shown by MainScreen when FarmSection.dairy is selected.
///
/// Sections (top to bottom):
///   - Unit header with Log Milk button
///   - 4 KPI cards (totalCows / milkingToday / milkToday / avgPerCow)
///   - Cow records card + 7-day trend (placeholder; backend endpoint pending)
///   - Reproduction tracker (placeholder; no schema yet)
class DairyPage extends StatefulWidget {
  const DairyPage({super.key});

  @override
  State<DairyPage> createState() => _DairyPageState();
}

class _DairyData {
  _DairyData({
    required this.summary,
    required this.workers,
    required this.houses,
  });
  final DairySummary summary;
  final List<DairyWorkerSummary> workers;
  final List<DairyHouseOverview> houses;
}

class _DairyPageState extends State<DairyPage> {
  Future<_DairyData>? _future;

  // Filter state lives at the page level so the houses grid, the cow
  // records table, and the milk-logging cow grid stay in sync.
  // null = "All" (no filter active for that category).
  String? _houseFilterId;
  String? _workerFilterId;

  final _milkPanelKey = GlobalKey<MilkLoggingPanelState>();
  final _housesGridKey = GlobalKey<HousesOverviewCardState>();
  final _cowRecordsKey = GlobalKey<CowRecordsTableState>();

  // Active pill tab. Defaults to Overview which combines the houses
  // grid + milk-logging panel — the most common daily view.
  DairyTab _activeTab = DairyTab.overview;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DairyData> _load() async {
    // Three parallel requests: summary KPIs, the worker list (drives
    // the worker pills + register dialog dropdown), and the houses
    // overview (drives the house pills + the houses grid).
    final summaryFuture = ApiService.getDairySummary();
    final workersFuture = ApiService.getDairyWorkers();
    final housesFuture = ApiService.getDairyHousesOverview();

    final summary = DairySummary.fromJson(
      (await summaryFuture).cast<String, dynamic>(),
    );
    final workers = (await workersFuture)
        .whereType<Map>()
        .map((m) => DairyWorkerSummary.fromJson(m.cast<String, dynamic>()))
        .toList();
    final houses = (await housesFuture)
        .whereType<Map>()
        .map((m) => DairyHouseOverview.fromJson(m.cast<String, dynamic>()))
        .toList();

    return _DairyData(summary: summary, workers: workers, houses: houses);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  // Filter handlers — kept independent so "All" on one category doesn't
  // wipe the other (matches the v4.1 HTML behavior exactly).
  void _setHouseFilter(String? id) =>
      setState(() => _houseFilterId = id);
  void _setWorkerFilter(String? id) =>
      setState(() => _workerFilterId = id);

  // Body widgets per tab. Each tab returns a flat list so the parent
  // ListView can spread them inline. Overview is the "everything in
  // one scroll" view; the others are focused drill-downs.
  List<Widget> _tabBody(_DairyData data) {
    Widget housesGrid({Key? key, bool jumpToHousesPill = false}) =>
        HousesOverviewCard(
          key: key ?? _housesGridKey,
          selectedHouseId: _houseFilterId,
          // Tapping a house card mirrors into the page's house filter.
          // CowRecordsTable + MilkLoggingPanel both observe it.
          onSelect: _setHouseFilter,
          // From the Overview tab, tapping a house jumps to the Houses
          // pill so the cow list comes into view (otherwise the user
          // wouldn't see the effect of the filter from this tab).
          onCardTap: jumpToHousesPill
              ? (_) => setState(() => _activeTab = DairyTab.houses)
              : null,
        );

    Widget milkPanel() => MilkLoggingPanel(
          key: _milkPanelKey,
          houseFilterId: _houseFilterId,
          houses: data.houses,
          onChanged: () async {
            await _refresh();
            await _housesGridKey.currentState?.reload();
          },
        );

    Widget cowRecords() => CowRecordsTable(
          key: _cowRecordsKey,
          workers: data.workers,
          houses: data.houses,
          selectedWorkerId: _workerFilterId,
          selectedHouseId: _houseFilterId,
          onWorkerSelect: _setWorkerFilter,
          onHouseSelect: _setHouseFilter,
          onChanged: _refresh,
        );

    switch (_activeTab) {
      case DairyTab.overview:
        // Light, mobile-first overview: chart → day totals → houses.
        // Heavy sections (full milk-logging panel, cow records, calves,
        // inventory, vaccinations, reproduction) live behind their own
        // pills to reduce vertical clutter on phones.
        return [
          const DailyMilkTrendCard(),
          const SizedBox(height: 16),
          const DairyDayTotalsCard(),
          const SizedBox(height: 16),
          housesGrid(jumpToHousesPill: true),
        ];
      case DairyTab.milk:
        return [milkPanel()];
      case DairyTab.houses:
        return [
          housesGrid(),
          const SizedBox(height: 16),
          cowRecords(),
        ];
      case DairyTab.cows:
        return [cowRecords()];
      case DairyTab.reproduction:
        return const [ReproductionTracker()];
      case DairyTab.calves:
        return const [CalvesRegisterCard()];
      case DairyTab.vaccination:
        return const [DairyVaccinationCard()];
      case DairyTab.reminders:
        return const [UnitRemindersCard(unit: 'Dairy')];
      case DairyTab.inventory:
        return const [DairyInventoryCard()];
      case DairyTab.dailyMilk:
        return const [DailyMilkTrendCard()];
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_DairyData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 36,
                      color: Color(0xFF854F0B),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              const _UnitHeader(),
              const SizedBox(height: 16),
              _KpiRow(summary: data.summary),
              const SizedBox(height: 16),
              // Pill-tab nav. KPIs above stay pinned; only the body
              // below the tabs swaps based on the active pill.
              DairyPillTabs(
                selected: _activeTab,
                onSelect: (t) => setState(() => _activeTab = t),
              ),
              const SizedBox(height: 16),
              ..._tabBody(data),
            ],
          );
        },
      ),
    );
  }
}

//////////////////////////////////////////////////////
// Unit header
//////////////////////////////////////////////////////

class _UnitHeader extends StatelessWidget {
  const _UnitHeader();

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3DE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🐄', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dairy Unit',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Cow records · milk sessions',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        // Log Milk lives inside the milk-logging workflow (Milk pill);
        // Report sick lives under Cow records — see CowRecordsTable.
      ],
    );
  }
}

//////////////////////////////////////////////////////
// KPI row
//////////////////////////////////////////////////////

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.summary});
  final DairySummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      KpiCard(
        label: 'Total herd',
        value: '${summary.totalCows}',
        sub: 'Registered cows',
      ),
      KpiCard(
        label: 'Milking today',
        value: '${summary.milkingToday}',
        sub: 'Active lactation',
      ),
      KpiCard(
        label: 'Litres today',
        value: '${_fmtNum(summary.milkToday)} L',
        sub: 'Across all sessions',
      ),
      KpiCard(
        label: 'Avg per cow',
        value: '${_fmtNum(summary.avgPerCow)} L',
        sub: 'Per milking cow',
      ),
    ];

    return KpiGrid(children: cards);
  }

  static String _fmtNum(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(1);
  }
}

