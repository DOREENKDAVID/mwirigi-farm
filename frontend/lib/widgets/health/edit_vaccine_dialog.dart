import 'package:flutter/material.dart';

import '../../core/models/health.dart';
import '../../core/service/api_service.dart';

/// Edit (or create the first) VaccinationRecord for a DB protocol row.
///
/// When [row.lastRecordId] is non-null the dialog PATCHes the existing
/// record. When it is null (no vaccination has ever been logged) the
/// dialog POSTs a new record using [row.protocolId].
class EditVaccineDialog extends StatefulWidget {
  const EditVaccineDialog({super.key, required this.row});
  final VaccinationRow row;

  @override
  State<EditVaccineDialog> createState() => _EditVaccineDialogState();
}

class _EditVaccineDialogState extends State<EditVaccineDialog> {
  static const _primary = Color(0xFF27500A);

  static const _statusOptions = ['DONE', 'DUE_NOW', 'OVERDUE'];
  static const _statusLabels = {'DONE': 'Done', 'DUE_NOW': 'Due', 'OVERDUE': 'Overdue'};

  static String _mapStatus(String s) {
    if (s == 'DONE') return 'DONE';
    if (s == 'OVERDUE') return 'OVERDUE';
    return 'DUE_NOW';
  }

  final _formKey = GlobalKey<FormState>();
  final _animalsController = TextEditingController();
  final _administeredByController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _dateDone;
  DateTime? _nextDueOverride;
  late String _statusOverride;
  bool _submitting = false;

  bool get _isCreate => widget.row.lastRecordId == null;

  @override
  void initState() {
    super.initState();
    _animalsController.text = widget.row.animals.toString();
    _administeredByController.text =
        widget.row.lastRecordAdministeredBy ?? '';
    _notesController.text = widget.row.lastRecordNotes ?? '';
    _dateDone = widget.row.lastDoneAt ?? DateTime.now();
    _nextDueOverride = widget.row.lastRecordNextDue;
    _statusOverride = _mapStatus(widget.row.status);
  }

  @override
  void dispose() {
    _animalsController.dispose();
    _administeredByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isNextDue}) async {
    final initial = isNextDue ? (_nextDueOverride ?? _dateDone) : _dateDone;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isNextDue) {
        _nextDueOverride = picked;
      } else {
        _dateDone = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final animalCount = int.tryParse(_animalsController.text.trim()) ?? 0;
    final administeredBy = _administeredByController.text.trim();
    final notes = _notesController.text.trim();

    setState(() => _submitting = true);
    try {
      if (_isCreate) {
        final body = <String, dynamic>{
          'animalCount': animalCount,
          'administeredAt': _dateDone.toIso8601String(),
          'nextDueOverride': _nextDueOverride?.toIso8601String(),
          'statusOverride': _statusOverride,
          if (administeredBy.isNotEmpty) 'administeredBy': administeredBy,
          if (notes.isNotEmpty) 'notes': notes,
        };
        // Brooder rows have no protocolId — send brooderId + vaccineName + dayOffset.
        if (widget.row.protocolId != null) {
          body['protocolId'] = widget.row.protocolId;
        } else {
          body['brooderId'] = widget.row.brooderId;
          body['vaccineName'] = widget.row.vaccine;
          body['dayOffset'] = widget.row.dayOffsetStart;
        }
        await ApiService.createHealthVaccination(body);
      } else {
        await ApiService.updateHealthVaccinationRecord(
          widget.row.lastRecordId!,
          {
            'animalCount': animalCount,
            'administeredAt': _dateDone.toIso8601String(),
            'nextDueOverride': _nextDueOverride?.toIso8601String(),
            'statusOverride': _statusOverride,
            'administeredBy': administeredBy.isNotEmpty ? administeredBy : null,
            'notes': notes.isNotEmpty ? notes : null,
          },
        );
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
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isCreate ? 'Log Vaccination' : 'Edit Vaccination Record',
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.row.vaccine,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
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
                // Animal type + Status row
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Animal Type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(
                          widget.row.unit,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(12, 8, 4, 8),
                        ),
                        child: DropdownButton<String>(
                          value: _statusOverride,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: _statusOptions
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      _statusLabels[s]!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ))
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (v) => setState(
                                  () => _statusOverride = v ?? _statusOverride),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Administered By
                TextFormField(
                  controller: _administeredByController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Administered By',
                    hintText: 'Vet / staff name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                // Animals count
                TextFormField(
                  controller: _animalsController,
                  keyboardType: TextInputType.number,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Animals *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter a number > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Date done + Next due side-by-side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _submitting
                            ? null
                            : () => _pickDate(isNextDue: false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date done *',
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.calendar_month, size: 18),
                          ),
                          child: Text(
                            _fmt(_dateDone),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _submitting
                            ? null
                            : () => _pickDate(isNextDue: true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Next due',
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.calendar_month, size: 18),
                          ),
                          child: Text(
                            _nextDueOverride == null
                                ? 'dd/mm/yyyy'
                                : _fmt(_nextDueOverride!),
                            style: TextStyle(
                              fontSize: 13,
                              color: _nextDueOverride == null
                                  ? Colors.black38
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Notes
                TextFormField(
                  controller: _notesController,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional remarks',
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
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _primary),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isCreate ? 'Log' : 'Save'),
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
