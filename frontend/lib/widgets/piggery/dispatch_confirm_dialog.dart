import 'package:flutter/material.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';

/// Shown when a manager taps a PendingDispatch batch in the Farmers pill.
/// Pre-fills pens, count, category from the batch; manager adds date, ref,
/// driver, and optional amount. On submit → POST /piggery/dispatch/confirm.
class DispatchConfirmDialog extends StatefulWidget {
  const DispatchConfirmDialog({super.key, required this.batch});
  final PendingDispatchBatch batch;

  @override
  State<DispatchConfirmDialog> createState() => _DispatchConfirmDialogState();
}

class _DispatchConfirmDialogState extends State<DispatchConfirmDialog> {
  static const _primary = Color(0xFF27500A);

  final _formKey   = GlobalKey<FormState>();
  final _refCtrl   = TextEditingController();
  final _driverCtrl= TextEditingController();
  final _ageCtrl   = TextEditingController();
  final _amountCtrl= TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date       = DateTime.now();
  bool     _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.batch.ageRange != null) _ageCtrl.text = widget.batch.ageRange!;
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _driverCtrl.dispose();
    _ageCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      await ApiService.confirmDispatch({
        'pendingDispatchId': widget.batch.id,
        'date':    _date.toIso8601String(),
        if (_refCtrl.text.trim().isNotEmpty)    'ref':      _refCtrl.text.trim(),
        if (_driverCtrl.text.trim().isNotEmpty) 'driver':   _driverCtrl.text.trim(),
        if (_ageCtrl.text.trim().isNotEmpty)    'ageRange': _ageCtrl.text.trim(),
        if (amount > 0)                         'amount':   amount,
        if (_notesCtrl.text.trim().isNotEmpty)  'notes':    _notesCtrl.text.trim(),
      });
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
    final pensLabel = widget.batch.pens.join(', ');
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🚚  Confirm Dispatch',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pens $pensLabel · ${widget.batch.totalCount} pigs · ${widget.batch.category}',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
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
                // Read-only summary chip strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF3E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _Chip(label: 'Pens',     value: pensLabel),
                      const SizedBox(width: 20),
                      _Chip(label: 'Head',     value: '${widget.batch.totalCount}'),
                      const SizedBox(width: 20),
                      _Chip(label: 'Category', value: widget.batch.category),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Date picker
                InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dispatch Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month, size: 18),
                    ),
                    child: Text(_fmt(_date), style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 14),
                // Ref + Driver row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _refCtrl,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'FC Reference',
                          hintText: 'FC-2026-05A',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _driverCtrl,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Driver / Handler',
                          hintText: 'Sam Bwira',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Age range + Amount row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageCtrl,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Age Range',
                          hintText: '5-6 mo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _amountCtrl,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (KES)',
                          hintText: 'e.g. 180000',
                          border: OutlineInputBorder(),
                          prefixText: 'KES ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesCtrl,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'e.g. Slap tattoos applied at truck',
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
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _primary),
          icon: _submitting
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.local_shipping_outlined, size: 16),
          label: const Text('Log Dispatch'),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: Colors.black54, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
