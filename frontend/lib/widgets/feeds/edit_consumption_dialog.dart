import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/feeds.dart';
import '../../core/service/api_service.dart';

/// "Edit consumption rates" form. The user enters quantity used over a
/// duration; the dialog previews the resulting daily-use rate (kg/day)
/// and the new days-of-stock-remaining figure live as they type.
///
/// On submit POSTs to /feeds/consumption — the backend creates a log row
/// and atomically updates FeedMaterial.dailyUseKg.
class EditConsumptionDialog extends StatefulWidget {
  const EditConsumptionDialog({super.key, required this.material});
  final FeedMaterial material;

  @override
  State<EditConsumptionDialog> createState() => _EditConsumptionDialogState();
}

class _EditConsumptionDialogState extends State<EditConsumptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityUsed = TextEditingController();
  final _duration = TextEditingController();
  final _notes = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _quantityUsed.dispose();
    _duration.dispose();
    _notes.dispose();
    super.dispose();
  }

  // Live preview values. Recomputed on every keystroke via setState in
  // the field onChanged. Returns null when the inputs aren't valid yet.
  ({double dailyUse, double? daysLeft, double reorderAt})? _preview() {
    final qty = double.tryParse(_quantityUsed.text.trim());
    final dur = int.tryParse(_duration.text.trim());
    if (qty == null || qty <= 0 || dur == null || dur <= 0) return null;
    final dailyUse = qty / dur;
    final stock = widget.material.stockOnHandKg;
    final daysLeft = dailyUse > 0 ? stock / dailyUse : null;
    final reorderAt = dailyUse * widget.material.reorderLevelDays;
    return (dailyUse: dailyUse, daysLeft: daysLeft, reorderAt: reorderAt);
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final qty = double.tryParse(_quantityUsed.text.trim());
    final dur = int.tryParse(_duration.text.trim());
    if (qty == null || dur == null) return;

    final body = <String, dynamic>{
      'materialId': widget.material.id,
      'quantityUsedKg': qty,
      'durationDays': dur,
    };
    if (_notes.text.trim().isNotEmpty) body['notes'] = _notes.text.trim();

    setState(() => _submitting = true);
    try {
      await ApiService.createFeedConsumption(body);
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
    final preview = _preview();

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'Update — ${widget.material.name}',
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
                  'Adjust consumption rate',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityUsed,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Quantity used *',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Over how many days? *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CalcPreview(material: widget.material, preview: preview),
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

class _CalcPreview extends StatelessWidget {
  const _CalcPreview({required this.material, required this.preview});
  final FeedMaterial material;
  final ({double dailyUse, double? daysLeft, double reorderAt})? preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFE9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: preview == null
          ? const Text(
              'Calculation: enter quantity used + duration to preview daily use.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          : RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Calculation: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        '${preview!.dailyUse.toStringAsFixed(2)} kg/day → ',
                  ),
                  TextSpan(
                    text: preview!.daysLeft == null
                        ? '— days'
                        : '${preview!.daysLeft!.toStringAsFixed(1)} days',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text: ' of stock remaining. Reorder when stock drops below ',
                  ),
                  TextSpan(
                    text:
                        '${preview!.reorderAt.toStringAsFixed(0)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
    );
  }
}
