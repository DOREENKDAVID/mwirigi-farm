// Register / log a harvest event for a Ngusishi block.
//
// Persistence: writes the core harvest row via POST /api/ngushish/harvests
// and folds the extras (buyer, transport, storage, priority, assigned
// workers) into the harvest's `notes` payload until the backend grows
// dedicated columns.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/ngushish.dart';
import '../../core/service/api_service.dart';

class RegisterHarvestDialog extends StatefulWidget {
  const RegisterHarvestDialog({
    super.key,
    required this.blocks,
    this.initialBlock,
  });

  final List<CropView> blocks;
  final CropView? initialBlock;

  @override
  State<RegisterHarvestDialog> createState() => _RegisterHarvestDialogState();
}

class _RegisterHarvestDialogState extends State<RegisterHarvestDialog> {
  static const _primary = Color(0xFF27500A);

  static const _statuses = [
    ('URGENT', '🔴 Urgent'),
    ('SOON', '🟡 Soon'),
    ('SCHEDULED', '🟢 Scheduled'),
    ('PLANT_SOON', '🟡 Plant soon'),
    ('HARVESTED', '✅ Harvested'),
  ];

  static const _priorities = [
    'Immediate',
    'High',
    'Medium',
    'Normal',
    'Plan',
  ];

  static const _yieldUnits = [
    'Bags',
    'Crates',
    'Tons',
    'Kilograms',
    'Pieces',
  ];

  final _formKey = GlobalKey<FormState>();
  final _yieldController = TextEditingController();
  final _buyerController = TextEditingController();
  final _storageController = TextEditingController();
  final _notesController = TextEditingController();

  CropView? _block;
  String _status = 'SCHEDULED';
  String _priority = 'Normal';
  String _yieldUnit = 'Crates';
  DateTime _harvestDate = DateTime.now();
  bool _transportRequired = false;
  final Set<String> _workersSelected = <String>{};

