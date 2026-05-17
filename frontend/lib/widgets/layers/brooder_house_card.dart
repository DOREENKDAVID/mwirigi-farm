import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_unit.dart';
import 'allocation_plan.dart';
import 'brooder_occurrence_dialog.dart';
import 'brooder_weekly_report.dart';
import 'vaccination_timeline.dart';

/// "Brooder house" card — combines the population/age/transfer KPIs with a
/// progress-to-caging bar, the vaccination timeline, and the allocation
/// plan, all derived from the unified Layers Unit payload.
///
/// Layout:
///   1. Header (🐣 Brooder house · status pill)
///   2. 3 mini-KPIs: Population | Age | Transfer to layer houses
///   3. Progress bar
///   4. Divider + "Vaccination schedule (per vet protocol)" + timeline
///   5. Divider + "Allocation plan when chicks reach 3 months" + 2 cards
class BrooderHouseCard extends StatelessWidget {
  const BrooderHouseCard({
    super.key,
    required this.brooder,
    required this.vaccination,
    required this.allocation,
    this.onChanged,
  });

  final BrooderSection brooder;
  final List<VaccinationStep> vaccination;
  final List<AllocationRow> allocation;
  /// Called after a successful "Log Occurrence" submission so the parent
  /// can refetch the unit payload (mortality counter etc. may shift).
  final VoidCallback? onChanged;

  Future<void> _logOccurrence(BuildContext context) async {
    final logged = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BrooderOccurrenceDialog(
        brooderId: brooder.id,
        brooderLabel: brooder.label ?? 'Brooder house',
      ),
    );
    if (logged == true) {
      onChanged?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Occurrence logged')),
        );
      }
    }
  }

  static const _amber = Color(0xFFD9A640);
  static const _amberBg = Color(0xFFFFF1DD);
  static const _green = Color(0xFF27500A);

  @override
  Widget build(BuildContext context) {
    // Flutter only allows borderRadius with uniform border colors. The
    // design wants a 3px amber accent on the left + a 1px hairline on
    // the other three sides, so we render a uniform-bordered rounded
    // card and overlay the amber accent strip via Stack.
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                brooder: brooder,
                onLogOccurrence: () => _logOccurrence(context),
              ),
              const SizedBox(height: 14),
              _MiniKpis(brooder: brooder),
              const SizedBox(height: 14),
              _ProgressBar(brooder: brooder),
              const _Divider(),
              const _SectionLabel('This week — occurrences logged'),
              const SizedBox(height: 6),
              BrooderWeeklyReport(brooderId: brooder.id),
              const _Divider(),
              const _SectionLabel('Vaccination schedule (per vet protocol)'),
              const SizedBox(height: 10),
              VaccinationTimeline(steps: vaccination),
              const _Divider(),
              const _SectionLabel('Allocation plan when chicks reach 3 months'),
              const SizedBox(height: 10),
              AllocationPlan(
                rows: allocation,
                brooderId: brooder.id,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        // Amber accent strip — same height as the card, rounded on the
        // left to match the card's corners.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 3,
            decoration: const BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.brooder, required this.onLogOccurrence});
  final BrooderSection brooder;
  final VoidCallback onLogOccurrence;

  @override
  Widget build(BuildContext context) {
    final tag = '${brooder.ageDays} days old · '
        '${brooder.daysRemaining} days to caging';
    return Row(
      children: [
        const Expanded(
          child: Text(
            '🐣 Brooder house',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF27500A),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onLogOccurrence,
          icon: const Icon(Icons.report_outlined, size: 14),
          label: const Text('Log occurrence'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF854F0B),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: BrooderHouseCard._amberBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: BrooderHouseCard._amber,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniKpis extends StatelessWidget {
  const _MiniKpis({required this.brooder});
  final BrooderSection brooder;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('d MMM yyyy');

    final tiles = <Widget>[
      _KpiTile(
        bg: const Color(0xFFFFF7E8),
        valueColor: const Color(0xFF854F0B),
        label: 'Population',
        value: fmt.format(brooder.population),
        sub:
            'Day-1 chicks · received ${dateFmt.format(brooder.receivedDate)}',
      ),
      _KpiTile(
        bg: const Color(0xFFEFF5E6),
        valueColor: const Color(0xFF27500A),
        label: 'Age',
        value: 'Day ${brooder.ageDays}',
        sub: 'Of ${brooder.targetDays} days (3 months target)',
      ),
      _KpiTile(
        bg: const Color(0xFFE6F1F0),
        valueColor: const Color(0xFF105D5C),
        label: 'Transfer to layer houses',
        value: dateFmt.format(brooder.transferDate),
        sub: 'In ~${brooder.daysRemaining} days',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 720 ? 3 : 1;
        final width = (constraints.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in tiles) SizedBox(width: width, child: t),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.bg,
    required this.valueColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  final Color bg;
  final Color valueColor;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.brooder});
  final BrooderSection brooder;

  @override
  Widget build(BuildContext context) {
    final pct = brooder.progressPercent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progress to caging',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            Text(
              'Day ${brooder.ageDays} of ${brooder.targetDays} — $pct%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: const Color(0x14000000),
            valueColor: const AlwaysStoppedAnimation<Color>(
              BrooderHouseCard._green,
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: Color(0x14000000)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.black54,
      ),
    );
  }
}
