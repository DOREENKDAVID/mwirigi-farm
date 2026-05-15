import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// Logs an irrigation event for an existing crop.
/// POSTs to /api/ngushish/irrigation. Pops `true` on success.
class AddIrrigationDialog extends StatefulWidget {
  const AddIrrigationDialog({
    super.key,
    required this.cropId,
    required this.cropName,
  });

  final String cropId;
  final String cropName;

  @override
  State<AddIrrigationDialog> createState() => _AddIrrigationDialogState();
}

class _AddIrrigationDialogState extends State<AddIrrigationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _duration = TextEditingController();
  final _waterSource = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _duration.dispose();
    _waterSource.dispose();
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

    final body = <String, dynamic>{
      'cropId': widget.cropId,
      'irrigationDate': _date.toIso8601String(),
    };
    final dur = int.tryParse(_duration.text.trim());
    if (dur != null && dur > 0) body['durationMinutes'] = dur;
    if (_waterSource.text.trim().isNotEmpty) {
      body['waterSource'] = _waterSource.text.trim();
    }
    if (_notes.text.trim().isNotEmpty) body['notes'] = _notes.text.trim();

    setState(() => _submitting = true);
    try {
      await ApiService.createNgushishIrrigation(body);
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
        'Log irrigation — ${widget.cropName}',
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
                InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Irrigation date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    suffixText: 'min',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return null;
                    final n = int.tryParse(s);
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _waterSource,
                  decoration: const InputDecoration(
                    labelText: 'Water source',
                    hintText: 'e.g. Borehole, river, dam',
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
