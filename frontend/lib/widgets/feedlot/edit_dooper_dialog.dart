import 'package:flutter/material.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';

/// PATCH-only dialog for an individual dooper. Mirrors EditBullDialog:
/// editable fields are `category` and `currentWeight`. ADG is derived
/// server-side from the new currentWeight against entryWeight.
class EditDooperDialog extends StatefulWidget {
  const EditDooperDialog({super.key, required this.sheep});

  final SheepView sheep;

  @override
  State<EditDooperDialog> createState() => _EditDooperDialogState();
}

class _EditDooperDialogState extends State<EditDooperDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late SheepCategory _category;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _category = widget.sheep.category;
    final initial =
        widget.sheep.currentWeight ?? widget.sheep.entryWeight;
    _weightController = TextEditingController(
      text: initial == null ? '' : initial.toString(),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};
    if (_category != widget.sheep.category) patch['category'] = _category.wire;

    final raw = _weightController.text.trim();
    if (raw.isNotEmpty) {
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed != widget.sheep.currentWeight) {
        patch['currentWeight'] = parsed;
      }
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
      await ApiService.updateSheep(widget.sheep.id, patch);
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
        'Edit ${widget.sheep.tag}',
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
                DropdownButtonFormField<SheepCategory>(
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
                      : (v) => setState(() => _category = v ?? _category),
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
                    if (v.isEmpty) return null;
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Must be > 0';
                    if (n > 500) return 'Unrealistic value';
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'ADG (kg/day) is recalculated automatically from entry '
                  'weight, current weight, and days on feed.',
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
