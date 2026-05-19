import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';
import '../dairy/report_sick_dialog.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import '../reminders/unit_reminders_card.dart';
import 'fc_dispatch_log_card.dart';
import 'log_farrowing_dialog.dart';
import 'monthly_piglet_chart.dart';
import 'piggery_entry_dialogs.dart';
import 'piggery_inventory_card.dart';
import 'piggery_pill_tabs.dart';
import 'sow_register_table.dart';

/// Piggery module — pill-driven layout matching Dairy / Layers / Feedlot.
///
/// Composition top → bottom:
///   • Unit header (icon · title · subtitle · Log Farrowing · Sick buttons)
///   • 4 KPI cards (pinned across pills)
///   • Pill row (18 sections — see PiggeryTab)
///   • Body for the active pill
class PiggeryPage extends StatefulWidget {
  const PiggeryPage({super.key});

  @override
  State<PiggeryPage> createState() => _PiggeryPageState();
}

class _PiggeryData {
  _PiggeryData({
    required this.kpis,
    required this.houses,
    required this.sows,
    required this.boars,
    required this.litters,
    required this.nursery,
    required this.fattening,
    required this.finishing,
    required this.farrowing,
    required this.trend,
  });

  final PiggeryKpis kpis;
  final List<PigHouse> houses;
  final List<Sow> sows;
  final List<Boar> boars;
  final List<Litter> litters;
  final List<NurseryGroup> nursery;
  final List<FattenPen> fattening;
  final List<FattenPen> finishing;
  final List<FarrowingRecordView> farrowing;
  final List<MonthlyPigletPoint> trend;
}

