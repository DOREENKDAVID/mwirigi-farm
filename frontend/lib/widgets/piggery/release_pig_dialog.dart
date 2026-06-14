import 'package:flutter/material.dart';

import '../../core/service/api_service.dart';

/// Release / sell dialog for an individual sow or boar.
///
/// Sends POST /piggery/pigs/:id/release. The caller should reload its list
/// on a `true` result since the pig will no longer appear in active registers.
class ReleasePigDialog extends StatefulWidget {
  const ReleasePigDialog({
    super.key,
    required this.pigId,
    required this.pigTag,
    required this.category, // "SOW" | "BOAR"
  });

  final String pigId;
  final String pigTag;
  final String category;

  @override
  State<ReleasePigDialog> createState() => _ReleasePigDialogState();
}

class _ReleasePigDialogState extends State<ReleasePigDialog> {
  static const _primary = Color(0xFF27500A);

  static const _reasons = [
    ('SOLD',     'Sold'),
    ('CULLED',   'Culled'),
    ('DIED',     'Died'),
    ('OLD_AGE',  'Old Age'),
    ('INJURED',  'Injured'),
    ('OTHER',    'Other'),
  ];

  final _formKey  = GlobalKey<FormState>();
  final _amountCtl = TextEditingController();
  final _notesCtl  = TextEditingController();

  String _reason      = 'SOLD';
  DateTime _releaseDate = DateTime.now();
  bool _submitting    = false;

  bool get _isSold => _reason == 'SOLD';

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _releaseDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'releaseReason': _reason,
        'releaseDate':   _releaseDate.toIso8601String(),
        if (_notesCtl.text.trim().isNotEmpty) 'releaseNotes': _notesCtl.text.trim(),
        if (_isSold && _amountCtl.text.trim().isNotEmpty)
          'releaseAmount': double.tryParse(_amountCtl.text.trim()) ?? 0.0,
      };
      await ApiService.releasePig(widget.pigId, body);
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
    final label = widget.category == 'SOW' ? 'Sow' : 'Boar';
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Release $label',
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tag: ${widget.pigTag}',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Reason dropdown
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason *',
                    border: OutlineInputBorder(),
                  ),
                  items: _reasons
                      .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _reason = v ?? _reason),
                ),
                const SizedBox(height: 14),
                // Sale amount (only shown when Sold)
                if (_isSold) ...[
                  TextFormField(
                    controller: _amountCtl,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Sale Amount (KES)',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                      prefixText: 'KES ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = double.tryParse(v.trim());
                      if (n == null || n < 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                // Release date
                InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Release Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month, size: 18),
                    ),
                    child: Text(
                      '${_releaseDate.day.toString().padLeft(2, '0')}/'
                      '${_releaseDate.month.toString().padLeft(2, '0')}/'
                      '${_releaseDate.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Notes
                TextFormField(
                  controller: _notesCtl,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional remarks',
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
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Release'),
        ),
      ],
    );
  }
}
