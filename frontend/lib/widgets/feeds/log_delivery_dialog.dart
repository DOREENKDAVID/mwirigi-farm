import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/feeds.dart';
import '../../core/service/api_service.dart';

/// Logs an incoming raw-material delivery. The backend atomically bumps
/// `stockOnHandKg` on the chosen material in the same transaction.
///
/// If [preselected] is provided, the material dropdown locks to that row
/// (used when the dialog is opened from a per-row "Log delivery" action).
class LogDeliveryDialog extends StatefulWidget {
  const LogDeliveryDialog({
    super.key,
    required this.materials,
    this.preselected,
  });

  final List<FeedMaterial> materials;
  final FeedMaterial? preselected;

  @override
  State<LogDeliveryDialog> createState() => _LogDeliveryDialogState();
}

class _LogDeliveryDialogState extends State<LogDeliveryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _supplier = TextEditingController();
  final _invoice = TextEditingController();
  final _unitCost = TextEditingController();
  final _notes = TextEditingController();

  FeedMaterial? _selected;
  DateTime _delivered = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselected ??
        (widget.materials.isNotEmpty ? widget.materials.first : null);
    if (_selected?.supplier != null) {
      _supplier.text = _selected!.supplier!;
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _supplier.dispose();
    _invoice.dispose();
    _unitCost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _delivered,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) setState(() => _delivered = picked);
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || _selected == null) return;
    final qty = double.tryParse(_quantity.text.trim());
    if (qty == null || qty <= 0) return;

    final body = <String, dynamic>{
      'materialId': _selected!.id,
      'quantityKg': qty,
      'deliveredAt': _delivered.toIso8601String(),
    };
    if (_supplier.text.trim().isNotEmpty) {
      body['supplier'] = _supplier.text.trim();
    }
    if (_invoice.text.trim().isNotEmpty) {
      body['invoiceNumber'] = _invoice.text.trim();
    }
    final cost = double.tryParse(_unitCost.text.trim());
    if (cost != null && cost >= 0) body['unitCost'] = cost;
    if (_notes.text.trim().isNotEmpty) body['notes'] = _notes.text.trim();

    setState(() => _submitting = true);
    try {
      await ApiService.createFeedDelivery(body);
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
      title: const Text(
        'Log Feed Delivery',
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
                  'Add stock when materials arrive',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<FeedMaterial>(
                  initialValue: _selected,
                  decoration: const InputDecoration(
                    labelText: 'Material *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in widget.materials)
                      DropdownMenuItem(
                        value: m,
                        child: Text('${m.name} (${m.packSize})'),
                      ),
                  ],
                  onChanged: widget.preselected != null || _submitting
                      ? null
                      : (v) => setState(() {
                            _selected = v;
                            if (v?.supplier != null && _supplier.text.isEmpty) {
                              _supplier.text = v!.supplier!;
                            }
                          }),
                  validator: (v) => v == null ? 'Pick a material' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Quantity received *',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter quantity > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _supplier,
                  decoration: const InputDecoration(
                    labelText: 'Supplier',
                    hintText: 'e.g. Pembe Flour Mills',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _invoice,
                  decoration: const InputDecoration(
                    labelText: 'Invoice number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _unitCost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Unit cost',
                    prefixText: 'KSh ',
                    suffixText: '/ kg',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date received',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('d MMM yyyy').format(_delivered)),
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
              : const Text('Save delivery'),
        ),
      ],
    );
  }
}