class _PiggeryPageState extends State<PiggeryPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  Future<_PiggeryData>? _future;
  PiggeryTab _active = PiggeryTab.overview;

  // Sow filters (only used on the Sows pill).
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _houseFilter;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<_PiggeryData> _load() async {
    final results = await Future.wait([
      ApiService.getPiggeryKpis(),
      ApiService.getPiggeryHouses(),
      ApiService.getPiggerySows(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        house: _houseFilter,
        status: _statusFilter,
      ),
      ApiService.getPiggeryBoars(),
      ApiService.getPiggeryLitters(),
      ApiService.getPiggeryNursery(),
      ApiService.getPiggeryFattening(),
      ApiService.getPiggeryFinishing(),
      ApiService.getPiggeryFarrowing(limit: 50),
      ApiService.getPiggeryTrend(months: 7),
    ]);

    List<T> parse<T>(int idx, T Function(Map<String, dynamic>) f) {
      return (results[idx] as List<dynamic>)
          .whereType<Map>()
          .map((m) => f(m.cast<String, dynamic>()))
          .toList();
    }

    return _PiggeryData(
      kpis: PiggeryKpis.fromJson(
        (results[0] as Map).cast<String, dynamic>(),
      ),
      houses: parse(1, PigHouse.fromJson),
      sows: parse(2, Sow.fromJson),
      boars: parse(3, Boar.fromJson),
      litters: parse(4, Litter.fromJson),
      nursery: parse(5, NurseryGroup.fromJson),
      fattening: parse(6, FattenPen.fromJson),
      finishing: parse(7, FattenPen.fromJson),
      farrowing: parse(8, FarrowingRecordView.fromJson),
      trend: parse(9, MonthlyPigletPoint.fromJson),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _onSowSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
      _refresh();
    });
  }

  Future<void> _openLogFarrowing(List<Sow> sows) async {
    if (sows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sows registered yet.')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LogFarrowingDialog(sows: sows),
    );
    if (saved == true) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Farrowing logged')),
        );
      }
    }
  }

  Future<void> _openReportSick() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ReportSickDialog(defaultUnit: 'Piggery'),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sick animal reported to vet')),
      );
    }
  }

  Future<void> _afterSave(String snack) async {
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(snack)));
    }
  }

  Future<void> _openAddSow(List<PigHouse> houses) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddSowDialog(houses: houses),
    );
    if (saved == true) await _afterSave('Sow added');
  }

  Future<void> _openAddBoar(List<PigHouse> houses) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddBoarDialog(houses: houses),
    );
    if (saved == true) await _afterSave('Boar added');
  }

  Future<void> _openEditBoar(Boar b, List<PigHouse> houses) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditBoarDialog(boar: b, houses: houses),
    );
    if (saved == true) await _afterSave('${b.tag} updated');
  }

  Future<void> _openAddLitter(List<Sow> sows) async {
    if (sows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sows available')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddLitterDialog(sows: sows),
    );
    if (saved == true) await _afterSave('Litter added');
  }

  Future<void> _openEditLitter(Litter l) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditLitterDialog(litter: l),
    );
    if (saved == true) await _afterSave('${l.litterId} updated');
  }

  Future<void> _openAddNursery() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddNurseryDialog(),
    );
    if (saved == true) await _afterSave('Nursery group added');
  }

  Future<void> _openEditNursery(NurseryGroup g) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditNurseryDialog(group: g),
    );
    if (saved == true) await _afterSave('Nursery ${g.pen} updated');
  }

  Future<void> _openAddPen(String house) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddPenDialog(house: house),
    );
    if (saved == true) await _afterSave('Pen added');
  }

  Future<void> _openEditPen(FattenPen p) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditPenDialog(pen: p),
    );
    if (saved == true) await _afterSave('${p.pen} updated');
  }

  Future<void> _deleteEntity({
    required String entityName,
    required String label,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $entityName'),
        content: Text(
          'Delete $label? This is a soft delete — the row is hidden but the '
          'database keeps the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4A),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await onConfirm();
      await _afterSave('$label deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_PiggeryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              const _UnitHeader(),
              const SizedBox(height: 16),
              _KpiRow(kpis: data.kpis),
              const SizedBox(height: 16),
              PiggeryPillTabs(
                selected: _active,
                onSelect: (t) => setState(() => _active = t),
              ),
              const SizedBox(height: 16),
              ..._tabBody(data),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _tabBody(_PiggeryData data) {
    switch (_active) {
      case PiggeryTab.overview:
        return [
          _OverviewActions(
            onLogFarrowing: () => _openLogFarrowing(data.sows),
            onSick: _openReportSick,
            onOpenSows: () => setState(() => _active = PiggeryTab.sows),
            onOpenHouses: () => setState(() => _active = PiggeryTab.houses),
            onOpenLitters: () => setState(() => _active = PiggeryTab.litters),
          ),
          const SizedBox(height: 16),
          _GlanceRow(kpis: data.kpis),
        ];
      case PiggeryTab.houses:
        return [
          _HousesGrid(
            houses: data.houses,
            selected: _houseFilter,
            onSelect: (h) {
              // Sows live in A/B/C/D/EM; E is fattening and F is
              // finishing. Routing E/F to the Sows pill used to leave
              // the table empty — fan out to the right pill instead.
              final code = h.code.toUpperCase();
              final target = code == 'E'
                  ? PiggeryTab.fattening
                  : code == 'F'
                      ? PiggeryTab.finishing
                      : PiggeryTab.sows;
              setState(() {
                _houseFilter = h.code;
                _active = target;
              });
              _refresh();
            },
          ),
        ];
      case PiggeryTab.sows:
        return [
          _SectionActionBar(
            label: 'Add sow',
            emoji: '🐖',
            onTap: () => _openAddSow(data.houses),
            onReportSick: _openReportSick,
          ),
          const SizedBox(height: 10),
          _SowFiltersBar(
            houseFilter: _houseFilter,
            statusFilter: _statusFilter,
            onHouseChanged: (v) {
              setState(() => _houseFilter = v);
              _refresh();
            },
            onStatusChanged: (v) {
              setState(() => _statusFilter = v);
              _refresh();
            },
            houses: data.houses,
          ),
          const SizedBox(height: 12),
          SowRegisterTable(
            sows: data.sows,
            searchController: _searchController,
            onSearchChanged: _onSowSearchChanged,
            onChanged: _refresh,
          ),
        ];
      case PiggeryTab.boars:
        return [
          _SectionActionBar(
            label: 'Add boar',
            emoji: '🐗',
            onTap: () => _openAddBoar(data.houses),
            onReportSick: _openReportSick,
          ),
          const SizedBox(height: 10),
          _BoarsTable(
            boars: data.boars,
            onEdit: (b) => _openEditBoar(b, data.houses),
            onDelete: (b) => _deleteEntity(
              entityName: 'boar',
              label: b.tag,
              onConfirm: () => ApiService.deletePig(b.id),
            ),
          ),
        ];
      case PiggeryTab.litters:
        return [
          _SectionActionBar(
            label: 'Add litter',
            emoji: '👶',
            onTap: () => _openAddLitter(data.sows),
            onReportSick: _openReportSick,
          ),
          const SizedBox(height: 10),
          _LittersTable(
            litters: data.litters,
            onEdit: _openEditLitter,
            onDelete: (l) => _deleteEntity(
              entityName: 'litter',
              label: l.litterId,
              onConfirm: () => ApiService.deletePiggeryLitter(l.id),
            ),
          ),
        ];
      case PiggeryTab.nursery:
        return [
          _SectionActionBar(
            label: 'Add group',
            emoji: '🍼',
            onTap: _openAddNursery,
            onReportSick: _openReportSick,
          ),
          const SizedBox(height: 10),
          _NurseryTable(
            groups: data.nursery,
            onEdit: _openEditNursery,
            onDelete: (g) => _deleteEntity(
              entityName: 'nursery group',
              label: g.pen,
              onConfirm: () => ApiService.deletePiggeryNursery(g.id),
            ),
          ),
        ];
      case PiggeryTab.fattening:
        return [
          _SectionActionBar(
            label: 'Add pen',
            emoji: '⚖️',
            onTap: () => _openAddPen('E'),
            onReportSick: _openReportSick,
          ),
          const SizedBox(height: 10),
          _PenSummaryCard(
            title: 'House E — Fattening',
            subtitle: 'David · Beaconners building weight',
            pens: data.fattening,
            onEdit: _openEditPen,
            onDelete: (p) => _deleteEntity(
              entityName: 'pen',
              label: p.pen,
              onConfirm: () => ApiService.deletePiggeryPen(p.id),
            ),
          ),
        ];
      case PiggeryTab.finishing:
        return [
          _SectionActionBar(
            label: 'Add pen',
            emoji: '⚡',
            onTap: () => _openAddPen('F'),
            onReportSick: _openReportSick,
          ),
          const SizedBox(height: 10),
          _PenSummaryCard(
            title: 'House F — Finishing',
            subtitle: 'Sam Bwira · Final stage before FC delivery',
            pens: data.finishing,
            showSaleStatus: true,
            onEdit: _openEditPen,
            onDelete: (p) => _deleteEntity(
              entityName: 'pen',
              label: p.pen,
              onConfirm: () => ApiService.deletePiggeryPen(p.id),
            ),
          ),
        ];
      case PiggeryTab.farrowing:
        return [
          _SectionActionBar(
            label: 'Log Farrowing',
            emoji: '📋',
            onTap: () => _openLogFarrowing(data.sows),
          ),
          const SizedBox(height: 10),
          _FarrowingTable(records: data.farrowing),
          const SizedBox(height: 16),
          MonthlyPigletChart(points: data.trend),
        ];
      case PiggeryTab.health:
        return const [UnitRemindersCard(unit: 'Piggery')];
      case PiggeryTab.vaccination:
        // The pill label is "Farmers" — Vaccinations have moved fully
        // into the Health module (cross-unit) so this slot now hosts
        // the Farmers Choice dispatch log: one row per FC truck-load.
        return const [FcDispatchLogCard()];
      case PiggeryTab.feed:
        return const [
          _ModuleLinkCard(
            emoji: '🌾',
            title: 'Feed comes from the Feeds module',
            body:
                'Pig concentrate, grower pellets, and the rest of the '
                'raw-material inventory are tracked in the central Feeds '
                'module. Daily allocations and stock-on-hand for the '
                'piggery surface there.',
            bullets: [
              'Pig concentrate · grower pellets · supplements',
              'Days-left per material vs. lead time',
              'Reorder alerts on the dashboard',
            ],
            cta: 'Open the Feeds module',
          ),
        ];
      case PiggeryTab.inventory:
        return [const PiggeryInventoryCard()];
      case PiggeryTab.staff:
        return [_StaffCard(houses: data.houses)];
      case PiggeryTab.breeding:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Breeding — sire/dam pedigree, AI vs natural service, '
                'conception rates per boar, retainer flagging at 3-4 months. '
                'Coming once the boar/sow service log lands.',
          ),
        ];
      case PiggeryTab.reports:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Reports — farrowing PDF · sales · mortality · feed cost · '
                'beaconners-vs-target. CSV + PDF export.',
          ),
        ];
      case PiggeryTab.observations:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Observations — pinned notes, priorities, linked tags, '
                'attachments. Cross-module observation feed coming in v2.',
          ),
        ];
      case PiggeryTab.settings:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Settings — capacity targets, gestation length override, '
                'beaconners target, naming-convention reference.',
          ),
        ];
    }
  }
}

