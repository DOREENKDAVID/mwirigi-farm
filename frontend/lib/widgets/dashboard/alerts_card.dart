import 'package:flutter/material.dart';

import '../../core/models/dashboard_overview.dart';

/// "Active alerts" card. Renders the alerts list from the overview API and
/// supports local dismiss (close icon). Dismissed ids are kept in widget
/// state — a refresh of the page brings them back if still active server-side.
class AlertsCard extends StatefulWidget {
  const AlertsCard({super.key, required this.alerts});

  final List<DashboardAlert> alerts;

  @override
  State<AlertsCard> createState() => _AlertsCardState();
}

class _AlertsCardState extends State<AlertsCard> {
  final Set<int> _dismissed = <int>{};

  @override
  void didUpdateWidget(AlertsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the API stops returning an alert, drop it from our dismissed set
    // so we don't leak ids across refreshes.
    final liveIds = widget.alerts.map((a) => a.id).toSet();
    _dismissed.removeWhere((id) => !liveIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.alerts.where((a) => !_dismissed.contains(a.id)).toList();

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
            'ACTIVE ALERTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No active alerts. Everything looks good.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              _AlertRow(
                alert: visible[i],
                onDismiss: () =>
                    setState(() => _dismissed.add(visible[i].id)),
              ),
              if (i < visible.length - 1) const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onDismiss});

  final DashboardAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (Color bg, IconData icon, Color iconColor) = switch (alert.type) {
      AlertType.danger => (
          const Color(0xFFFCEBEB),
          Icons.warning_amber_rounded,
          const Color(0xFFE24B4A),
        ),
      AlertType.warning => (
          const Color(0xFFFAEEDA),
          Icons.notifications_active_outlined,
          const Color(0xFF854F0B),
        ),
      AlertType.info => (
          const Color(0xFFE6F1FB),
          Icons.info_outline,
          const Color(0xFF185FA5),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 16),
            color: Colors.black45,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}
