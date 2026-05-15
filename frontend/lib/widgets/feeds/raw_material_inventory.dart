import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feeds.dart';
import '../../core/service/api_service.dart';
import 'bulk_consumption_dialog.dart';
import 'edit_consumption_dialog.dart';
import 'edit_material_dialog.dart';
import 'feed_status_chip.dart';
import 'log_delivery_dialog.dart';

/// "Raw material inventory" card. Owns its own (search, status filter,
/// page) state. The parent FeedsPage rebuilds KPIs after mutations via
/// the `onChanged` callback.
class RawMaterialInventory extends StatefulWidget {
  const RawMaterialInventory({
    super.key,
    required this.kpis,
    required this.onChanged,
  });

  final FeedKpis? kpis;
  final VoidCallback onChanged;

  @override
  State<RawMaterialInventory> createState() => RawMaterialInventoryState();
}

class RawMaterialInventoryState extends State<RawMaterialInventory> {
  static const _pageSize = 50;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _search = '';
  FeedStatus? _statusFilter;
  int _page = 1;

  Future<FeedMaterialListResult>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<FeedMaterialListResult> _load() async {
    final res = await ApiService.getFeedMaterials(
      search: _search.isEmpty ? null : _search,
      status: _statusFilter?.wire,
      page: _page,
      limit: _pageSize,
    );
    final items = (res['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => FeedMaterial.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
    final pagination = Pagination.fromJson(
      (res['pagination'] as Map?)?.cast<String, dynamic>(),
    );
    return FeedMaterialListResult(items: items, pagination: pagination);
  }

  Future<void> reload() async {
    setState(() => _future = _load());
    await _future;
  }

  // The "Log Delivery" header button needs the material list for its
  // dropdown. We expose the loaded items so the parent FeedsPage can grab
  // them without re-querying.
  List<FeedMaterial>? get currentMaterials {
    if (_future == null) return null;
    // Future may be unresolved; this getter returns null in that case.
    // Callers should handle null by falling back to a fresh fetch.
    return _lastLoaded;
  }

  List<FeedMaterial>? _lastLoaded;

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _search = v.trim();
        _page = 1;
        _future = _load();
      });
    });
  }

  void _setStatus(FeedStatus? s) {
    setState(() {
      _statusFilter = s;
      _page = 1;
      _future = _load();
    });
  }

  Future<void> _openEditMaterial(FeedMaterial m) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EditMaterialDialog(material: m),
    );
    if (saved == true) {
      _toast('${m.name} updated');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _openLogDelivery(FeedMaterial m) async {
    if (_lastLoaded == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => LogDeliveryDialog(
        materials: _lastLoaded!,
        preselected: m,
      ),
    );
    if (saved == true) {
      _toast('Delivery logged for ${m.name}');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _openEditConsumption(FeedMaterial m) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EditConsumptionDialog(material: m),
    );
    if (saved == true) {
      _toast('Consumption rate updated');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _openBulkConsumption() async {
    if (_lastLoaded == null || _lastLoaded!.isEmpty) {
      _toast('No materials available to update.');
      return;
    }
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkConsumptionDialog(materials: _lastLoaded!),
    );
    if (result != null && result > 0) {
      _toast('$result consumption rate${result == 1 ? '' : 's'} updated');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _confirmDelete(FeedMaterial m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete material?'),
        content: Text(
          '${m.name} will be removed from the inventory. '
          'This is a soft delete — historical deliveries and consumption '
          'logs stay intact for reporting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteFeedMaterial(m.id);
      if (!mounted) return;
      _toast('${m.name} removed');
      await reload();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RAW MATERIAL INVENTORY — stock vs daily consumption',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openBulkConsumption,
                icon: const Icon(Icons.tune, size: 14),
                label: const Text('Edit consumption rates'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF27500A),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SearchField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          _StatusPills(
            kpis: widget.kpis,
            selected: _statusFilter,
            onSelect: _setStatus,
          ),
          const SizedBox(height: 14),
          FutureBuilder<FeedMaterialListResult>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _ErrorBlock(
                  message: snap.error
                      .toString()
                      .replaceFirst('Exception: ', ''),
                  onRetry: reload,
                );
              }
              final data = snap.data!;
              _lastLoaded = data.items;

              if (data.items.isEmpty) {
                return const _EmptyState();
              }

              return LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 760;
                  return wide
                      ? _DesktopTable(
                          materials: data.items,
                          onEdit: _openEditMaterial,
                          onLogDelivery: _openLogDelivery,
                          onEditConsumption: _openEditConsumption,
                          onDelete: _confirmDelete,
                        )
                      : _MobileList(
                          materials: data.items,
                          onEdit: _openEditMaterial,
                          onLogDelivery: _openLogDelivery,
                          onEditConsumption: _openEditConsumption,
                          onDelete: _confirmDelete,
                        );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'How this works: daily use is calculated from quantity used ÷ duration. '
            'Days left = stock ÷ daily use. Status flips to Critical when days '
            'left ≤ lead time, Low when ≤ 2× lead time. Default lead time = 5 days.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFAAAAAA),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search materials…',
        prefixIcon: const Icon(Icons.search, size: 18),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF0EFE9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

class _StatusPills extends StatelessWidget {
  const _StatusPills({
    required this.kpis,
    required this.selected,
    required this.onSelect,
  });

  final FeedKpis? kpis;
  final FeedStatus? selected;
  final ValueChanged<FeedStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = <(FeedStatus?, String, int?)>[
      (null, 'All', kpis?.materialsTracked),
      (FeedStatus.critical, 'Critical', kpis?.critical),
      (FeedStatus.low, 'Low', kpis?.low),
      (FeedStatus.adequate, 'Adequate', kpis?.adequate),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          _Pill(
            label: e.$2,
            count: e.$3,
            active: selected == e.$1,
            onTap: () => onSelect(e.$1),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    final bg = active ? primary : Colors.white;
    final fg = active ? Colors.white : Colors.black87;
    final border = active ? primary : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFF0EFE9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.materials,
    required this.onEdit,
    required this.onLogDelivery,
    required this.onEditConsumption,
    required this.onDelete,
  });
  final List<FeedMaterial> materials;
  final void Function(FeedMaterial) onEdit;
  final void Function(FeedMaterial) onLogDelivery;
  final void Function(FeedMaterial) onEditConsumption;
  final void Function(FeedMaterial) onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 22,
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.black54,
        ),
        dataTextStyle:
            const TextStyle(fontSize: 13, color: Colors.black87),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('MATERIAL')),
          DataColumn(label: Text('PACK SIZE')),
          DataColumn(label: Text('DAILY USE'), numeric: true),
          DataColumn(label: Text('STOCK ON HAND'), numeric: true),
          DataColumn(label: Text('DAYS LEFT'), numeric: true),
          DataColumn(label: Text('REORDER AT'), numeric: true),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: [
          for (var i = 0; i < materials.length; i++)
            DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(
                materials[i].name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              )),
              DataCell(Text(materials[i].packSize)),
              DataCell(Text('${fmt.format(materials[i].dailyUseKg)} kg/d')),
              DataCell(Text('${fmt.format(materials[i].stockOnHandKg)} kg')),
              DataCell(Text(
                materials[i].daysLeft == null
                    ? '—'
                    : '${materials[i].daysLeft!.toStringAsFixed(materials[i].daysLeft! >= 10 ? 0 : 1)} d',
              )),
              DataCell(Text('${fmt.format(materials[i].reorderAtKg)} kg')),
              DataCell(FeedStatusChip(status: materials[i].status)),
              DataCell(_RowActions(
                material: materials[i],
                onEdit: onEdit,
                onLogDelivery: onLogDelivery,
                onEditConsumption: onEditConsumption,
                onDelete: onDelete,
              )),
            ]),
        ],
      ),
    );
  }
}