// =====================================================================
// Unit header
// =====================================================================

class _UnitHeader extends StatelessWidget {
  const _UnitHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFCEDC8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🐷', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Piggery Unit',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _PiggeryPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '~494 head · 67 sows · 7 boars · 7 houses · Beaconners 100/mo',
                style: TextStyle(
                  fontSize: 12,
                  color: _PiggeryPageState._txt2,
                ),
              ),
            ],
          ),
        ),
        // Sick + Log Farrowing buttons live inside the Sows / Farrowing
        // pill action bars now — the header stays compact.
      ],
    );
  }
}

// =====================================================================
// KPI row
// =====================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final PiggeryKpis kpis;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final cards = <Widget>[
      KpiCard(
        label: 'Total head',
        value: '~${fmt.format(kpis.totalHead)}',
        sub: 'All categories',
      ),
      KpiCard(
        label: 'Breeding sows',
        value: fmt.format(kpis.totalSows),
        sub: 'Houses A·B·C·D + EM',
      ),
      KpiCard(
        label: 'Active litters',
        value: fmt.format(kpis.activeLitters),
        sub: '${fmt.format(kpis.pigletsOnMilk)} piglets on milk',
      ),
      KpiCard(
        label: 'Sale-ready (F)',
        value: fmt.format(kpis.saleReady),
        sub: '5–6 mo · Schedule FC delivery',
        trendColor: kpis.saleReady > 0
            ? const Color(0xFF27500A)
            : const Color(0xFF6B7770),
      ),
    ];

    return KpiGrid(children: cards);
  }
}

