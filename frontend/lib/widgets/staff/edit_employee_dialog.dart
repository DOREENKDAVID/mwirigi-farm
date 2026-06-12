import 'package:flutter/material.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';

/// Edit an employee's mutable HR fields.
/// Calls PATCH /staff/:id — only sends fields that changed.
class EditEmployeeDialog extends StatefulWidget {
  const EditEmployeeDialog({super.key, required this.staff});
  final Staff staff;

  @override
  State<EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<EditEmployeeDialog> {
  static const _primary = Color(0xFF27500A);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deptCtrl;
  late final TextEditingController _jobTitleCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _dailyRateCtrl;
  late final TextEditingController _monthlyCtrl;
  String? _salaryType;
  bool _submitting = false;

  static const _departments = [
    'Dairy', 'Layers', 'Piggery', 'Feedlot',
    'Admin', 'Feeds', 'Ngushish',
  ];

  static const _salaryTypes = ['DAILY', 'MONTHLY'];

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _deptCtrl = TextEditingController(text: s.department ?? '');
    _jobTitleCtrl = TextEditingController(text: s.jobTitle ?? '');
    _phoneCtrl = TextEditingController(text: s.phoneNumber ?? '');
    _dailyRateCtrl =
        TextEditingController(text: s.dailyRate?.toString() ?? '');
    _monthlyCtrl =
        TextEditingController(text: s.monthlySalary?.toString() ?? '');
    _salaryType = s.salaryType ?? 'DAILY';
  }

  @override
  void dispose() {
    _deptCtrl.dispose();
    _jobTitleCtrl.dispose();
    _phoneCtrl.dispose();
    _dailyRateCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final patch = <String, dynamic>{};
    final dept = _deptCtrl.text.trim();
    final jobTitle = _jobTitleCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final daily = double.tryParse(_dailyRateCtrl.text.trim());
    final monthly = double.tryParse(_monthlyCtrl.text.trim());

    if (dept != (widget.staff.department ?? '')) {
      patch['department'] = dept.isEmpty ? null : dept;
    }
    if (jobTitle != (widget.staff.jobTitle ?? '')) {
      patch['jobTitle'] = jobTitle.isEmpty ? null : jobTitle;
    }
    if (phone != (widget.staff.phoneNumber ?? '')) {
      patch['phoneNumber'] = phone.isEmpty ? null : phone;
    }
    if (_salaryType != widget.staff.salaryType) {
      patch['salaryType'] = _salaryType;
    }
    if (daily != null && daily != widget.staff.dailyRate?.toDouble()) {
      patch['dailyRate'] = daily;
    }
    if (monthly != null && monthly != widget.staff.monthlySalary?.toDouble()) {
      patch['monthlySalary'] = monthly;
    }

    if (patch.isEmpty) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    try {
      await ApiService.updateStaff(widget.staff.id, patch);
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
            'Edit Employee',
            style: TextStyle(
              color: _primary,
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Department — dropdown + free text fallback
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _departments.contains(_deptCtrl.text)
                            ? _deptCtrl.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— None —')),
                          for (final d in _departments)
                            DropdownMenuItem(value: d, child: Text(d)),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(
                                () => _deptCtrl.text = v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Job title
                TextFormField(
                  controller: _jobTitleCtrl,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Job Title',
                    hintText: 'e.g. Dairy Supervisor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                // Phone number
                TextFormField(
                  controller: _phoneCtrl,
                  enabled: !_submitting,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '07XX XXX XXX',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                // Salary type + rate
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _salaryType,
                        decoration: const InputDecoration(
                          labelText: 'Salary type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final t in _salaryTypes)
                            DropdownMenuItem(
                              value: t,
                              child: Text(
                                  t == 'DAILY' ? 'Daily rate' : 'Monthly'),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _salaryType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _salaryType == 'MONTHLY'
                          ? TextFormField(
                              controller: _monthlyCtrl,
                              enabled: !_submitting,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Monthly (KSh)',
                                border: OutlineInputBorder(),
                              ),
                            )
                          : TextFormField(
                              controller: _dailyRateCtrl,
                              enabled: !_submitting,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Daily rate (KSh)',
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
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
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
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
