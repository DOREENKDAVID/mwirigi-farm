import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/ngushish.dart';
import '../../core/service/api_service.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import 'crop_activity_sheet.dart';
import 'crop_issue_dialog.dart';
import 'ngushish_inventory_card.dart';
import 'ngushish_pill_tabs.dart';
import 'register_block_dialog.dart';
import 'register_harvest_dialog.dart';

/// Ngusishi Farm dashboard — full operational layout matching the v4.5
/// HTML mockup. Composition top → bottom:
///   • Unit header (🌿 icon · title · subtitle · Issue + Register buttons)
///   • 4 KPI cards (Total blocks · Ready · Growing · Awaiting)
///   • Blocks overview tiles (A / B / C / D)
///   • Crop portfolio breakdown (Cabbage · Maize · Potatoes · Avocado · Infra · Awaiting)
///   • Crop register (status pills + search + table)
///   • Harvest planner (table)
///   • Estimated harvest value (financial table)
///   • Immediate actions (this-week command center)
///   • Inventory card
///   • Observations placeholder
class NgushishPage extends StatefulWidget {
  const NgushishPage({super.key});

  @override
  State<NgushishPage> createState() => _NgushishPageState();
}

class _NgushishPageState extends State<NgushishPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _red = Color(0xFFC4393B);
  static const _amber = Color(0xFF8A5A0A);
  static const _green = Color(0xFF27500A);
  static const _brown = Color(0xFF7A2E00);
  static const _teal = Color(0xFF0E5E50);

  Future<_NgushishData>? _future;
  NgushishTab _active = NgushishTab.overview;

  // Status filter for the crop register pills (null = "all").
  CropStatus? _statusFilter;
  // Block-area filter when a user taps an A/B/C/D tile.
  String? _areaFilter;
  // Free-text search across block, crop name, season, status.
  String _search = '';
  Timer? _searchDebounce;
  final _searchController = TextEditingController();

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

  Future<_NgushishData> _load() async {
    // Pull all crops (no pagination — Ngusishi caps at 21 blocks) +
    // dashboard KPIs in parallel.
    final results = await Future.wait([
      ApiService.getNgushishCrops(limit: 200),
      ApiService.getNgushishDashboard(),
    ]);
    final cropsRaw = results[0];
    final dashboardRaw = results[1];
    final items = (cropsRaw['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => CropView.fromJson(m.cast<String, dynamic>()))
        .toList();
    return _NgushishData(
      blocks: items,
      kpis: NgushishKpis.fromJson(dashboardRaw),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _search = v.trim().toLowerCase());
    });
  }

  Future<void> _openIssue(List<CropView> blocks, {CropView? initial}) async {
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register a block before logging issues')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CropIssueDialog(blocks: blocks, initialBlock: initial),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crop issue reported')),
      );
      _refresh();
    }
  }

  Future<void> _openRegister() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RegisterBlockDialog(),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Block registered')),
      );
      _refresh();
    }
  }

  Future<void> _openHarvestLog(List<CropView> blocks, {CropView? initial}) async {
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register a block before logging harvests')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RegisterHarvestDialog(blocks: blocks, initialBlock: initial),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harvest logged')),
      );
      _refresh();
    }
  }

  Future<void> _openActivity(CropView crop) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CropActivitySheet(crop: crop),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_NgushishData>(
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
              _KpiRow(blocks: data.blocks),
              const SizedBox(height: 16),
              NgushishPillTabs(
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

  // ----------------- Pill body dispatch -----------------

  List<Widget> _tabBody(_NgushishData data) {
    switch (_active) {
      case NgushishTab.overview:
        return [
          _BlocksOverview(
            blocks: data.blocks,
            activeArea: _areaFilter,
            onTap: (area) {
              setState(() {
                _areaFilter = _areaFilter == area ? null : area;
                // Tapping a tile is a "drill into the register" gesture
                // — jump to the Blocks pill so the filter is visible.
                if (_areaFilter != null) _active = NgushishTab.blocks;
              });
            },
            onClear: () => setState(() => _areaFilter = null),
          ),
          const SizedBox(height: 16),
          _CropPortfolio(blocks: data.blocks),
          const SizedBox(height: 16),
          _ImmediateActionsCard(blocks: data.blocks),
        ];
      case NgushishTab.blocks:
        final filtered = _applyFilters(data.blocks);
        return [
          _BlocksActionBar(
            onRegister: _openRegister,
            onLogIssue: () => _openIssue(data.blocks),
          ),
          const SizedBox(height: 12),
          _CropRegisterCard(
            title: _areaFilter == null
                ? 'Crop register — all ${data.blocks.length} blocks'
                : 'Crop register — Block $_areaFilter',
            blocks: data.blocks,
            filtered: filtered,
            statusFilter: _statusFilter,
            onStatusChanged: (s) => setState(() => _statusFilter = s),
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onRowIssue: (b) => _openIssue(data.blocks, initial: b),
            onRowActivity: _openActivity,
          ),
        ];
      case NgushishTab.harvest:
        return [
          _HarvestActionBar(
            onLogHarvest: () => _openHarvestLog(data.blocks),
          ),
          const SizedBox(height: 12),
          _HarvestPlanner(
            blocks: data.blocks,
            onRowLog: (b) => _openHarvestLog(data.blocks, initial: b),
            onRowActivity: _openActivity,
          ),
        ];
      case NgushishTab.revenue:
        return [_EstimatedRevenueCard(blocks: data.blocks)];
      case NgushishTab.inventory:
        return [const NgushishInventoryCard()];
      case NgushishTab.observations:
        return [const _ObservationsPlaceholder()];
    }
  }

  List<CropView> _applyFilters(List<CropView> all) {
    Iterable<CropView> out = all;
    if (_areaFilter != null) {
      out = out.where((b) => _areaPrefix(b.block) == _areaFilter);
    }
    if (_statusFilter != null) {
      out = out.where((b) => b.status == _statusFilter);
    }
    if (_search.isNotEmpty) {
      out = out.where((b) =>
          (b.block ?? '').toLowerCase().contains(_search) ||
          b.name.toLowerCase().contains(_search) ||
          (b.season ?? '').toLowerCase().contains(_search) ||
          b.status.label.toLowerCase().contains(_search));
    }
    return out.toList();
  }

  static String _areaPrefix(String? block) {
    if (block == null || block.isEmpty) return '';
    final c = block[0];
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '';
  }
}

class _NgushishData {
  _NgushishData({required this.blocks, required this.kpis});
  final List<CropView> blocks;
  final NgushishKpis kpis;
}

// =====================================================================
// Unit header — 🌿 icon · title · subtitle · Issue + Register actions
// =====================================================================

class _UnitHeader extends StatelessWidget {
  const _UnitHeader();

  @override
  Widget build(BuildContext context) {
    // Title-only header — the Issue + Register actions moved into the
    // Blocks and Harvest pill bodies where they read with context.
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
          child: const Text('🌿', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ngusishi Farm',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _NgushishPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Integrated horticulture · 21 blocks · 17.95 acres · '
                'Season 2025/26 · Manager: A. Wangari',
                style: TextStyle(
                  fontSize: 12,
                  color: _NgushishPageState._txt2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// KPI row — Total blocks · Ready · Growing · Awaiting
// =====================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.blocks});
  final List<CropView> blocks;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final ready =
        blocks.where((b) => b.status == CropStatus.ready).length;
    final growing =
        blocks.where((b) => b.status == CropStatus.growing).length;
    final awaiting =
        blocks.where((b) => b.status == CropStatus.awaiting).length;
    final totalAcres = blocks.fold<double>(0, (s, b) => s + b.acreage);
    final acresLabel =
        '${totalAcres.toStringAsFixed(totalAcres == totalAcres.roundToDouble() ? 0 : 2)} acres';

    final cards = <Widget>[
      KpiCard(
        label: 'Total blocks',
        value: fmt.format(blocks.length),
        sub: acresLabel,
      ),
      KpiCard(
        label: 'Ready to harvest',
        value: fmt.format(ready),
        sub: ready > 0 ? 'Urgent — harvest now' : 'Nothing ready',
        trendColor: const Color(0xFFC4393B),
      ),
      KpiCard(
        label: 'Growing',
        value: fmt.format(growing),
        sub: 'Active crops in field',
        trendColor: const Color(0xFF27500A),
      ),
      KpiCard(
        label: 'Awaiting planting',
        value: fmt.format(awaiting),
        sub: 'Blocks prepared for planting',
        trendColor: const Color(0xFF8A5A0A),
      ),
    ];

    return KpiGrid(children: cards);
  }
}

// =====================================================================
// Blocks overview — tap a tile to filter the register by area
// =====================================================================

class _BlocksOverview extends StatelessWidget {
  const _BlocksOverview({
    required this.blocks,
    required this.activeArea,
    required this.onTap,
    required this.onClear,
  });
  final List<CropView> blocks;
  final String? activeArea;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // Aggregate by area prefix (A/B/C/D).
    final areas = <String, _AreaSummary>{};
    for (final b in blocks) {
      final a = _NgushishPageState._areaPrefix(b.block);
      if (a.isEmpty) continue;
      final s = areas.putIfAbsent(a, () => _AreaSummary(a));
      s.count += 1;
      s.acres += b.acreage;
      if (b.status == CropStatus.ready) s.ready += 1;
      if (b.status == CropStatus.growing) s.growing += 1;
      if (b.status == CropStatus.awaiting) s.awaiting += 1;
    }
    final ordered = ['A', 'B', 'C', 'D']
        .where(areas.containsKey)
        .map((a) => areas[a]!)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🌿 BLOCKS OVERVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              if (activeArea != null)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Clear filter'),
                  style: TextButton.styleFrom(
                    foregroundColor: _NgushishPageState._txt2,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a block area to filter the register',
            style: TextStyle(
              fontSize: 11,
              color: _NgushishPageState._txt3,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  for (final s in ordered)
                    _AreaTile(
                      summary: s,
                      active: activeArea == s.area,
                      onTap: () => onTap(s.area),
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

class _AreaSummary {
  _AreaSummary(this.area);
  final String area;
  int count = 0;
  double acres = 0;
  int ready = 0;
  int growing = 0;
  int awaiting = 0;
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.summary,
    required this.active,
    required this.onTap,
  });
  final _AreaSummary summary;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (summary.ready > 0) parts.add('${summary.ready} ready');
    if (summary.growing > 0) parts.add('${summary.growing} growing');
    if (summary.awaiting > 0) parts.add('${summary.awaiting} awaiting');
    final subline = parts.isEmpty ? '—' : parts.join(' · ');
    final acres =
        summary.acres.toStringAsFixed(summary.acres == summary.acres.roundToDouble() ? 0 : 1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFEAF3DE)
              : const Color(0xFFFAFBF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? _NgushishPageState._primary
                : const Color(0x14000000),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              summary.area,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _NgushishPageState._primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.count}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$acres ac · $subline',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: _NgushishPageState._txt2,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Crop portfolio breakdown — 6 colored tiles
// =====================================================================

class _CropPortfolio extends StatelessWidget {
  const _CropPortfolio({required this.blocks});
  final List<CropView> blocks;

  @override
  Widget build(BuildContext context) {
    final totalAc = blocks.fold<double>(0, (s, b) => s + b.acreage);
    final cabbage = _PortfolioGroup('Cabbage', blocks
        .where((b) => b.name.toLowerCase().contains('cabbage'))
        .toList());
    final maize = _PortfolioGroup('Maize',
        blocks.where((b) => b.name.toLowerCase().contains('maize')).toList());
    final potatoes = _PortfolioGroup(
        'Potatoes',
        blocks
            .where((b) => b.name.toLowerCase().contains('potato'))
            .toList());
    final avocado = _PortfolioGroup(
        'Avocado',
        blocks
            .where((b) => b.name.toLowerCase().contains('avocado'))
            .toList());
    final infra = _PortfolioGroup(
        'Infrastructure',
        blocks
            .where((b) => b.status == CropStatus.infrastructure)
            .toList());
    final awaiting = _PortfolioGroup(
        'Awaiting',
        blocks
            .where((b) => b.status == CropStatus.awaiting)
            .toList());

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '📊 CROP PORTFOLIO BREAKDOWN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 880
                  ? 3
                  : c.maxWidth >= 520
                      ? 2
                      : 1;
              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: w,
                    child: _PortfolioTile(
                      label: 'Cabbage',
                      accent: _NgushishPageState._green,
                      group: cabbage,
                      totalAc: totalAc,
                      window: 'May–Jun 2026',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _PortfolioTile(
                      label: 'Maize',
                      accent: _NgushishPageState._amber,
                      group: maize,
                      totalAc: totalAc,
                      window: 'Aug–Oct 2026',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _PortfolioTile(
                      label: 'Potatoes',
                      accent: _NgushishPageState._brown,
                      group: potatoes,
                      totalAc: totalAc,
                      window: 'Now + Aug 2026',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _PortfolioTile(
                      label: 'Avocado',
                      accent: _NgushishPageState._teal,
                      group: avocado,
                      totalAc: totalAc,
                      window: 'Perennial · intercropped',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _PortfolioTile(
                      label: 'Infrastructure',
                      accent: _NgushishPageState._txt2,
                      group: infra,
                      totalAc: totalAc,
                      window: 'Homestead / Dam',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _PortfolioTile(
                      label: 'Awaiting',
                      accent: _NgushishPageState._amber,
                      group: awaiting,
                      totalAc: totalAc,
                      window: 'Land prepared · plant May 2026',
                    ),
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

class _PortfolioGroup {
  _PortfolioGroup(this.label, this.blocks);
  final String label;
  final List<CropView> blocks;
  int get count => blocks.length;
  double get acres => blocks.fold<double>(0, (s, b) => s + b.acreage);
  int get readyNow =>
      blocks.where((b) => b.status == CropStatus.ready).length;
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({
    required this.label,
    required this.accent,
    required this.group,
    required this.totalAc,
    required this.window,
  });
  final String label;
  final Color accent;
  final _PortfolioGroup group;
  final double totalAc;
  final String window;

  @override
  Widget build(BuildContext context) {
    if (group.count == 0) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBF8),
          borderRadius: BorderRadius.circular(10),
          border: const Border(
            left: BorderSide(width: 3, color: Color(0x33000000)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.05,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            const Text('—',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF99A39B),
                )),
          ],
        ),
      );
    }
    final pct = totalAc == 0
        ? 0
        : ((group.acres / totalAc) * 100).round();
    final acres = group.acres.toStringAsFixed(
        group.acres == group.acres.roundToDouble() ? 0 : 2);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBF8),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(width: 3, color: accent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.05,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A18)),
              children: [
                TextSpan(
                  text: '${group.count} '
                      'block${group.count == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: ' · $acres ac · $pct% of farm'),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$window'
            '${group.readyNow > 0 ? " · ${group.readyNow} ready NOW" : ""}',
            style: const TextStyle(
              fontSize: 11,
              color: _NgushishPageState._txt2,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Crop register — search + status pills + table
// =====================================================================

class _CropRegisterCard extends StatelessWidget {
  const _CropRegisterCard({
    required this.title,
    required this.blocks,
    required this.filtered,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRowIssue,
    required this.onRowActivity,
  });

  final String title;
  final List<CropView> blocks;
  final List<CropView> filtered;
  final CropStatus? statusFilter;
  final ValueChanged<CropStatus?> onStatusChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CropView> onRowIssue;
  final ValueChanged<CropView> onRowActivity;

  @override
  Widget build(BuildContext context) {
    int countOf(CropStatus s) =>
        blocks.where((b) => b.status == s).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _NgushishPageState._primary,
                  ),
                ),
              ),
              Text(
                '${filtered.length} block${filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: _NgushishPageState._txt3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by block, crop, season, status…',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusPill(
                label: 'All',
                count: blocks.length,
                selected: statusFilter == null,
                onTap: () => onStatusChanged(null),
              ),
              _StatusPill(
                label: '✅ Ready',
                count: countOf(CropStatus.ready),
                selected: statusFilter == CropStatus.ready,
                onTap: () => onStatusChanged(CropStatus.ready),
              ),
              _StatusPill(
                label: '🌱 Growing',
                count: countOf(CropStatus.growing),
                selected: statusFilter == CropStatus.growing,
                onTap: () => onStatusChanged(CropStatus.growing),
              ),
              _StatusPill(
                label: '🟡 Awaiting',
                count: countOf(CropStatus.awaiting),
                selected: statusFilter == CropStatus.awaiting,
                onTap: () => onStatusChanged(CropStatus.awaiting),
              ),
              _StatusPill(
                label: '🏠 Infra',
                count: countOf(CropStatus.infrastructure),
                selected: statusFilter == CropStatus.infrastructure,
                onTap: () => onStatusChanged(CropStatus.infrastructure),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No blocks match this filter.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            )
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
                    const TextStyle(fontSize: 12, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('BLOCK')),
                  DataColumn(label: Text('AREA (ac)'), numeric: true),
                  DataColumn(label: Text('CROP')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('AGE')),
                  DataColumn(label: Text('DUE / HARVEST')),
                  DataColumn(label: Text('SEASON')),
                  DataColumn(label: Text('NOTES & ACTIONS')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final b in filtered)
                    DataRow(cells: [
                      DataCell(Text(
                        b.block ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      )),
                      DataCell(Text(
                        b.acreage.toStringAsFixed(
                            b.acreage == b.acreage.roundToDouble() ? 0 : 2),
                      )),
                      DataCell(Text(b.name)),
                      DataCell(_StatusTag(status: b.status)),
                      DataCell(Text(b.age ?? '—')),
                      DataCell(
                        b.status == CropStatus.ready
                            ? const Text(
                                'HARVEST NOW',
                                style: TextStyle(
                                  color: Color(0xFFC4393B),
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Text(
                                b.dueDate == null
                                    ? '—'
                                    : DateFormat('d MMM yyyy').format(b.dueDate!),
                              ),
                      ),
                      DataCell(Text(b.season ?? '—')),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            b.actionNote ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: b.isUrgentAction
                                  ? const Color(0xFFC4393B)
                                  : null,
                              fontWeight: b.isUrgentAction
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      DataCell(_RowActions(
                        onIssue: () => onRowIssue(b),
                        onActivity: () => onRowActivity(b),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _NgushishPageState._primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _NgushishPageState._primary
                : const Color(0x33000000),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFFEAF3DE)
                    : _NgushishPageState._txt3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});
  final CropStatus status;
  @override
  Widget build(BuildContext context) {
    final emoji = switch (status) {
      CropStatus.ready => '✅',
      CropStatus.growing => '🌱',
      CropStatus.awaiting => '🟡',
      CropStatus.infrastructure => '🏠',
      _ => '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        emoji.isEmpty ? status.label : '$emoji ${status.label}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.fg,
        ),
      ),
    );
  }
}

// =====================================================================
// Harvest planner — timeline-style table
// =====================================================================

class _HarvestPlanner extends StatelessWidget {
  const _HarvestPlanner({
    required this.blocks,
    required this.onRowLog,
    required this.onRowActivity,
  });
  final List<CropView> blocks;
  final ValueChanged<CropView> onRowLog;
  final ValueChanged<CropView> onRowActivity;

  static int _sortKey(CropView b) {
    // Ready first, then growing by due date, then awaiting (planting).
    if (b.status == CropStatus.ready) return 0;
    if (b.status == CropStatus.growing) return 1;
    if (b.status == CropStatus.awaiting) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final sortable = blocks
        .where((b) => b.status != CropStatus.infrastructure)
        .toList()
      ..sort((a, b) {
        final ka = _sortKey(a);
        final kb = _sortKey(b);
        if (ka != kb) return ka - kb;
        final da = a.dueDate?.millisecondsSinceEpoch ?? 0;
        final db = b.dueDate?.millisecondsSinceEpoch ?? 0;
        return da - db;
      });

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🌾 HARVEST PLANNER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "What's coming when",
            style: TextStyle(
              fontSize: 11,
              color: _NgushishPageState._txt3,
            ),
          ),
          const SizedBox(height: 12),
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
                  const TextStyle(fontSize: 12, color: Colors.black87),
              columns: const [
                DataColumn(label: Text('BLOCK')),
                DataColumn(label: Text('CROP')),
                DataColumn(label: Text('AREA'), numeric: true),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('PRIORITY')),
                DataColumn(label: Text('ESTIMATED YIELD')),
                DataColumn(label: Text('ACTION')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final b in sortable)
                  DataRow(cells: [
                    DataCell(Text(b.block ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(b.name)),
                    DataCell(Text('${b.acreage.toStringAsFixed(b.acreage == b.acreage.roundToDouble() ? 0 : 2)} ac')),
                    DataCell(_PlannerStatusTag(block: b)),
                    DataCell(Text(_dateLabel(b))),
                    DataCell(_PriorityText(block: b)),
                    DataCell(Text(_yieldEstimate(b))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        b.actionNote ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    )),
                    DataCell(_RowActions(
                      onLogHarvest: () => onRowLog(b),
                      onActivity: () => onRowActivity(b),
                    )),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(CropView b) {
    if (b.status == CropStatus.ready) return 'READY NOW';
    if (b.dueDate == null) return '—';
    return DateFormat('d MMM yyyy').format(b.dueDate!);
  }

  /// Rough yield estimate per acre. These multipliers come from the
  /// HTML mockup's per-crop totals and are intentionally a range so
  /// operators read them as guidance, not commitments.
  static String _yieldEstimate(CropView b) {
    if (b.status == CropStatus.awaiting ||
        b.status == CropStatus.infrastructure) {
      return '—';
    }
    final name = b.name.toLowerCase();
    final ac = b.acreage;
    if (name.contains('cabbage')) {
      return '~${(ac * 160).round()}–${(ac * 200).round()} crates';
    }
    if (name.contains('potato')) {
      return '~${(ac * 20).round()}–${(ac * 30).round()} bags';
    }
    if (name.contains('maize')) {
      return '~${(ac * 25).round()}–${(ac * 35).round()} bags';
    }
    if (name.contains('avocado')) {
      return '~${(ac * 30).round()}–${(ac * 50).round()} crates';
    }
    return '—';
  }
}

class _PlannerStatusTag extends StatelessWidget {
  const _PlannerStatusTag({required this.block});
  final CropView block;
  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String txt) = switch (block.status) {
      CropStatus.ready => (
          const Color(0xFFFADBD8),
          const Color(0xFFC4393B),
          '🔴 URGENT',
        ),
      CropStatus.awaiting => (
          const Color(0xFFFCEDC8),
          const Color(0xFF8A5A0A),
          '🟡 Plant soon',
        ),
      CropStatus.growing => (
          const Color(0xFFE7F0DD),
          const Color(0xFF27500A),
          '🟢 Scheduled',
        ),
      _ => (
          const Color(0xFFEEEEEE),
          const Color(0xFF6B7770),
          block.status.label,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _PriorityText extends StatelessWidget {
  const _PriorityText({required this.block});
  final CropView block;
  @override
  Widget build(BuildContext context) {
    String txt;
    Color? color;
    FontWeight weight = FontWeight.normal;
    if (block.status == CropStatus.ready) {
      txt = '⬆ Immediate';
      color = const Color(0xFFC4393B);
      weight = FontWeight.w700;
    } else if (block.isUrgentAction) {
      txt = '⬆ Urgent';
      color = const Color(0xFF8A5A0A);
      weight = FontWeight.w700;
    } else if (block.status == CropStatus.awaiting) {
      txt = 'Plan';
    } else if (block.dueDate != null &&
        block.dueDate!.difference(DateTime.now()).inDays < 45) {
      txt = '⬆ High';
      weight = FontWeight.w700;
    } else {
      txt = 'Normal';
    }
    return Text(
      txt,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: weight,
      ),
    );
  }
}

// =====================================================================
// Estimated revenue card — fixed financial projection (HTML-derived)
// =====================================================================

class _EstimatedRevenueCard extends StatelessWidget {
  const _EstimatedRevenueCard({required this.blocks});
  final List<CropView> blocks;

  @override
  Widget build(BuildContext context) {
    // Per-enterprise totals derived from the HTML template — these are
    // operator-facing season estimates, not live-computed yields.
    final rows = const [
      _RevRow(
        enterprise: 'Cabbage (all blocks)',
        qty: '~600–730 crates',
        price: '800–1,200/crate',
        revenue: '480,000 – 876,000',
        timing: 'May–Jun 2026',
      ),
      _RevRow(
        enterprise: 'Maize (all blocks)',
        qty: '~150–185 bags',
        price: '2,500–3,500/bag',
        revenue: '375,000 – 647,500',
        timing: 'Jul–Oct 2026',
      ),
      _RevRow(
        enterprise: 'Potatoes (all blocks)',
        qty: '~80–100 bags',
        price: '3,000–5,000/bag',
        revenue: '240,000 – 500,000',
        timing: 'Now + Aug 2026',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '💰 ESTIMATED HARVEST VALUE — CURRENT SEASON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: _NgushishPageState._primary,
            ),
          ),
          const SizedBox(height: 14),
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
                  const TextStyle(fontSize: 12, color: Colors.black87),
              columns: const [
                DataColumn(label: Text('ENTERPRISE')),
                DataColumn(label: Text('QUANTITY ESTIMATE')),
                DataColumn(label: Text('UNIT PRICE (KSh)')),
                DataColumn(label: Text('GROSS REVENUE (KSh)')),
                DataColumn(label: Text('HARVEST TIMING')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text(r.enterprise,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(r.qty)),
                    DataCell(Text(r.price)),
                    DataCell(Text(
                      r.revenue,
                      style:
                          const TextStyle(fontWeight: FontWeight.w800),
                    )),
                    DataCell(Text(r.timing)),
                  ]),
                DataRow(
                  color: WidgetStatePropertyAll(
                      Color(0xFFEAF3DE).withValues(alpha: 0.6)),
                  cells: const [
                    DataCell(Text('TOTAL ESTIMATE',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text('—')),
                    DataCell(Text('—')),
                    DataCell(Text(
                      'KSh 1,095,000 – 2,023,500',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _NgushishPageState._primary,
                      ),
                    )),
                    DataCell(Text('Season 2025/26')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevRow {
  const _RevRow({
    required this.enterprise,
    required this.qty,
    required this.price,
    required this.revenue,
    required this.timing,
  });
  final String enterprise;
  final String qty;
  final String price;
  final String revenue;
  final String timing;
}

// =====================================================================
// Immediate actions — derived from urgent ready/awaiting blocks
// =====================================================================

class _ImmediateActionsCard extends StatelessWidget {
  const _ImmediateActionsCard({required this.blocks});
  final List<CropView> blocks;

  @override
  Widget build(BuildContext context) {
    final ready = blocks.where((b) => b.status == CropStatus.ready).toList();
    // Awaiting-with-urgent-note rows that need planting this week.
    final urgentPlant = blocks
        .where((b) =>
            b.status == CropStatus.awaiting && b.isUrgentAction)
        .toList();
    final otherPlant = blocks
        .where((b) =>
            b.status == CropStatus.awaiting && !b.isUrgentAction)
        .toList();

    final actions = <_ActionLine>[
      for (final b in ready)
        _ActionLine(
          verb: 'HARVEST',
          block: b.block ?? '?',
          crop: b.name,
          detail: b.actionNote ?? '',
        ),
      for (final b in urgentPlant)
        _ActionLine(
          verb: 'PLANT',
          block: b.block ?? '?',
          crop: b.name,
          detail: b.actionNote ?? '',
          urgent: true,
        ),
      for (final b in otherPlant)
        _ActionLine(
          verb: 'PLANT',
          block: b.block ?? '?',
          crop: b.name,
          detail: b.actionNote ?? '',
        ),
    ];

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(width: 3, color: Color(0xFFC4393B)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🔴 IMMEDIATE ACTIONS THIS WEEK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: _NgushishPageState._red,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < actions.length; i++) ...[
            _ActionRow(index: i + 1, line: actions[i]),
            if (i < actions.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ActionLine {
  _ActionLine({
    required this.verb,
    required this.block,
    required this.crop,
    required this.detail,
    this.urgent = false,
  });
  final String verb;
  final String block;
  final String crop;
  final String detail;
  final bool urgent;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.index, required this.line});
  final int index;
  final _ActionLine line;
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: Color(0xFF1A1A18),
        ),
        children: [
          TextSpan(
            text: '$index. ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: '${line.verb} ${line.block} ${line.crop}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: line.verb == 'HARVEST'
                  ? const Color(0xFFC4393B)
                  : (line.urgent
                      ? const Color(0xFF8A5A0A)
                      : _NgushishPageState._primary),
            ),
          ),
          TextSpan(
            text: ' — ${line.detail}',
            style: const TextStyle(
              color: _NgushishPageState._txt2,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Observations placeholder
// =====================================================================

class _ObservationsPlaceholder extends StatelessWidget {
  const _ObservationsPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '📝 RECENT OBSERVATIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No observations recorded yet. Field issues reported via '
              'the 🌿 Issue button will appear here once the observation '
              'feed is wired in.',
              style: TextStyle(
                fontSize: 12,
                color: _NgushishPageState._txt2,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Blocks + Harvest action bars (now host the Issue + Register CTAs that
// used to sit in the page header)
// =====================================================================

class _BlocksActionBar extends StatelessWidget {
  const _BlocksActionBar({
    required this.onRegister,
    required this.onLogIssue,
  });
  final VoidCallback onRegister;
  final VoidCallback onLogIssue;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: onRegister,
          icon: const Text('📋', style: TextStyle(fontSize: 13)),
          label: const Text('Register block'),
          style: FilledButton.styleFrom(
            backgroundColor: _NgushishPageState._primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onLogIssue,
          icon: const Text('🌿', style: TextStyle(fontSize: 13)),
          label: const Text('Report issue'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _NgushishPageState._red,
            side: const BorderSide(color: Color(0xFFC4393B)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _HarvestActionBar extends StatelessWidget {
  const _HarvestActionBar({required this.onLogHarvest});
  final VoidCallback onLogHarvest;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: onLogHarvest,
          icon: const Text('🌾', style: TextStyle(fontSize: 13)),
          label: const Text('Log harvest'),
          style: FilledButton.styleFrom(
            backgroundColor: _NgushishPageState._primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

/// Per-row icon cluster used by both the Blocks register and Harvest
/// planner tables. Exposes either an "Issue" (blocks) or "Log harvest"
/// (planner) primary action plus a shared "Activity" history button.
class _RowActions extends StatelessWidget {
  const _RowActions({this.onIssue, this.onLogHarvest, required this.onActivity})
      : assert(onIssue != null || onLogHarvest != null,
            'Pass either onIssue (Blocks) or onLogHarvest (Harvest)');

  final VoidCallback? onIssue;
  final VoidCallback? onLogHarvest;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onIssue != null)
          IconButton(
            tooltip: 'Report issue',
            onPressed: onIssue,
            icon: const Icon(
              Icons.report_gmailerrorred_outlined,
              size: 18,
              color: Color(0xFFC4393B),
            ),
            visualDensity: VisualDensity.compact,
          ),
        if (onLogHarvest != null)
          IconButton(
            tooltip: 'Log harvest',
            onPressed: onLogHarvest,
            icon: const Icon(
              Icons.agriculture_outlined,
              size: 18,
              color: Color(0xFF27500A),
            ),
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          tooltip: 'View activity',
          onPressed: onActivity,
          icon: const Icon(
            Icons.history_outlined,
            size: 18,
            color: Color(0xFF6B7770),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// =====================================================================
// Error view
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
          'Could not load Ngusishi data',
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
