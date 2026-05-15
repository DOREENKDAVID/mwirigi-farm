import 'package:flutter/material.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';

/// PATCH-only dialog for an individual bull.
/// Editable fields: breed, currentWeight.
///
/// Updating currentWeight via this dialog also creates a WeightRecord on
/// the backend, so the audit trail stays coherent — no separate "log weight"
/// dance is needed for routine weight updates.
class EditBullDialog extends StatefulWidget {
  const EditBullDialog({super.key, required this.bull});

  final BullView bull;

  @override
  State<EditBullDialog> createState() => _EditBullDialogState();
}

class _EditBullDialogState extends State<EditBullDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _breedController;
  late final TextEditingController _weightController;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _breedController = TextEditingController(text: widget.bull.breed);
    _weightController = TextEditingController(
      text: widget.bull.currentWeight.toString(),
    );
  }

  @override
  void dispose() {
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};
    final newBreed = _breedController.text.trim();
    final newWeight = double.tryParse(_weightController.text.trim());

    if (newBreed.isNotEmpty && newBreed != widget.bull.breed) {
      patch['breed'] = newBreed;
    }
    if (newWeight != null && newWeight != widget.bull.currentWeight) {
      patch['currentWeight'] = newWeight;
    }
    return patch;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final patch = _buildPatch();
    if (patch.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.updateBull(widget.bull.id, patch);
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
        'Edit ${widget.bull.tag}',
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
                  controller: _breedController,
                  decoration: const InputDecoration(
                    labelText: 'Breed',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Breed is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Current weight (kg)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Current weight is required';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Must be > 0';
                    if (n > 2000) return 'Unrealistic value';
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'Updating current weight also adds an entry to the weight '
                  'history.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
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
