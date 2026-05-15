import 'package:flutter/material.dart';

import '../../core/models/feeds.dart';
import 'feed_status_chip.dart';

/// "Bulk feed (silage / Napier)" card. Renders a 3-row read-only table
/// matching the HTML mockup. Editing happens through the backend's
/// PATCH /feeds/bulk-feed/:id endpoint — this card surfaces the data
/// only for now.
class BulkFeedCard extends StatelessWidget {
  const BulkFeedCard({super.key, required this.entries});
  final List<BulkFeed> entries;

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
            'BULK FEED (SILAGE / NAPIER)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No bulk feed records yet.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _BulkRow(entry: entries[i]),
                  if (i < entries.length - 1)
                    const Divider(height: 1, color: Color(0x14000000)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BulkRow extends StatelessWidget {
  const _BulkRow({required this.entry});
  final BulkFeed entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.typeLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry.stockDisplay,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          BulkFeedStatusChip(status: entry.status),
        ],
      ),
    );
  }
}
