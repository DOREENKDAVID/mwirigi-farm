import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/ngushish.dart';
import '../../core/service/api_service.dart';
import 'add_dispatch_dialog.dart';
import 'add_harvest_dialog.dart';
import 'add_irrigation_dialog.dart';
import 'crop_status_chip.dart';
import 'edit_crop_dialog.dart';

/// Crop Register card — search bar, status filter, irrigated filter, and a
/// data table on wide layouts that collapses to a card list on mobile.
///
/// Owns its own (search, filter, page) state so the parent NgushishPage
/// only re-runs the dashboard / KPI fetch on `onChanged`.
class CropRegisterTable extends StatefulWidget {
  const CropRegisterTable({
    super.key,
    required this.onViewDetails,
    required this.onChanged,
  });

  /// Tapping a row → opens the crop details screen.
  final void Function(CropView crop) onViewDetails;

  /// Called after any mutation (delete, harvest, dispatch, irrigation) so
  /// the parent can refresh KPIs.
  final VoidCallback onChanged;

  @override
  State<CropRegisterTable> createState() => CropRegisterTableState();
}

class CropRegisterTableState extends State<CropRegisterTable> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _search = '';
  CropStatus? _statusFilter;
  bool? _irrigatedFilter;
  int _page = 1;

  Future<CropListResult>? _future;

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

  Future<CropListResult> _load() async {
    final res = await ApiService.getNgushishCrops(
      search: _search.isEmpty ? null : _search,
      status: _statusFilter?.wire,
      irrigated: _irrigatedFilter,
      page: _page,
      limit: _pageSize,
    );
    final items = (res['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => CropView.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
    final pagination = Pagination.fromJson(
      (res['pagination'] as Map?)?.cast<String, dynamic>(),
    );
    return CropListResult(items: items, pagination: pagination);
  }

  Future<void> reload() async {
    setState(() => _future = _load());
    await _future;
  }

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

  void _setStatus(CropStatus? s) {
    setState(() {
      _statusFilter = s;
      _page = 1;
      _future = _load();
    });
  }

  void _setIrrigated(bool? v) {
    setState(() {
      _irrigatedFilter = v;
      _page = 1;
      _future = _load();
    });
  }

  void _setPage(int p) {
    setState(() {
      _page = p;
      _future = _load();
    });
  }

  Future<void> _confirmDelete(CropView crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete crop?'),
        content: Text(
          '${crop.name} will be removed from the register. '
          'This is a soft delete — historical harvests and dispatches stay '
          'intact for reporting.',
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
      await ApiService.deleteNgushishCrop(crop.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${crop.name} removed')),
      );
      await reload();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openEdit(CropView crop) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EditCropDialog(crop: crop),
    );
    if (saved == true) {
      _toast('${crop.name} updated');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _openHarvest(CropView crop) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddHarvestDialog(cropId: crop.id, cropName: crop.name),
    );
    if (saved == true) {
      _toast('Harvest logged');
      widget.onChanged();
      await reload();
    }
  }

  Future<void> _openIrrigation(CropView crop) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AddIrrigationDialog(cropId: crop.id, cropName: crop.name),
    );
    if (saved == true) {
      _toast('Irrigation event logged');
      widget.onChanged();
      await reload();
    }
  }

  Future<void> _openDispatch(CropView crop) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddDispatchDialog(
        cropId: crop.id,
        cropName: crop.name,
        defaultDestination: crop.destination,
      ),
    );
    if (saved == true) {
      _toast('Dispatch recorded');
      widget.onChanged();
      await reload();
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
          const Text(
            'CROP REGISTER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          _Toolbar(
            controller: _searchCtrl,
            onSearchChanged: _onSearchChanged,
            statusFilter: _statusFilter,
            onStatusChanged: _setStatus,
            irrigatedFilter: _irrigatedFilter,
            onIrrigatedChanged: _setIrrigated,
          ),
          const SizedBox(height: 14),
          FutureBuilder<CropListResult>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _ErrorBlock(
                  message:
                      snap.error.toString().replaceFirst('Exception: ', ''),
                  onRetry: reload,
                );
              }
              final data = snap.data!;
              if (data.items.isEmpty) {
                return const _EmptyState();
              }

              return LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 720;
                  return Column(
                    children: [
                      if (wide)
                        _DesktopTable(
                          crops: data.items,
                          onView: widget.onViewDetails,
                          onEdit: _openEdit,
                          onHarvest: _openHarvest,
                          onIrrigate: _openIrrigation,
                          onDispatch: _openDispatch,
                          onDelete: _confirmDelete,
                        )
                      else
                        _MobileList(
                          crops: data.items,
                          onView: widget.onViewDetails,
                          onEdit: _openEdit,
                          onHarvest: _openHarvest,
                          onIrrigate: _openIrrigation,
                          onDispatch: _openDispatch,
                          onDelete: _confirmDelete,
                        ),
                      if (data.pagination.pages > 1) ...[
                        const SizedBox(height: 12),
                        _Pager(
                          page: data.pagination.page,
                          pages: data.pagination.pages,
                          onPage: _setPage,
                        ),
                      ],
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

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.irrigatedFilter,
    required this.onIrrigatedChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final CropStatus? statusFilter;
  final ValueChanged<CropStatus?> onStatusChanged;
  final bool? irrigatedFilter;
  final ValueChanged<bool?> onIrrigatedChanged;

  @override
  Widget build(BuildContext context) {
    // Search bar takes the full row width on top, filters sit on a second
    // row below. Matches the design mock where search is a primary, full-
    // width input with status / irrigated filters as secondary chips
    // underneath.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search crops…',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFEFEDE6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<CropStatus?>(
              value: statusFilter,
              hint: const Text('All statuses'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<CropStatus?>(
                  child: Text('All statuses'),
                ),
                for (final s in CropStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: onStatusChanged,
            ),
            DropdownButton<bool?>(
              value: irrigatedFilter,
              hint: const Text('All crops'),
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem<bool?>(child: Text('All crops')),
                DropdownMenuItem<bool?>(value: true, child: Text('Irrigated')),
                DropdownMenuItem<bool?>(value: false, child: Text('Rain-fed')),
              ],
              onChanged: onIrrigatedChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.crops,
    required this.onView,
    required this.onEdit,
    required this.onHarvest,
    required this.onIrrigate,
    required this.onDispatch,
    required this.onDelete,
  });

  final List<CropView> crops;
  final void Function(CropView) onView;
  final void Function(CropView) onEdit;
  final void Function(CropView) onHarvest;
  final void Function(CropView) onIrrigate;
  final void Function(CropView) onDispatch;
  final void Function(CropView) onDelete;

  // Flex weights per column. Sum is arbitrary — Row + Expanded
  // distributes the parent width proportionally, so the table fills the
  // entire card width regardless of content length. Picked to match
  // the screenshot's visual rhythm: name + destination wider, numeric
  // and date columns narrower, actions narrowest.
  static const _flexCrop = 4;
  static const _flexAcreage = 2;
  static const _flexPlanted = 3;
  static const _flexHarvest = 3;
  static const _flexStatus = 3;
  static const _flexDestination = 4;
  static const _flexActions = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: const [
              Expanded(flex: _flexCrop, child: _HeaderCell('CROP')),
              Expanded(flex: _flexAcreage, child: _HeaderCell('ACREAGE')),
              Expanded(flex: _flexPlanted, child: _HeaderCell('PLANTED')),
              Expanded(flex: _flexHarvest, child: _HeaderCell('HARVEST')),
              Expanded(flex: _flexStatus, child: _HeaderCell('STATUS')),
              Expanded(
                flex: _flexDestination,
                child: _HeaderCell('DESTINATION'),
              ),
              Expanded(
                flex: _flexActions,
                child: _HeaderCell('ACTIONS', alignEnd: true),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x14000000)),

        // Body rows.
        for (var i = 0; i < crops.length; i++) ...[
          InkWell(
            onTap: () => onView(crops[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: _flexCrop,
                    child: Text(
                      crops[i].name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _flexAcreage,
                    child: Text(
                      '${_fmtAcreage(crops[i].acreage)} ac',
                      style: _bodyStyle,
                    ),
                  ),
                  Expanded(
                    flex: _flexPlanted,
                    child: Text(_fmtPlanted(crops[i]), style: _bodyStyle),
                  ),
                  Expanded(
                    flex: _flexHarvest,
                    child: Text(_fmtHarvest(crops[i]), style: _bodyStyle),
                  ),
                  Expanded(
                    flex: _flexStatus,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CropStatusChip(status: crops[i].status),
                    ),
                  ),
                  Expanded(
                    flex: _flexDestination,
                    child: Text(
                      crops[i].destination ?? '—',
                      style: _bodyStyle,
                    ),
                  ),
                  Expanded(
                    flex: _flexActions,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _RowActions(
                        crop: crops[i],
                        onView: onView,
                        onEdit: onEdit,
                        onHarvest: onHarvest,
                        onIrrigate: onIrrigate,
                        onDispatch: onDispatch,
                        onDelete: onDelete,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i < crops.length - 1)
            const Divider(height: 1, color: Color(0x14000000)),
        ],
      ],
    );
  }
}

const _bodyStyle = TextStyle(fontSize: 14, color: Colors.black87);

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.alignEnd = false});
  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Color(0xFF7A7A7A),
      ),
    );
  }
}

