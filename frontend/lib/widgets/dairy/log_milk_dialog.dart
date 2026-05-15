import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// Modal form that records a milk session for a single cow.
/// POSTs to /api/dairy/milk. Pops `true` on success.
///
/// Backend accepts AM | MID | PM. The HTML mockup only surfaces AM and PM,
/// so MID is intentionally not in the dropdown — re-add a third option here
/// if mid-day sessions ever become part of the workflow.
class LogMilkDialog extends StatefulWidget {
  const LogMilkDialog({super.key});

  @override
  State<LogMilkDialog> createState() => _LogMilkDialogState();
}

class _LogMilkDialogState extends State<LogMilkDialog> {
  static const _sessions = [
    ('AM', 'AM (Morning)'),
    ('PM', 'PM (Evening)'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _litresController = TextEditingController();

  String _session = 'AM';
  DateTime _date = DateTime.now();

  bool _submitting = false;

  @override
  void dispose() {
    _tagController.dispose();
    _litresController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final litres = double.tryParse(_litresController.text);
    if (litres == null) return;

    setState(() => _submitting = true);
    try {
      await ApiService.createMilkRecord({
        'tag': _tagController.text.trim(),
        'litres': litres,
        'session': _session,
        'date': _date.toIso8601String(),
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
    const primary = Color(0xFF27500A);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Log Milk Session',
        style: TextStyle(
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
                const Text(
                  "Enter today's milk yield",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _session,
                        decoration: const InputDecoration(
                          labelText: 'Session',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final (wire, label) in _sessions)
                            DropdownMenuItem(value: wire, child: Text(label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _session = v ?? 'AM'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _submitting ? null : _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(DateFormat('d MMM yyyy').format(_date)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _tagController,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Cow tag',
                    hintText: 'e.g. MW-001',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Cow tag is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _litresController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Litres',
                    hintText: 'e.g. 22',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Litres is required';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Must be greater than 0';
                    if (n > 100) return 'Unrealistic value';
                    return null;
                  },
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
