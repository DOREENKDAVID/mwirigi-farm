import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// Logs a harvest event for an existing crop. POSTs to /api/ngushish/harvests.
/// Pops `true` on success.
class AddHarvestDialog extends StatefulWidget {
  const AddHarvestDialog({
    super.key,
    required this.cropId,
    required this.cropName,
  });

  final String cropId;
  final String cropName;

  @override
  State<AddHarvestDialog> createState() => _AddHarvestDialogState();
}

class _AddHarvestDialogState extends State<AddHarvestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _qualityGrade = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _quantity.dispose();
    _qualityGrade.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final qty = double.tryParse(_quantity.text.trim());
    if (qty == null || qty <= 0) return;

    final body = <String, dynamic>{
      'cropId': widget.cropId,
      'quantityKg': qty,
      'harvestDate': _date.toIso8601String(),
    };
    if (_qualityGrade.text.trim().isNotEmpty) {
      body['qualityGrade'] = _qualityGrade.text.trim();
    }
    if (_notes.text.trim().isNotEmpty) body['notes'] = _notes.text.trim();

    setState(() => _submitting = true);
    try {
      await ApiService.createNgushishHarvest(body);
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
    const primary = Color(0xFF27500A);
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'Log harvest — ${widget.cropName}',
        style: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter a quantity > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Harvest date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _qualityGrade,
                  decoration: const InputDecoration(
                    labelText: 'Quality grade',
                    hintText: 'e.g. A, B, mixed',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
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
