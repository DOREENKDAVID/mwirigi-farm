import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_unit.dart';

/// "Allocation plan when chicks reach 3 months" — two side-by-side cards
/// (POL sale + Replacement). On narrow screens the cards stack.
///
/// Each row pulls the latest revision per allocation type from the backend
/// payload (already deduplicated server-side).
class AllocationPlan extends StatelessWidget {
  const AllocationPlan({super.key, required this.rows});
  final List<AllocationRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No allocation plan recorded yet.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final cards = rows.map((r) => _AllocCard(row: r)).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _AllocCard extends StatelessWidget {
  const _AllocCard({required this.row});
  final AllocationRow row;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(row.type);
    final birds = NumberFormat.decimalPattern().format(row.birds);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F4),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: palette.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Text(palette.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$birds birds',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF27500A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _AllocPalette _palette(String type) {
    switch (type) {
      case 'POL_SALE':
        return const _AllocPalette(emoji: '💰', accent: Color(0xFFD9A640));
      case 'REPLACEMENT':
      default:
        return const _AllocPalette(emoji: '🏠', accent: Color(0xFF27500A));
    }
  }
}

class _AllocPalette {
  const _AllocPalette({required this.emoji, required this.accent});
  final String emoji;
  final Color accent;
}
