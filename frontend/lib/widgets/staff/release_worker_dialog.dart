import 'package:flutter/material.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';

/// Release / terminate a worker. Mirrors the Cow release workflow:
/// the record is preserved with status=RELEASED; nothing is deleted.
class ReleaseWorkerDialog extends StatefulWidget {
  const ReleaseWorkerDialog({super.key, required this.staff});
  final Staff staff;

  @override
  State<ReleaseWorkerDialog> createState() => _ReleaseWorkerDialogState();
}

class _ReleaseWorkerDialogState extends State<ReleaseWorkerDialog> {
  static const _red = Color(0xFFB52C2B);
  static const _redBg = Color(0xFFFEE2E2);

  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();

  late DateTime _releaseDate;
  String _reason = 'CONTRACT_ENDED';
  bool _submitting = false;

  static const _reasons = <String, String>{
    'CONTRACT_ENDED': 'Contract Ended',
    'RESIGNED': 'Resigned',
    'DISMISSED': 'Dismissed',
    'RETIRED': 'Retired',
    'SEASONAL_ENDED': 'Seasonal Work Ended',
    'OTHER': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _releaseDate = DateTime.now();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate,
      firstDate: widget.staff.createdAt ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _releaseDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.releaseStaffMember(widget.staff.id, {
        'releaseDate': _releaseDate.toIso8601String(),
        'releaseReason': _reason,
        if (_notesCtrl.text.trim().isNotEmpty)
          'releaseNotes': _notesCtrl.text.trim(),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Release Worker',
            style: TextStyle(
              color: _red,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.staff.fullName,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
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
                // Warning banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _redBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'The employee record will be preserved. '
                    'Their status will be marked as Released and they '
                    'will no longer appear in active staff lists.',
                    style: TextStyle(fontSize: 12, color: _red, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                // Release date
                InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Release Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month, size: 18),
                    ),
                    child: Text(
                      _fmt(_releaseDate),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Reason
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Release Reason *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in _reasons.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _reason = v ?? _reason),
                  validator: (v) =>
                      v == null ? 'Select a reason' : null,
                ),
                const SizedBox(height: 14),
                // Notes
                TextFormField(
                  controller: _notesCtrl,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional — additional context',
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
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _red),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Release'),
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
