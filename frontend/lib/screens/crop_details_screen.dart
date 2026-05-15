import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models/ngushish.dart';
import '../core/service/api_service.dart';
import '../widgets/ngushish/add_dispatch_dialog.dart';
import '../widgets/ngushish/add_harvest_dialog.dart';
import '../widgets/ngushish/add_irrigation_dialog.dart';
import '../widgets/ngushish/crop_status_chip.dart';

/// Crop details + activity timeline. 4 tabs:
///   Overview / Irrigation / Harvests / Dispatches
///
/// Loads from GET /ngushish/crops/:id which returns the crop plus its
/// (latest 100) related rows.
class CropDetailsScreen extends StatefulWidget {
  const CropDetailsScreen({super.key, required this.cropId});
  final String cropId;

  @override
  State<CropDetailsScreen> createState() => _CropDetailsScreenState();
}

class _CropDetailsScreenState extends State<CropDetailsScreen> {
  Future<CropDetails>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CropDetails> _load() async {
    final raw = await ApiService.getNgushishCropById(widget.cropId);
    return CropDetails.fromJson(raw);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _addHarvest(CropDetails d) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AddHarvestDialog(cropId: d.crop.id, cropName: d.crop.name),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _addIrrigation(CropDetails d) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AddIrrigationDialog(cropId: d.crop.id, cropName: d.crop.name),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _addDispatch(CropDetails d) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddDispatchDialog(
        cropId: d.crop.id,
        cropName: d.crop.name,
        defaultDestination: d.crop.destination,
      ),
    );
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primary,
        title: const Text(
          'Crop Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<CropDetails>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snap.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snap.data!;
          return DefaultTabController(
            length: 4,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: Column(
                children: [
                  _Header(crop: data.crop),
                  const TabBar(
                    labelColor: primary,
                    indicatorColor: primary,
                    unselectedLabelColor: Colors.black54,
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Irrigation'),
                      Tab(text: 'Harvests'),
                      Tab(text: 'Dispatches'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OverviewTab(details: data),
                        _IrrigationTab(
                          details: data,
                          onAdd: () => _addIrrigation(data),
                        ),
                        _HarvestsTab(
                          details: data,
                          onAdd: () => _addHarvest(data),
                        ),
                        _DispatchesTab(
                          details: data,
                          onAdd: () => _addDispatch(data),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.crop});
  final CropView crop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  crop.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF27500A),
                  ),
                ),
              ),
              CropStatusChip(status: crop.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${crop.acreage.toStringAsFixed(crop.acreage == crop.acreage.roundToDouble() ? 1 : 2)} ac · ${crop.destination ?? "No destination set"}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.details});
  final CropDetails details;

  @override
  Widget build(BuildContext context) {
    final c = details.crop;
    final dateFmt = DateFormat('d MMM yyyy');

    final rows = <(String, String)>[
      ('Acreage', '${c.acreage} ac'),
      ('Status', c.status.label),
      ('Perennial', c.isPerennial ? 'Yes' : 'No'),
      ('Irrigated', c.irrigated ? 'Yes' : 'No'),
      if (c.irrigationType != null) ('Irrigation type', c.irrigationType!),
      if (c.plantedDate != null)
        ('Planted', dateFmt.format(c.plantedDate!)),
      if (!c.isPerennial && c.expectedHarvest != null)
        ('Expected harvest', dateFmt.format(c.expectedHarvest!)),
      if (c.isPerennial && (c.harvestFrequency ?? '').isNotEmpty)
        ('Harvest frequency', c.harvestFrequency!),
      if (c.destination != null) ('Destination', c.destination!),
      ('Total harvests', '${details.harvests.length}'),
      ('Total dispatches', '${details.dispatches.length}'),
      if (c.notes != null && c.notes!.isNotEmpty) ('Notes', c.notes!),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _OverviewRow(label: rows[i].$1, value: rows[i].$2),
                if (i < rows.length - 1)
                  const Divider(height: 1, color: Color(0x14000000)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _IrrigationTab extends StatelessWidget {
  const _IrrigationTab({required this.details, required this.onAdd});
  final CropDetails details;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return _ActivityList(
      onAdd: onAdd,
      addLabel: 'Add irrigation',
      emptyLabel: 'No irrigation events logged.',
      isEmpty: details.irrigation.isEmpty,
      items: [
        for (final i in details.irrigation)
          _ActivityItem(
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF0E5E50),
            title: i.waterSource ?? 'Irrigation event',
            subtitle: dateFmt.format(i.irrigationDate),
            trailing: i.durationMinutes == null ? null : '${i.durationMinutes} min',
            note: i.notes,
          ),
      ],
    );
  }
}

class _HarvestsTab extends StatelessWidget {
  const _HarvestsTab({required this.details, required this.onAdd});
  final CropDetails details;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final qty = NumberFormat.decimalPattern();
    return _ActivityList(
      onAdd: onAdd,
      addLabel: 'Log harvest',
      emptyLabel: 'No harvests recorded yet.',
      isEmpty: details.harvests.isEmpty,
      items: [
        for (final h in details.harvests)
          _ActivityItem(
            icon: Icons.agriculture_outlined,
            color: const Color(0xFF27500A),
            title: '${qty.format(h.quantityKg)} kg',
            subtitle: dateFmt.format(h.harvestDate),
            trailing: h.qualityGrade,
            note: h.notes,
          ),
      ],
    );
  }
}

class _DispatchesTab extends StatelessWidget {
  const _DispatchesTab({required this.details, required this.onAdd});
  final CropDetails details;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final qty = NumberFormat.decimalPattern();
    final money = NumberFormat.currency(symbol: 'KSh ', decimalDigits: 0);
    return _ActivityList(
      onAdd: onAdd,
      addLabel: 'Record dispatch',
      emptyLabel: 'No dispatches recorded yet.',
      isEmpty: details.dispatches.isEmpty,
      items: [
        for (final d in details.dispatches)
          _ActivityItem(
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF854F0B),
            title:
                '${qty.format(d.quantityKg)} kg → ${d.destination}',
            subtitle:
                '${dateFmt.format(d.dispatchDate)}${d.buyerName == null ? '' : ' · ${d.buyerName}'}',
            trailing: money.format(d.revenue),
            note: d.notes,
          ),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.onAdd,
    required this.addLabel,
    required this.emptyLabel,
    required this.isEmpty,
    required this.items,
  });

  final VoidCallback onAdd;
  final String addLabel;
  final String emptyLabel;
  final bool isEmpty;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_note_outlined,
                      size: 36, color: Color(0xFFAAAAAA)),
                  const SizedBox(height: 8),
                  Text(emptyLabel,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
          )
        else
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: items,
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: onAdd,
            backgroundColor: const Color(0xFF27500A),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.note,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
