// Health Reports dashboard — accessible from Reports → Health Report card.
//
// Filter dimensions:
//   Period  — PeriodFilterPanel (shared widget, same wire-format as Dairy / Layers)
//   Unit    — HouseFilterPills  (All Units · Dairy · Layers · Piggery)
//
// Data sources:
//   GET /api/health/vaccinations?unit=<X>  — unit-filtered server-side
//   GET /api/health/treatments?activeOnly=false — filtered client-side by
//       unit + period (treatments table has no unit param today)
//
// All aggregation (done / overdue / due-7d / active-cases counts) is
// computed here from the returned rows so the backend needs no changes.
//
// Filtering rules (spec §4–5):
//   Vaccinations : row.unit == selectedUnit  (or all if selectedUnit == null)
//   Treatments   : treatment.unit == selectedUnit
//                  AND treatment.startDate ∈ period  (or still active in period)
//   Combined     : both filters applied simultaneously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/health.dart';
import '../../core/service/api_service.dart';
import '../../core/util/period.dart';
import '../dairy/dairy_reports/report_widgets.dart';
import '../shared/house_filter_pills.dart';
import '../shared/period_filter_panel.dart';
import 'status_badge.dart';

class HealthReportsPage extends StatefulWidget {
  const HealthReportsPage({super.key});

  @override
  State<HealthReportsPage> createState() => _HealthReportsPageState();
}

// ── Internal data bag ─────────────────────────────────────────────────

class _PageData {
  const _PageData({
    required this.vaccinations,
    required this.allTreatments,
  });
  final List<VaccinationRow> vaccinations;
  final List<TreatmentRow> allTreatments;
}

// ── State ─────────────────────────────────────────────────────────────

class _HealthReportsPageState extends State<HealthReportsPage> {
  static const _primary = Color(0xFF27500A);

  // Filter state — both default to "all / this month", matching spec §2.
  PeriodPreset _period = PeriodPreset.thisMonth;
  DateTimeRange? _customRange;
  String? _selectedUnit; // null == "All Units"

  Future<_PageData>? _future;

