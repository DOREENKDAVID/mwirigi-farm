import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_unit.dart';
import 'allocation_edit_dialog.dart';
import 'allocation_history_sheet.dart';

/// "Allocation plan when chicks reach 3 months" — two side-by-side cards
/// (POL sale + Replacement). On narrow screens the cards stack.
///
/// Each row pulls the latest revision per allocation type from the backend
/// payload (already deduplicated server-side).
///
/// When [brooderId] is provided, an Edit + History header appears so
/// the CEO / LAYERS_MANAGER can revise the plan and audit changes.
class AllocationPlan extends StatelessWidget {
  const AllocationPlan({
    super.key,
    required this.rows,
    this.brooderId,
    this.onChanged,
  });
  final List<AllocationRow> rows;
  final String? brooderId;
  final VoidCallback? onChanged;

  Future<void> _openEdit(BuildContext context) async {
    if (brooderId == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AllocationEditDialog(brooderId: brooderId!, existing: rows),
    );
    if (saved == true) {
      onChanged?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allocation revision saved')),
        );
      }
    }
  }

  void _openHistory(BuildContext context) {
    if (brooderId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AllocationHistorySheet(brooderId: brooderId!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = brooderId != null;
    final actions = canEdit
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openHistory(context),
                  icon: const Icon(Icons.history, size: 14),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF666666),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: () => _openEdit(context),
                  icon: const Icon(Icons.edit_note, size: 14),
                  label: const Text('Revise'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF3DE),
                    foregroundColor: const Color(0xFF27500A),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          actions,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No allocation plan recorded yet.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      );
    }

    final cards = rows.map((r) => _AllocCard(row: r)).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        actions,
        LayoutBuilder(
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
        ),
      ],
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
