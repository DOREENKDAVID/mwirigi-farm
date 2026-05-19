import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// "Log Farmers Choice dispatch" dialog. Captures the audit-trail
/// fields from the HTML mockup (date · ref · pens · count · category ·
/// ageRange · driver · notes) plus an optional amount that, when > 0,
/// triggers a Revenue row server-side in the same transaction.
class LogFcDispatchDialog extends StatefulWidget {
  const LogFcDispatchDialog({super.key});

  @override
  State<LogFcDispatchDialog> createState() => _LogFcDispatchDialogState();
}

class _LogFcDispatchDialogState extends State<LogFcDispatchDialog> {
  static const _primary = Color(0xFF27500A);

  final _formKey   = GlobalKey<FormState>();
  final _ref       = TextEditingController();
  final _pens      = TextEditingController();
  final _count     = TextEditingController();
  final _ageRange  = TextEditingController();
  final _driver    = TextEditingController();
  final _notes     = TextEditingController();
  final _amount    = TextEditingController();

  static const _categories = ['Beaconners', 'Fatteners', 'Winners', 'Mixed'];
  String _category = 'Beaconners';

  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _ref.dispose();
    _pens.dispose();
    _count.dispose();
    _ageRange.dispose();
    _driver.dispose();
    _notes.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final amount = double.tryParse(_amount.text.trim()) ?? 0;
      await ApiService.createFcDelivery({
        'date': _date.toIso8601String(),
        'ref': _ref.text.trim(),
        'pens': _pens.text.trim(),
        'count': int.parse(_count.text.trim()),
        'category': _category,
        if (_ageRange.text.trim().isNotEmpty)
          'ageRange': _ageRange.text.trim(),
        'driver': _driver.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (amount > 0) 'amount': amount,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    final isMobile = MediaQuery.of(context).size.width < 560;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Text('🚚', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Log Farmers Choice dispatch',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'One row per truck-load that left for FC. When you '
                  'enter an amount, a Revenue line is auto-created in '
                  'the finance ledger.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7770)),
                ),
                const SizedBox(height: 18),

                _Row2(
                  isMobile: isMobile,
                  left: _field(
                    label: 'DATE *',
                    child: InkWell(
                      onTap: _submitting ? null : _pickDate,
                      child: InputDecorator(
                        decoration: _inputDec(),
                        child: Row(
                          children: [
                            Expanded(child: Text(df.format(_date))),
                            const Icon(Icons.event,
                                size: 18, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                  right: _field(
                    label: 'REFERENCE *',
                    child: TextFormField(
                      controller: _ref,
                      enabled: !_submitting,
                      decoration: _inputDec(hint: 'FC-2026-05A'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _Row2(
                  isMobile: isMobile,
                  left: _field(
                    label: 'PENS *',
                    child: TextFormField(
                      controller: _pens,
                      enabled: !_submitting,
                      decoration: _inputDec(hint: 'F2 through F10'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  right: _field(
                    label: 'COUNT *',
                    child: TextFormField(
                      controller: _count,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      decoration: _inputDec(hint: '45'),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Whole number > 0';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _Row2(
                  isMobile: isMobile,
                  left: _field(
                    label: 'CATEGORY *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: _inputDec(),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _category = v ?? _category),
                    ),
                  ),
                  right: _field(
                    label: 'AGE RANGE',
                    child: TextFormField(
                      controller: _ageRange,
                      enabled: !_submitting,
                      decoration: _inputDec(hint: '5-6mo'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _Row2(
                  isMobile: isMobile,
                  left: _field(
                    label: 'DRIVER / HANDLER *',
                    child: TextFormField(
                      controller: _driver,
                      enabled: !_submitting,
                      decoration: _inputDec(hint: 'Sam Bwira'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  right: _field(
                    label: 'AMOUNT (KSH)',
                    hint:
                        'Optional — when set, a Revenue line is added.',
                    child: TextFormField(
                      controller: _amount,
                      enabled: !_submitting,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDec(hint: 'e.g. 180000'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _field(
                  label: 'NOTES',
                  child: TextFormField(
                    controller: _notes,
                    enabled: !_submitting,
                    maxLines: 2,
                    decoration: _inputDec(
                      hint:
                          'e.g. Cleared 9 pens of fully-finished beaconners. '
                          'Slap tattoos applied at truck.',
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
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
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Log dispatch'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Widget _field({
    required String label,
    required Widget child,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF6B7770),
            ),
          ),
        ),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
      );
}

class _Row2 extends StatelessWidget {
  const _Row2({
    required this.left,
    required this.right,
    required this.isMobile,
  });
  final Widget left;
  final Widget right;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}
