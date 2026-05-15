import 'package:flutter/material.dart';

import '../../core/models/ngushish.dart';

/// Small color-coded pill for crop lifecycle status. Mirrors the HTML
/// mockup's `tag-g / tag-t / tag-a` styles via colours carried on the
/// [CropStatus] enum itself.
class CropStatusChip extends StatelessWidget {
  const CropStatusChip({super.key, required this.status});
  final CropStatus status;

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