class _MobileList extends StatelessWidget {
  const _MobileList({
    required this.crops,
    required this.onView,
    required this.onEdit,
    required this.onHarvest,
    required this.onIrrigate,
    required this.onDispatch,
    required this.onDelete,
  });

  final List<CropView> crops;
  final void Function(CropView) onView;
  final void Function(CropView) onEdit;
  final void Function(CropView) onHarvest;
  final void Function(CropView) onIrrigate;
  final void Function(CropView) onDispatch;
  final void Function(CropView) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in crops) ...[
          _CropCard(
            crop: c,
            onTap: () => onView(c),
            actions: _RowActions(
              crop: c,
              onView: onView,
              onEdit: onEdit,
              onHarvest: onHarvest,
              onIrrigate: onIrrigate,
              onDispatch: onDispatch,
              onDelete: onDelete,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({
    required this.crop,
    required this.onTap,
    required this.actions,
  });

  final CropView crop;
  final VoidCallback onTap;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
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
                    crop.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                CropStatusChip(status: crop.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_fmtAcreage(crop.acreage)} ac · ${crop.destination ?? "—"}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InlineMeta(
                    label: 'Planted',
                    value: _fmtPlanted(crop),
                  ),
                ),
                Expanded(
                  child: _InlineMeta(
                    label: 'Harvest',
                    value: _fmtHarvest(crop),
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

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.label, required this.value});
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
    required this.crop,
    required this.onView,
    required this.onEdit,
    required this.onHarvest,
    required this.onIrrigate,
    required this.onDispatch,
    required this.onDelete,
  });

  final CropView crop;
  final void Function(CropView) onView;
  final void Function(CropView) onEdit;
  final void Function(CropView) onHarvest;
  final void Function(CropView) onIrrigate;
  final void Function(CropView) onDispatch;
  final void Function(CropView) onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (key) {
        switch (key) {
          case 'view':
            onView(crop);
            break;
          case 'edit':
            onEdit(crop);
            break;
          case 'harvest':
            onHarvest(crop);
            break;
          case 'irrigate':
            onIrrigate(crop);
            break;
          case 'dispatch':
            onDispatch(crop);
            break;
          case 'delete':
            onDelete(crop);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'view',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.visibility_outlined, size: 18),
            title: Text('View details'),
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined, size: 18),
            title: Text('Edit crop'),
          ),
        ),
        PopupMenuItem(
          value: 'harvest',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.agriculture_outlined, size: 18),
            title: Text('Add harvest'),
          ),
        ),
        PopupMenuItem(
          value: 'irrigate',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.water_drop_outlined, size: 18),
            title: Text('Add irrigation'),
          ),
        ),
        PopupMenuItem(
          value: 'dispatch',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.local_shipping_outlined, size: 18),
            title: Text('Record dispatch'),
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

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pages,
    required this.onPage,
  });
  final int page;
  final int pages;
  final void Function(int) onPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $page of $pages'),
        IconButton(
          onPressed: page < pages ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
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
          Icon(Icons.spa_outlined, size: 36, color: Color(0xFFAAAAAA)),
          SizedBox(height: 8),
          Text(
            'No crops registered yet.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          SizedBox(height: 4),
          Text(
            'Tap "+ Add Crop" to log your first planting.',
            style: TextStyle(fontSize: 12, color: Colors.black45),
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

// ---------- formatting helpers ----------

String _fmtAcreage(double a) =>
    a == a.roundToDouble() ? a.toStringAsFixed(1) : a.toStringAsFixed(2);

String _fmtPlanted(CropView c) {
  if (c.isPerennial) return 'Perennial';
  if (c.plantedDate == null) return '—';
  return DateFormat('MMM yyyy').format(c.plantedDate!);
}

String _fmtHarvest(CropView c) {
  if (c.harvestFrequency != null && c.harvestFrequency!.isNotEmpty) {
    return c.harvestFrequency!;
  }
  if (c.expectedHarvest == null) return '—';
  return DateFormat('MMM yyyy').format(c.expectedHarvest!);
}
