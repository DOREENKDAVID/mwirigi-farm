import 'package:flutter/material.dart';

import '../../core/models/brooder.dart';
import '../../core/service/api_service.dart';

/// 7-day rollup of occurrences for a single brooder cycle. Calls
/// GET /api/layers/brooder/occurrences/weekly?brooderId=... once on
/// mount and renders one row per occurrence type with count +
/// number affected. Empty state when nothing was logged in the
/// window.
class BrooderWeeklyReport extends StatefulWidget {
  const BrooderWeeklyReport({super.key, required this.brooderId});

  final String brooderId;

  @override
  State<BrooderWeeklyReport> createState() => _BrooderWeeklyReportState();
}

class _BrooderWeeklyReportState extends State<BrooderWeeklyReport> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getBrooderWeeklyReport(widget.brooderId);
  }

  @override
  void didUpdateWidget(covariant BrooderWeeklyReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brooderId != widget.brooderId) {
      _future = ApiService.getBrooderWeeklyReport(widget.brooderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Could not load weekly report: ${snap.error.toString().replaceFirst('Exception: ', '')}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF854F0B)),
            ),
          );
        }
        final data = snap.data ?? const <String, dynamic>{};
        final rows = (data['byType'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();

        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No occurrences logged in the last 7 days.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          );
        }

        // Sort by affected desc so the most impactful sits on top.
        rows.sort(
          (a, b) => ((b['affected'] as num?) ?? 0).compareTo(
            (a['affected'] as num?) ?? 0,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in rows) _Row(row: r),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final wire = (row['type'] ?? '').toString();
    final label = BrooderOccurrenceType.values
        .firstWhere(
          (t) => t.wire == wire,
          orElse: () => BrooderOccurrenceType.other,
        )
        .label;
    final count = (row['count'] as num?)?.toInt() ?? 0;
    final affected = (row['affected'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count event${count == 1 ? '' : 's'}'
            '${affected > 0 ? ' · $affected affected' : ''}',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
