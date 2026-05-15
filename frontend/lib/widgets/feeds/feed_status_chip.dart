import 'package:flutter/material.dart';

import '../../core/models/feeds.dart';

/// Color-coded pill for raw-material status (CRITICAL / LOW / ADEQUATE).
/// Mirrors the HTML mockup's `tag-r / tag-a / tag-g` styles via colours
/// carried on the [FeedStatus] enum.
class FeedStatusChip extends StatelessWidget {
  const FeedStatusChip({super.key, required this.status});
  final FeedStatus status;

  @override
  Widget build(BuildContext context) {
    final showIcon = status == FeedStatus.critical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(Icons.warning_amber_rounded, size: 12, color: status.fg),
            const SizedBox(width: 4),
          ],
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: status.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class BulkFeedStatusChip extends StatelessWidget {
  const BulkFeedStatusChip({super.key, required this.status});
  final BulkFeedStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.fg,
        ),
      ),
    );
  }
}