  List<String> _workers = const [];
  bool _loadingWorkers = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _block = widget.initialBlock ??
        (widget.blocks.isNotEmpty ? widget.blocks.first : null);
    _loadWorkers();
  }

  @override
  void dispose() {
    _yieldController.dispose();
    _buyerController.dispose();
    _storageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      final raw = await ApiService.getDairyWorkers();
      final names = raw
          .whereType<Map>()
          .map((m) => (m['name'] ?? m['fullName'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _workers = names;
        _loadingWorkers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingWorkers = false);
    }
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (_block == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a block')),
      );
      return;
    }

    setState(() => _submitting = true);

    // Convert the entered yield to kilograms so the backend keeps a
    // single canonical column. Bags/crates fall back to count semantics
    // when no conversion is known.
    final yieldAmt = double.tryParse(_yieldController.text.trim()) ?? 0;
    final quantityKg = switch (_yieldUnit) {
      'Tons' => yieldAmt * 1000,
      'Kilograms' => yieldAmt,
      _ => yieldAmt, // bags/crates/pieces — store as raw count
    };

    final meta = {
      'kind': 'HARVEST',
      'status': _status,
      'priority': _priority,
      'estimatedYield': yieldAmt,
      'yieldUnit': _yieldUnit,
      'buyer': _buyerController.text.trim(),
      'transportRequired': _transportRequired,
      'storageDestination': _storageController.text.trim(),
      'assignedWorkers': _workersSelected.toList(),
    }..removeWhere((_, v) =>
        (v is String && v.isEmpty) || (v is List && v.isEmpty));

    final notesPayload = StringBuffer(_notesController.text.trim());
    if (notesPayload.isNotEmpty) notesPayload.write('\n');
    notesPayload.write(jsonEncode(meta));

    final body = <String, dynamic>{
      'cropId': _block!.id,
      'quantityKg': quantityKg,
      'harvestDate': _harvestDate.toIso8601String(),
      'notes': notesPayload.toString(),
    };

    try {
      await ApiService.createNgushishHarvest(body);
      // If the block is still flagged READY, mark it harvested so the
      // planner pulls it out of the urgent bucket on next refresh.
      if (_status == 'HARVESTED' && _block!.status == CropStatus.ready) {
        try {
          await ApiService.updateNgushishCrop(_block!.id, {
            'status': 'HARVESTED',
          });
        } catch (_) {
          // Best-effort — don't block the dialog close on the side-effect.
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('🌾', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Log Harvest',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _block == null
                      ? 'Records yield against the chosen block.'
                      : 'Block ${_block!.block ?? "—"} · ${_block!.name} '
                          '· ${_block!.acreage} ac',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 18),
                _Field(
                  label: 'BLOCK *',
                  child: DropdownButtonFormField<CropView>(
                    initialValue: _block,
                    isExpanded: true,
                    decoration: _decoration(),
                    items: [
                      for (final b in widget.blocks)
                        DropdownMenuItem(
                          value: b,
                          child: Text(
                            '${b.block ?? "—"} · ${b.name} · ${b.acreage} ac',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _block = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'HARVEST STATUS *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: _decoration(),
                      items: [
                        for (final (wire, label) in _statuses)
                          DropdownMenuItem(value: wire, child: Text(label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                  right: _Field(
                    label: 'PRIORITY *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      isExpanded: true,
                      decoration: _decoration(),
                      items: [
                        for (final p in _priorities)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _priority = v ?? _priority),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'HARVEST DATE *',
                    child: _DateField(
                      value: _harvestDate,
                      enabled: !_submitting,
                      format: dateFmt,
                      onPick: (d) => setState(() => _harvestDate = d),
                    ),
                  ),
                  right: _Field(
                    label: 'ESTIMATED YIELD *',
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _yieldController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _decoration(hint: 'e.g. 80'),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              final n = double.tryParse(s);
                              if (n == null || n <= 0) return 'Enter yield';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            initialValue: _yieldUnit,
                            isExpanded: true,
                            decoration: _decoration(),
                            items: [
                              for (final u in _yieldUnits)
                                DropdownMenuItem(value: u, child: Text(u)),
                            ],
                            onChanged: _submitting
                                ? null
                                : (v) => setState(
                                    () => _yieldUnit = v ?? _yieldUnit),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'ASSIGNED WORKERS',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0x22000000)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _loadingWorkers
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Loading workers…',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7A7A7A),
                                )),
                          )
                        : _workers.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('No workers available',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7A7A7A),
                                    )),
                              )
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final w in _workers)
                                    FilterChip(
                                      label: Text(w),
                                      selected: _workersSelected.contains(w),
                                      onSelected: _submitting
                                          ? null
                                          : (sel) {
                                              setState(() {
                                                if (sel) {
                                                  _workersSelected.add(w);
                                                } else {
                                                  _workersSelected.remove(w);
                                                }
                                              });
                                            },
                                    ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'BUYER / MARKET',
                    child: TextFormField(
                      controller: _buyerController,
                      decoration: _decoration(
                        hint: 'e.g. Marigiti / Local agent / Wholesale',
                      ),
                    ),
                  ),
                  right: _Field(
                    label: 'STORAGE DESTINATION',
                    child: TextFormField(
                      controller: _storageController,
                      decoration: _decoration(
                        hint: 'e.g. Cold room / Bagged on-farm / Direct dispatch',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'TRANSPORT REQUIRED?',
                  child: SwitchListTile.adaptive(
                    value: _transportRequired,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _transportRequired = v),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _transportRequired
                          ? 'Yes — arrange transport'
                          : 'No — buyer collects',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _Field(
                  label: 'NOTES / ACTIONS',
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: _decoration(
                      hint:
                          "e.g. 'Harvest today. Contact buyer immediately.', "
                          "'Dry before bagging.'",
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.agriculture_outlined, size: 16),
                      label: _submitting
                          ? const Text('Saving…')
                          : const Text('Log Harvest'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF555555),
                        side: const BorderSide(color: Color(0x33000000)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: _primary, width: 1.6),
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF7A7A7A),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.format,
    required this.onPick,
    required this.enabled,
  });
  final DateTime value;
  final DateFormat format;
  final ValueChanged<DateTime> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 3),
              );
              if (picked != null) onPick(picked);
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0x22000000)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0x22000000)),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: Color(0xFF555555),
            ),
          ),
        ),
        child: Text(
          format.format(value),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }
}
