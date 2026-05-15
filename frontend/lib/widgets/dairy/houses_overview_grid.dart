import 'package:flutter/material.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';

/// "Houses overview" card — selectable house cards that filter the
/// downstream views (cow records, milk-logging cow grid). Tap a card to
/// activate the filter; tap "✕ Clear filter" to deactivate.
///
/// The card list comes from `GET /api/dairy/houses/overview`. Card
/// content per house: name, total cows, milking count, litres-today,
/// assigned workers, status pill.
class HousesOverviewCard extends StatefulWidget {
  const HousesOverviewCard({
    super.key,
    required this.selectedHouseId,
    required this.onSelect,
    this.onCardTap,
  });

  /// Currently active house filter, or null when nothing is selected.
  final String? selectedHouseId;

  /// Fired when a card is tapped (or cleared via the "✕" button — pass
  /// null in that case).
  final ValueChanged<String?> onSelect;

  /// Optional secondary action fired only on a positive tap (not on
  /// clear-filter, not on toggle-off). Used by the Overview tab to
  /// jump to the Houses pill so the cow list comes into view.
  final ValueChanged<String>? onCardTap;

  @override
  State<HousesOverviewCard> createState() => HousesOverviewCardState();
}

class HousesOverviewCardState extends State<HousesOverviewCard> {
  Future<List<DairyHouseOverview>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DairyHouseOverview>> _load() async {
    final raw = await ApiService.getDairyHousesOverview();
    return raw
        .whereType<Map>()
        .map((m) => DairyHouseOverview.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'HOUSES OVERVIEW — tap a house to supervise it',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              if (widget.selectedHouseId != null)
                TextButton.icon(
                  onPressed: () => widget.onSelect(null),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Clear filter'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF555555),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DairyHouseOverview>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Text(
                        snap.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: reload,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final houses = snap.data ?? const [];
              if (houses.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No dairy houses configured.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, c) {
                  // Aim for ~140-180px cards. 5 across on a wide page,
                  // 2 across on phones.
                  final maxW = c.maxWidth;
                  final cols = maxW >= 900
                      ? 5
                      : maxW >= 680
                          ? 4
                          : maxW >= 480
                              ? 3
                              : 2;
                  final width = (maxW - 12 * (cols - 1)) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final h in houses)
                        SizedBox(
                          width: width,
                          child: _HouseCard(
                            house: h,
                            selected: widget.selectedHouseId == h.id,
                            // Maternity isn't a milk-logging filter (no
                            // milking cows), so we still let the user
                            // tap it for read-only context.
                            onTap: () {
                              final isToggleOff =
                                  widget.selectedHouseId == h.id;
                              widget.onSelect(isToggleOff ? null : h.id);
                              if (!isToggleOff) {
                                widget.onCardTap?.call(h.id);
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HouseCard extends StatelessWidget {
  const _HouseCard({
    required this.house,
    required this.selected,
    required this.onTap,
  });
  final DairyHouseOverview house;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = house.parsedColor();
    final bg = selected
        ? accent.withValues(alpha: 0.12)
        : const Color(0xFFFAFAF7);
    final border = selected ? accent : const Color(0x14000000);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    house.status == 'MATERNITY' ? '🤰' : '🐄',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _displayName(house.name),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${house.totalCows} cow${house.totalCows == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              house.status == 'MATERNITY'
                  ? 'Awaiting calving'
                  : '${house.milkingCount} milking · ${_fmtLitres(house.litresToday)} L today',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            _StatusPill(status: house.status, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.accent});
  final String status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'ALL_MILKING' => (
          'All milking',
          const Color(0xFFEAF3DE),
          const Color(0xFF27500A),
        ),
      'PARTIAL' => (
          'Partial',
          const Color(0xFFFAEEDA),
          const Color(0xFF854F0B),
        ),
      'DRY' => (
          'Dry',
          const Color(0xFFEDEDED),
          const Color(0xFF555555),
        ),
      'EMPTY' => (
          'Empty',
          const Color(0xFFEDEDED),
          const Color(0xFF555555),
        ),
      'MATERNITY' => (
          'Maternity',
          const Color(0xFFFAEEDA),
          const Color(0xFF854F0B),
        ),
      _ => ('—', const Color(0xFFEDEDED), const Color(0xFF555555)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

String _fmtLitres(num v) {
  if (v == 0) return '0';
  if (v == v.toInt()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

// Display "Dairy A" as "House A" so the dairy unit's house cards match
// the convention used elsewhere (the pill letter labels, the poultry
// "House A/B/C" naming, etc.). The DB keeps the "Dairy " prefix because
// `House.name` is unique across the whole table — poultry already owns
// "House A/B/C", so we can't rename the underlying rows without a more
// invasive migration.
String _displayName(String raw) {
  if (raw.toLowerCase().startsWith('dairy ')) {
    return 'House ${raw.substring(6)}';
  }
  return raw;
}
