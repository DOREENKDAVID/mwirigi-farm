import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';

/// PATCH-only dialog for an individual sow.
///
/// Editable fields: status, dueDate, litterCount.
/// `Clear` next to status / due date sends null on submit (backend allows
/// nullable on both). Status may still be re-derived on the next read if
/// lifecycle events justify it — that's by design.
class EditSowDialog extends StatefulWidget {
  const EditSowDialog({super.key, required this.sow});

  final Sow sow;

  @override
  State<EditSowDialog> createState() => _EditSowDialogState();
}

class _EditSowDialogState extends State<EditSowDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _litterController;

  PigStatus? _status;
  bool _clearStatus = false;
  DateTime? _dueDate;
  bool _clearDueDate = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.sow.status;
    _dueDate = widget.sow.dueDate;
    _litterController = TextEditingController(
      text: widget.sow.litterCount.toString(),
    );
  }

  @override
  void dispose() {
    _litterController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final base = _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 2),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = picked;
        _clearDueDate = false;
      });
    }
  }

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};
    final litter = int.tryParse(_litterController.text.trim());

    if (_clearStatus) {
      patch['status'] = null;
    } else if (_status != widget.sow.status) {
      patch['status'] = _status?.wire;
    }

    if (_clearDueDate) {
      patch['dueDate'] = null;
    } else if (_dueDate != widget.sow.dueDate) {
      patch['dueDate'] = _dueDate?.toIso8601String();
    }

    if (litter != null && litter != widget.sow.litterCount) {
      patch['litterCount'] = litter;
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
      await ApiService.updatePig(widget.sow.id, patch);
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
        'Edit ${widget.sow.tag}',
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PigStatus?>(
                        initialValue: _clearStatus ? null : _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final s in PigStatus.values)
                            DropdownMenuItem<PigStatus?>(
                              value: s,
                              child: Text(s.label),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() {
                                  _status = v;
                                  _clearStatus = false;
                                }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                                _status = null;
                                _clearStatus = true;
                              }),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _submitting ? null : _pickDueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _clearDueDate || _dueDate == null
                                ? '—'
                                : DateFormat('d MMM yyyy').format(_dueDate!),
                            style: TextStyle(
                              color: (_clearDueDate || _dueDate == null)
                                  ? Colors.black45
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                                _dueDate = null;
                                _clearDueDate = true;
                              }),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _litterController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Litter count',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Litter count is required';
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Must be a non-negative integer';
                    if (n > 50) return 'Unrealistic value';
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
