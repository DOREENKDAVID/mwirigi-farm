import 'package:flutter/material.dart';

import '../../core/models/layers_unit.dart';

/// "Vaccination schedule (per vet protocol)" — a vertical list of vaccination
/// steps in the brooder's lifecycle. Each row shows the status pill on the
/// right (DONE / DUE NOW / UPCOMING / OVERDUE) and a leading icon that
/// matches the status color.
///
/// Status colors mirror the HTML mockup tag classes:
///   DONE     → green
///   DUE_NOW  → amber
///   OVERDUE  → red
///   UPCOMING → muted grey
class VaccinationTimeline extends StatelessWidget {
  const VaccinationTimeline({super.key, required this.steps});

  final List<VaccinationStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No vaccination protocol loaded.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in steps) ...[
          _StepRow(step: s),
          if (s != steps.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final VaccinationStep step;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(step.status);
    final dayLabel = step.windowDays > 0
        ? 'Day ${step.dayOffset}-${step.dayOffset + step.windowDays}'
        : 'Day ${step.dayOffset}';
    final subtitle = step.milestone
        ? '$dayLabel · transfer milestone'
        : dayLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: palette.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          // Leading status icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(palette.icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(label: palette.label, color: palette.accent),
        ],
      ),
    );
  }

  static _StatusPalette _palette(String status) {
    switch (status) {
      case 'DONE':
        return const _StatusPalette(
          accent: Color(0xFF27500A),
          bg: Color(0xFFEFF5E6),
          icon: Icons.check,
          label: 'DONE',
        );
      case 'DUE_NOW':
        return const _StatusPalette(
          accent: Color(0xFF854F0B),
          bg: Color(0xFFFFF1DD),
          icon: Icons.priority_high,
          label: 'DUE NOW',
        );
      case 'OVERDUE':
        return const _StatusPalette(
          accent: Color(0xFFE24B4A),
          bg: Color(0xFFFEEBEB),
          icon: Icons.error_outline,
          label: 'OVERDUE',
        );
      case 'UPCOMING':
      default:
        return const _StatusPalette(
          accent: Color(0xFFAAAAAA),
          bg: Color(0xFFF1F1F1),
          icon: Icons.circle_outlined,
          label: 'UPCOMING',
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.accent,
    required this.bg,
    required this.icon,
    required this.label,
  });
  final Color accent;
  final Color bg;
  final IconData icon;
  final String label;
}
