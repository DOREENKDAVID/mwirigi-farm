// Dairy unit inventory — "📦 Inventory pill" on the Dairy page.
//
// Mirrors the v4.2 HTML mockup: items grouped by category (Bedding,
// Equipment, Veterinary) with Item · Qty · Location · Condition · Actions
// columns. Quantities are editable inline via a small dialog.

import 'package:flutter/material.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';

class DairyInventoryCard extends StatefulWidget {
  const DairyInventoryCard({super.key});

  @override
  State<DairyInventoryCard> createState() => _DairyInventoryCardState();
}

class _DairyInventoryCardState extends State<DairyInventoryCard> {
  static const _primary = Color(0xFF27500A);
  static const _txt3 = Color(0xFF99A39B);

  // Render order matches the HTML category list.
  static const _categoryOrder = ['Bedding', 'Equipment', 'Veterinary'];

  late Future<List<DairyInventoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DairyInventoryItem>> _load() async {
    final raw = await ApiService.getDairyInventory();
    return raw
        .whereType<Map>()
        .map((m) => DairyInventoryItem.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _editQuantity(DairyInventoryItem item) async {
    final controller = TextEditingController(
      text: _formatQty(item.quantity),
    );
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
      await ApiService.updateDairyInventoryItem(item.id, {'quantity': result});
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

  // Mirror the HTML auto-condition rules:
  //   qty == 0   → "Out"
  //   qty < 5    → "Low"
  //   else       → use stored condition (default Good)
  String _displayCondition(DairyInventoryItem item) {
    if (item.quantity == 0) return 'Out';
    if (item.quantity < 5 && (item.condition ?? 'Good') != 'Poor') {
      return 'Low';
    }
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
      child: FutureBuilder<List<DairyInventoryItem>>(
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
          final items = snap.data ?? const <DairyInventoryItem>[];
          final groups = <String, List<DairyInventoryItem>>{};
          for (final i in items) {
            groups.putIfAbsent(i.category, () => []).add(i);
          }
          // Sort categories: known first (in HTML order), then anything new.
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
                    '📦  Inventory — Dairy unit',
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
  final List<DairyInventoryItem> items;
  final String Function(double) formatQty;
  final String Function(DairyInventoryItem) displayCondition;
  final ValueChanged<DairyInventoryItem> onEdit;

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
          // On narrow phones the 5 columns can't fit at readable widths
          // (Qty/Location/Condition wrap char-by-char). Force a min table
          // width and allow horizontal scroll if the screen is narrower.
          child: LayoutBuilder(
            builder: (context, constraints) {
              const minTableWidth = 460.0;
              final width = constraints.maxWidth < minTableWidth
                  ? minTableWidth
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: _inventoryTable(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _inventoryTable() {
    return Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1.2),
              4: FixedColumnWidth(56),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _hdr),
                children: const [
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
                    _Td(child: Text(
                      items[i].name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    )),
                    _Td(child: Text(
                      '${formatQty(items[i].quantity)}'
                      '${items[i].unit != null ? ' ${items[i].unit}' : ''}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    )),
                    _Td(child: Text(
                      items[i].location ?? '—',
                      style: const TextStyle(fontSize: 12),
                    )),
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
                            minWidth: 32, minHeight: 32),
                      ),
                    ),
                  ],
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
    switch (condition) {
      case 'Good':
      case 'Fair':
        bg = const Color(0xFFE7F0DD);
        fg = const Color(0xFF27500A);
        break;
      case 'Low':
        bg = const Color(0xFFFCEDC8);
        fg = const Color(0xFF8A5A0A);
        break;
      case 'Out':
      case 'Poor':
      case 'Broken':
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
        'No inventory items recorded for the dairy unit yet.',
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
