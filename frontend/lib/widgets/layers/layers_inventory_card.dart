// Layers unit inventory pill body. Mirrors the Dairy inventory card
// pattern but adds:
//   • Top KPI strip (total birds · feed remaining · eggs today ·
//     vaccine alerts · mortality alert)
//   • Alert chips (low feed · expiring vaccines · overcrowded ·
//     mortality above expected)
//   • Per-row alert badges (OUT / LOW / EXPIRING / EXPIRED) sourced
//     from the backend `alert` field — UI never recomputes thresholds.
//
// Categories: Feed · Vaccines · Consumables (rendered in this order).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

class LayersInventoryCard extends StatefulWidget {
  const LayersInventoryCard({super.key});
  @override
  State<LayersInventoryCard> createState() => _LayersInventoryCardState();
}

class _LayersInventoryCardState extends State<LayersInventoryCard> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _amber = Color(0xFF8A5A0A);

  static const _categoryOrder = ['Feed', 'Vaccines', 'Consumables'];

  late Future<_Summary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Summary> _load() async {
    final raw = await ApiService.getLayersInventorySummary();
    return _Summary.fromJson(raw);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _editQuantity(_Item item) async {
    final controller = TextEditingController(text: _formatQty(item.quantity));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Update — ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${_formatQty(item.quantity)}'
              '${item.unit != null ? ' ${item.unit}' : ''}',
              style: const TextStyle(fontSize: 12, color: _txt3),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'New quantity',
                suffixText: item.unit,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v == null || v < 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ApiService.updateLayersInventoryItem(
        item.id,
        {'quantity': result},
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated: ${item.name} = $result')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  String _formatQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Summary>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _ErrorState(
            message: snap.error.toString(),
            onRetry: _reload,
          );
        }
        final s = snap.data!;
        final groups = <String, List<_Item>>{};
        for (final i in s.items) {
          groups.putIfAbsent(i.category, () => []).add(i);
        }
        final orderedCats = [
          ..._categoryOrder.where(groups.containsKey),
          ...groups.keys.where((k) => !_categoryOrder.contains(k)),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiStrip(kpis: s.kpis, alerts: s.alerts),
            const SizedBox(height: 14),
            _AlertChips(alerts: s.alerts),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14000000)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '📦  Inventory — Layers unit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                          letterSpacing: 0.04,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${s.items.length} items',
                        style: const TextStyle(
                            fontSize: 11, color: _txt3),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Refresh',
                        onPressed: _reload,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (s.items.isEmpty)
                    const _Empty()
                  else
                    for (final cat in orderedCats) ...[
                      _CategoryGroup(
                        category: cat,
                        items: groups[cat]!,
                        onEdit: _editQuantity,
                        formatQty: _formatQty,
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// KPI strip (top)
// ---------------------------------------------------------------

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis, required this.alerts});
  final _Kpis kpis;
  final _Alerts alerts;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final tiles = [
      _KpiTile(
        label: 'Total birds',
        value: fmt.format(kpis.totalBirds),
        sub: kpis.totalCapacity > 0
            ? '${((kpis.totalBirds / kpis.totalCapacity) * 100).round()}% of capacity'
            : '—',
      ),
      _KpiTile(
        label: 'Feed remaining',
        value: '${_fmt(kpis.feedRemainingKg)} kg',
        sub: alerts.lowFeed > 0
            ? '${alerts.lowFeed} low'
            : 'on hand',
        alert: alerts.lowFeed > 0,
      ),
      _KpiTile(
        label: 'Eggs today',
        value: fmt.format(kpis.eggsToday),
        sub: '${(kpis.eggsToday / 30).floor()} crates',
      ),
      _KpiTile(
        label: 'Vaccine alerts',
        value: '${alerts.expiringVaccines}',
        sub: alerts.expiringVaccines > 0
            ? 'expiring soon'
            : 'all on file',
        alert: alerts.expiringVaccines > 0,
      ),
      _KpiTile(
        label: 'Mortality',
        value: '${kpis.mortalityToday}',
        sub: '${kpis.mortalityPct.toStringAsFixed(2)}% — '
            '${alerts.mortalityAboveExpected ? "above expected" : "ok"}',
        alert: alerts.mortalityAboveExpected,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // 2-up by default on phones; expand to 3 on small tablets and
        // 5-up on laptops. Only fall back to a single column on truly
        // tiny widths (legacy 320-dp phones).
        final cols = c.maxWidth >= 900
            ? 5
            : c.maxWidth >= 640
                ? 3
                : c.maxWidth >= 320
                    ? 2
                    : 1;
        final cellW = (c.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in tiles) SizedBox(width: cellW, child: t),
          ],
        );
      },
    );
  }

  static String _fmt(num v) {
    if (v == 0) return '0';
    if (v == v.toInt()) return NumberFormat.decimalPattern().format(v.toInt());
    return v.toStringAsFixed(1);
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.sub,
    this.alert = false,
  });
  final String label;
  final String value;
  final String sub;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final accent = alert
        ? _LayersInventoryCardState._amber
        : _LayersInventoryCardState._primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alert
              ? const Color(0x55B45A0A)
              : const Color(0x14000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _LayersInventoryCardState._txt2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: _LayersInventoryCardState._txt3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Alert chips (only render when there's something to flag)
// ---------------------------------------------------------------

class _AlertChips extends StatelessWidget {
  const _AlertChips({required this.alerts});
  final _Alerts alerts;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (alerts.lowFeed > 0) {
      chips.add(_AlertChip(
        text: '⚠ Feed below threshold (${alerts.lowFeed})',
        tone: _AlertTone.amber,
      ));
    }
    if (alerts.expiringVaccines > 0) {
      chips.add(_AlertChip(
        text: '⚠ Vaccine expiring soon (${alerts.expiringVaccines})',
        tone: _AlertTone.amber,
      ));
    }
    if (alerts.overcrowdedHouses > 0) {
      chips.add(_AlertChip(
        text: '⚠ House overcrowded (${alerts.overcrowdedHouses})',
        tone: _AlertTone.danger,
      ));
    }
    if (alerts.mortalityAboveExpected) {
      chips.add(const _AlertChip(
        text: '⚠ Mortality above expected range',
        tone: _AlertTone.danger,
      ));
    }
    if (chips.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF5E6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 14, color: _LayersInventoryCardState._primary),
            SizedBox(width: 6),
            Text(
              'All clear — no inventory or flock alerts.',
              style: TextStyle(
                fontSize: 12,
                color: _LayersInventoryCardState._primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

enum _AlertTone { amber, danger }

class _AlertChip extends StatelessWidget {
  const _AlertChip({required this.text, required this.tone});
  final String text;
  final _AlertTone tone;
  @override
  Widget build(BuildContext context) {
    final bg = tone == _AlertTone.amber
        ? const Color(0xFFFCEDC8)
        : const Color(0xFFFADBD8);
    final fg = tone == _AlertTone.amber
        ? const Color(0xFF8A5A0A)
        : const Color(0xFFC4393B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Category group (Feed / Vaccines / Consumables)
// ---------------------------------------------------------------

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.category,
    required this.items,
    required this.onEdit,
    required this.formatQty,
  });
  final String category;
  final List<_Item> items;
  final ValueChanged<_Item> onEdit;
  final String Function(double) formatQty;

  static const _hdr = Color(0xFFEEF3E8);

  IconData _categoryIcon() {
    switch (category) {
      case 'Feed':
        return Icons.grass_outlined;
      case 'Vaccines':
        return Icons.vaccines_outlined;
      case 'Consumables':
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Icon(_categoryIcon(),
                  size: 14, color: _LayersInventoryCardState._txt2),
              const SizedBox(width: 6),
              Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _LayersInventoryCardState._txt2,
                  letterSpacing: 0.05,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${items.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _LayersInventoryCardState._txt3,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x14000000)),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          // On narrow phones the 5 cols can't fit at readable widths
          // (Qty / Location / Status wrap char-by-char). Force a
          // 460-dp min table width and allow horizontal scroll below.
          child: LayoutBuilder(
            builder: (context, c) {
              const minW = 460.0;
              final w = c.maxWidth < minW ? minW : c.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: w,
                  child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.6),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.6),
              3: FlexColumnWidth(1.4),
              4: FixedColumnWidth(48),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(
                decoration: BoxDecoration(color: _hdr),
                children: [
                  _Th('Item'),
                  _Th('Qty'),
                  _Th('Location'),
                  _Th('Status'),
                  _Th('', alignRight: true),
                ],
              ),
              for (var i = 0; i < items.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isOdd ? const Color(0xFFFAFBF8) : Colors.white,
                  ),
                  children: [
                    _Td(child: _ItemNameCell(item: items[i])),
                    _Td(child: Text(
                      '${formatQty(items[i].quantity)}'
                      '${items[i].unit != null ? ' ${items[i].unit}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    )),
                    _Td(child: Text(
                      items[i].location ?? '—',
                      style: const TextStyle(fontSize: 12),
                    )),
                    _Td(child: _StatusBadge(item: items[i])),
                    _Td(
                      alignRight: true,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Update qty',
                        onPressed: () => onEdit(items[i]),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ),
                  ],
                ),
            ],
          ),
                ), // SizedBox
              ); // SingleChildScrollView
            },
          ), // LayoutBuilder
        ),
      ],
    );
  }
}

