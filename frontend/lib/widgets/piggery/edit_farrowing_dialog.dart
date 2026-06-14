import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';

/// Edit an existing farrowing record.
/// Pre-fills every field from [record]; saves a PATCH to /piggery/farrowing/:id.
///
/// Fields editable:
///   Farrowing date  | Service date
///   Winners         | Fatteners  | Beaconners
///   Total alive (auto)           | Dead piglets
///   Remarks
class EditFarrowingDialog extends StatefulWidget {
  const EditFarrowingDialog({super.key, required this.record});
  final FarrowingRecordView record;

  @override
  State<EditFarrowingDialog> createState() => _EditFarrowingDialogState();
}

class _EditFarrowingDialogState extends State<EditFarrowingDialog> {
  static const _primary  = Color(0xFF27500A);
  static const _txt2     = Color(0xFF6B7770);
  static const _winColor = Color(0xFF7A2E00);
  static const _fatColor = Color(0xFF854F0B);
  static const _beaColor = Color(0xFF27500A);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _winCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _beaCtrl;
  late final TextEditingController _deadCtrl;
  late final TextEditingController _remarksCtrl;

  late DateTime  _date;
  DateTime?      _service;
  bool           _submitting = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _date    = r.date;
    _service = r.service;
    _winCtrl    = TextEditingController(text: r.winners    != null ? '${r.winners}'    : '');
    _fatCtrl    = TextEditingController(text: r.fatteners  != null ? '${r.fatteners}'  : '');
    _beaCtrl    = TextEditingController(text: r.beaconners != null ? '${r.beaconners}' : '');
    _deadCtrl   = TextEditingController(text: '${r.pigletsDead}');
    _remarksCtrl = TextEditingController(text: r.remarks ?? '');

    _winCtrl.addListener(_recalc);
    _fatCtrl.addListener(_recalc);
    _beaCtrl.addListener(_recalc);
  }

  @override
  void dispose() {
    _winCtrl.removeListener(_recalc);
    _fatCtrl.removeListener(_recalc);
    _beaCtrl.removeListener(_recalc);
    _winCtrl.dispose();
    _fatCtrl.dispose();
    _beaCtrl.dispose();
    _deadCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _recalc() => setState(() {});

  int get _alive {
    final w = int.tryParse(_winCtrl.text.trim())  ?? 0;
    final f = int.tryParse(_fatCtrl.text.trim())  ?? 0;
    final b = int.tryParse(_beaCtrl.text.trim())  ?? 0;
    return w + f + b;
  }

  Future<void> _pickFarrowing() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 4),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickService() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _service ?? _date.subtract(const Duration(days: 114)),
      firstDate: DateTime(_date.year - 4),
      lastDate: _date,
    );
    if (picked != null && mounted) setState(() => _service = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final winners    = int.tryParse(_winCtrl.text.trim());
    final fatteners  = int.tryParse(_fatCtrl.text.trim());
    final beaconners = int.tryParse(_beaCtrl.text.trim());
    final dead       = int.tryParse(_deadCtrl.text.trim()) ?? 0;

    setState(() => _submitting = true);
    try {
      await ApiService.updateFarrowing(widget.record.id, {
        'date':        _date.toIso8601String(),
        if (_service != null) 'service': _service!.toIso8601String(),
        'winners':     winners,
        'fatteners':   fatteners,
        'beaconners':  beaconners,
        'pigletsDead': dead,
        'remarks': _remarksCtrl.text.trim().isEmpty
            ? null
            : _remarksCtrl.text.trim(),
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
    final sowLabel = widget.record.sowTag ?? widget.record.sowId ?? '—';
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Farrowing Record',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sow $sowLabel',
                  style: const TextStyle(fontSize: 12, color: _txt2),
                ),
                const SizedBox(height: 18),

                // Dates row
                _TwoCol(
                  left: _DateField(
                    label: 'Farrowing date *',
                    value: _date,
                    onTap: _submitting ? null : _pickFarrowing,
                  ),
                  right: _DateField(
                    label: 'Service date',
                    value: _service,
                    onTap: _submitting ? null : _pickService,
                    placeholder: 'Not recorded',
                  ),
                ),
                const SizedBox(height: 22),

                const Text(
                  'LITTER CATEGORIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: Color(0x14000000)),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 460;
                    final fields = [
                      _CategoryField(label: 'WINNERS',    color: _winColor, controller: _winCtrl),
                      _CategoryField(label: 'FATTENERS',  color: _fatColor, controller: _fatCtrl),
                      _CategoryField(
                        label: 'BEACONNERS',
                        color: _beaColor,
                        controller: _beaCtrl,
                        helper: 'Target: 100/month',
                      ),
                    ];
                    if (narrow) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 12),
                          fields[1],
                          const SizedBox(height: 12),
                          fields[2],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[1]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[2]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Total alive (auto) + Dead piglets
                _TwoCol(
                  left: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Total alive (auto)'),
                      const SizedBox(height: 6),
                      Container(
                        height: 52,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF5E3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x14000000)),
                        ),
                        child: Text(
                          _alive == 0 ? '' : '$_alive',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  right: _NumberField(
                    label: 'Dead piglets',
                    controller: _deadCtrl,
                    hint: '0',
                  ),
                ),
                const SizedBox(height: 16),

                _FieldLabel('Remarks'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _remarksCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    hint: 'Observations, health notes, etc.',
                  ),
                ),

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('✓  Save Changes'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _txt2,
                        side: const BorderSide(color: Color(0x33000000)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  static const _txt3 = Color(0xFF99A39B);

  static InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _txt3),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x33000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x33000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      );
}

// ── Local helpers (reuse shared layout widgets from log_farrowing_dialog) ──

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color ?? const Color(0xFF6B7770),
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
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
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
  });
  final String label;
  final DateTime? value;
  final VoidCallback? onTap;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33000000)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? DateFormat('dd/MM/yyyy').format(value!)
                        : (placeholder ?? '—'),
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null ? Colors.black87 : const Color(0xFF99A39B),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today,
                    size: 16, color: Color(0xFF6B7770)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.hint,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _EditFarrowingDialogState._inputDecoration(hint: hint),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return null;
            final n = int.tryParse(v);
            if (n == null || n < 0) return 'Non-negative integer';
            return null;
          },
        ),
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.label,
    required this.color,
    required this.controller,
    this.helper,
  });
  final String label;
  final Color color;
  final TextEditingController controller;
  final String? helper;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label, color: color),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _EditFarrowingDialogState._inputDecoration(hint: '0'),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return null;
            final n = int.tryParse(v);
            if (n == null || n < 0) return 'Non-negative integer';
            return null;
          },
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B))),
        ],
      ],
    );
  }
}