  // Unit pills — static because the list never changes at runtime.
  static const _unitOptions = [
    HouseFilterOption(id: 'Dairy', label: 'Dairy', emoji: '🐄'),
    HouseFilterOption(id: 'Layers', label: 'Layers', emoji: '🐔'),
    HouseFilterOption(id: 'Piggery', label: 'Piggery', emoji: '🐷'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<_PageData> _load() async {
    final results = await Future.wait([
      // Vaccinations are unit-filtered server-side — avoids shipping the
      // full cross-unit list to the client when scoped to one unit.
      ApiService.getHealthVaccinations(unit: _selectedUnit),
      // Treatments have no server-side unit param; filter client-side.
      ApiService.getHealthTreatments(activeOnly: false),
    ]);

    final vaccsRaw = results[0];
    final treatsRaw = results[1];

    return _PageData(
      vaccinations: vaccsRaw
          .whereType<Map>()
          .map((m) => VaccinationRow.fromJson(m.cast<String, dynamic>()))
          .toList(),
      allTreatments: treatsRaw
          .whereType<Map>()
          .map((m) => TreatmentRow.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }

  // Re-fetch when unit changes (vaccinations need a new ?unit= param).
  // Re-filter treatments happens automatically on build from allTreatments.
  void _refetch() => setState(() => _future = _load());

  // ── Computed helpers ─────────────────────────────────────────────────

  ResolvedRange get _range => resolveRange(
        period: _period,
        customStart: _customRange?.start,
        customEnd: _customRange?.end,
      );

  // Treatments filtered by unit (already done for vaccinations server-side)
  // and by period: started-in-period OR still active during the period.
  List<TreatmentRow> _filteredTreatments(
    List<TreatmentRow> all,
    ResolvedRange range,
  ) {
    return all.where((t) {
      if (_selectedUnit != null &&
          t.unit.toLowerCase() != _selectedUnit!.toLowerCase()) {
        return false;
      }
      // Active in period: started on or before range.end AND (no end date
      // OR end date on or after range.start).
      final startedByRangeEnd = !t.startDate.isAfter(range.end);
      final notEndedBeforeRange =
          t.endDate == null || !t.endDate!.isBefore(range.start);
      return startedByRangeEnd && notEndedBeforeRange;
    }).toList();
  }

  // ── Aggregation ──────────────────────────────────────────────────────

  int _doneThisPeriod(List<VaccinationRow> rows, ResolvedRange range) =>
      rows
          .where((r) =>
              r.lastDoneAt != null &&
              !r.lastDoneAt!.isBefore(range.start) &&
              !r.lastDoneAt!.isAfter(range.end))
          .length;

  int _overdueCount(List<VaccinationRow> rows) =>
      rows.where((r) => r.status == 'OVERDUE').length;

  int _due7dCount(List<VaccinationRow> rows) => rows
      .where((r) =>
          r.status == 'DUE_NOW' ||
          r.status == 'DUE_WINDOW_OPEN' ||
          (r.status == 'DUE_SOON' && (r.daysUntilDue ?? 999) <= 7))
      .length;

  int _activeCases(List<TreatmentRow> rows) =>
      rows.where((r) => r.status == 'ACTIVE' || r.status == 'IMPROVING').length;

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Health Reports',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                DateFormat('d MMM yyyy').format(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message:
                  snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refetch,
            );
          }

          final data = snap.data!;
          final range = _range;
          final treatments = _filteredTreatments(data.allTreatments, range);

          return RefreshIndicator(
            onRefresh: () async => _refetch(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // ── Filter bar ─────────────────────────────────────────
                PeriodFilterPanel(
                  selectedPeriod: _period,
                  customStartDate: _customRange?.start,
                  customEndDate: _customRange?.end,
                  onCustomRangeSelected: (s, e) =>
                      setState(() => _customRange = DateTimeRange(start: s, end: e)),
                  onChanged: (p) {
                    setState(() => _period = p);
                    // Period change re-filters client-side treatments only;
                    // vaccinations don't need a re-fetch (no period param).
                  },
                ),
                const SizedBox(height: 8),
                // Unit filter pills — matching HouseFilterPills visual style.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F4F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: _primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Unit:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      HouseFilterPills(
                        options: _unitOptions,
                        selectedId: _selectedUnit,
                        allLabel: 'All Units',
                        compact: true,
                        onChanged: (id) {
                          setState(() => _selectedUnit = id);
                          _refetch();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── KPI strip ──────────────────────────────────────────
                ReportKpiGrid(cells: [
                  ReportKpi(
                    label: 'Done (period)',
                    value: '${_doneThisPeriod(data.vaccinations, range)}',
                    sub: 'vaccinations administered',
                    color: reportPrimary,
                  ),
                  ReportKpi(
                    label: 'Overdue',
                    value: '${_overdueCount(data.vaccinations)}',
                    sub: 'need immediate action',
                    color: const Color(0xFFB52C2B),
                  ),
                  ReportKpi(
                    label: 'Due in 7d',
                    value: '${_due7dCount(data.vaccinations)}',
                    sub: 'upcoming vaccines',
                    color: const Color(0xFF854F0B),
                  ),
                  ReportKpi(
                    label: 'Active cases',
                    value: '${_activeCases(treatments)}',
                    sub: 'under treatment now',
                    color: const Color(0xFF854F0B),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Vaccination summary ────────────────────────────────
                _VaccinationSection(
                  rows: data.vaccinations,
                  range: range,
                  unitLabel: _selectedUnit ?? 'All Units',
                ),
                const SizedBox(height: 16),

                // ── Treatment summary ──────────────────────────────────
                _TreatmentSection(
                  rows: treatments,
                  range: range,
                  unitLabel: _selectedUnit ?? 'All Units',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =====================================================================
// Vaccination summary section
// =====================================================================

class _VaccinationSection extends StatelessWidget {
  const _VaccinationSection({
    required this.rows,
    required this.range,
    required this.unitLabel,
  });

  final List<VaccinationRow> rows;
  final ResolvedRange range;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyCard(
        icon: Icons.vaccines_outlined,
        title: 'VACCINATION SCHEDULE',
        message: 'No vaccination records for $unitLabel.',
      );
    }

    final fmt = NumberFormat.decimalPattern();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
              const Text(
                'VACCINATION SCHEDULE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              _ScopeBadge(label: unitLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${rows.length} protocol${rows.length == 1 ? '' : 's'} · ${range.label}',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth >= 640) {
              return _VaccDesktopTable(rows: rows, fmt: fmt);
            }
            return _VaccMobileCards(rows: rows, fmt: fmt);
          }),
        ],
      ),
    );
  }
}

class _VaccDesktopTable extends StatelessWidget {
  const _VaccDesktopTable({required this.rows, required this.fmt});
  final List<VaccinationRow> rows;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(1.6),
        4: FlexColumnWidth(1.6),
        5: FlexColumnWidth(1.5),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x14000000))),
          ),
          children: [
            _Th('Vaccine'),
            _Th('Unit'),
            _Th('Animals'),
            _Th('Last done'),
            _Th('Next due'),
            _Th('Status'),
          ],
        ),
        for (final r in rows)
          TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0F000000))),
            ),
            children: [
              _Td(r.vaccine, bold: true),
              _Td(r.unit),
              _Td(fmt.format(r.animals)),
              _Td(r.lastDone ?? '—', muted: r.lastDone == null),
              _Td(r.nextDue ?? '—', muted: r.nextDue == null),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(status: r.status),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _VaccMobileCards extends StatelessWidget {
  const _VaccMobileCards({required this.rows, required this.fmt});
  final List<VaccinationRow> rows;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in rows) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.vaccine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    StatusBadge(status: r.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.unit} · ${fmt.format(r.animals)} animals',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                _MetaPair('Last done', r.lastDone ?? '—'),
                _MetaPair('Next due', r.nextDue ?? '—'),
              ],
            ),
          ),
          if (r != rows.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

// =====================================================================
// Treatment summary section
// =====================================================================

class _TreatmentSection extends StatelessWidget {
  const _TreatmentSection({
    required this.rows,
    required this.range,
    required this.unitLabel,
  });

  final List<TreatmentRow> rows;
  final ResolvedRange range;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyCard(
        icon: Icons.medical_services_outlined,
        title: 'TREATMENT LOG',
        message: 'No treatment records for $unitLabel in this period.',
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
              const Text(
                'TREATMENT LOG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              _ScopeBadge(label: unitLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${rows.length} case${rows.length == 1 ? '' : 's'} · ${range.label}',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
          const SizedBox(height: 12),
          for (final t in rows) ...[
            _TreatmentCard(row: t),
            if (t != rows.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({required this.row});
  final TreatmentRow row;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      row.tag,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF3E5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        row.unit,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF27500A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  row.diagnosis,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  row.medication,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Started ${fmt.format(row.startDate)}',
                  style: const TextStyle(fontSize: 10, color: Colors.black38),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: row.status),
              const SizedBox(height: 4),
              Text(
                row.statusLabel,
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Shared table building blocks — read-only versions (no edit button)
// =====================================================================

class _Th extends StatelessWidget {
  const _Th(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.bold = false, this.muted = false});
  final String text;
  final bool bold;
  final bool muted;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: muted ? Colors.black38 : const Color(0xFF222222),
          ),
        ),
      );
}

class _MetaPair extends StatelessWidget {
  const _MetaPair(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF3E5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF27500A),
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          Icon(icon, size: 32, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: Color(0xFFE24B4A)),
            const SizedBox(height: 12),
            const Text(
              'Could not load Health Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
