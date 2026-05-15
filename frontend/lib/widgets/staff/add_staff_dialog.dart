import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/service/api_service.dart';

/// "Add Staff Member" modal — matches the HTML mockup field-for-field.
///
///   Row 1:  [ Full name ]   [ Role ]
///   Row 2:  [ Unit (optional dept) ]   [ Daily rate (KSh) ]
///   Save · Cancel
///
/// On success, shows the temporary password the backend generated so the
/// admin can hand it to the new staff member. Pops `true` to trigger a
/// dashboard refresh.
class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({super.key});

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  // Map from the role-label text the user types (or unit selection) to
  // the backend Role enum. New staff default to WORKER unless the
  // typed role contains a clear manager keyword.
  static const _roleEnumByKeyword = <String, String>{
    'ceo': 'CEO',
    'admin': 'ADMIN',
    'vet': 'VET',
    'dairy manager': 'DAIRY_MANAGER',
    'layers manager': 'LAYERS_MANAGER',
    'piggery manager': 'PIGGERY_MANAGER',
    'feedlot': 'FEEDLOT_MANAGER',
    'feed manager': 'FEEDS_MANAGER',
    'store': 'STORE_MANAGER',
  };

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleLabelController = TextEditingController();
  final _rateController = TextEditingController(text: '900');

  String _unit = 'Dairy';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _roleLabelController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  String _resolveRoleEnum(String label) {
    final lc = label.toLowerCase();
    for (final entry in _roleEnumByKeyword.entries) {
      if (lc.contains(entry.key)) return entry.value;
    }
    return 'WORKER';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rateStr = _rateController.text.trim();
    final rate = rateStr.isEmpty ? null : double.tryParse(rateStr);
    final roleLabel = _roleLabelController.text.trim();

    setState(() => _submitting = true);
    try {
      final result = await ApiService.createStaffMember({
        'fullName': _nameController.text.trim(),
        // Backend accepts the enum; the human-readable label flows
        // through `department` so the payroll row's Role column shows
        // exactly what the admin typed (e.g. "Dairy Worker").
        'role': _resolveRoleEnum(roleLabel),
        'department': _unit,
        'roleLabel': roleLabel,
        'salaryType': 'DAILY',
        if (rate != null) 'dailyRate': rate,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _showTempPassword(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showTempPassword(Map<String, dynamic> result) {
    final tempPassword = result['tempPassword']?.toString() ?? '';
    final staff = (result['staff'] as Map?) ?? const {};
    final email = staff['email']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Staff added — temporary password',
          style: TextStyle(color: Color(0xFF27500A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: $email', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Password: ',
                  style: TextStyle(fontSize: 13),
                ),
                SelectableText(
                  tempPassword,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  iconSize: 16,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: tempPassword),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'They will be prompted to change this on first login. '
              'Hand it over now — it won\'t be shown again.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Add Staff Member',
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
                  'Register a new employee',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full name *',
                          hintText: 'e.g. James Mwangi',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length < 2) return 'Full name is required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Role is free-text per the HTML mockup ("e.g. Dairy
                    // Worker") — it's the human-readable title, not the
                    // permission role. The DB role enum is derived from
                    // unit + role-text on the backend.
                    Expanded(
                      child: TextFormField(
                        controller: _roleLabelController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Role *',
                          hintText: 'e.g. Dairy Worker',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length < 2) return 'Role is required';
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
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Dairy', child: Text('Dairy')),
                          DropdownMenuItem(value: 'Piggery', child: Text('Piggery')),
                          DropdownMenuItem(value: 'Layers', child: Text('Layers')),
                          DropdownMenuItem(value: 'Feedlot', child: Text('Feedlot')),
                          DropdownMenuItem(value: 'Feeds', child: Text('Feeds')),
                          DropdownMenuItem(value: 'Ngushish', child: Text('Ngushish')),
                          DropdownMenuItem(value: 'All units', child: Text('All units')),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _unit = v ?? _unit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rateController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Daily rate (KSh) *',
                          hintText: '900',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Daily rate is required';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Must be > 0';
                          return null;
                        },
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
              : const Text('Add Staff'),
        ),
      ],
    );
  }
}