class _ItemNameCell extends StatelessWidget {
  const _ItemNameCell({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF222222),
          ),
        ),
        if (item.subCategory != null && item.subCategory!.isNotEmpty)
          Text(
            item.subCategory!,
            style: const TextStyle(
              fontSize: 10,
              color: _LayersInventoryCardState._txt3,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (item.expiresAt != null)
          Text(
            'expires ${DateFormat('d MMM yy').format(item.expiresAt!)}',
            style: const TextStyle(
              fontSize: 10,
              color: _LayersInventoryCardState._txt3,
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    final alert = item.alert;
    Color bg;
    Color fg;
    String label;
    switch (alert) {
      case 'OUT':
        bg = const Color(0xFFFADBD8);
        fg = const Color(0xFFC4393B);
        label = 'Out';
        break;
      case 'LOW':
        bg = const Color(0xFFFCEDC8);
        fg = const Color(0xFF8A5A0A);
        label = 'Low';
        break;
      case 'EXPIRING':
        bg = const Color(0xFFFCEDC8);
        fg = const Color(0xFF8A5A0A);
        label = 'Expiring';
        break;
      case 'EXPIRED':
        bg = const Color(0xFFFADBD8);
        fg = const Color(0xFFC4393B);
        label = 'Expired';
        break;
      default:
        bg = const Color(0xFFEFF5E6);
        fg = const Color(0xFF27500A);
        label = item.condition ?? 'Good';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.alignRight = false});
  final String text;
  final bool alignRight;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7770),
            letterSpacing: 0.04,
          ),
        ),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  const _Td({required this.child, this.alignRight = false});
  final Widget child;
  final bool alignRight;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: const Text(
        'No inventory items recorded for the layers unit yet.',
        style: TextStyle(fontSize: 13, color: Color(0xFF6B7770)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load inventory.\n$message',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Models
// ---------------------------------------------------------------

class _Summary {
  _Summary({required this.items, required this.kpis, required this.alerts});
  final List<_Item> items;
  final _Kpis kpis;
  final _Alerts alerts;

  factory _Summary.fromJson(Map<String, dynamic> j) {
    return _Summary(
      items: (j['items'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => _Item.fromJson(m.cast<String, dynamic>()))
          .toList(),
      kpis: _Kpis.fromJson(
        (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      alerts: _Alerts.fromJson(
        (j['alerts'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class _Kpis {
  _Kpis({
    required this.totalBirds,
    required this.totalCapacity,
    required this.eggsToday,
    required this.feedRemainingKg,
    required this.mortalityToday,
    required this.mortalityPct,
  });
  final int totalBirds;
  final int totalCapacity;
  final int eggsToday;
  final double feedRemainingKg;
  final int mortalityToday;
  final double mortalityPct;

  factory _Kpis.fromJson(Map<String, dynamic> j) => _Kpis(
        totalBirds: _toInt(j['totalBirds']),
        totalCapacity: _toInt(j['totalCapacity']),
        eggsToday: _toInt(j['eggsToday']),
        feedRemainingKg: _toDouble(j['feedRemainingKg']),
        mortalityToday: _toInt(j['mortalityToday']),
        mortalityPct: _toDouble(j['mortalityPct']),
      );
}

class _Alerts {
  _Alerts({
    required this.lowFeed,
    required this.expiringVaccines,
    required this.overcrowdedHouses,
    required this.mortalityAboveExpected,
  });
  final int lowFeed;
  final int expiringVaccines;
  final int overcrowdedHouses;
  final bool mortalityAboveExpected;

  factory _Alerts.fromJson(Map<String, dynamic> j) => _Alerts(
        lowFeed: _toInt(j['lowFeed']),
        expiringVaccines: _toInt(j['expiringVaccines']),
        overcrowdedHouses: _toInt(j['overcrowdedHouses']),
        mortalityAboveExpected: j['mortalityAboveExpected'] == true,
      );
}

class _Item {
  _Item({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.subCategory,
    this.unit,
    this.lowThreshold,
    this.location,
    this.condition,
    this.expiresAt,
    this.alert,
  });
  final String id;
  final String name;
  final String category;
  final double quantity;
  final String? subCategory;
  final String? unit;
  final double? lowThreshold;
  final String? location;
  final String? condition;
  final DateTime? expiresAt;
  final String? alert; // OUT | LOW | EXPIRING | EXPIRED | null

  factory _Item.fromJson(Map<String, dynamic> j) {
    return _Item(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      subCategory: j['subCategory']?.toString(),
      quantity: _toDouble(j['quantity']),
      unit: j['unit']?.toString(),
      lowThreshold: j['lowThreshold'] == null
          ? null
          : _toDouble(j['lowThreshold']),
      location: j['location']?.toString(),
      condition: j['condition']?.toString(),
      expiresAt: j['expiresAt'] == null
          ? null
          : DateTime.tryParse(j['expiresAt'].toString()),
      alert: j['alert']?.toString(),
    );
  }
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
