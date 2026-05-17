import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/layers_unit.dart';
import '../../core/service/api_service.dart';

/// Edit (revise) an allocation plan row. Each save creates a new
/// AllocationPlan revision server-side — the latest revision per
/// type wins on read — and writes an AuditLog row in the same
/// transaction. Restricted to CEO + LAYERS_MANAGER at the endpoint.
class AllocationEditDialog extends StatefulWidget {
  const AllocationEditDialog({
    super.key,
    required this.brooderId,
    required this.existing,
  });

  final String brooderId;
  /// Current latest row per type — used to pre-fill the form so the
  /// editor sees the "current" values and only diffs them.
  final List<AllocationRow> existing;

  @override
  State<AllocationEditDialog> createState() => _AllocationEditDialogState();
}

class _AllocationEditDialogState extends State<AllocationEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _birds = TextEditingController();
  final _description = TextEditingController();
  final _reason = TextEditingController();
  String _type = 'POL_SALE';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _applyTypeDefaults();
  }

  void _applyTypeDefaults() {
    final current = widget.existing.firstWhere(
      (r) => r.type == _type,
      orElse: () => AllocationRow(
        id: '',
        type: _type,
        birds: 0,
        description: '',
        cycleId: '',
        createdAt: DateTime.now(),
      ),
    );
    _birds.text = current.birds == 0 ? '' : current.birds.toString();
    _description.text = current.description;
  }

  @override
  void dispose() {
    _birds.dispose();
    _description.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createAllocationPlan({
        'brooderId': widget.brooderId,
        'type': _type,
        'birds': int.parse(_birds.text),
        'description': _description.text.trim(),
        'reason':
            _reason.text.trim().isEmpty ? null : _reason.text.trim(),
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
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.edit_note, color: Color(0xFF27500A), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Revise allocation plan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'A new revision is created on save. Previous rows are kept for the audit trail.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF27500A)),
                  ),
                ),
                const SizedBox(height: 14),
                _label('ALLOCATION TYPE'),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: _inputDec(),
                  items: const [
                    DropdownMenuItem(
                      value: 'POL_SALE',
                      child: Text('Point-of-lay sale'),
                    ),
                    DropdownMenuItem(
                      value: 'REPLACEMENT',
                      child: Text('Replacement'),
                    ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _type = v;
                            _applyTypeDefaults();
                          });
                        },
                ),
                const SizedBox(height: 14),
                _label('BIRDS *'),
                TextFormField(
                  controller: _birds,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDec(hint: 'e.g. 5000'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _label('DESCRIPTION *'),
                TextFormField(
                  controller: _description,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: _inputDec(
                    hint: _type == 'POL_SALE'
                        ? 'e.g. Sale at point-of-lay (POL pullets)'
                        : 'e.g. Replace Houses A & B (2,000 each)',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _label('REASON (audit log)'),
                TextFormField(
                  controller: _reason,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: _inputDec(
                    hint: 'Why this revision? Recorded in the audit trail.',
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
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 16),
          label: const Text('Save revision'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF27500A),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Colors.black54,
          ),
        ),
      );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFEFEDE6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
      );
}
