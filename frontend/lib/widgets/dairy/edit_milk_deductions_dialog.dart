import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';

/// Edit the calf + household deductions used by the milk session
/// summary panel. The calf count auto-detects from CALVING events in
/// the last 120 days — the dialog shows that count as a hint and lets
/// a manager override it (or leave the override blank to keep
/// auto-detect). Persists to FarmConfig via PATCH /dairy/config/deductions.
class EditMilkDeductionsDialog extends StatefulWidget {
  const EditMilkDeductionsDialog({super.key, required this.summary});

  final DayNetSummary summary;

  @override
  State<EditMilkDeductionsDialog> createState() =>
      _EditMilkDeductionsDialogState();
}

class _EditMilkDeductionsDialogState extends State<EditMilkDeductionsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _calf;
  late final TextEditingController _household;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _calf = TextEditingController(
      text: widget.summary.calfOverridden
          ? widget.summary.calfDeduction.toStringAsFixed(
              widget.summary.calfDeduction % 1 == 0 ? 0 : 1,
            )
          : '',
    );
    _household = TextEditingController(
      text: widget.summary.householdDeduction.toStringAsFixed(
        widget.summary.householdDeduction % 1 == 0 ? 0 : 1,
      ),
    );
  }

  @override
  void dispose() {
    _calf.dispose();
    _household.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final calfText = _calf.text.trim();
      final householdText = _household.text.trim();
      await ApiService.updateMilkDeductions({
        // Empty → 0, which the backend interprets as "revert override
        // and use the auto-detected calf count".
        'calfDeduction': calfText.isEmpty ? 0 : double.parse(calfText),
        if (householdText.isNotEmpty)
          'householdDeduct': double.parse(householdText),
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
    final autoCount = widget.summary.calfCount;
    return AlertDialog(
      title: const Text(
        'Edit milk deductions',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Auto-detected: $autoCount ${autoCount == 1 ? "calf" : "calves"} '
                  'under 4 months. Leave the override blank to use this count.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF27500A),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _calf,
                enabled: !_submitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Calf deduction (litres)',
                  hintText: 'Auto: ${autoCount.toStringAsFixed(0)} × 1L = '
                      '${autoCount.toStringAsFixed(0)} L',
                  helperText: 'Total litres reserved for calves under 4mo',
                  border: const OutlineInputBorder(),
                ),
                validator: _validateOptionalNumber,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _household,
                enabled: !_submitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Household usage (litres) *',
                  helperText: 'Daily litres set aside for the household',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 1000) {
                    return 'Must be between 0 and 1000';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF27500A),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
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

  String? _validateOptionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < 0 || n > 1000) return 'Must be between 0 and 1000';
    return null;
  }
}
