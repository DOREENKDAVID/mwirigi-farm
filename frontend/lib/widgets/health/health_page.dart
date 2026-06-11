import 'package:flutter/material.dart';

import '../../core/models/health.dart';
import '../../core/service/api_service.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import 'active_treatments_table.dart';
import 'add_treatment_dialog.dart';
import 'health_pill_tabs.dart';
import 'herd_calendar.dart';
import 'edit_vaccine_dialog.dart';
import 'log_vaccine_dialog.dart';
import 'vaccination_schedule_table.dart';
import 'vet_protocol_tabs.dart';

/// Health & Vaccines module — pill-driven layout matching Dairy / Layers /
/// Feedlot. Composition top → bottom:
///   • Page header (icon · title · subtitle)
///   • 3 KPI cards (pinned across pills)
///   • Pill row (5 sections)
///   • Body for the active pill
class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthData {
  _HealthData({
    required this.kpis,
    required this.vaccinations,
    required this.treatments,
    required this.reference,
  });

  final HealthKpis kpis;
  final List<VaccinationRow> vaccinations;
  final List<TreatmentRow> treatments;
  final ProtocolReference reference;
}

class _HealthPageState extends State<HealthPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  Future<_HealthData>? _future;
  HealthTab _active = HealthTab.overview;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HealthData> _load() async {
    final results = await Future.wait([
      ApiService.getHealthKpis(),
      ApiService.getHealthVaccinations(),
      ApiService.getHealthTreatments(),
      ApiService.getHealthProtocolReference(),
    ]);

    final kpisRaw = results[0] as Map<String, dynamic>;
    final vaccsRaw = results[1] as List<dynamic>;
    final treatsRaw = results[2] as List<dynamic>;
    final refRaw = results[3] as Map<String, dynamic>;

    return _HealthData(
      kpis: HealthKpis.fromJson(kpisRaw.cast<String, dynamic>()),
      vaccinations: vaccsRaw
          .whereType<Map>()
          .map((m) => VaccinationRow.fromJson(m.cast<String, dynamic>()))
          .toList(),
      treatments: treatsRaw
          .whereType<Map>()
          .map((m) => TreatmentRow.fromJson(m.cast<String, dynamic>()))
          .toList(),
      reference: ProtocolReference.fromJson(refRaw.cast<String, dynamic>()),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openLogVaccine() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const LogVaccineDialog(),
    );
    if (result == true) await _refresh();
  }

  Future<void> _openEditVaccine(VaccinationRow row) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EditVaccineDialog(row: row),
    );
    if (result == true) await _refresh();
  }

  Future<void> _openAddTreatment({TreatmentRow? prefillFrom}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddTreatmentDialog(
        initialTag: prefillFrom?.tag,
        initialUnit: prefillFrom?.unit,
        initialDiagnosis: prefillFrom?.diagnosis,
      ),
    );
    if (result == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_HealthData>(
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
              const _PageHeader(),
              const SizedBox(height: 16),
              _KpiRow(kpis: data.kpis),
              const SizedBox(height: 16),
              HealthPillTabs(
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

  List<Widget> _tabBody(_HealthData data) {
    switch (_active) {
      case HealthTab.overview:
        return [
          _OverviewActions(
            onLogVaccine: _openLogVaccine,
            onAddTreatment: _openAddTreatment,
            onOpenCalendar: () => setState(() => _active = HealthTab.calendar),
            onOpenVaccinations:
                () => setState(() => _active = HealthTab.vaccinations),
            onOpenTreatments:
                () => setState(() => _active = HealthTab.treatments),
          ),
          const SizedBox(height: 16),
          _GlanceRow(
            vaccinations: data.vaccinations.length,
            treatments: data.treatments.length,
            kpis: data.kpis,
          ),
        ];
      case HealthTab.calendar:
        return [HerdCalendar(rows: data.vaccinations, today: DateTime.now())];
      case HealthTab.vaccinations:
        return [
          _SectionActionBar(
            label: 'Log Vaccine',
            emoji: '💉',
            onTap: _openLogVaccine,
          ),
          const SizedBox(height: 10),
          VaccinationScheduleTable(
            rows: data.vaccinations,
            onEdit: _openEditVaccine,
          ),
        ];
      case HealthTab.treatments:
        return [
          ActiveTreatmentsTable(
            rows: data.treatments,
            onAdd: _openAddTreatment,
            onRowTap: (row) => _openAddTreatment(prefillFrom: row),
          ),
        ];
      case HealthTab.protocols:
        return [VetProtocolTabs(reference: data.reference)];
    }
  }
}

// =====================================================================
// Page header
// =====================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE6F1F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('💉', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health & Vaccines',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _HealthPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Cross-unit health · Vet protocols · Schedules',
                style: TextStyle(
                  fontSize: 12,
                  color: _HealthPageState._txt2,
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
// KPI row (pinned on every pill)
// =====================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final HealthKpis kpis;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      KpiCard(
        label: 'Vaccines due (7d)',
        value: _formatCount(kpis.vaccinesDue7d),
        sub: 'Animals requiring vaccination',
        trendColor: const Color(0xFF854F0B),
      ),
      KpiCard(
        label: 'Under treatment',
        value: '${kpis.underTreatment}',
        sub: kpis.treatmentBreakdown,
      ),
      KpiCard(
        label: 'Compliance rate',
        value: '${kpis.complianceRate}%',
        sub: 'Schedule adherence',
        trendColor: kpis.complianceRate >= 90
            ? const Color(0xFF27500A)
            : kpis.complianceRate >= 70
                ? const Color(0xFF854F0B)
                : const Color(0xFFB52C2B),
      ),
    ];

    return KpiGrid(children: cards);
  }

  static String _formatCount(int n) {
    if (n >= 1000) {
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i += 1) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return '$n';
  }
}

