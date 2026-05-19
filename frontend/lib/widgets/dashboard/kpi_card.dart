import 'package:flutter/material.dart';

/// A single key-metric tile. Used for the row of KPI cards on the dashboard.
///
/// Renders a label, a value, and an optional sub-line. If [trend] is provided
/// it appears as a pill below the value.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.trend,
    this.trendColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? sub;
  final String? trend;
  final Color? trendColor;
  // Override for the big-number colour. Used by the Active Alerts
  // tile so an alert count > 0 reads as red at a glance instead of
  // sitting in the same calm farm-green as the other KPIs.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    const surface2 = Color(0xFFF0EFE9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor ?? primary,
              height: 1,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
            ),
          ],
          if (trend != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (trendColor ?? primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                trend!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: trendColor ?? primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
