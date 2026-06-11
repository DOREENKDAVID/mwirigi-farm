// "Daily totals" card for the Dairy Overview pill.
//
// Two stacked panels — kept compact for mobile:
//   • AM/MID/PM SESSION SUMMARY (active session)
//       Gross collected · calf deduction · household · net for dispatch
//   • TODAY ACROSS SESSIONS
//       AM · Midday · PM · Day total (net)
//
// Mirrors the panels embedded in MilkLoggingPanel — extracted so the
// Overview tab can show the day-totals snapshot without rendering the
// whole milk-logging workflow on mobile.

import 'package:flutter/material.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';

class DairyDayTotalsCard extends StatefulWidget {
  const DairyDayTotalsCard({super.key});
  @override
  State<DairyDayTotalsCard> createState() => DairyDayTotalsCardState();
}

class DairyDayTotalsCardState extends State<DairyDayTotalsCard> {
  static const _primary = Color(0xFF27500A);

  late Future<DayNetSummary> _future;
  // Active "session" panel — AM by default, falls back to whichever
  // session has logged litres if the user reopens later in the day.
  MilkSession _session = MilkSession.am;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DayNetSummary> _load() async {
    final raw = await ApiService.getDairyTodayNet();
    final parsed = DayNetSummary.fromJson(raw);
    // Auto-select the latest session that has any activity so the card
    // shows the most relevant context after each milking pass. Falls
    // back to AM when nothing has been logged yet today.
    _session = MilkSession.am;
    for (final s in MilkSession.values) {
      if ((parsed.sessions[s] ?? 0) > 0) {
        _session = s;
      }
    }
    return parsed;
  }

  Future<void> reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: FutureBuilder<DayNetSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: reload,
            );
          }
          final summary = snap.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'DAILY TOTALS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: _primary,
                    ),
                  ),
                  const Spacer(),
                  _SessionToggle(
                    selected: _session,
                    onChanged: (s) => setState(() => _session = s),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: reload,
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 700;
                  final left =
                      _DeductionPanel(session: _session, summary: summary);
                  final right = _AcrossSessionsPanel(summary: summary);
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 12),
                        Expanded(child: right),
                      ],
                    );
                  }
                  return Column(
                    children: [left, const SizedBox(height: 12), right],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionToggle extends StatelessWidget {
  const _SessionToggle({required this.selected, required this.onChanged});
  final MilkSession selected;
  final ValueChanged<MilkSession> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in MilkSession.values) _Pill(
            label: s.wire == 'MID' ? 'MID' : s.wire,
            active: s == selected,
            onTap: () => onChanged(s),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF27500A) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF6B7770),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _DeductionPanel extends StatelessWidget {
  const _DeductionPanel({required this.session, required this.summary});
  final MilkSession session;
  final DayNetSummary summary;

  @override
  Widget build(BuildContext context) {
    final sessionGross = summary.sessions[session] ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading('${session.label} SESSION SUMMARY'),
          const SizedBox(height: 8),
          _Row(
            label: 'Gross collected',
            value: '${_fmt(sessionGross)} L',
          ),
          _Row(
            label:
                'Calves under 4mo (${summary.calfDeduction.toStringAsFixed(0)} × 1L)',
            value: '− ${_fmt(summary.calfDeduction)} L',
            minus: true,
          ),
          _Row(
            label: 'Household usage',
            value: '− ${_fmt(summary.householdDeduction)} L',
            minus: true,
          ),
          _Row(
            label: 'Bucket weight (${summary.milkedCows} × 0.8)',
            value: '− ${_fmt(summary.bucketDeduction)} L',
            minus: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0x22000000)),
          ),
          _Row(
            label: 'Net for dispatch (day)',
            value: '${_fmt(summary.dayNet)} L',
            net: true,
          ),
        ],
      ),
    );
  }
}

class _AcrossSessionsPanel extends StatelessWidget {
  const _AcrossSessionsPanel({required this.summary});
  final DayNetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading('TODAY ACROSS SESSIONS'),
          const SizedBox(height: 8),
          for (final s in MilkSession.values)
            _Row(
              label: s.label,
              value: '${_fmt(summary.sessions[s] ?? 0)} L',
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0x14000000)),
          ),
          _Row(
            label: 'Day total (net)',
            value: '${_fmt(summary.dayNet)} L',
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF6B7770),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.minus = false,
    this.net = false,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool minus;
  final bool net;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final muted = const Color(0xFF6B7770);
    final primary = const Color(0xFF27500A);
    final labelStyle = TextStyle(
      fontSize: 12,
      color: net || bold ? primary : muted,
      fontWeight: net || bold ? FontWeight.w700 : FontWeight.w500,
    );
    final valueStyle = TextStyle(
      fontSize: net ? 16 : (bold ? 14 : 13),
      color: net || bold
          ? primary
          : (minus ? const Color(0xFFB42318) : Colors.black87),
      fontWeight: net || bold ? FontWeight.w800 : FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load daily totals.\n$message',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _fmt(num v) {
  if (v == 0) return '0';
  if (v == v.toInt()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
