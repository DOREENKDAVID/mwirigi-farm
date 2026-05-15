import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/dashboard_overview.dart';

/// "5-year goals" card. One stacked progress bar per goal.
/// Bar fill color follows the percentage:
///   ≥ 80% → green (target nearly met)
///   ≥ 50% → teal  (on track)
///   ≥ 30% → amber (needs focus)
///   else   → red   (well behind)
class GoalsCard extends StatelessWidget {
  const GoalsCard({super.key, required this.goals});

  final List<GoalProgress> goals;

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
            '5-YEAR GOALS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < goals.length; i++) ...[
            _GoalRow(goal: goals[i]),
            if (i < goals.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});
  final GoalProgress goal;

  @override
  Widget build(BuildContext context) {
    final pct = goal.percentage;
    final color = pct >= 80
        ? const Color(0xFF639922)
        : pct >= 50
            ? const Color(0xFF1D9E75)
            : pct >= 30
                ? const Color(0xFFEF9F27)
                : const Color(0xFFE24B4A);

    final currentLabel = _formatNum(goal.current);
    final targetLabel = _formatNum(goal.target);
    final pctLabel =
        goal.target > 0 ? '$currentLabel / $targetLabel — $pct%' : currentLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              pctLabel,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 7,
            child: Stack(
              children: [
                Container(color: const Color(0xFFF0EFE9)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (pct.clamp(0, 100)) / 100,
                  child: Container(color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatNum(num n) {
    final fmt = NumberFormat.decimalPattern();
    if (n == n.roundToDouble()) return fmt.format(n.toInt());
    return fmt.format(n);
  }
}