class _MobileList extends StatelessWidget {
  const _MobileList({
    required this.materials,
    required this.onEdit,
    required this.onLogDelivery,
    required this.onEditConsumption,
    required this.onDelete,
  });
  final List<FeedMaterial> materials;
  final void Function(FeedMaterial) onEdit;
  final void Function(FeedMaterial) onLogDelivery;
  final void Function(FeedMaterial) onEditConsumption;
  final void Function(FeedMaterial) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in materials) ...[
          _MaterialCard(
            material: m,
            actions: _RowActions(
              material: m,
              onEdit: onEdit,
              onLogDelivery: onLogDelivery,
              onEditConsumption: onEditConsumption,
              onDelete: onDelete,
            ),
            onTap: () => onEdit(m),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.actions,
    required this.onTap,
  });
  final FeedMaterial material;
  final Widget actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    material.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                FeedStatusChip(status: material.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              material.packSize,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetaCell(
                    label: 'Stock',
                    value: '${fmt.format(material.stockOnHandKg)} kg',
                  ),
                ),
                Expanded(
                  child: _MetaCell(
                    label: 'Daily use',
                    value: '${fmt.format(material.dailyUseKg)} kg/d',
                  ),
                ),
                Expanded(
                  child: _MetaCell(
                    label: 'Days left',
                    value: material.daysLeft == null
                        ? '—'
                        : '${material.daysLeft!.toStringAsFixed(material.daysLeft! >= 10 ? 0 : 1)} d',
                  ),
                ),
                actions,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.material,
    required this.onEdit,
    required this.onLogDelivery,
    required this.onEditConsumption,
    required this.onDelete,
  });
  final FeedMaterial material;
  final void Function(FeedMaterial) onEdit;
  final void Function(FeedMaterial) onLogDelivery;
  final void Function(FeedMaterial) onEditConsumption;
  final void Function(FeedMaterial) onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (key) {
        switch (key) {
          case 'edit':
            onEdit(material);
            break;
          case 'delivery':
            onLogDelivery(material);
            break;
          case 'consumption':
            onEditConsumption(material);
            break;
          case 'delete':
            onDelete(material);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined, size: 18),
            title: Text('Edit material'),
          ),
        ),
        PopupMenuItem(
          value: 'delivery',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.local_shipping_outlined, size: 18),
            title: Text('Log delivery'),
          ),
        ),
        PopupMenuItem(
          value: 'consumption',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.tune_outlined, size: 18),
            title: Text('Edit consumption'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline, size: 18, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 36, color: Color(0xFFAAAAAA)),
          SizedBox(height: 8),
          Text(
            'No materials match these filters.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              size: 32, color: Color(0xFF854F0B)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