// =====================================================================
// Overview pill — quick actions + glance row
// =====================================================================

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.onLogFarrowing,
    required this.onSick,
    required this.onOpenSows,
    required this.onOpenHouses,
    required this.onOpenLitters,
  });
  final VoidCallback onLogFarrowing;
  final VoidCallback onSick;
  final VoidCallback onOpenSows;
  final VoidCallback onOpenHouses;
  final VoidCallback onOpenLitters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _PiggeryPageState._txt2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickPill(emoji: '📋', label: 'Log farrowing', onTap: onLogFarrowing),
              _QuickPill(emoji: '🤒', label: 'Report sick', onTap: onSick),
              _QuickPill(emoji: '🐖', label: 'Sows register', onTap: onOpenSows),
              _QuickPill(emoji: '🏠', label: 'Houses', onTap: onOpenHouses),
              _QuickPill(emoji: '👶', label: 'Litters', onTap: onOpenLitters),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.emoji,
    required this.label,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _PiggeryPageState._primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlanceRow extends StatelessWidget {
  const _GlanceRow({required this.kpis});
  final PiggeryKpis kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        final sows = _GlanceCard(
          emoji: '🐖',
          title: 'Sows + boars',
          headline: '${kpis.totalSows} sows · ${kpis.totalBoars} boars',
          sub: '${kpis.farrowingDue} due in the next 14 days',
        );
        final beaconners = _GlanceCard(
          emoji: '🎯',
          title: 'Beaconners this month',
          headline: '${kpis.monthlyBeaconners} head',
          sub: 'Target 100/month',
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: sows),
              const SizedBox(width: 12),
              Expanded(child: beaconners),
            ],
          );
        }
        return Column(
          children: [sows, const SizedBox(height: 12), beaconners],
        );
      },
    );
  }
}

