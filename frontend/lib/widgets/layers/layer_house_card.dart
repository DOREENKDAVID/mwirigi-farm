// Visual capacity card for one layer house. Mirrors the Dairy houses
// overview card style — hen emoji icon, name, count + capacity, a
// horizontal occupancy bar, and a status pill (Phasing out / Continuing).
//
// All values are rendered as-is from `LayerHouseView` (server-derived);
// this widget never recomputes percentages — the parent must reload
// after a POST so the new state is reflected.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_unit.dart';

class LayerHouseCard extends StatelessWidget {
  const LayerHouseCard({
    super.key,
    required this.house,
    this.compact = false,
    this.onTap,
    this.onLogEntry,
  });

  final LayerHouseView house;
  final bool compact;
  final VoidCallback? onTap;
  /// When non-null, renders a "Log entry" button at the bottom of the
  /// card. The Houses pill wires this up to open the per-house daily
  /// entry dialog (replaces the form that used to live under
  /// Production).
  final VoidCallback? onLogEntry;

  static const _amber = Color(0xFF854F0B);
  static const _danger = Color(0xFFC4393B);

  Color _accent() {
    final s = house.color.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0x27500A;
    return Color(0xFF000000 | v);
  }

  double get _occupancyPct {
    if (house.capacity <= 0) return 0;
    return (house.birdCount / house.capacity).clamp(0.0, 1.5);
  }

  // % laying = (eggs collected today / current bird count) * 100.
  // 1 crate = 30 eggs (matches the seed + log_eggs_dialog convention).
  double get _layingPct {
    if (house.birdCount <= 0) return 0;
    final eggs = house.cratesToday * 30;
    return (eggs / house.birdCount * 100).clamp(0, 200).toDouble();
  }

  Color _occupancyBarColor() {
    if (_occupancyPct > 1.0) return _danger; // overcrowded
    if (_occupancyPct < 0.6) return _amber;  // under-stocked
    return _accent();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final accent = _accent();
    final pctLabel = '${(_occupancyPct * 100).round()}%';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x14000000)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🐔', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    house.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
                _StatusPill(phasingOut: house.phasingOut),
              ],
            ),
            const SizedBox(height: 12),
            // Birds / capacity headline.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fmt.format(house.birdCount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ ${fmt.format(house.capacity)} hens',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7770),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _OccupancyBar(
              pct: _occupancyPct,
              color: _occupancyBarColor(),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                pctLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _occupancyBarColor(),
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0x14000000)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Crates today',
                      value: _formatNum(house.cratesToday),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0x14000000),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Production',
                      value: '${_layingPct.toStringAsFixed(0)}%',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0x14000000),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Feed (kg)',
                      value: _formatNum(house.feedKg),
                    ),
                  ),
                ],
              ),
              if (onLogEntry != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onLogEntry,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Log entry'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _formatNum(num n) {
    if (n == n.roundToDouble()) {
      return NumberFormat.decimalPattern().format(n.toInt());
    }
    return n.toStringAsFixed(1);
  }
}

class _OccupancyBar extends StatelessWidget {
  const _OccupancyBar({required this.pct, required this.color});
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = pct.clamp(0.0, 1.0);
    return Stack(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE9ECE5),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        // Fractional fill via FractionallySizedBox — animates as the
        // value updates after a successful POST.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: clamped),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          builder: (_, value, __) {
            return FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7770),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.phasingOut});
  final bool phasingOut;

  @override
  Widget build(BuildContext context) {
    final color = phasingOut
        ? const Color(0xFF854F0B)
        : const Color(0xFF27500A);
    final bg = phasingOut
        ? const Color(0xFFFFF1DD)
        : const Color(0xFFEFF5E6);
    final label = phasingOut ? 'Phasing out' : 'Active';
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
          color: color,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}

/// Responsive grid wrapper — drops to a single column on narrow screens.
class LayerHousesGrid extends StatelessWidget {
  const LayerHousesGrid({
    super.key,
    required this.houses,
    this.compact = false,
    this.onLogEntry,
  });

  final List<LayerHouseView> houses;
  final bool compact;
  /// Per-house "Log entry" handler — when provided, each card renders a
  /// button at the bottom that calls back with the tapped house.
  final ValueChanged<LayerHouseView>? onLogEntry;

  @override
  Widget build(BuildContext context) {
    if (houses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No layer houses recorded.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final cols = maxW >= 900
            ? 3
            : maxW >= 560
                ? 2
                : 1;
        final width = (maxW - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final h in houses)
              SizedBox(
                width: width,
                child: LayerHouseCard(
                  house: h,
                  compact: compact,
                  onLogEntry: onLogEntry == null ? null : () => onLogEntry!(h),
                ),
              ),
          ],
        );
      },
    );
  }
}
