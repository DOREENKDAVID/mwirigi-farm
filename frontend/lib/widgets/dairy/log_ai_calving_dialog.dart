import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// Modal `m-repro` from the HTML mockup, replicated exactly:
///
///   Row 1:  [ Cow tag ]   [ Event type (dropdown) ]
///   Row 2:  [ Date    ]   [ Semen / Bull          ]
///   Save / Cancel
///
/// Event type options (literal HTML order):
///   - Artificial Insemination → POST /reproduction { eventType: AI }
///   - Natural service         → POST /reproduction { eventType: AI }
///   - Calving                 → POST /reproduction { eventType: CALVING }
///   - Pregnancy confirmed     → POST /reproduction/confirm
///
/// Note: Natural service shares the AI event type because the schema does
/// not distinguish them today. The Semen / Bull field is reused for the
/// bull tag in the NS case (it goes into `sireCode`).
class LogAiCalvingDialog extends StatefulWidget {
  const LogAiCalvingDialog({super.key});

  @override
  State<LogAiCalvingDialog> createState() => _LogAiCalvingDialogState();
}

enum _EventChoice {
  artificialInsemination('Artificial Insemination'),
  naturalService('Natural service'),
  calving('Calving'),
  pregnancyConfirmed('Pregnancy confirmed');

  const _EventChoice(this.label);
  final String label;
}

class _LogAiCalvingDialogState extends State<LogAiCalvingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _bullController = TextEditingController();

  _EventChoice _choice = _EventChoice.artificialInsemination;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _tagController.dispose();
    _bullController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final tag = _tagController.text.trim();
      final bull = _bullController.text.trim();
      final dateIso = _date.toIso8601String();

      switch (_choice) {
        case _EventChoice.artificialInsemination:
        case _EventChoice.naturalService:
          await ApiService.createReproductionRecord({
            'eventType': 'AI',
            'tag': tag,
            'eventDate': dateIso,
            if (bull.isNotEmpty) 'sireCode': bull,
          });
          break;
        case _EventChoice.calving:
          await ApiService.createReproductionRecord({
            'eventType': 'CALVING',
            'tag': tag,
            'eventDate': dateIso,
          });
          break;
        case _EventChoice.pregnancyConfirmed:
          await ApiService.confirmReproductionPregnancy({
            'tag': tag,
            'checkDate': dateIso,
          });
          break;
      }

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
        'Log AI / Calving Record',
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
                  'Record insemination or calving event',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                // Row 1: Cow tag + Event type
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Cow tag',
                          hintText: 'MW-100',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Cow tag is required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<_EventChoice>(
                        initialValue: _choice,
                        decoration: const InputDecoration(
                          labelText: 'Event type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final c in _EventChoice.values)
                            DropdownMenuItem(value: c, child: Text(c.label)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(
                                () => _choice = v ?? _choice),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Row 2: Date + Semen / Bull
                Row(
                  children: [
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _bullController,
                        decoration: const InputDecoration(
                          labelText: 'Semen / Bull',
                          hintText: 'Semen code or bull tag',
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
}
