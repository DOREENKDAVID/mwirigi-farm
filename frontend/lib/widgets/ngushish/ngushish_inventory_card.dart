// Ngushish inventory — body for the "📦 Inventory — Ngusishi" card on
// the Ngushish page. Mirrors the Feedlot / Piggery / Layers inventory
// pattern: items grouped by category with inline quantity edit.

import 'package:flutter/material.dart';

import '../../core/service/api_service.dart';

class NgushishInventoryItemModel {
  NgushishInventoryItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.unit,
    this.location,
    this.condition,
    this.notes,
  });

  final String id;
  final String name;
  final String category;
  final double quantity;
  final String? unit;
  final String? location;
  final String? condition;
  final String? notes;

  factory NgushishInventoryItemModel.fromJson(Map<String, dynamic> j) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return NgushishInventoryItemModel(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      quantity: toDouble(j['quantity']),
      unit: j['unit']?.toString(),
      location: j['location']?.toString(),
      condition: j['condition']?.toString(),
      notes: j['notes']?.toString(),
    );
  }
}

class NgushishInventoryCard extends StatefulWidget {
  const NgushishInventoryCard({super.key});

  @override
  State<NgushishInventoryCard> createState() => _NgushishInventoryCardState();
}

class _NgushishInventoryCardState extends State<NgushishInventoryCard> {
  static const _primary = Color(0xFF27500A);
  static const _txt3 = Color(0xFF99A39B);

  static const _categoryOrder = ['Inputs', 'Equipment', 'Agrochemicals'];

  late Future<List<NgushishInventoryItemModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<NgushishInventoryItemModel>> _load() async {
    final raw = await ApiService.getNgushishInventory();
    return raw
        .whereType<Map>()
        .map((m) =>
            NgushishInventoryItemModel.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _editQuantity(NgushishInventoryItemModel item) async {
    final controller = TextEditingController(text: _formatQty(item.quantity));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update quantity — ${item.name}'),
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
                border: const OutlineInputBorder(),
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
      await ApiService.updateNgushishInventoryItem(item.id, {'quantity': result});
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

  String _displayCondition(NgushishInventoryItemModel item) {
    final c = (item.condition ?? '').toLowerCase();
    if (item.quantity == 0 || c == 'out') return 'Out';
    if (c == 'low' || (item.quantity < 5 && c != 'good')) return 'Low';
    return item.condition ?? 'Good';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<NgushishInventoryItemModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: _reload,
            );
          }
          final items = snap.data ?? const <NgushishInventoryItemModel>[];
          final groups = <String, List<NgushishInventoryItemModel>>{};
          for (final i in items) {
            groups.putIfAbsent(i.category, () => []).add(i);
          }
          final orderedCats = [
            ..._categoryOrder.where(groups.containsKey),
            ...groups.keys.where((k) => !_categoryOrder.contains(k)),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '📦  Inventory — Ngusishi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.05,
                      color: _primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} items',
                    style: const TextStyle(fontSize: 11, color: _txt3),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _reload,
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const _EmptyState()
              else
                for (final cat in orderedCats) ...[
                  _CategoryGroup(
                    category: cat,
                    items: groups[cat]!,
                    formatQty: _formatQty,
                    displayCondition: _displayCondition,
                    onEdit: _editQuantity,
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.category,
    required this.items,
    required this.formatQty,
    required this.displayCondition,
    required this.onEdit,
  });

  final String category;
  final List<NgushishInventoryItemModel> items;
  final String Function(double) formatQty;
  final String Function(NgushishInventoryItemModel) displayCondition;
  final ValueChanged<NgushishInventoryItemModel> onEdit;

  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _hdr = Color(0xFFEEF3E8);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _txt2,
                  letterSpacing: 0.05,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${items.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _txt3,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x14000000)),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          // On narrow phones the 5 cols can't fit at readable widths
          // (Qty / Location / Condition wrap char-by-char). Force a
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
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1.2),
              4: FixedColumnWidth(56),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(
                decoration: BoxDecoration(color: _hdr),
                children: [
                  _Th('Item'),
                  _Th('Qty'),
                  _Th('Location'),
                  _Th('Condition'),
                  _Th('', alignRight: true),
                ],
              ),
              for (var i = 0; i < items.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isOdd ? const Color(0xFFFAFBF8) : Colors.white,
                  ),
                  children: [
                    _Td(
                      child: Text(
                        items[i].name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Td(
                      child: Text(
                        '${formatQty(items[i].quantity)}'
                        '${items[i].unit != null ? ' ${items[i].unit}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Td(
                      child: Text(
                        items[i].location ?? '—',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    _Td(child: _ConditionTag(displayCondition(items[i]))),
                    _Td(
                      alignRight: true,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Update qty',
                        onPressed: () => onEdit(items[i]),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
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

class _ConditionTag extends StatelessWidget {
  const _ConditionTag(this.condition);
  final String condition;
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    final c = condition.toLowerCase();
    switch (c) {
      case 'good':
      case 'fair':
        bg = const Color(0xFFE7F0DD);
        fg = const Color(0xFF27500A);
        break;
      case 'low':
        bg = const Color(0xFFFCEDC8);
        fg = const Color(0xFF8A5A0A);
        break;
      case 'out':
      case 'poor':
      case 'broken':
        bg = const Color(0xFFFADBD8);
        fg = const Color(0xFFC4393B);
        break;
      default:
        bg = const Color(0xFFEEEEEE);
        fg = const Color(0xFF6B7770);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        condition,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: const Text(
        'No inventory items recorded for Ngusishi yet.',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 12),
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
