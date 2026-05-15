import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// "Add Bull to Feedlot" modal — matches the HTML mockup field-for-field.
///
///   Row 1:  [ Tag ]          [ Breed ]
///   Row 2:  [ Entry date ]   [ Entry weight (kg) ]
///   Save · Cancel
class AddBullDialog extends StatefulWidget {
  const AddBullDialog({super.key});

  @override
  State<AddBullDialog> createState() => _AddBullDialogState();
}

class _AddBullDialogState extends State<AddBullDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();

  DateTime _entryDate = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _tagController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _entryDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final weight = double.parse(_weightController.text.trim());

    setState(() => _submitting = true);
    try {
      await ApiService.createBull({
        'tag': _tagController.text.trim(),
        'breed': _breedController.text.trim(),
        'entryDate': _entryDate.toIso8601String(),
        'entryWeight': weight,
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
        'Add Bull to Feedlot',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Register a new feedlot entry',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Tag',
                          hintText: 'BL-013',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Tag is required';
                          if (v.length > 20) return 'Tag too long';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _breedController,
                        decoration: const InputDecoration(
                          labelText: 'Breed',
                          hintText: 'e.g. Boran',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Breed is required';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _submitting ? null : _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Entry date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            DateFormat('d MMM yyyy').format(_entryDate),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Entry weight (kg)',
                          hintText: 'e.g. 275',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Entry weight is required';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Must be > 0';
                          if (n > 2000) return 'Unrealistic value';
                          return null;
                        },
                      ),
                    ),
                  ],
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
