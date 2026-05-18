import 'package:flutter/material.dart';

import '../../core/service/api_service.dart';

/// "Add Treatment" modal — matches the HTML mockup field-for-field:
///   Animal tag · Unit (dropdown) · Diagnosis · Treatment · Start date · Attending vet
///
/// When opened from the Active Treatments table by tapping a "Pending
/// vet review" row, [initialTag] / [initialUnit] / [initialDiagnosis]
/// pre-populate the form so a vet doesn't have to retype what the
/// herd manager already entered.
class AddTreatmentDialog extends StatefulWidget {
  const AddTreatmentDialog({
    super.key,
    this.initialTag,
    this.initialUnit,
    this.initialDiagnosis,
  });

  final String? initialTag;
  final String? initialUnit;
  final String? initialDiagnosis;

  @override
  State<AddTreatmentDialog> createState() => _AddTreatmentDialogState();
}

class _AddTreatmentDialogState extends State<AddTreatmentDialog> {
  static const _units = <String>[
    'Dairy',
    'Piggery',
    'Layers',
    'Doopers',
    'Feedlot',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tagController;
  late final TextEditingController _diagnosisController;
  final _medicationController = TextEditingController();
  final _vetController = TextEditingController();

  late String _unit;
  DateTime _startDate = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController(text: widget.initialTag ?? '');
    _diagnosisController =
        TextEditingController(text: widget.initialDiagnosis ?? '');
    // Snap to a recognized unit; fall back to Dairy so the dropdown
    // doesn't hit assertion errors with an unknown value.
    _unit = _units.contains(widget.initialUnit)
        ? widget.initialUnit!
        : 'Dairy';
  }

  @override
  void dispose() {
    _tagController.dispose();
    _diagnosisController.dispose();
    _medicationController.dispose();
    _vetController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await ApiService.createHealthTreatment({
        'tag': _tagController.text.trim(),
        'unit': _unit,
        'diagnosis': _diagnosisController.text.trim(),
        'medication': _medicationController.text.trim(),
        'startDate': _startDate.toIso8601String(),
        if (_vetController.text.trim().isNotEmpty)
          'attendingVet': _vetController.text.trim(),
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
        'Add Treatment',
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
                  'Log an animal under treatment',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Animal tag *',
                          hintText: 'e.g. MW-050',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length < 2) return 'Tag is required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final u in _units)
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _unit = v ?? _unit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _diagnosisController,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis *',
                          hintText: 'e.g. Mastitis',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length < 2) return 'Diagnosis is required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _medicationController,
                        decoration: const InputDecoration(
                          labelText: 'Treatment *',
                          hintText: 'e.g. Amoxicillin',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length < 2) return 'Treatment is required';
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
                        onTap: _submitting ? null : _pickStartDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start date *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month, size: 18),
                          ),
                          child: Text(
                            _formatDate(_startDate),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vetController,
                        decoration: const InputDecoration(
                          labelText: 'Attending vet',
                          hintText: 'Dr. Omondi',
                          border: OutlineInputBorder(),
                        ),
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