class _GlanceCard extends StatelessWidget {
  const _GlanceCard({
    required this.emoji,
    required this.title,
    required this.headline,
    required this.sub,
  });
  final String emoji;
  final String title;
  final String headline;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEDC8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _PiggeryPageState._txt2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _PiggeryPageState._primary,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _PiggeryPageState._txt2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Houses pill — tile grid
// =====================================================================

class _HousesGrid extends StatelessWidget {
  const _HousesGrid({
    required this.houses,
    required this.onSelect,
    this.selected,
  });
  final List<PigHouse> houses;
  /// Fired when the user taps a house tile — the page filters the Sows
  /// pill to that house and jumps to it.
  final ValueChanged<PigHouse> onSelect;
  /// Currently-active house code (used to highlight the tile when the
  /// user lands back on Houses from a Sows filter).
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🏠 HOUSES OVERVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a house to see its pens',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.05,
                children: [
                  for (final h in houses)
                    _HouseTile(
                      house: h,
                      active: selected == h.code,
                      onTap: () => onSelect(h),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HouseTile extends StatelessWidget {
  const _HouseTile({
    required this.house,
    required this.onTap,
    this.active = false,
  });
  final PigHouse house;
  final VoidCallback onTap;
  /// True when this tile's house code matches the currently active
  /// sow-table filter — renders a green border so the user can see
  /// which house they jumped from.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isEm = house.code == 'EM';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFEAF3DE)
            : (isEm ? const Color(0xFFFCEDC8) : const Color(0xFFFAFBF8)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? _PiggeryPageState._primary
              : const Color(0x1A000000),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            house.code,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _PiggeryPageState._primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${house.count}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            house.subline,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            '${house.manager} · ${house.pens} pens',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontStyle: FontStyle.italic,
              color: Colors.black45,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// =====================================================================
// Sows filter bar
// =====================================================================

class _SowFiltersBar extends StatelessWidget {
  const _SowFiltersBar({
    required this.houseFilter,
    required this.statusFilter,
    required this.onHouseChanged,
    required this.onStatusChanged,
    required this.houses,
  });
  final String? houseFilter;
  final String? statusFilter;
  final ValueChanged<String?> onHouseChanged;
  final ValueChanged<String?> onStatusChanged;
  final List<PigHouse> houses;

  static const _statusOptions = [
    ('LACTATING', 'Nursing'),
    ('GESTATING', 'Gestation'),
    ('DRY', 'Dry'),
    ('SERVICE', 'Servicing'),
    ('FARROWING_SOON', 'Farrowing soon'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _FilterChip(
          label: 'All houses',
          selected: houseFilter == null,
          onTap: () => onHouseChanged(null),
        ),
        for (final h in houses)
          _FilterChip(
            label: h.code,
            selected: houseFilter == h.code,
            onTap: () => onHouseChanged(h.code),
          ),
        const SizedBox(width: 16),
        _FilterChip(
          label: 'All status',
          selected: statusFilter == null,
          onTap: () => onStatusChanged(null),
        ),
        for (final s in _statusOptions)
          _FilterChip(
            label: s.$2,
            selected: statusFilter == s.$1,
            onTap: () => onStatusChanged(s.$1),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _PiggeryPageState._primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _PiggeryPageState._primary
                : const Color(0x33000000),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Boars table
// =====================================================================

class _BoarsTable extends StatelessWidget {
  const _BoarsTable({
    required this.boars,
    required this.onEdit,
    required this.onDelete,
  });
  final List<Boar> boars;
  final ValueChanged<Boar> onEdit;
  final ValueChanged<Boar> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🐗 BOAR REGISTER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${boars.length} boars (6 active + 1 for sale)',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 14),
          if (boars.isEmpty)
            const _EmptyRow(text: 'No boars registered yet.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('TAG')),
                  DataColumn(label: Text('PEN')),
                  DataColumn(label: Text('HOUSE')),
                  DataColumn(label: Text('BREED')),
                  DataColumn(label: Text('AGE')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final b in boars)
                    DataRow(cells: [
                      DataCell(Text(b.tag,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text(b.pen ?? '—')),
                      DataCell(Text(b.house ?? '—')),
                      DataCell(Text(b.breed ?? '—')),
                      DataCell(Text(b.age ?? '—')),
                      DataCell(_BoarRoleText(role: b.role ?? '')),
                      DataCell(_RowActions(
                        onEdit: () => onEdit(b),
                        onDelete: () => onDelete(b),
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BoarRoleText extends StatelessWidget {
  const _BoarRoleText({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    Color? color;
    FontWeight? weight;
    if (role.contains('CASTRATED')) {
      color = const Color(0xFFC0392B);
    } else if (role.contains('Currently servicing')) {
      color = _PiggeryPageState._primary;
      weight = FontWeight.w700;
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Text(
        role,
        style: TextStyle(fontSize: 12, color: color, fontWeight: weight),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

// =====================================================================
// Litters table
// =====================================================================

class _LittersTable extends StatelessWidget {
  const _LittersTable({
    required this.litters,
    required this.onEdit,
    required this.onDelete,
  });
  final List<Litter> litters;
  final ValueChanged<Litter> onEdit;
  final ValueChanged<Litter> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '👶 ACTIVE LITTERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${litters.length} with sow · '
            '${litters.fold<int>(0, (s, l) => s + l.count)} piglets on milk',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 14),
          if (litters.isEmpty)
            const _EmptyRow(text: 'No active litters.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('PEN')),
                  DataColumn(label: Text('SOW')),
                  DataColumn(label: Text('LITTER ID')),
                  DataColumn(label: Text('BORN')),
                  DataColumn(label: Text('AGE')),
                  DataColumn(label: Text('ALIVE'), numeric: true),
                  DataColumn(label: Text('NOTES')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final l in litters)
                    DataRow(
                      color: l.count <= 1
                          ? const WidgetStatePropertyAll(Color(0xFFFADBD8))
                          : null,
                      cells: [
                        DataCell(Text(l.pen ?? '—',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text(l.sowTag ?? '—')),
                        DataCell(Text(
                          l.litterId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        )),
                        DataCell(Text(l.born == null
                            ? '—'
                            : DateFormat('d MMM').format(l.born!))),
                        DataCell(Text(_age(l.born))),
                        DataCell(Text(
                          '${l.count}',
                          style: TextStyle(
                            color: l.count <= 1
                                ? const Color(0xFFC0392B)
                                : null,
                            fontWeight: FontWeight.w700,
                          ),
                        )),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            l.note ?? '',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(_RowActions(
                          onEdit: () => onEdit(l),
                          onDelete: () => onDelete(l),
                        )),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _age(DateTime? born) {
    if (born == null) return 'TBC';
    final d = DateTime.now().difference(born).inDays;
    return '${d}d';
  }
}

// =====================================================================
// Nursery table
// =====================================================================

class _NurseryTable extends StatelessWidget {
  const _NurseryTable({
    required this.groups,
    required this.onEdit,
    required this.onDelete,
  });
  final List<NurseryGroup> groups;
  final ValueChanged<NurseryGroup> onEdit;
  final ValueChanged<NurseryGroup> onDelete;

  @override
  Widget build(BuildContext context) {
    final total = groups.fold<int>(0, (s, g) => s + g.count);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🍼 NURSERY (HOUSE C)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${groups.length} groups · $total weaned, headed for House E',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            const _EmptyRow(text: 'Nursery is empty.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('PEN')),
                  DataColumn(label: Text('COUNT'), numeric: true),
                  DataColumn(label: Text('AGE')),
                  DataColumn(label: Text('BREED')),
                  DataColumn(label: Text('NOTES')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final g in groups)
                    DataRow(cells: [
                      DataCell(Text(g.pen,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text('${g.count}')),
                      DataCell(Text(g.age ?? '—')),
                      DataCell(Text(g.breed ?? '—')),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          g.note ?? '',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(_RowActions(
                        onEdit: () => onEdit(g),
                        onDelete: () => onDelete(g),
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// Pen summary (Fattening / Finishing)
// =====================================================================

class _PenSummaryCard extends StatelessWidget {
  const _PenSummaryCard({
    required this.title,
    required this.subtitle,
    required this.pens,
    required this.onEdit,
    required this.onDelete,
    this.showSaleStatus = false,
  });
  final String title;
  final String subtitle;
  final List<FattenPen> pens;
  final bool showSaleStatus;
  final ValueChanged<FattenPen> onEdit;
  final ValueChanged<FattenPen> onDelete;

  @override
  Widget build(BuildContext context) {
    final total = pens.fold<int>(0, (s, p) => s + p.count);
    final saleReady =
        pens.where((p) => p.saleReady).fold<int>(0, (s, p) => s + p.count);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$subtitle · $total head'
            '${showSaleStatus ? ' · $saleReady sale-ready' : ''}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 14),
          if (pens.isEmpty)
            const _EmptyRow(text: 'No pens recorded.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                columns: [
                  const DataColumn(label: Text('PEN')),
                  const DataColumn(label: Text('COUNT'), numeric: true),
                  const DataColumn(label: Text('AGE')),
                  if (showSaleStatus) const DataColumn(label: Text('STATUS')),
                  const DataColumn(label: Text('ACTIONS')),
                ],
                rows: [
                  for (final p in pens)
                    DataRow(cells: [
                      DataCell(Text(p.pen,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text('${p.count}')),
                      DataCell(Text(p.age ?? '—')),
                      if (showSaleStatus) DataCell(_SaleTag(pen: p)),
                      DataCell(_RowActions(
                        onEdit: () => onEdit(p),
                        onDelete: () => onDelete(p),
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SaleTag extends StatelessWidget {
  const _SaleTag({required this.pen});
  final FattenPen pen;
  @override
  Widget build(BuildContext context) {
    if (pen.saleReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F0DD),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '⚡ Sale-ready',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF27500A),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        pen.saleWindow ?? 'Hold',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8A5A0A),
        ),
      ),
    );
  }
}

// =====================================================================
// Farrowing table
// =====================================================================

class _FarrowingTable extends StatelessWidget {
  const _FarrowingTable({required this.records});
  final List<FarrowingRecordView> records;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'FARROWING RECORDS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              Text(
                '${records.length} records',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const _EmptyRow(text: 'No farrowing records yet.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.black54,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 12, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('FARROW')),
                  DataColumn(label: Text('SERVICE')),
                  DataColumn(label: Text('SOW')),
                  DataColumn(label: Text('WIN'), numeric: true),
                  DataColumn(label: Text('FAT'), numeric: true),
                  DataColumn(label: Text('BEA'), numeric: true),
                  DataColumn(label: Text('ALIVE'), numeric: true),
                  DataColumn(label: Text('DEAD'), numeric: true),
                ],
                rows: [
                  for (final r in records)
                    DataRow(cells: [
                      DataCell(Text(DateFormat('d MMM yy').format(r.date))),
                      DataCell(Text(r.service == null
                          ? '—'
                          : DateFormat('d MMM yy').format(r.service!))),
                      DataCell(Text(r.sowTag ?? '—')),
                      DataCell(Text(_n(r.winners),
                          style: const TextStyle(color: Color(0xFF7A2E00)))),
                      DataCell(Text(_n(r.fatteners),
                          style: const TextStyle(color: Color(0xFF8A5A0A)))),
                      DataCell(Text(_n(r.beaconners),
                          style: const TextStyle(
                            color: Color(0xFF27500A),
                            fontWeight: FontWeight.w700,
                          ))),
                      DataCell(Text(
                        '${r.pigletsAlive}',
                        style: const TextStyle(
                          color: Color(0xFF27500A),
                          fontWeight: FontWeight.w700,
                        ),
                      )),
                      DataCell(Text(
                        '${r.pigletsDead}',
                        style: const TextStyle(
                          color: Color(0xFFC0392B),
                          fontWeight: FontWeight.w700,
                        ),
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _n(int? v) => (v == null || v == 0) ? '—' : '$v';
}

// =====================================================================
// Staff card
// =====================================================================

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.houses});
  final List<PigHouse> houses;

  @override
  Widget build(BuildContext context) {
    // Group houses by manager.
    final byManager = <String, List<PigHouse>>{};
    for (final h in houses) {
      byManager.putIfAbsent(h.manager, () => []).add(h);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '👥 STAFF & RESPONSIBILITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in byManager.entries) ...[
            _StaffRow(
              name: entry.key,
              houses: entry.value.map((h) => h.code).join(' · '),
              load: entry.value
                  .map((h) => '${h.label}: ${h.count} ${h.subline.toLowerCase()}')
                  .join('\n'),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.name,
    required this.houses,
    required this.load,
  });
  final String name;
  final String houses;
  final String load;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _PiggeryPageState._primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Houses: $houses',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              load,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Cross-module link card (used by Vaccination / Feed pills)
// =====================================================================

class _ModuleLinkCard extends StatelessWidget {
  const _ModuleLinkCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.bullets,
    required this.cta,
  });
  final String emoji;
  final String title;
  final String body;
  final List<String> bullets;
  final String cta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3DE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _PiggeryPageState._primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: _PiggeryPageState._txt2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 12,
                      color: _PiggeryPageState._primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _PiggeryPageState._txt2,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new,
                    size: 12, color: _PiggeryPageState._primary),
                const SizedBox(width: 4),
                Text(
                  cta,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _PiggeryPageState._primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Section action bar + coming-soon + empty row
// =====================================================================

class _SectionActionBar extends StatelessWidget {
  const _SectionActionBar({
    required this.label,
    required this.emoji,
    required this.onTap,
    this.onReportSick,
  });
  final String label;
  final String emoji;
  final VoidCallback onTap;
  final VoidCallback? onReportSick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onReportSick != null) ...[
          OutlinedButton.icon(
            onPressed: onReportSick,
            icon: const Text('🤒', style: TextStyle(fontSize: 14)),
            label: const Text('Report sick'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC0392B),
              side: const BorderSide(color: Color(0xFFC0392B)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton.icon(
          onPressed: onTap,
          icon: Text(emoji, style: const TextStyle(fontSize: 14)),
          label: Text('+ $label'),
          style: FilledButton.styleFrom(
            backgroundColor: _PiggeryPageState._primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.tab, required this.description});
  final PiggeryTab tab;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: [
          Text(tab.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            '${tab.label} — coming soon',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _PiggeryPageState._primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _PiggeryPageState._txt2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          color: _PiggeryPageState._primary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 16),
          color: const Color(0xFFE24B4A),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}

// =====================================================================
// Error
// =====================================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 40, color: Color(0xFFE24B4A)),
        const SizedBox(height: 12),
        Text(
          'Could not load piggery data',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
