import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';

/// "Add Dooper" modal — same field layout as Add Bull (Tag, Breed-equivalent,
/// Entry date, Entry weight). Here "Breed" is replaced with "Category"
/// (Ewe / Ram / Lamb) since doopers don't have breeds in this model.
///
///   Row 1:  [ Tag ]          [ Category ]
///   Row 2:  [ Entry date ]   [ Entry weight (kg) ]
///   Save · Cancel
class AddDooperDialog extends StatefulWidget {
  const AddDooperDialog({super.key});

  @override
  State<AddDooperDialog> createState() => _AddDooperDialogState();
}

class _AddDooperDialogState extends State<AddDooperDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _weightController = TextEditingController();

  SheepCategory _category = SheepCategory.ewe;
  DateTime _entryDate = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _tagController.dispose();
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

    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);

    setState(() => _submitting = true);
    try {
      await ApiService.createSheep({
        'tag': _tagController.text.trim(),
        'category': _category.wire,
        'entryDate': _entryDate.toIso8601String(),
        if (weight != null) 'entryWeight': weight,
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
        'Add Dooper to Flock',
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
                  'Register a new sheep into the doopers flock',
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
                          hintText: 'DR-085',
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
                      child: DropdownButtonFormField<SheepCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final c in SheepCategory.values)
                            DropdownMenuItem(value: c, child: Text(c.label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) =>
                                setState(() => _category = v ?? _category),
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
                          hintText: 'optional',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Must be > 0';
                          if (n > 500) return 'Unrealistic value';
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
