import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/ngushish.dart';
import '../../core/service/api_service.dart';

/// Modal form to register a new crop on Ngushish. POSTs to
/// /api/ngushish/crops and pops `true` on success so the caller can
/// refresh the register table + KPIs.
///
/// Mirrors the "Add Crop — Ngushish" sheet in the HTML mockup, with the
/// addition of irrigated / perennial switches and notes — all of which the
/// backend already supports. Perennial flips `expectedHarvest` off and
/// requires a `harvestFrequency` instead.
class AddCropDialog extends StatefulWidget {
  const AddCropDialog({super.key});

  @override
  State<AddCropDialog> createState() => _AddCropDialogState();
}

class _AddCropDialogState extends State<AddCropDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _acreage = TextEditingController();
  final _destination = TextEditingController();
  final _harvestFrequency = TextEditingController();
  final _notes = TextEditingController();

  CropStatus _status = CropStatus.active;
  DateTime? _planted;
  DateTime? _expectedHarvest;
  bool _isPerennial = false;
  bool _irrigated = false;

  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _acreage.dispose();
    _destination.dispose();
    _harvestFrequency.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool planted}) async {
    final now = DateTime.now();
    final initial =
        (planted ? _planted : _expectedHarvest) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        if (planted) {
          _planted = picked;
        } else {
          _expectedHarvest = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final acreage = double.tryParse(_acreage.text.trim());
    if (acreage == null || acreage <= 0) return;

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'acreage': acreage,
      'status': _status.wire,
      'isPerennial': _isPerennial,
      'irrigated': _irrigated,
    };
    if (_planted != null) {
      body['plantedDate'] = _planted!.toIso8601String();
    }
    if (!_isPerennial && _expectedHarvest != null) {
      body['expectedHarvest'] = _expectedHarvest!.toIso8601String();
    }
    if (_isPerennial && _harvestFrequency.text.trim().isNotEmpty) {
      body['harvestFrequency'] = _harvestFrequency.text.trim();
    }
    if (_destination.text.trim().isNotEmpty) {
      body['destination'] = _destination.text.trim();
    }
    if (_notes.text.trim().isNotEmpty) {
      body['notes'] = _notes.text.trim();
    }

    setState(() => _submitting = true);
    try {
      await ApiService.createNgushishCrop(body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    final dateFmt = DateFormat('d MMM yyyy');

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Add Crop — Ngushish',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Log a new crop or planting batch',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Crop *',
                    hintText: 'e.g. Cabbages',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Crop name is required';
                    if (s.length > 80) return 'Max 80 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _acreage,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Acreage *',
                    hintText: 'e.g. 1.5',
                    suffixText: 'ac',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter acreage > 0';
                    if (n > 10000) return 'Acreage too large';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _DateField(
                  label: 'Date planted',
                  value: _planted,
                  format: dateFmt,
                  onTap: _submitting ? null : () => _pickDate(planted: true),
                  onClear: _planted == null
                      ? null
                      : () => setState(() => _planted = null),
                ),
                const SizedBox(height: 14),
                if (!_isPerennial)
                  _DateField(
                    label: 'Expected harvest',
                    value: _expectedHarvest,
                    format: dateFmt,
                    onTap:
                        _submitting ? null : () => _pickDate(planted: false),
                    onClear: _expectedHarvest == null
                        ? null
                        : () => setState(() => _expectedHarvest = null),
                  )
                else
                  TextFormField(
                    controller: _harvestFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Harvest frequency *',
                      hintText: 'e.g. Monthly',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (!_isPerennial) return null;
                      if ((v ?? '').trim().isEmpty) {
                        return 'Required for perennials';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<CropStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in CropStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) =>
                          setState(() => _status = v ?? CropStatus.active),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _destination,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    hintText: 'e.g. Stopover shop',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Irrigated'),
                  subtitle: const Text(
                    'Counts toward irrigated area KPI',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  value: _irrigated,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _irrigated = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Perennial'),
                  subtitle: const Text(
                    'No fixed harvest date; uses frequency instead',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  value: _isPerennial,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() {
                            _isPerennial = v;
                            if (v) _expectedHarvest = null;
                          }),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: primary),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// Tappable read-only date field with an optional clear button. Used for
// optional dates (planted / expected harvest).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.format,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final DateFormat format;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? 'Pick a date' : format.format(value!),
          style: TextStyle(
            color: value == null ? Colors.black45 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
