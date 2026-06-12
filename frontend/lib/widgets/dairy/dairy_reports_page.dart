// Dairy Reports dashboard.
//
// Sticky pill-based filter bar at the top:
//   Row 1 — Report type pills    (Milk · Reproduction · Health · Vaccinations
//                                 enabled in Phase 2; Calves · Workers ·
//                                 Inventory disabled until Phase 2.5)
//   Row 2 — Period pills         (Today · Week · Month · Quarter · Half · Year · Custom)
//   Row 3 — Scope pills          (All houses · House A·B·…  +  All workers · …  +  All cows · …)
//
// Below the bar, the active report renders via a small router that
// switches on `_type`. Each report has its own Future field so we don't
// refetch unrelated reports when the user flips a filter pill.

import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/models/cow.dart';
import '../../core/models/dairy_ops.dart';
import '../../core/models/dairy_report.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/dairy_report_pdf.dart';
import 'dairy_reports/health_report_card.dart';
import 'dairy_reports/reproduction_report_card.dart';
import 'dairy_reports/vaccination_report_card.dart';

class DairyReportsPage extends StatefulWidget {
  const DairyReportsPage({super.key});

  @override
  State<DairyReportsPage> createState() => _DairyReportsPageState();
}

class _DairyReportsPageState extends State<DairyReportsPage> {
  static const _primary = Color(0xFF27500A);
  static const _bg = Color(0xFFF5F4F0);
  static const _txt2 = Color(0xFF6B7770);

  DairyReportType _type = DairyReportType.milk;
  DairyReportPeriod _period = DairyReportPeriod.month;
  DateTimeRange? _customRange;

  // Filter scope. null = "all".
  String? _houseId;
  String? _workerId;
  String? _cowId;

  // Filter option lists — loaded once.
  List<Cow> _cows = const [];
  List<DairyHouseOverview> _houses = const [];
  List<DairyWorkerSummary> _workers = const [];
  bool _optionsLoaded = false;

