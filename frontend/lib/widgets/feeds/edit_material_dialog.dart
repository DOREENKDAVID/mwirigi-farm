import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/feeds.dart';
import '../../core/service/api_service.dart';

/// Edits material metadata only (pack size, supplier, cost, reorder lead
/// time). Stock and daily-use are intentionally NOT editable here — they
/// have dedicated audit-trail flows (deliveries / consumption).
class EditMaterialDialog extends StatefulWidget {
  const EditMaterialDialog({super.key, required this.material});
  final FeedMaterial material;

  @override
  State<EditMaterialDialog> createState() => _EditMaterialDialogState();
}

class _EditMaterialDialogState extends State<EditMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _packSize;
  late final TextEditingController _supplier;
  late final TextEditingController _costPerKg;
  late final TextEditingController _leadTime;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _packSize = TextEditingController(text: widget.material.packSize);
    _supplier = TextEditingController(text: widget.material.supplier ?? '');
    _costPerKg = TextEditingController(
      text: widget.material.costPerKg?.toString() ?? '',
    );
    _leadTime = TextEditingController(
      text: widget.material.reorderLevelDays.toString(),
    );
  }

  @override
  void dispose() {
    _packSize.dispose();
    _supplier.dispose();
    _costPerKg.dispose();
    _leadTime.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final patch = <String, dynamic>{};
    final pack = _packSize.text.trim();
    if (pack.isNotEmpty && pack != widget.material.packSize) {
      patch['packSize'] = pack;
    }
    final supplier = _supplier.text.trim();
    if (supplier != (widget.material.supplier ?? '')) {
      patch['supplier'] = supplier.isEmpty ? null : supplier;
    }
    final costStr = _costPerKg.text.trim();
    final cost = costStr.isEmpty ? null : double.tryParse(costStr);
    if (cost != widget.material.costPerKg) {
      patch['costPerKg'] = cost;
    }
    final lead = int.tryParse(_leadTime.text.trim());
    if (lead != null && lead != widget.material.reorderLevelDays) {
      patch['reorderLevelDays'] = lead;
    }

    if (patch.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.updateFeedMaterial(widget.material.id, patch);
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
        'Edit — ${widget.material.name}',
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
                const Text(
                  'Update material metadata. Stock and daily use are managed via deliveries and consumption logs.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _packSize,
                  decoration: const InputDecoration(
                    labelText: 'Pack size',
                    hintText: 'e.g. 50 kg bag',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _supplier,
                  decoration: const InputDecoration(
                    labelText: 'Supplier',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _costPerKg,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Cost per kg',
                    prefixText: 'KSh ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _leadTime,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Reorder lead time',
                    suffixText: 'days',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Must be > 0';
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