// =====================================================================
// Overview pill — quick actions + glance row
// =====================================================================

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.onLogVaccine,
    required this.onAddTreatment,
    required this.onOpenCalendar,
    required this.onOpenVaccinations,
    required this.onOpenTreatments,
  });
  final VoidCallback onLogVaccine;
  final VoidCallback onAddTreatment;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenVaccinations;
  final VoidCallback onOpenTreatments;

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
              color: _HealthPageState._txt2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickPill(
                emoji: '💉',
                label: 'Log vaccine',
                onTap: onLogVaccine,
              ),
              _QuickPill(
                emoji: '🩺',
                label: 'Add treatment',
                onTap: onAddTreatment,
              ),
              _QuickPill(
                emoji: '📅',
                label: 'Calendar',
                onTap: onOpenCalendar,
              ),
              _QuickPill(
                emoji: '📋',
                label: 'Schedule',
                onTap: onOpenVaccinations,
              ),
              _QuickPill(
                emoji: '🩺',
                label: 'Treatments',
                onTap: onOpenTreatments,
              ),
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
                color: _HealthPageState._primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlanceRow extends StatelessWidget {
  const _GlanceRow({
    required this.vaccinations,
    required this.treatments,
    required this.kpis,
  });
  final int vaccinations;
  final int treatments;
  final HealthKpis kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        final schedule = _GlanceCard(
          emoji: '💉',
          title: 'Vaccination schedule',
          headline: '$vaccinations rows',
          sub: '${kpis.vaccinesDue7d} animals due in the next 7 days',
        );
        final treats = _GlanceCard(
          emoji: '🩺',
          title: 'Active treatments',
          headline: '$treatments cases',
          sub: kpis.treatmentBreakdown,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: schedule),
              const SizedBox(width: 12),
              Expanded(child: treats),
            ],
          );
        }
        return Column(
          children: [schedule, const SizedBox(height: 12), treats],
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
              color: const Color(0xFFE1F5EE),
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
                    color: _HealthPageState._txt2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _HealthPageState._primary,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _HealthPageState._txt2,
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
// Section action bar — used by the Vaccinations pill
// =====================================================================

class _SectionActionBar extends StatelessWidget {
  const _SectionActionBar({
    required this.label,
    required this.emoji,
    required this.onTap,
  });
  final String label;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: onTap,
          icon: Text(emoji, style: const TextStyle(fontSize: 14)),
          label: Text('+ $label'),
          style: FilledButton.styleFrom(
            backgroundColor: _HealthPageState._primary,
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
          'Could not load Health module',
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