  // One future per report type. We rebuild only the active one when a
  // filter changes, so flipping pills doesn't trigger four parallel
  // requests for reports the user isn't even looking at.
  Future<MilkProductionReport>? _milkFuture;
  Future<ReproductionReport>? _reproFuture;
  Future<HealthReport>? _healthFuture;
  Future<VaccinationReport>? _vaccinationFuture;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _refetch();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        ApiService.getCows(),
        ApiService.getDairyHousesOverview(),
        ApiService.getDairyWorkers(),
      ]);
      if (!mounted) return;
      setState(() {
        _cows = results[0]
            .whereType<Map>()
            .map((m) => Cow.fromJson(m.cast<String, dynamic>()))
            .toList();
        _houses = results[1]
            .whereType<Map>()
            .map((m) => DairyHouseOverview.fromJson(m.cast<String, dynamic>()))
            .toList();
        _workers = results[2]
            .whereType<Map>()
            .map((m) =>
                DairyWorkerSummary.fromJson(m.cast<String, dynamic>()))
            .toList();
        _optionsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _optionsLoaded = true);
    }
  }

  // Common filter args used by every report request.
  DateTime? get _customStart =>
      _period == DairyReportPeriod.custom ? _customRange?.start : null;
  DateTime? get _customEnd =>
      _period == DairyReportPeriod.custom ? _customRange?.end : null;

  void _refetch() {
    setState(() {
      switch (_type) {
        case DairyReportType.milk:
          _milkFuture = _fetchMilk();
          break;
        case DairyReportType.reproduction:
          _reproFuture = _fetchRepro();
          break;
        case DairyReportType.health:
          _healthFuture = _fetchHealth();
          break;
        case DairyReportType.vaccinations:
          _vaccinationFuture = _fetchVaccinations();
          break;
        case DairyReportType.calves:
        case DairyReportType.worker:
        case DairyReportType.inventory:
          // Phase 2.5 — handled by the _ComingSoon branch in _buildBody.
          break;
      }
    });
  }

  Future<MilkProductionReport> _fetchMilk() async {
    final raw = await ApiService.getDairyMilkReport(
      animalId: _cowId,
      houseId: _houseId,
      workerId: _workerId,
      period: _period.wire,
      startDate: _customStart,
      endDate: _customEnd,
    );
    return MilkProductionReport.fromJson(raw);
  }

  Future<ReproductionReport> _fetchRepro() async {
    final raw = await ApiService.getDairyReproductionReport(
      animalId: _cowId,
      houseId: _houseId,
      workerId: _workerId,
      period: _period.wire,
      startDate: _customStart,
      endDate: _customEnd,
    );
    return ReproductionReport.fromJson(raw);
  }

  Future<HealthReport> _fetchHealth() async {
    final raw = await ApiService.getDairyHealthReport(
      animalId: _cowId,
      houseId: _houseId,
      workerId: _workerId,
      period: _period.wire,
      startDate: _customStart,
      endDate: _customEnd,
    );
    return HealthReport.fromJson(raw);
  }

  Future<VaccinationReport> _fetchVaccinations() async {
    final raw = await ApiService.getDairyVaccinationReport(
      animalId: _cowId,
      houseId: _houseId,
      workerId: _workerId,
      period: _period.wire,
      startDate: _customStart,
      endDate: _customEnd,
    );
    return VaccinationReport.fromJson(raw);
  }

  /// Resolve the filter pills to printable labels — the PDF can't tell
  /// "selected House A" from "selected Maternity" once everything is
  /// just an id, so we look the labels up here and hand them off.
  DairyReportFilterLabels _currentFilterLabels(String periodLabel) {
    String? houseLabel;
    if (_houseId != null) {
      final hit = _houses.where((h) => h.id == _houseId);
      if (hit.isNotEmpty) houseLabel = _displayHouseName(hit.first.name);
    }
    String? workerLabel;
    if (_workerId != null) {
      final hit = _workers.where((w) => w.id == _workerId);
      if (hit.isNotEmpty) workerLabel = hit.first.name;
    }
    String? animalLabel;
    if (_cowId != null) animalLabel = _cowLabelFor(_cowId!);
    return DairyReportFilterLabels(
      periodLabel: periodLabel,
      house: houseLabel,
      worker: workerLabel,
      animal: animalLabel,
    );
  }

  Future<void> _downloadPdf() async => _exportPdf(share: false);
  Future<void> _sharePdf() async => _exportPdf(share: true);

  Future<void> _exportPdf({required bool share}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      Uint8List bytes;
      String name;
      switch (_type) {
        case DairyReportType.milk:
          final r = await (_milkFuture ?? _fetchMilk());
          name = 'Mwirigi-Dairy-Milk-Report';
          bytes = await buildDairyMilkReportPdf(
              report: r, filters: _currentFilterLabels(r.period.label));
        case DairyReportType.reproduction:
          final r = await (_reproFuture ?? _fetchRepro());
          name = 'Mwirigi-Dairy-Reproduction-Report';
          bytes = await buildDairyReproductionReportPdf(
              report: r, filters: _currentFilterLabels(r.period.label));
        case DairyReportType.health:
          final r = await (_healthFuture ?? _fetchHealth());
          name = 'Mwirigi-Dairy-Health-Report';
          bytes = await buildDairyHealthReportPdf(
              report: r, filters: _currentFilterLabels(r.period.label));
        case DairyReportType.vaccinations:
          final r = await (_vaccinationFuture ?? _fetchVaccinations());
          name = 'Mwirigi-Dairy-Vaccination-Report';
          bytes = await buildDairyVaccinationReportPdf(
              report: r, filters: _currentFilterLabels(r.period.label));
        case DairyReportType.calves:
        case DairyReportType.worker:
        case DairyReportType.inventory:
          messenger.showSnackBar(const SnackBar(
            content: Text('Export for this report type is coming in Phase 2.5.'),
          ));
          return;
      }
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      } else {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('PDF export failed: '
            '${e.toString().replaceFirst('Exception: ', '')}'),
      ));
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _period = DairyReportPeriod.custom;
    });
    _refetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Dairy Reports'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _downloadPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Download'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton.icon(
            onPressed: _sharePdf,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(child: _buildFilterBar()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            sliver: SliverToBoxAdapter(child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_type) {
      case DairyReportType.milk:
        return _futureBody<MilkProductionReport>(
          _milkFuture,
          (r) => MilkProductionCard(report: r),
        );
      case DairyReportType.reproduction:
        return _futureBody<ReproductionReport>(
          _reproFuture,
          (r) => ReproductionReportCard(report: r),
        );
      case DairyReportType.health:
        return _futureBody<HealthReport>(
          _healthFuture,
          (r) => HealthReportCard(report: r),
        );
      case DairyReportType.vaccinations:
        return _futureBody<VaccinationReport>(
          _vaccinationFuture,
          (r) => VaccinationReportCard(report: r),
        );
      case DairyReportType.calves:
      case DairyReportType.worker:
      case DairyReportType.inventory:
        return _ComingSoon(type: _type);
    }
  }

  Widget _futureBody<T>(Future<T>? future, Widget Function(T) builder) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _ErrorCard(
            message: snap.error.toString(),
            onRetry: _refetch,
          );
        }
        return builder(snap.data as T);
      },
    );
  }

  // ─────────────────── filter bar ───────────────────

  Widget _buildFilterBar() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pillRow(
            label: 'Report',
            children: [
              for (final t in DairyReportType.values)
                _Pill(
                  label: t.label,
                  selected: _type == t,
                  disabled: !t.enabled,
                  onTap: t.enabled
                      ? () {
                          // Flipping report type kicks off the matching
                          // request via _refetch(); it only fires for
                          // the active report so other reports stay
                          // cached if the user toggles back.
                          setState(() => _type = t);
                          _refetch();
                        }
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 6),
          _pillRow(
            label: 'Period',
            children: [
              for (final p in DairyReportPeriod.values)
                _Pill(
                  label: p == DairyReportPeriod.custom && _customRange != null
                      ? _customLabel()
                      : p.label,
                  selected: _period == p,
                  onTap: () async {
                    if (p == DairyReportPeriod.custom) {
                      await _pickCustomRange();
                    } else {
                      setState(() {
                        _period = p;
                        _customRange = null;
                      });
                      _refetch();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          _pillRow(
            label: 'House',
            children: [
              _Pill(
                label: 'All houses',
                selected: _houseId == null,
                onTap: () {
                  setState(() => _houseId = null);
                  _refetch();
                },
              ),
              if (_optionsLoaded)
                for (final h in _houses)
                  _Pill(
                    label: _displayHouseName(h.name),
                    selected: _houseId == h.id,
                    onTap: () {
                      setState(() => _houseId = h.id);
                      _refetch();
                    },
                  ),
            ],
          ),
          const SizedBox(height: 6),
          _pillRow(
            label: 'Worker',
            children: [
              _Pill(
                label: 'All workers',
                selected: _workerId == null,
                onTap: () {
                  setState(() => _workerId = null);
                  _refetch();
                },
              ),
              if (_optionsLoaded)
                for (final w in _workers)
                  _Pill(
                    label: w.name,
                    selected: _workerId == w.id,
                    onTap: () {
                      setState(() => _workerId = w.id);
                      _refetch();
                    },
                  ),
            ],
          ),
          const SizedBox(height: 6),
          _pillRow(
            label: 'Cow',
            children: [
              _Pill(
                label: 'All cows',
                selected: _cowId == null,
                onTap: () {
                  setState(() => _cowId = null);
                  _refetch();
                },
              ),
              if (_optionsLoaded)
                ActionChip(
                  label: Text(
                    _cowId == null
                        ? 'Pick a cow…'
                        : _cowLabelFor(_cowId!) ?? 'Pick a cow…',
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _cowId != null
                      ? const Color(0xFFEAF3DE)
                      : Colors.white,
                  side: BorderSide(
                    color: _cowId != null
                        ? _primary
                        : const Color(0x22000000),
                  ),
                  onPressed: _openCowPicker,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillRow({required String label, required List<Widget> children}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _txt2,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _customLabel() {
    if (_customRange == null) return 'Custom';
    final fmt = DateFormat('d MMM');
    return '${fmt.format(_customRange!.start)} → ${fmt.format(_customRange!.end)}';
  }

  String? _cowLabelFor(String id) {
    final hit = _cows.where((c) => c.id == id);
    if (hit.isEmpty) return null;
    final c = hit.first;
    return c.nickname == null ? c.tag : '${c.tag} · ${c.nickname}';
  }

  String _displayHouseName(String raw) {
    if (raw.toLowerCase() == 'dairy maternity') return 'Maternity';
    if (raw.toLowerCase().startsWith('dairy ')) {
      return 'House ${raw.substring(6)}';
    }
    return raw;
  }

  Future<void> _openCowPicker() async {
    final picked = await showModalBottomSheet<Cow?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CowPickerSheet(cows: _cows, selectedId: _cowId),
    );
    if (picked == null && _cowId == null) return;
    setState(() => _cowId = picked?.id);
    _refetch();
  }
}

// ════════════════════════ filter pill widget ════════════════════════

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    this.disabled = false,
    this.onTap,
  });
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = disabled
        ? const Color(0xFFA8A8A8)
        : selected
            ? Colors.white
            : const Color(0xFF27500A);
    final bg = disabled
        ? const Color(0xFFEDEDED)
        : selected
            ? const Color(0xFF27500A)
            : Colors.white;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: disabled
                ? const Color(0x22000000)
                : selected
                    ? const Color(0xFF27500A)
                    : const Color(0x22000000),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ persistent header ════════════════════════

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FilterHeaderDelegate({required this.child});
  final Widget child;

  static const double _height = 230;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext c, double shrinkOffset, bool overlapsContent) =>
      SizedBox(height: _height, child: child);

  @override
  bool shouldRebuild(_FilterHeaderDelegate old) => old.child != child;
}

// ════════════════════════ cow picker bottom sheet ════════════════════════

class _CowPickerSheet extends StatefulWidget {
  const _CowPickerSheet({required this.cows, this.selectedId});
  final List<Cow> cows;
  final String? selectedId;

  @override
  State<_CowPickerSheet> createState() => _CowPickerSheetState();
}

class _CowPickerSheetState extends State<_CowPickerSheet> {
  late final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.cows
        : widget.cows
            .where((c) =>
                c.tag.toLowerCase().contains(q) ||
                (c.nickname ?? '').toLowerCase().contains(q))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pick a cow',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF27500A),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search by tag or name…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.selectedId != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Clear cow filter'),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final selected = c.id == widget.selectedId;
                    return ListTile(
                      title: Text(c.tag),
                      subtitle: c.nickname == null ? null : Text(c.nickname!),
                      trailing: selected
                          ? const Icon(Icons.check, color: Color(0xFF27500A))
                          : null,
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════ Milk Production card ════════════════════════

class MilkProductionCard extends StatelessWidget {
  const MilkProductionCard({super.key, required this.report});
  final MilkProductionReport report;

  static const _primary = Color(0xFF27500A);
  static const _bar = Color(0xFF7DA567);
  static const _txt2 = Color(0xFF6B7770);

  @override
  Widget build(BuildContext context) {
    final r = report;
    final periodFmt = DateFormat('d MMM yy');
    final delta = r.totals.deltaPct;
    final deltaColor = delta == null
        ? _txt2
        : delta >= 0
            ? const Color(0xFF1D9E75)
            : const Color(0xFFC4393B);
    final deltaText = delta == null
        ? '— vs previous'
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs previous';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── KPI strip ──
        _kpiGrid([
          _KpiCell(
            label: 'TOTAL LITRES',
            value: r.totals.litres.toStringAsFixed(1),
            suffix: 'L',
            sub: '${r.period.label} · ${periodFmt.format(r.period.start)} → ${periodFmt.format(r.period.end)}',
            color: _primary,
          ),
          _KpiCell(
            label: 'AVG / COW',
            value: r.totals.avgPerCow.toStringAsFixed(1),
            suffix: 'L',
            sub: '${r.totals.activeCows} active cow${r.totals.activeCows == 1 ? '' : 's'}',
            color: _primary,
          ),
          _KpiCell(
            label: 'BEST PRODUCER',
            value: r.best?.tag ?? '—',
            sub: r.best == null
                ? 'No production yet'
                : '${r.best!.litres.toStringAsFixed(1)} L · ${r.best!.nickname ?? ''}',
            color: const Color(0xFF1D9E75),
          ),
          _KpiCell(
            label: 'LOWEST PRODUCER',
            value: r.lowest?.tag ?? '—',
            sub: r.lowest == null
                ? '—'
                : '${r.lowest!.litres.toStringAsFixed(1)} L · ${r.lowest!.nickname ?? ''}',
            color: const Color(0xFFAC7B0F),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Previous-period comparison strip ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Row(
            children: [
              Icon(
                delta == null
                    ? Icons.remove
                    : delta >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                color: deltaColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deltaText,
                      style: TextStyle(
                        color: deltaColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Previous: ${r.totals.prevLitres.toStringAsFixed(1)} L'
                      ' · This period: ${r.totals.litres.toStringAsFixed(1)} L',
                      style: const TextStyle(fontSize: 11, color: _txt2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Daily trend chart ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DAILY TREND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: _txt2,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: _DailyTrendChart(points: r.daily),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Session breakdown ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SESSION BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: _txt2,
                ),
              ),
              const SizedBox(height: 12),
              _sessionRow('Dawn', r.totals.sessions.dawn, r.totals.litres),
              _sessionRow('AM',   r.totals.sessions.am,   r.totals.litres),
              _sessionRow('Mid',  r.totals.sessions.mid,  r.totals.litres),
              _sessionRow('PM',   r.totals.sessions.pm,   r.totals.litres),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sessionRow(String label, double value, double total) {
    final pct = total > 0 ? (value / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} L',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: pct.clamp(0, 1),
              backgroundColor: const Color(0xFFEFEDE6),
              valueColor: const AlwaysStoppedAnimation(_bar),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid(List<_KpiCell> cells) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 4 : 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final cell in cells)
              SizedBox(
                width: (c.maxWidth - 10 * (cols - 1)) / cols,
                child: cell,
              ),
          ],
        );
      },
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.suffix,
  });
  final String label;
  final String value;
  final String? suffix;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF99A39B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.05,
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    suffix!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7770)),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendChart extends StatelessWidget {
  const _DailyTrendChart({required this.points});
  final List<MilkReportDailyPoint> points;

  static const _bar = Color(0xFF7DA567);
  static const _grid = Color(0xFFE6EBE0);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No milk records for this period.',
          style: TextStyle(fontSize: 12, color: Color(0xFF99A39B)),
        ),
      );
    }
    final maxY = points.fold<double>(0, (m, p) => p.litres > m ? p.litres : m);
    final yMax = (maxY <= 0 ? 10 : (maxY * 1.15)).ceilToDouble();
    // Show every N-th label to keep the axis legible when the range
    // is wide. ~12 labels max.
    final step = (points.length / 12).ceil().clamp(1, 30);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: _grid, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yMax / 4,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF99A39B),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                if (i % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    points[i].dow,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF99A39B),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].litres,
                  color: _bar,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ════════════════════════ misc placeholders ════════════════════════

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.type});
  final DairyReportType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: [
          Text(
            type.label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF27500A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming in Phase 2 of the Dairy Reports rollout. '
            'The pill bar is already wired up so this view will light up '
            'as soon as the matching endpoint lands.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7770)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load report.\n${message.replaceFirst('Exception: ', '')}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
